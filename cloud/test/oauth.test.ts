import { createExecutionContext, waitOnExecutionContext } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { describe, expect, it } from "vitest";
import type { AppEnv } from "../src/env";
import worker from "../src/index";

const ORIGIN = "https://cloud.test";
const REDIRECT = "contextrecorder://oauth/callback";

async function hit(path: string, init: RequestInit = {}, envOverride: Partial<AppEnv> = {}): Promise<Response> {
  const ctx = createExecutionContext();
  const headers = new Headers(init.headers);
  headers.set("host", new URL(ORIGIN).host);
  const res = await worker.fetch(new Request(ORIGIN + path, { redirect: "manual", ...init, headers }) as never, { ...env, ...envOverride } as AppEnv, ctx);
  await waitOnExecutionContext(ctx);
  return res;
}

/** Signed in through Access (DEV_IDENTITY stands in) but calling with a bearer token: no dev shortcut. */
const noDev = { DEV_IDENTITY: undefined } as Partial<AppEnv>;
const bearer = (token: string) => ({ authorization: `Bearer ${token}` });

const b64url = (bytes: ArrayBuffer) => btoa(String.fromCharCode(...new Uint8Array(bytes))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

async function register(name = "Context Recorder (Test Mac)") {
  const res = await hit("/register", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ client_name: name, redirect_uris: [REDIRECT], token_endpoint_auth_method: "none", grant_types: ["authorization_code", "refresh_token"], response_types: ["code"] }),
  });
  expect(res.status).toBe(201);
  return ((await res.json()) as { client_id: string }).client_id;
}

async function consent(clientId: string, verifier = "a-verifier-that-is-long-enough-for-pkce-0123456789") {
  const challenge = b64url(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(verifier)));
  const q = new URLSearchParams({ response_type: "code", client_id: clientId, redirect_uri: REDIRECT, state: "st4te", code_challenge: challenge, code_challenge_method: "S256" });
  const page = await hit(`/authorize?${q}`);
  expect(page.status).toBe(200);
  const html = await page.text();
  const pending = /name="pending" value="([^"]+)"/.exec(html)![1]!;
  const sig = /name="sig" value="([^"]+)"/.exec(html)![1]!;
  return { html, pending, sig, verifier };
}

async function signIn() {
  const clientId = await register();
  const { pending, sig, verifier } = await consent(clientId);
  const allow = await hit("/authorize", { method: "POST", headers: { origin: ORIGIN }, body: new URLSearchParams({ pending, sig, decision: "allow" }) });
  expect(allow.status).toBe(302);
  const back = new URL(allow.headers.get("location")!);
  expect(`${back.protocol}//${back.host}${back.pathname}`).toBe(REDIRECT);
  expect(back.searchParams.get("state")).toBe("st4te");
  const token = await hit("/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "authorization_code", code: back.searchParams.get("code")!, client_id: clientId, code_verifier: verifier, redirect_uri: REDIRECT }),
  });
  expect(token.status).toBe(200);
  const t = (await token.json()) as { access_token: string; refresh_token: string; expires_in: number };
  return { clientId, ...t };
}

