import type { AuthRequest, OAuthHelpers } from "@cloudflare/workers-oauth-provider";
import type { AppEnv } from "./env";
import { escapeHtml as esc, HttpError, toHex } from "./http";
import { identifyPerson, type UserProps } from "./identity";

/**
 * GET /authorize: Access has already signed the person in (this path is never bypassed), so all that's
 * left is consent: which app, sending the result where. POST /authorize with Allow completes the grant.
 * The pending request rides in the form, HMAC-signed so the page can't be replayed with other values.
 */
type Env = AppEnv & { OAUTH_PROVIDER: OAuthHelpers };

const enc = new TextEncoder();
const b64url = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const fromB64url = (s: string) => Uint8Array.from(atob(s.replace(/-/g, "+").replace(/_/g, "/")), (c) => c.charCodeAt(0));

async function hmac(env: AppEnv, text: string): Promise<string> {
  if (!env.SIGNING_SECRET) throw new HttpError(500, "SIGNING_SECRET is not configured");
  const key = await crypto.subtle.importKey("raw", enc.encode(env.SIGNING_SECRET), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return toHex(await crypto.subtle.sign("HMAC", key, enc.encode("authorize\n" + text)));
}

export async function handleAuthorize(request: Request, env: Env): Promise<Response> {
  const person = await identifyPerson(request, env);
  const url = new URL(request.url);

  if (request.method === "GET") {
    const oauthReq = await env.OAUTH_PROVIDER.parseAuthRequest(request);
    const client = await env.OAUTH_PROVIDER.lookupClient(oauthReq.clientId);
    if (!client) throw new HttpError(400, "unknown client");
    const pending = b64url(enc.encode(JSON.stringify({ req: oauthReq, user: person.id, at: Date.now() })));
    return html(consentPage({
      clientName: client.clientName || "An app",
      redirect: oauthReq.redirectUri,
      email: person.id,
      pending,
      sig: await hmac(env, pending),
      action: url.pathname,
    }));
  }

  if (request.method === "POST") {
    if (request.headers.get("origin") !== url.origin) throw new HttpError(403, "cross-site request refused");
    const form = await request.formData();
    const pending = String(form.get("pending") || "");
    if ((await hmac(env, pending)) !== String(form.get("sig") || "")) throw new HttpError(400, "this sign-in page has expired; start again");
    const { req, user, at } = JSON.parse(new TextDecoder().decode(fromB64url(pending))) as { req: AuthRequest; user: string; at: number };
    if (user !== person.id || Date.now() - at > 10 * 60_000) throw new HttpError(400, "this sign-in page has expired; start again");
    if (form.get("decision") !== "allow") {
      const back = new URL(req.redirectUri);
      back.searchParams.set("error", "access_denied");
      if (req.state) back.searchParams.set("state", req.state);
      return Response.redirect(back.toString(), 302);
    }
    const client = await env.OAUTH_PROVIDER.lookupClient(req.clientId);
    const props: UserProps = { email: person.id };
    const { redirectTo } = await env.OAUTH_PROVIDER.completeAuthorization({
      request: req,
      userId: person.id,
      metadata: { label: client?.clientName || "Unnamed app" },
      scope: req.scope,
      props,
    });
    return Response.redirect(redirectTo, 302);
  }
  throw new HttpError(405, "method not allowed");
}

const html = (body: string) =>
  new Response(body, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store", "x-frame-options": "DENY" } });

function consentPage(p: { clientName: string; redirect: string; email: string; pending: string; sig: string; action: string }): string {
  let where = p.redirect;
  try {
    const u = new URL(p.redirect);
    where = u.protocol === "http:" || u.protocol === "https:" ? u.host : `${u.protocol}//${u.host}`;
  } catch {}
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Allow ${esc(p.clientName)}?</title>
<style>
:root { --bg:#fbfbfa; --text:#1d1d1f; --muted:#6e6e73; --line:#e6e6e3; --accent:#2457c5; --accent-text:#fff; }
@media (prefers-color-scheme: dark) { :root { --bg:#161617; --text:#ececec; --muted:#9a9aa0; --line:#2c2c2f; --accent:#7aa5ff; --accent-text:#0b1220; } }
* { box-sizing:border-box; }
body { margin:0; min-height:100vh; display:grid; place-items:center; background:var(--bg); color:var(--text); font:14px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; padding:16px; }
main { width:100%; max-width:380px; }
h1 { font-size:18px; margin:0 0 8px; }
p { margin:0 0 6px; color:var(--muted); }
p strong { color:var(--text); font-weight:600; }
.row { display:flex; gap:8px; margin-top:20px; }
button { flex:1; font:inherit; font-weight:500; padding:8px 12px; border-radius:6px; border:1px solid var(--line); background:none; color:var(--text); cursor:pointer; transition:background-color 140ms ease; }
button.allow { background:var(--accent); border-color:var(--accent); color:var(--accent-text); }
button:active { transform:translateY(1px); }
@media (prefers-reduced-motion: reduce) { button { transition:none; } }
</style></head>
<body><main>
<h1>Allow ${esc(p.clientName)}?</h1>
<p>It will be able to list, read and push sessions as <strong>${esc(p.email)}</strong>.</p>
<p>Sign-in returns to <strong>${esc(where)}</strong>.</p>
<form method="post" action="${esc(p.action)}">
<input type="hidden" name="pending" value="${esc(p.pending)}"><input type="hidden" name="sig" value="${esc(p.sig)}">
<div class="row"><button type="submit" name="decision" value="deny">Cancel</button><button class="allow" type="submit" name="decision" value="allow" autofocus>Allow</button></div>
</form>
</main></body></html>`;
}
