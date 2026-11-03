import type { AppEnv } from "./env";
import { serveSessionFile, serveViewer } from "./files";
import { HttpError } from "./http";
import { isValidPath } from "./manifest";
import { cookie, verifyAccessJwt } from "./identity";
import { Store, type ShareView } from "./store";

/**
 * /share/:token/ (docs/cloud-sessions.md §8): one session in the viewer, read-only, with no sign-in. Every
 * request looks the token up, so a revoke takes effect on the next request.
 */

/** What a share link serves: the files the viewer loads. The raw logs (activity, browser, marks) stay private. */
const SHARED_FILES = new Set(["manifest.json", "session.json", "drawings.json", "recording.mp4"]);
const SHARED_FOLDERS = ["thumbs/", "frames/", "screenshots/", "drawings/", "annotations/", "pages/", "sources/"];

export const isSharedPath = (path: string) => SHARED_FILES.has(path) || SHARED_FOLDERS.some((f) => path.startsWith(f));

/** `rest` is undefined for `/share/<token>` (no slash), else the path after `/share/<token>/`. */
export async function handleShare(request: Request, env: AppEnv, rawToken: string, rest: string | undefined): Promise<Response> {
  if (rest === undefined) return new Response(null, { status: 301, headers: { location: `/share/${rawToken}/` } });
  const token = decodeURIComponent(rawToken);
  const path = decodeURIComponent(rest);
  const store = new Store(env);
  const page = path === "" || path === "index.html";

  let id: string;
  try {
    id = await store.shareSession(token);
  } catch (e) {
    if (page && e instanceof HttpError) return notShared(e.status);
    throw e;
  }

  if (path === "view" && request.method === "POST") {
    if (!(await isOwner(request, env))) await store.recordView(token, await readView(request));
    return new Response(null, { status: 204 });
  }

  if (page) {
    const res = await serveViewer(request, env, store, id);
    const headers = new Headers(res.headers);
    // The token is in the URL: links out of the viewer (a mark's page) must not carry it in Referer.
    headers.set("referrer-policy", "no-referrer");
    headers.set("x-robots-tag", "noindex");
    return new Response(res.body, { status: res.status, headers });
  }
  if (!isValidPath(path) || !isSharedPath(path)) throw new HttpError(404, "not part of the shared session");
  return await serveSessionFile(request, store, id, path);
}

/**
 * The beacon's body (`{ viewer, referrer }`, sent as text by sendBeacon) plus where Cloudflare says the request came
 * from. Nothing here is trusted: a bad viewer id gets a random one, and the referrer keeps only its host.
 */
async function readView(request: Request): Promise<ShareView> {
  let body: { viewer?: unknown; referrer?: unknown } = {};
  try {
    body = JSON.parse((await request.text()).slice(0, 2000));
  } catch {
    /* counted with defaults */
  }
  const viewer = typeof body.viewer === "string" && /^[A-Za-z0-9-]{8,40}$/.test(body.viewer) ? body.viewer : crypto.randomUUID();
  let referrer: string | null = null;
  try {
    const host = new URL(String(body.referrer)).hostname;
    if (host && host !== new URL(request.url).hostname) referrer = host;
  } catch {
    /* direct */
  }
  const cf = (request as Request & { cf?: IncomingRequestCfProperties }).cf;
  const ua = request.headers.get("user-agent") || "";
  return {
    viewer,
    country: (cf?.country as string | undefined) ?? null,
    region: cf?.region ?? null,
    city: cf?.city ?? null,
    referrer,
    device: /Mobi|Android|iPhone|iPad/.test(ua) ? "mobile" : "desktop",
  };
}

/** You, watching your own link while signed in to Access: not counted. */
async function isOwner(request: Request, env: AppEnv): Promise<boolean> {
  const token = cookie(request, "CF_Authorization");
  if (!token || !env.ACCESS_TEAM_DOMAIN || !env.ACCESS_AUD) return false;
  return verifyAccessJwt(token, { teamDomain: env.ACCESS_TEAM_DOMAIN, audience: env.ACCESS_AUD }).then(
    () => true,
    () => false,
  );
}

function notShared(status: number): Response {
  const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex"><title>Not shared</title>
<style>
:root { --bg:#fbfbfa; --text:#1d1d1f; --muted:#6e6e73; }
@media (prefers-color-scheme: dark) { :root { --bg:#161617; --text:#ececec; --muted:#9a9aa0; } }
body { margin:0; min-height:100vh; display:grid; place-items:center; background:var(--bg); color:var(--text); font:14px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; padding:16px; box-sizing:border-box; }
h1 { font-size:16px; margin:0 0 4px; }
p { margin:0; color:var(--muted); }
</style></head>
<body><main><h1>This recording is no longer shared</h1><p>Ask the person who sent the link for a new one.</p></main></body></html>`;
  return new Response(html, { status, headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store", "x-robots-tag": "noindex" } });
}
