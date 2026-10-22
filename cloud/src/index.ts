import { handleApi } from "./api";
import type { AppEnv } from "./env";
import { serveSessionFile, serveViewer } from "./files";
import { errorResponse, HttpError, json } from "./http";
import { identify } from "./identity";
import { libraryPage } from "./library";
import { assertSessionId, isValidPath } from "./manifest";
import { handleMcp } from "./mcp/handler";
import { verifyFileUrl } from "./signing";
import { Store } from "./store";

/**
 * One Worker (contract §2). Every route goes through Identity except /f/* (signed URLs) and, from
 * milestone 6, /share/* (checked against D1).
 *
 * Milestone 5: wrap this in workers-oauth-provider, e.g.
 *   export default new OAuthProvider({
 *     apiRoute: "/mcp", apiHandler: { fetch: (req, env, ctx) => handleMcp(req, env, ctx, identityFrom(ctx.props)) },
 *     defaultHandler: { fetch: handleRequest },   // everything below, plus /authorize and /callback for Access OIDC
 *     authorizeEndpoint: "/authorize", tokenEndpoint: "/token", clientRegistrationEndpoint: "/register",
 *   });
 * and drop "/mcp" from handleRequest. OAUTH_KV is already bound for the provider's token storage.
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

    const identity = await identify(request, env);

    if (path === "/mcp") return await handleMcp(request, env, ctx, identity);

    if (path.startsWith("/api/")) {
      const res = await handleApi(request, env, identity, url);
      if (res) return res;
      throw new HttpError(404, "no such route");
    }

    if (path === "/" && (request.method === "GET" || request.method === "HEAD")) {
      const html = libraryPage(await new Store(env).listSessions(), identity.id);
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

export default {
  fetch: handleRequest,
} satisfies ExportedHandler<AppEnv>;
