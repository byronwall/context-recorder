import { exportJWK, generateKeyPair, SignJWT, createLocalJWKSet } from "jose";
import { beforeAll, describe, expect, it } from "vitest";
import { identify, verifyAccessJwt } from "../src/identity";
import type { AppEnv } from "../src/env";
import { call, seed } from "./helpers";

const prod = { DEV_IDENTITY: undefined } as Partial<AppEnv>;

beforeAll(async () => {
  await seed("id-1", 600);
});

describe("Identity without DEV_IDENTITY", () => {
  it.each(["/", "/api/sessions", "/api/sessions/id-1", "/s/id-1/", "/s/id-1/recording.mp4", "/v/id-1", "/mcp"])(
    "rejects %s without a JWT",
    async (path) => {
      const res = await call(path, {}, prod);
      expect(res.status).toBe(401);
    },
  );

  it("rejects writes without a JWT", async () => {
    expect((await call("/api/sessions/id-1", { method: "DELETE" }, prod)).status).toBe(401);
    expect((await call("/api/sessions/id-1")).status).toBe(200); // still there
  });

  it("rejects a garbage JWT", async () => {
    const res = await call("/api/sessions", { headers: { "cf-access-jwt-assertion": "not.a.jwt" } }, prod);
    expect(res.status).toBe(401);
  });

  it("accepts DEV_IDENTITY", async () => {
    expect((await call("/api/sessions")).status).toBe(200);
  });
});

describe("Access JWT verification", () => {
  const team = "team.cloudflareaccess.com";
  const aud = "aud-tag";
  let keys: ReturnType<typeof createLocalJWKSet>;
  let privateKey: CryptoKey;

  beforeAll(async () => {
    const pair = await generateKeyPair("RS256", { extractable: true });
    privateKey = pair.privateKey as CryptoKey;
    const jwk = { ...(await exportJWK(pair.publicKey)), kid: "k1", alg: "RS256" };
    keys = createLocalJWKSet({ keys: [jwk] });
  });

  const sign = (claims: Record<string, unknown>, opts: { aud?: string; iss?: string; exp?: string } = {}) =>
    new SignJWT(claims)
      .setProtectedHeader({ alg: "RS256", kid: "k1" })
      .setIssuer(opts.iss ?? `https://${team}`)
      .setAudience(opts.aud ?? aud)
      .setIssuedAt()
      .setExpirationTime(opts.exp ?? "5m")
      .sign(privateKey);

  it("accepts a valid user token and a service token", async () => {
    expect(await verifyAccessJwt(await sign({ email: "me@example.com", sub: "u1" }), { teamDomain: team, audience: aud, keys })).toEqual({
      id: "me@example.com",
      via: "access",
    });
    const svc = await sign({ common_name: "abc.access", sub: "" });
    expect((await verifyAccessJwt(svc, { teamDomain: team, audience: aud, keys })).id).toBe("abc.access");
  });

  it("rejects the wrong audience, issuer, or an expired token", async () => {
    await expect(verifyAccessJwt(await sign({ email: "a@b" }, { aud: "other" }), { teamDomain: team, audience: aud, keys })).rejects.toThrow();
    await expect(verifyAccessJwt(await sign({ email: "a@b" }, { iss: "https://evil" }), { teamDomain: team, audience: aud, keys })).rejects.toThrow();
    await expect(verifyAccessJwt(await sign({ email: "a@b" }, { exp: "-1m" }), { teamDomain: team, audience: aud, keys })).rejects.toThrow();
  });

  it("identify() reads the header", async () => {
    const env = { ACCESS_TEAM_DOMAIN: team, ACCESS_AUD: aud } as AppEnv;
    const req = new Request("http://x/", { headers: { "cf-access-jwt-assertion": await sign({ email: "me@example.com" }) } });
    expect((await identify(req, env, keys)).id).toBe("me@example.com");
    await expect(identify(new Request("http://x/"), env, keys)).rejects.toMatchObject({ status: 401 });
  });
});
