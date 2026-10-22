import type { AppEnv } from "./env";
import { HttpError } from "./http";

/**
 * Signed file URLs: `<origin>/f/<id>/<path>?exp=<unix seconds>&sig=<base64url HMAC-SHA256>`.
 * The MAC covers `<id>/<path>\n<exp>`. /f/* bypasses Identity (it must be reachable by Media
 * Transformations and by agents without Access), so the signature and expiry are the only check.
 */
export const MAX_TTL_SECONDS = 3600;

const b64url = (buf: ArrayBuffer) =>
  btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

const fromB64url = (s: string): Uint8Array => {
  const bin = atob(s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4));
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
};

async function key(env: AppEnv): Promise<CryptoKey> {
  if (!env.SIGNING_SECRET) throw new HttpError(503, "SIGNING_SECRET is not configured");
  return crypto.subtle.importKey("raw", new TextEncoder().encode(env.SIGNING_SECRET), { name: "HMAC", hash: "SHA-256" }, false, [
    "sign",
    "verify",
  ]);
}

const message = (id: string, path: string, exp: number) => new TextEncoder().encode(`${id}/${path}\n${exp}`);

/** Encodes each path segment for use in a URL. */
export const encodePath = (path: string) => path.split("/").map(encodeURIComponent).join("/");

export async function signFileUrl(
  env: AppEnv,
  origin: string,
  id: string,
  path: string,
  ttlSeconds: number,
  now = Date.now(),
): Promise<{ url: string; expiresAt: string }> {
  const ttl = Math.max(1, Math.min(MAX_TTL_SECONDS, Math.floor(ttlSeconds)));
  const exp = Math.floor(now / 1000) + ttl;
  const sig = b64url(await crypto.subtle.sign("HMAC", await key(env), message(id, path, exp)));
  return {
    url: `${origin}/f/${encodeURIComponent(id)}/${encodePath(path)}?exp=${exp}&sig=${sig}`,
    expiresAt: new Date(exp * 1000).toISOString(),
  };
}

/** Throws 403 unless `exp`/`sig` are a valid, unexpired signature for id/path. */
export async function verifyFileUrl(env: AppEnv, id: string, path: string, url: URL, now = Date.now()): Promise<void> {
  const exp = Number(url.searchParams.get("exp"));
  const sig = url.searchParams.get("sig");
  if (!sig || !Number.isSafeInteger(exp)) throw new HttpError(403, "missing signature");
  if (exp * 1000 < now) throw new HttpError(403, "link expired");
  if (exp * 1000 > now + (MAX_TTL_SECONDS + 60) * 1000) throw new HttpError(403, "expiry too far in the future");
  let bytes: Uint8Array;
  try {
    bytes = fromB64url(sig);
  } catch {
    throw new HttpError(403, "bad signature");
  }
  const ok = await crypto.subtle.verify("HMAC", await key(env), bytes, message(id, path, exp));
  if (!ok) throw new HttpError(403, "bad signature");
}
