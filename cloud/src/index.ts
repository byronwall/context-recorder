import { OAuthProvider, type OAuthHelpers } from "@cloudflare/workers-oauth-provider";
import { handleApi, listGrants } from "./api";
import { handleAuthorize } from "./authorize";
import type { AppEnv } from "./env";
import { serveSessionFile, serveViewer } from "./files";
import { errorResponse, HttpError, json } from "./http";
import { identify, type UserProps } from "./identity";
import { libraryPage } from "./library";
import { assertSessionId, isValidPath } from "./manifest";
import { handleMcp } from "./mcp/handler";
import { verifyFileUrl } from "./signing";
import { Store } from "./store";

/**
 * One Worker (contract §2 and §6). The OAuth provider in front owns /token, /register and the
 * /.well-known metadata, and lets only bearer-token requests through to /mcp. Everything else lands in
 * handleRequest, where Identity accepts a bearer token, Access, or (locally) DEV_IDENTITY. /f/* is
 * checked by its signature and, from milestone 6, /share/* against D1.
 */
export async function handleRequest(request: Request, env: AppEnv, ctx: ExecutionContext): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname;
  try {
    // Signed file links: no Identity, the signature is the check.
    const signed = /^\/f\/([^/]+)\/(.+)$/.exec(path);
    if (signed) {
      const id = decodeURIComponent(signed[1]!);
      const filePath = decodeURIComponent(signed[2]!);
      assertSessionId(id);
      if (!isValidPath(filePath)) throw new HttpError(400, "invalid path");
      await verifyFileUrl(env, id, filePath, url);
      return await serveSessionFile(request, env, new Store(env), id, filePath);
    }

    if (path === "/authorize") return await handleAuthorize(request, env as AppEnv & { OAUTH_PROVIDER: OAuthHelpers });

    const identity = await identify(request, env);

    if (path === "/mcp") return await handleMcp(request, env, ctx, identity);

    if (path.startsWith("/api/")) {
      const res = await handleApi(request, env, identity, url);
      if (res) return res;
      throw new HttpError(404, "no such route");
    }

    if (path === "/" && (request.method === "GET" || request.method === "HEAD")) {
      const oauth = (env as AppEnv & { OAUTH_PROVIDER?: OAuthHelpers }).OAUTH_PROVIDER;
      const grants = oauth ? await listGrants(oauth, identity.id) : [];
      const html = libraryPage(await new Store(env).listSessions(), identity.id, grants);
      return new Response(html, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "private, no-cache" } });
    }

    const view = /^\/v\/([^/]+)\/?$/.exec(path);
    if (view) {
      return new Response(null, { status: 302, headers: { location: `/s/${view[1]}/` } });
    }

    const s = /^\/s\/([^/]+)(\/(.*))?$/.exec(path);
    if (s) {
      const id = decodeURIComponent(s[1]!);
      assertSessionId(id);
      if (s[2] === undefined) return new Response(null, { status: 301, headers: { location: `/s/${s[1]}/` } });
      const filePath = decodeURIComponent(s[3] ?? "");
      const store = new Store(env);
      if (filePath === "" || filePath === "index.html") return await serveViewer(request, env, store, id);
      if (!isValidPath(filePath)) throw new HttpError(400, "invalid path");
      return await serveSessionFile(request, env, store, id, filePath);
    }

    return json({ error: "not found" }, { status: 404 });
  } catch (e) {
    return errorResponse(e);
  }
}

const DAY = 86_400;

/**
 * The provider binds tokens to one canonical resource URL, so it's built per origin on first use:
 * `https://<host>/mcp`. The Mac app's tokens carry the same audience and work on /api too.
 */
const providers = new Map<string, OAuthProvider<AppEnv>>();

export function providerFor(origin: string): OAuthProvider<AppEnv> {
  let provider = providers.get(origin);
  if (!provider) {
    provider = new OAuthProvider<AppEnv>({
      apiHandlers: {
        "/mcp": {
          fetch: (request, env, ctx) => {
            const props = (ctx as ExecutionContext & { props: UserProps }).props;
            return handleMcp(request, env, ctx, { id: props.email, via: "oauth" });
          },
        },
      },
      defaultHandler: { fetch: (request, env, ctx) => handleRequest(request, env, ctx) },
      authorizeEndpoint: "/authorize",
      tokenEndpoint: "/token",
      clientRegistrationEndpoint: "/register",
      resourceMetadata: { resource: `${origin}/mcp`, resource_name: "Context Recorder sessions" },
      accessTokenTTL: 3600,
      refreshTokenTTL: 365 * DAY,
      refreshTokenIdleTTL: 90 * DAY,
      clientRegistrationTTL: undefined,
      allowPrivateUseRedirectUris: true,
    });
    providers.set(origin, provider);
  }
  return provider;
}

export default {
  fetch(request, env, ctx) {
    // Locally, /mcp without a token runs as DEV_IDENTITY, so `wrangler dev` and the MCP Inspector just work.
    const url = new URL(request.url);
    if (env.DEV_IDENTITY && url.pathname === "/mcp" && !request.headers.has("authorization")) return handleRequest(request, env, ctx);
    return providerFor(url.origin).fetch(request, env, ctx);
  },
} satisfies ExportedHandler<AppEnv>;
