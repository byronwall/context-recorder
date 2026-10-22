import type { AppEnv } from "./env";
import { HttpError, json } from "./http";
import type { Store } from "./store";

/**
 * Serving a session file: /s/:id/<path> (behind Identity) and /f/:id/<path> (signed).
 *
 * Caching: paths like session.json or recording.mp4 keep their URL across pushes while their bytes
 * change, so responses carry ETag = sha256 and must revalidate (cheap 304s). A request that pins the
 * content with `?v=<sha256>` gets immutable caching.
 */

type Range = { offset: number; length: number } | "unsatisfiable" | null;

/** Parses a single `bytes=` range against `size`. Multi-range and malformed headers are ignored (200). */
export function parseRange(header: string | null, size: number): Range {
  if (!header) return null;
  const m = /^bytes=(\d*)-(\d*)$/.exec(header.trim());
  if (!m) return null;
  const [, a, b] = m;
  if (a === "" && b === "") return null;
  if (a === "") {
    const suffix = Number(b);
    if (suffix === 0) return "unsatisfiable";
    const length = Math.min(suffix, size);
    return { offset: size - length, length };
  }
  const start = Number(a);
  if (start >= size) return "unsatisfiable";
  const end = b === "" ? size - 1 : Math.min(Number(b), size - 1);
  if (end < start) return null;
  return { offset: start, length: end - start + 1 };
}

const securityHeaders = {
  "x-content-type-options": "nosniff",
  // Uploaded files are data, never an app: saved pages and the like render sandboxed.
  "content-security-policy": "sandbox",
};

export async function serveSessionFile(
  request: Request,
  env: AppEnv,
  store: Store,
  id: string,
  path: string,
): Promise<Response> {
  if (request.method !== "GET" && request.method !== "HEAD") throw new HttpError(405, "method not allowed");
  const url = new URL(request.url);

  if (path === "manifest.json") {
    const session = await store.getSession(id);
    if (!session) throw new HttpError(404, "no such session");
    const etag = `"${session.manifestSha256}"`;
    const headers = { "content-type": "application/json; charset=utf-8", etag, "cache-control": "private, no-cache", ...securityHeaders };
    if (request.headers.get("if-none-match") === etag) return new Response(null, { status: 304, headers });
    return new Response(request.method === "HEAD" ? null : session.manifestText, { headers });
  }

  const file = await store.getFile(id, path);
  if (!file) throw new HttpError(404, "no such file in this session");
  const etag = `"${file.sha256}"`;
  const headers: Record<string, string> = {
    "content-type": file.type,
    etag,
    "accept-ranges": "bytes",
    "cache-control": url.searchParams.get("v") === file.sha256 ? "private, max-age=31536000, immutable" : "private, no-cache",
    ...securityHeaders,
  };
  if (request.headers.get("if-none-match") === etag) return new Response(null, { status: 304, headers });

  const ifRange = request.headers.get("if-range");
  const range = ifRange && ifRange !== etag ? null : parseRange(request.headers.get("range"), file.size);
  if (range === "unsatisfiable") {
    return new Response(null, { status: 416, headers: { ...headers, "content-range": `bytes */${file.size}` } });
  }

  if (request.method === "HEAD") {
    if (range) {
      headers["content-range"] = `bytes ${range.offset}-${range.offset + range.length - 1}/${file.size}`;
      headers["content-length"] = String(range.length);
      return new Response(null, { status: 206, headers });
    }
    headers["content-length"] = String(file.size);
    return new Response(null, { headers });
  }

  const object = await store.readBlob(file.sha256, range ? { range } : undefined);
  if (!object) throw new HttpError(404, "blob missing from storage");
  if (range) {
    headers["content-range"] = `bytes ${range.offset}-${range.offset + range.length - 1}/${file.size}`;
    headers["content-length"] = String(range.length);
    return new Response(object.body, { status: 206, headers });
  }
  headers["content-length"] = String(file.size);
  return new Response(object.body, { headers });
}

/** GET /s/:id/ — the shared viewer from static assets; it fetches session.json etc. relative to itself. */
export async function serveViewer(request: Request, env: AppEnv, store: Store, id: string): Promise<Response> {
  if (!(await store.getSession(id))) {
    return json({ error: "no such session" }, { status: 404 });
  }
  const asset = await env.ASSETS.fetch(new Request(new URL("/viewer.html", request.url)));
  if (!asset.ok) throw new HttpError(500, "viewer.html missing from static assets (run pnpm copy-viewer)");
  const headers = new Headers(asset.headers);
  headers.set("content-type", "text/html; charset=utf-8");
  headers.set("cache-control", "private, no-cache");
  return new Response(request.method === "HEAD" ? null : asset.body, { headers });
}
