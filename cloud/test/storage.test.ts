import { env } from "cloudflare:workers";
import { describe, expect, it } from "vitest";
import { sha256Hex } from "../src/http";
import { bytes, call, inR2, makeFiles, makeManifest, postJson, pushSession, putBlob, seed, shaOf } from "./helpers";

describe("push → upload → commit", () => {
  it("reports every blob missing on first push, then nothing on an unchanged re-push", async () => {
    const files = makeFiles("s-flow");
    const manifest = await makeManifest("s-flow", files);
    const first = await pushSession(manifest, files);
    expect(first.missing.length).toBe(Object.keys(files).length);
    expect(first.commit.url).toBe("http://localhost/s/s-flow/");
    expect(first.commit.manifestSha256).toBe(await sha256Hex(JSON.stringify(manifest)));

    const again = await postJson("/api/sessions/s-flow/push", manifest);
    expect(await again.json()).toEqual({ missing: [] });
    const second = await pushSession(manifest, files);
    expect(second.missing).toEqual([]);
  });

  it("re-push after a change uploads only the changed file and leaves no orphans", async () => {
    const { manifest: v1 } = await seed("s-change", 11);
    const oldVideo = shaOf(v1, "recording.mp4");
    const files2 = makeFiles("s-change", 12);
    const v2 = await makeManifest("s-change", files2);
    const { missing } = await pushSession(v2, files2);
    expect(missing).toEqual([shaOf(v2, "recording.mp4")]);
    expect(await inR2(oldVideo)).toBe(false);
    const row = await env.DB.prepare("SELECT COUNT(*) AS n FROM blobs WHERE sha256 = ?").bind(oldVideo).first<{ n: number }>();
    expect(row!.n).toBe(0);
    // Unchanged files stay.
    expect(await inR2(shaOf(v2, "session.json"))).toBe(true);
  });

  it("keeps a blob another session still references", async () => {
    // Two sessions with identical thumbs share blobs; changing one must not delete the other's.
    const { manifest: a } = await seed("s-share-a", 7);
    await seed("s-share-b", 7);
    const files = makeFiles("s-share-a", 8);
    await pushSession(await makeManifest("s-share-a", files), files);
    expect(await inR2(shaOf(a, "recording.mp4"))).toBe(true); // still used by s-share-b
  });

  it("If-Match commits only over the version the pusher last saw", async () => {
    const { manifest: v1 } = await seed("s-match", 21);
    const v1sha = await sha256Hex(JSON.stringify(v1));
    // Another Mac pushes v2 over v1.
    const files2 = makeFiles("s-match", 22);
    const v2 = await makeManifest("s-match", files2, { machine: "Studio" });
    await pushSession(v2, files2);
    const v2sha = await sha256Hex(JSON.stringify(v2));

    // This Mac still thinks v1 is current: refused, and the cloud keeps v2 and its files.
    const files3 = makeFiles("s-match", 23);
    const v3 = await makeManifest("s-match", files3);
    for (const [sha, f] of v3.files.map((f) => [f.sha256, files3[f.path]!] as const)) await putBlob(sha, f.bytes);
    const commit = (ifMatch: string) =>
      call("/api/sessions/s-match/commit", {
        method: "POST",
        headers: { "content-type": "application/json", "if-match": ifMatch },
        body: JSON.stringify(v3),
      });
    const stale = await commit(`"${v1sha}"`);
    expect(stale.status).toBe(412);
    const body = (await stale.json()) as { current: { manifestSha256: string; machine: string } };
    expect(body.current.manifestSha256).toBe(v2sha);
    expect(body.current.machine).toBe("Studio");
    const kept = (await (await call("/api/sessions/s-match")).json()) as { manifest: { files: { sha256: string }[] } };
    expect(kept.manifest.files.map((f) => f.sha256)).toEqual(v2.files.map((f) => f.sha256));
    const video = await call("/s/s-match/recording.mp4");
    expect(video.headers.get("etag")).toBe(`"${shaOf(v2, "recording.mp4")}"`);
    expect(await inR2(shaOf(v2, "recording.mp4"))).toBe(true);

    // With the current version it goes through.
    expect((await commit(`"${v2sha}"`)).status).toBe(200);
    expect((await call("/s/s-match/recording.mp4")).headers.get("etag")).toBe(`"${shaOf(v3, "recording.mp4")}"`);
  });

  it("commit returns 409 with the missing blobs", async () => {
    const files = makeFiles("s-409", 409);
    const manifest = await makeManifest("s-409", files);
    const res = await postJson("/api/sessions/s-409/commit", manifest);
    expect(res.status).toBe(409);
    const body = (await res.json()) as { missing: string[] };
    // Storage is shared within this file, so only the files unique to this session are missing.
    expect(body.missing.sort()).toEqual([shaOf(manifest, "recording.mp4"), shaOf(manifest, "session.json")].sort());
    expect((await call("/api/sessions/s-409")).status).toBe(404);
  });

  it("rejects a manifest whose sessionId doesn't match or whose path escapes", async () => {
    const files = makeFiles("s-bad");
    const manifest = await makeManifest("s-bad", files);
    expect((await postJson("/api/sessions/other/push", manifest)).status).toBe(400);
    const escape = { ...manifest, files: [{ ...manifest.files[0]!, path: "../etc/passwd" }] };
    expect((await postJson("/api/sessions/s-bad/push", escape)).status).toBe(400);
    expect((await postJson("/api/sessions/s-bad/push", "{not json")).status).toBe(400);
    const form = await call("/api/sessions/s-bad/push", { method: "POST", headers: { "content-type": "text/plain" }, body: JSON.stringify(manifest) });
    expect(form.status).toBe(415);
  });
});