describe("OAuth sign-in (docs/cloud-sessions.md §6)", () => {
  it("publishes discovery metadata", async () => {
    const as = await hit("/.well-known/oauth-authorization-server");
    const meta = (await as.json()) as Record<string, unknown>;
    expect(meta.authorization_endpoint).toBe(`${ORIGIN}/authorize`);
    expect(meta.registration_endpoint).toBe(`${ORIGIN}/register`);
    const pr = (await (await hit("/.well-known/oauth-protected-resource/mcp")).json()) as Record<string, unknown>;
    expect(pr.resource).toBe(`${ORIGIN}/mcp`);
  });

  it("shows a consent page naming the app, the account and where it returns", async () => {
    const { html } = await consent(await register("Context Recorder (Byron's Mac)"));
    expect(html).toContain("Allow Context Recorder (Byron&#39;s Mac)?");
    expect(html).toContain("test@localhost");
    expect(html).toContain("contextrecorder://oauth");
  });

  it("signs in, then the bearer token works on /api and /mcp without Access", async () => {
    const { access_token, expires_in, refresh_token } = await signIn();
    expect(expires_in).toBe(3600);
    expect(refresh_token).toBeTruthy();
    const me = await hit("/api/me", { headers: bearer(access_token) }, noDev);
    expect(await me.json()).toEqual({ id: "test@localhost", via: "oauth" });
    const list = await hit("/api/sessions", { headers: bearer(access_token) }, noDev);
    expect(list.status).toBe(200);
    const mcp = await hit("/mcp", {
      method: "POST",
      headers: { ...bearer(access_token), "content-type": "application/json", accept: "application/json, text/event-stream" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/list", params: {} }),
    }, noDev);
    expect(mcp.status).toBe(200);
    expect(await mcp.text()).toContain("get_frame");
  });

  it("refreshes, and a revoked grant stops working", async () => {
    const { clientId, refresh_token } = await signIn();
    const res = await hit("/token", {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "refresh_token", refresh_token, client_id: clientId }),
    });
    expect(res.status).toBe(200);
    const fresh = ((await res.json()) as { access_token: string }).access_token;
    expect((await hit("/api/me", { headers: bearer(fresh) }, noDev)).status).toBe(200);

    const grants = (await (await hit("/api/grants", { headers: bearer(fresh) }, noDev)).json()) as { id: string; clientId: string; name: string }[];
    const mine = grants.find((g) => g.clientId === clientId)!;
    expect(mine.name).toBe("Context Recorder (Test Mac)");
    expect(mine).toBeTruthy();
    const revoke = await hit(`/api/grants/${mine.id}/revoke`, { method: "POST", headers: { ...bearer(fresh), "content-type": "application/json" } }, noDev);
    expect(revoke.status).toBe(204);
    expect((await hit("/api/me", { headers: bearer(fresh) }, noDev)).status).toBe(401);
  });

  it("refuses /mcp without a token, with a discovery challenge", async () => {
    const res = await hit("/mcp", { method: "POST", headers: { "content-type": "application/json" }, body: "{}" }, noDev);
    expect(res.status).toBe(401);
    expect(res.headers.get("www-authenticate")).toContain("resource_metadata");
  });

  it("refuses garbage bearer tokens on /api", async () => {
    const res = await hit("/api/sessions", { headers: bearer("nope:nope:nope") }, noDev);
    expect(res.status).toBe(401);
  });

  it("refuses a cross-site or tampered consent POST", async () => {
    const { pending, sig } = await consent(await register());
    const cross = await hit("/authorize", { method: "POST", headers: { origin: "https://evil.test" }, body: new URLSearchParams({ pending, sig, decision: "allow" }) });
    expect(cross.status).toBe(403);
    const tampered = await hit("/authorize", { method: "POST", headers: { origin: ORIGIN }, body: new URLSearchParams({ pending, sig: "0".repeat(64), decision: "allow" }) });
    expect(tampered.status).toBe(400);
  });

  it("Cancel returns access_denied to the app", async () => {
    const { pending, sig } = await consent(await register());
    const res = await hit("/authorize", { method: "POST", headers: { origin: ORIGIN }, body: new URLSearchParams({ pending, sig, decision: "deny" }) });
    const back = new URL(res.headers.get("location")!);
    expect(back.searchParams.get("error")).toBe("access_denied");
    expect(back.searchParams.get("state")).toBe("st4te");
  });

  it("refuses a cookie-authenticated write from another origin", async () => {
    const res = await hit("/api/grants/x/revoke", { method: "POST", headers: { cookie: "CF_Authorization=abc", origin: "https://evil.test" } }, noDev);
    expect(res.status).toBe(403);
  });

  it("still serves /mcp locally without a token when DEV_IDENTITY is set", async () => {
    const res = await hit("/mcp", {
      method: "POST",
      headers: { "content-type": "application/json", accept: "application/json, text/event-stream" },
      body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/list", params: {} }),
    });
    expect(res.status).toBe(200);
  });
});
