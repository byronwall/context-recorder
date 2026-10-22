import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from "jose";
import type { AppEnv } from "./env";
import { HttpError } from "./http";

/**
 * Identity seam (contract §2). Production: Cloudflare Access puts a signed JWT in
 * `Cf-Access-Jwt-Assertion` for both browser sign-ins and service tokens; we verify it (RS256) against
 * the team's certs with `aud` = ACCESS_AUD. Dev: DEV_IDENTITY, when set, is the identity.
 *
 * Milestone 5: /mcp moves behind workers-oauth-provider, whose `ctx.props` (from the Access-for-SaaS
 * OIDC upstream) becomes the identity for MCP calls instead of this header. See src/index.ts.
 */
export interface Identity {
  /** Email for people, the service token's client id (common_name) for the Mac. */
  id: string;
  via: "dev" | "access";
}

const jwksCache = new Map<string, JWTVerifyGetKey>();

function teamJwks(teamDomain: string): JWTVerifyGetKey {
  let jwks = jwksCache.get(teamDomain);
  if (!jwks) {
    jwks = createRemoteJWKSet(new URL(`https://${teamDomain}/cdn-cgi/access/certs`));
    jwksCache.set(teamDomain, jwks);
  }
  return jwks;
}

/** Verifies an Access JWT. `keys` is injectable so tests can use a local key set. */
export async function verifyAccessJwt(
  token: string,
  opts: { teamDomain: string; audience: string; keys?: JWTVerifyGetKey },
): Promise<Identity> {
  const { payload } = await jwtVerify(token, opts.keys ?? teamJwks(opts.teamDomain), {
    issuer: `https://${opts.teamDomain}`,
    audience: opts.audience,
    algorithms: ["RS256"],
  });
  const id =
    (typeof payload.email === "string" && payload.email) ||
    (typeof payload.common_name === "string" && payload.common_name) ||
    payload.sub;
  if (!id) throw new Error("token has no subject");
  return { id, via: "access" };
}

export async function identify(request: Request, env: AppEnv, keys?: JWTVerifyGetKey): Promise<Identity> {
  if (env.DEV_IDENTITY) return { id: env.DEV_IDENTITY, via: "dev" };
  const token = request.headers.get("cf-access-jwt-assertion");
  if (!token) throw new HttpError(401, "sign in required (no Cf-Access-Jwt-Assertion)");
  if (!env.ACCESS_TEAM_DOMAIN || !env.ACCESS_AUD) throw new HttpError(500, "Access is not configured");
  try {
    return await verifyAccessJwt(token, { teamDomain: env.ACCESS_TEAM_DOMAIN, audience: env.ACCESS_AUD, keys });
  } catch {
    throw new HttpError(401, "invalid Access token");
  }
}
