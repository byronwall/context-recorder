import type { AppEnv } from "./env";
import { HttpError, toHex } from "./http";
import { contentTypeOf, type Manifest } from "./manifest";

/**
 * Store: content-addressed blobs in R2 (`blobs/<sha256>`) plus each session's current manifest in D1.
 *
 * D1 `blobs` is an index of verified R2 objects, so `push` and `commit` are one query instead of one
 * R2 HEAD per file (a long session has thousands of thumbnails). Rows are written only after the hash
 * has been checked, and removed together with the R2 object.
 */

/** Largest single-request upload. Larger files use multipart. 90 MiB keeps under the 100 MB body limit. */
export const MAX_SINGLE_PUT = 90 * 1024 * 1024;
/** Unreferenced blobs older than this are swept at commit/delete (abandoned pushes). */
const ABANDONED_AFTER_MS = 24 * 60 * 60 * 1000;

export const blobKey = (sha: string) => `blobs/${sha}`;

export interface SessionRow {
  id: string;
  title: string;
  recordedAt: string;
  duration: number;
  markCount: number;
  size: number;
  poster: string | null;
  pushedAt: string;
  /** The Mac that pushed it (manifest `machine`); null for older pushes. */
  machine: string | null;
}

interface SessionDbRow {
  id: string;
  title: string;
  recorded_at: string;
  duration: number;
  mark_count: number;
  size: number;
  poster: string | null;
  pushed_at: string;
  machine: string | null;
  manifest?: string;
  manifest_sha256?: string;
}

export interface FileRow {
  path: string;
  sha256: string;
  size: number;
  type: string;
}

const toRow = (r: SessionDbRow): SessionRow => ({
  id: r.id,
  title: r.title,
  recordedAt: r.recorded_at,
  duration: r.duration,
  markCount: r.mark_count,
  size: r.size,
  poster: r.poster,
  pushedAt: r.pushed_at,
  machine: r.machine,
});

/** The session row (?1) holds manifest ?2: the commit's upsert went through. */
const HOLDS_NEW = "EXISTS (SELECT 1 FROM sessions WHERE id = ?1 AND manifest_sha256 = ?2)";

const ROW_COLUMNS = "id, title, recorded_at, duration, mark_count, size, poster, pushed_at, json_extract(manifest, '$.machine') AS machine";

export class Store {
  constructor(private readonly env: AppEnv) {}

  // ---- blobs ----

  /** The subset of `shas` with no verified blob yet. */
  async missing(shas: string[]): Promise<string[]> {
    const unique = [...new Set(shas)];
    if (!unique.length) return [];
    const { results } = await this.env.DB.prepare(
      "SELECT b.sha256 FROM blobs b JOIN json_each(?1) j ON b.sha256 = j.value",
    )
      .bind(JSON.stringify(unique))
      .all<{ sha256: string }>();
    const have = new Set(results.map((r) => r.sha256));
    return unique.filter((s) => !have.has(s));
  }

  async blobSizes(shas: string[]): Promise<Map<string, number>> {
    const { results } = await this.env.DB.prepare(
      "SELECT b.sha256, b.size FROM blobs b JOIN json_each(?1) j ON b.sha256 = j.value",
    )
      .bind(JSON.stringify([...new Set(shas)]))
      .all<{ sha256: string; size: number }>();
    return new Map(results.map((r) => [r.sha256, r.size]));
  }

  private async recordBlob(sha: string, size: number): Promise<void> {
    await this.env.DB.prepare(
      "INSERT INTO blobs (sha256, size, created_at) VALUES (?1, ?2, ?3) ON CONFLICT (sha256) DO NOTHING",
    )
      .bind(sha, size, new Date().toISOString())
      .run();
  }

  /**
   * Single-request upload. The bytes stream through crypto.DigestStream on their way into R2 and R2 is
   * also given the expected sha256, so R2 rejects a mismatch before it replaces anything; the DigestStream
   * check is a backstop that deletes anything that slipped through, index row included, so a later push
   * uploads it again. There is no "already stored" lookup first: the client only sends what `push`
   * reported missing, and that extra D1 query on every blob made long pushes slower.
   */
  async putBlob(sha: string, request: Request): Promise<void> {
    const lengthHeader = request.headers.get("content-length");
    if (lengthHeader === null) throw new HttpError(411, "content-length required");
    const length = Number(lengthHeader);
    if (!Number.isSafeInteger(length) || length < 0) throw new HttpError(400, "bad content-length");
    if (length > MAX_SINGLE_PUT) throw new HttpError(413, `use multipart above ${MAX_SINGLE_PUT} bytes`);
    const body = request.body ?? new Response(new Uint8Array()).body!;

    const digest = new crypto.DigestStream("SHA-256");
    const digestWriter = digest.getWriter();
    const tap = new TransformStream<Uint8Array, Uint8Array>({
      async transform(chunk, controller) {
        await digestWriter.write(chunk);
        controller.enqueue(chunk);
      },
      async flush() {
        await digestWriter.close();
      },
    });
    const fixed = new FixedLengthStream(length);
    const piping = body.pipeThrough(tap).pipeTo(fixed.writable);
    const key = blobKey(sha);
    let putError: unknown;
    try {
      await Promise.all([this.env.BUCKET.put(key, fixed.readable, { sha256: sha }), piping]);
    } catch (e) {
      putError = e;
    }
    let actual: string | undefined;
    try {
      actual = toHex(await digest.digest);
    } catch {
      /* stream aborted before finishing */
    }
    if (actual !== undefined && actual !== sha) {
      if (!putError) await this.forgetBlob(sha);
      throw new HttpError(400, "sha256 mismatch", { expected: sha, actual });
    }
    if (putError) {
      // R2 rejects checksum mismatches itself; report those as 400, anything else as a failure.
      if (String(putError).toLowerCase().includes("digest") || String(putError).toLowerCase().includes("checksum")) {
        throw new HttpError(400, "sha256 mismatch", { expected: sha });
      }
      throw putError;
    }
    await this.recordBlob(sha, length);
  }

