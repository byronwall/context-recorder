import type { OAuthHelpers } from "@cloudflare/workers-oauth-provider";
import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from "jose";
import type { AppEnv } from "./env";
import { HttpError } from "./http";

/**
 * Identity seam (docs/cloud-sessions.md §2 and §6). In order:
 * - `Authorization: Bearer` — an access token issued by our OAuth provider (the Mac app, MCP agents).
 * - `Cf-Access-Jwt-Assertion` — Access put a signed JWT on a request to a path it guards.
 * - The `CF_Authorization` cookie — a signed-in browser calling a path Access bypasses (the library's
 *   Delete button). Writes need a same-origin `Origin`, so another site can't ride the cookie.
 * - `DEV_IDENTITY` — local only.
 */
export interface Identity {
  /** The person's email (or a service token's client id, for old Access service tokens). */
  id: string;
  via: "dev" | "access" | "oauth";
}

export interface UserProps {
  email: string;
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

export function cookie(request: Request, name: string): string | undefined {
  for (const part of (request.headers.get("cookie") || "").split(";")) {
    const i = part.indexOf("=");
    if (i > 0 && part.slice(0, i).trim() === name) return part.slice(i + 1).trim();
  }
  return undefined;
}

async function viaAccess(token: string, env: AppEnv, keys?: JWTVerifyGetKey): Promise<Identity> {
  if (!env.ACCESS_TEAM_DOMAIN || !env.ACCESS_AUD) throw new HttpError(500, "Access is not configured");
  try {
    return await verifyAccessJwt(token, { teamDomain: env.ACCESS_TEAM_DOMAIN, audience: env.ACCESS_AUD, keys });
  } catch {
    throw new HttpError(401, "invalid Access token");
  }
}

/** A person signed in through Access (or dev), never a bearer token: for /authorize and grant management. */
export async function identifyPerson(request: Request, env: AppEnv, keys?: JWTVerifyGetKey): Promise<Identity> {
  if (env.DEV_IDENTITY) return { id: env.DEV_IDENTITY, via: "dev" };
  const header = request.headers.get("cf-access-jwt-assertion");
  if (header) return viaAccess(header, env, keys);
  const fromCookie = cookie(request, "CF_Authorization");
  if (fromCookie) {
    if (request.method !== "GET" && request.method !== "HEAD") {
      const origin = request.headers.get("origin");
      if (origin !== new URL(request.url).origin) throw new HttpError(403, "cross-site request refused");
    }
    return viaAccess(fromCookie, env, keys);
  }
  throw new HttpError(401, "sign in required");
}

export async function identify(request: Request, env: AppEnv, keys?: JWTVerifyGetKey): Promise<Identity> {
  const auth = request.headers.get("authorization");
  if (auth?.toLowerCase().startsWith("bearer ")) {
    const helpers = (env as AppEnv & { OAUTH_PROVIDER?: OAuthHelpers }).OAUTH_PROVIDER;
    const token = helpers && (await helpers.unwrapToken<UserProps>(auth.slice(7).trim()).catch(() => null));
    if (!token || token.expiresAt * 1000 < Date.now() || !token.grant.props?.email) {
      throw new HttpError(401, "invalid or expired token", { signIn: true });
    }
    return { id: token.grant.props.email, via: "oauth" };
  }
  return identifyPerson(request, env, keys);
}
