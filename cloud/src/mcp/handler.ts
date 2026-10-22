import { createMcpHandler } from "agents/mcp/server";
import type { AppEnv } from "../env";
import type { Identity } from "../identity";
import { Store } from "../store";
import { buildMcpServer } from "./server";

/**
 * /mcp — stateless Streamable HTTP via the agents package's createMcpHandler (one McpServer per
 * request). The caller has already established `identity`.
 *
 * Milestone 5 (workers-oauth-provider, following Cloudflare's remote-mcp-cf-access template): this
 * function becomes the provider's `apiHandler` for "/mcp". The provider validates the bearer token and
 * puts the Access-for-SaaS user into `ctx.props`; read the identity from there instead of
 * Cf-Access-Jwt-Assertion and pass it through `authContext: { props }`. Nothing in buildMcpServer changes.
 */
export async function handleMcp(request: Request, env: AppEnv, ctx: ExecutionContext, identity: Identity): Promise<Response> {
  const origin = new URL(request.url).origin;
  const store = new Store(env);
  const handler = createMcpHandler(() => buildMcpServer({ env, store, origin }), {
    route: "/mcp",
    authContext: { props: { identity: identity.id, via: identity.via } },
    // Access (or the OAuth provider) already gates the route; allow the deployment's own hostname.
    allowedHostnames: [new URL(request.url).hostname],
  });
  return handler(request, env, ctx);
}