  private async forgetBlob(sha: string): Promise<void> {
    await this.env.BUCKET.delete(blobKey(sha));
    await this.env.DB.prepare("DELETE FROM blobs WHERE sha256 = ?1").bind(sha).run();
  }

  async createUpload(sha: string): Promise<string> {
    const upload = await this.env.BUCKET.createMultipartUpload(blobKey(sha));
    return upload.uploadId;
  }

  async uploadPart(sha: string, uploadId: string, partNumber: number, request: Request): Promise<string> {
    if (!request.body) throw new HttpError(400, "empty part");
    const upload = this.env.BUCKET.resumeMultipartUpload(blobKey(sha), uploadId);
    const part = await upload.uploadPart(partNumber, request.body);
    return part.etag;
  }

  /** Completes a multipart upload, then reads the object back through DigestStream to verify it. */
  async completeUpload(sha: string, uploadId: string, parts: R2UploadedPart[]): Promise<void> {
    const key = blobKey(sha);
    const upload = this.env.BUCKET.resumeMultipartUpload(key, uploadId);
    const object = await upload.complete(parts);
    const stored = await this.env.BUCKET.get(key);
    if (!stored) throw new HttpError(500, "completed upload not found");
    const digest = new crypto.DigestStream("SHA-256");
    await stored.body.pipeTo(digest);
    const actual = toHex(await digest.digest);
    if (actual !== sha) {
      await this.forgetBlob(sha);
      throw new HttpError(400, "sha256 mismatch", { expected: sha, actual });
    }
    await this.recordBlob(sha, object.size);
  }

  /**
   * Deletes blobs that no session references. `candidates` are checked precisely (the shas a commit
   * or delete just dropped); unreferenced blobs older than a day are swept too (abandoned pushes).
   * Fresh unreferenced blobs are left alone: they may belong to a push that hasn't committed yet.
   */
  async collectGarbage(candidates: string[]): Promise<string[]> {
    const cutoff = new Date(Date.now() - ABANDONED_AFTER_MS).toISOString();
    const { results } = await this.env.DB.prepare(
      `SELECT sha256 FROM blobs
        WHERE (sha256 IN (SELECT value FROM json_each(?1)) OR created_at < ?2)
          AND sha256 NOT IN (SELECT sha256 FROM session_files)
        LIMIT 1000`,
    )
      .bind(JSON.stringify([...new Set(candidates)]), cutoff)
      .all<{ sha256: string }>();
    const orphans = results.map((r) => r.sha256);
    if (!orphans.length) return [];
    await this.env.BUCKET.delete(orphans.map(blobKey));
    await this.env.DB.prepare("DELETE FROM blobs WHERE sha256 IN (SELECT value FROM json_each(?1))")
      .bind(JSON.stringify(orphans))
      .run();
    return orphans;
  }

  // ---- sessions ----

  async listSessions(): Promise<SessionRow[]> {
    const { results } = await this.env.DB.prepare(
      `SELECT ${ROW_COLUMNS} FROM sessions ORDER BY recorded_at DESC, id DESC`,
    ).all<SessionDbRow>();
    return results.map(toRow);
  }

  async getSession(id: string): Promise<(SessionRow & { manifestText: string; manifestSha256: string }) | null> {
    const r = await this.env.DB.prepare(`SELECT ${ROW_COLUMNS}, manifest, manifest_sha256 FROM sessions WHERE id = ?1`)
      .bind(id)
      .first<SessionDbRow>();
    if (!r) return null;
    return { ...toRow(r), manifestText: r.manifest!, manifestSha256: r.manifest_sha256! };
  }

  async getFile(id: string, path: string): Promise<FileRow | null> {
    return this.env.DB.prepare("SELECT path, sha256, size, type FROM session_files WHERE session_id = ?1 AND path = ?2")
      .bind(id, path)
      .first<FileRow>();
  }

  private async sessionShas(id: string): Promise<string[]> {
    const { results } = await this.env.DB.prepare("SELECT sha256 FROM session_files WHERE session_id = ?1")
      .bind(id)
      .all<{ sha256: string }>();
    return results.map((r) => r.sha256);
  }

