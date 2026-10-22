import { createMcpHandler } from "agents/mcp/server";
import type { AppEnv } from "../env";
import type { Identity } from "../identity";
import { Store } from "../store";
import { buildMcpServer } from "./server";

/**
 * /mcp — stateless Streamable HTTP via the agents package's createMcpHandler (one McpServer per
 * request). The caller has already established `identity`: the OAuth provider's `ctx.props` in
 * production (src/index.ts), DEV_IDENTITY locally.
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