describe("PUT /api/blobs/:sha256", () => {
  it("rejects bytes whose hash doesn't match and stores nothing", async () => {
    const data = bytes(1000, 999);
    const wrong = await sha256Hex(bytes(1000, 998));
    const res = await putBlob(wrong, data);
    expect(res.status).toBe(400);
    expect(await inR2(wrong)).toBe(false);
    expect((await postJson("/api/sessions/x/push", { format: 1 })).status).toBe(400);
  });

  it("accepts matching bytes and is idempotent", async () => {
    const data = bytes(5000, 42);
    const sha = await sha256Hex(data);
    expect((await putBlob(sha, data)).status).toBe(204);
    expect((await putBlob(sha, data)).status).toBe(204);
    expect(await inR2(sha)).toBe(true);
  });

  it("keeps a stored blob when a re-upload of it has the wrong bytes", async () => {
    const data = bytes(3000, 11);
    const sha = await sha256Hex(data);
    expect((await putBlob(sha, data)).status).toBe(204);
    expect((await putBlob(sha, bytes(3000, 12))).status).toBe(400);
    const stored = await env.BUCKET.get(`blobs/${sha}`);
    expect(stored && (await sha256Hex(new Uint8Array(await stored.arrayBuffer())))).toBe(sha);
    const res = await postJson("/api/sessions/s-keep/push", await makeManifest("s-keep", { "a.bin": { bytes: data, type: "application/octet-stream" } }));
    expect(((await res.json()) as { missing: string[] }).missing).toEqual([]);
  });

  it("rejects a malformed sha", async () => {
    expect((await putBlob("abc", bytes(10))).status).toBe(400);
  });
});

describe("multipart", () => {
  it("uploads parts, completes, and verifies the hash", async () => {
    const data = bytes(10_000, 77);
    const sha = await sha256Hex(data);
    const created = await call(`/api/blobs/${sha}/uploads`, { method: "POST" });
    const { uploadId } = (await created.json()) as { uploadId: string };
    const part = await call(`/api/blobs/${sha}/uploads/${encodeURIComponent(uploadId)}/1`, { method: "PUT", body: data });
    expect(part.status).toBe(200);
    const { etag } = (await part.json()) as { etag: string };
    const done = await postJson(`/api/blobs/${sha}/uploads/${encodeURIComponent(uploadId)}/complete`, { parts: [{ partNumber: 1, etag }] });
    expect(done.status).toBe(204);
    expect(await inR2(sha)).toBe(true);
    const push = await postJson("/api/sessions/mp/push", {
      format: 1, sessionId: "mp", title: "", recordedAt: "", duration: 0, markCount: 0,
      files: [{ path: "recording.mp4", size: data.length, sha256: sha, type: "video/mp4" }],
    });
    expect(await push.json()).toEqual({ missing: [] });
  });

  it("deletes a completed upload whose bytes don't match", async () => {
    const data = bytes(10_000, 78);
    const sha = await sha256Hex(bytes(10_000, 79));
    const { uploadId } = (await (await call(`/api/blobs/${sha}/uploads`, { method: "POST" })).json()) as { uploadId: string };
    const { etag } = (await (await call(`/api/blobs/${sha}/uploads/${encodeURIComponent(uploadId)}/1`, { method: "PUT", body: data })).json()) as { etag: string };
    const done = await postJson(`/api/blobs/${sha}/uploads/${encodeURIComponent(uploadId)}/complete`, { parts: [{ partNumber: 1, etag }] });
    expect(done.status).toBe(400);
    expect(await inR2(sha)).toBe(false);
  });
});

describe("sessions", () => {
  it("lists newest recording first and gets one with its manifest", async () => {
    const older = makeFiles("s-old");
    await pushSession(await makeManifest("s-old", older, { recordedAt: "2020-01-01T00:00:00Z" }), older);
    const newer = makeFiles("s-new");
    await pushSession(await makeManifest("s-new", newer, { recordedAt: "2030-01-01T00:00:00Z", machine: "Studio" }), newer);
    const list = (await (await call("/api/sessions")).json()) as { id: string }[];
    const ids = list.map((r) => r.id);
    expect(ids.indexOf("s-new")).toBeLessThan(ids.indexOf("s-old"));
    const row = list.find((r) => r.id === "s-new") as Record<string, unknown>;
    expect(Object.keys(row).sort()).toEqual(["duration", "id", "machine", "markCount", "poster", "pushedAt", "recordedAt", "size", "title"]);
    expect(row.machine).toBe("Studio");
    expect((list.find((r) => r.id === "s-old") as Record<string, unknown>).machine).toBeNull();

    const got = (await (await call("/api/sessions/s-new")).json()) as { manifest: { sessionId: string } };
    expect(got.manifest.sessionId).toBe("s-new");
    expect((await call("/api/sessions/nope")).status).toBe(404);
  });

  it("delete removes the row and its orphaned blobs", async () => {
    const { manifest } = await seed("s-del", 31);
    const video = shaOf(manifest, "recording.mp4");
    expect(await inR2(video)).toBe(true);
    expect((await call("/api/sessions/s-del", { method: "DELETE" })).status).toBe(204);
    expect((await call("/api/sessions/s-del")).status).toBe(404);
    expect(await inR2(video)).toBe(false);
    expect((await call("/s/s-del/recording.mp4")).status).toBe(404);
    expect((await call("/api/sessions/s-del", { method: "DELETE" })).status).toBe(404);
  });
});