  /**
   * Swaps in a session's manifest. Throws 409 + { missing } when a blob is absent, and 400 when a
   * file's size disagrees with the stored blob. Returns the blobs garbage-collected afterwards.
   */
  /**
   * `expected` (the If-Match of docs/cloud-sessions.md §2) is the manifest the pusher last saw. When given and
   * the stored session has another one, nothing changes and it throws 412 with the current row. The check and
   * the write are one batch: the file rows are replaced only if the session row now holds this manifest.
   */
  async commit(manifest: Manifest, manifestText: string, manifestSha256: string, identity: string, expected?: string): Promise<string[]> {
    const shas = manifest.files.map((f) => f.sha256);
    const sizes = await this.blobSizes(shas);
    const missing = [...new Set(shas.filter((s) => !sizes.has(s)))];
    if (missing.length) throw new HttpError(409, "blobs missing", { missing });
    const wrongSize = manifest.files.filter((f) => sizes.get(f.sha256) !== f.size).map((f) => f.path);
    if (wrongSize.length) throw new HttpError(400, "file sizes do not match the uploaded blobs", { paths: wrongSize });

    const previous = await this.sessionShas(manifest.sessionId);
    const files = manifest.files.map((f) => ({ path: f.path, sha256: f.sha256, size: f.size, type: contentTypeOf(f) }));
    const size = files.reduce((n, f) => n + f.size, 0);
    const db = this.env.DB;
    await db.batch([
      db
        .prepare(
          `INSERT INTO sessions (id, title, recorded_at, duration, mark_count, size, poster, manifest, manifest_sha256, pushed_at, pushed_by)
           VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
           ON CONFLICT (id) DO UPDATE SET title = excluded.title, recorded_at = excluded.recorded_at,
             duration = excluded.duration, mark_count = excluded.mark_count, size = excluded.size,
             poster = excluded.poster, manifest = excluded.manifest, manifest_sha256 = excluded.manifest_sha256,
             pushed_at = excluded.pushed_at, pushed_by = excluded.pushed_by
           WHERE ?12 IS NULL OR sessions.manifest_sha256 = ?12`,
        )
        .bind(
          manifest.sessionId,
          manifest.title,
          manifest.recordedAt,
          manifest.duration,
          manifest.markCount,
          size,
          manifest.poster ?? null,
          manifestText,
          manifestSha256,
          new Date().toISOString(),
          identity,
          expected ?? null,
        ),
      db
        .prepare(`DELETE FROM session_files WHERE session_id = ?1 AND ${HOLDS_NEW}`)
        .bind(manifest.sessionId, manifestSha256),
      db
        .prepare(
          `INSERT INTO session_files (session_id, path, sha256, size, type)
           SELECT ?1, json_extract(value, '$.path'), json_extract(value, '$.sha256'),
                  json_extract(value, '$.size'), json_extract(value, '$.type')
             FROM json_each(?3) WHERE ${HOLDS_NEW}`,
        )
        .bind(manifest.sessionId, manifestSha256, JSON.stringify(files)),
    ]);
    if (expected !== undefined) {
      const now = await this.getSession(manifest.sessionId);
      if (now && now.manifestSha256 !== manifestSha256) {
        const { manifestText: _m, ...current } = now;
        throw new HttpError(412, "the cloud copy changed since you last pushed or downloaded it", { current });
      }
    }
    return this.collectGarbage(previous);
  }

  /** Removes a session and its now-orphaned blobs. Returns false when it didn't exist. */
  async deleteSession(id: string): Promise<boolean> {
    const previous = await this.sessionShas(id);
    const db = this.env.DB;
    const [, deleted] = await db.batch([
      db.prepare("DELETE FROM session_files WHERE session_id = ?1").bind(id),
      db.prepare("DELETE FROM sessions WHERE id = ?1").bind(id),
    ]);
    if (!deleted?.meta.changes) return false;
    await this.collectGarbage(previous);
    return true;
  }

  // ---- reading session content (viewer files, MCP) ----

  async readBlob(sha: string, options?: R2GetOptions): Promise<R2ObjectBody | null> {
    return this.env.BUCKET.get(blobKey(sha), options) as Promise<R2ObjectBody | null>;
  }

  async headBlob(sha: string): Promise<R2Object | null> {
    return this.env.BUCKET.head(blobKey(sha));
  }

  /** A session file's bytes, or null when the path isn't in its manifest. */
  async readFileBytes(id: string, path: string): Promise<{ file: FileRow; bytes: ArrayBuffer } | null> {
    const file = await this.getFile(id, path);
    if (!file) return null;
    const obj = await this.readBlob(file.sha256);
    if (!obj) return null;
    return { file, bytes: await obj.arrayBuffer() };
  }

  async readFileJson<T>(id: string, path: string): Promise<T | null> {
    const got = await this.readFileBytes(id, path);
    return got ? (JSON.parse(new TextDecoder().decode(got.bytes)) as T) : null;
  }
}
