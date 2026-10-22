import { env } from "cloudflare:workers";
import { beforeAll, describe, expect, it } from "vitest";
import type { AppEnv } from "../src/env";
import { signFileUrl } from "../src/signing";
import { call, ORIGIN, seed } from "./helpers";

const prod = { DEV_IDENTITY: undefined } as Partial<AppEnv>;

beforeAll(async () => {
  await seed("sig-1", 700);
});

describe("/f/* signed URLs", () => {
  it("serves the file without Identity while the signature is valid, with Range", async () => {
    const { url } = await signFileUrl(env, ORIGIN, "sig-1", "recording.mp4", 60);
    const res = await call(url, {}, prod);
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toBe("video/mp4");
    const ranged = await call(url, { headers: { range: "bytes=0-9" } }, prod);
    expect(ranged.status).toBe(206);
  });

  it("rejects an expired link", async () => {
    const { url } = await signFileUrl(env, ORIGIN, "sig-1", "recording.mp4", 60, Date.now() - 120_000);
    const res = await call(url, {}, prod);
    expect(res.status).toBe(403);
    expect(((await res.json()) as { error: string }).error).toBe("link expired");
  });

  it("rejects a tampered signature, a different path, or a missing signature", async () => {
    const { url } = await signFileUrl(env, ORIGIN, "sig-1", "recording.mp4", 60);
    const u = new URL(url);
    u.searchParams.set("sig", u.searchParams.get("sig")!.replace(/^./, (c) => (c === "A" ? "B" : "A")));
    expect((await call(u.href, {}, prod)).status).toBe(403);
    expect((await call(url.replace("recording.mp4", "session.json"), {}, prod)).status).toBe(403);
    expect((await call("/f/sig-1/recording.mp4", {}, prod)).status).toBe(403);
  });

  it("caps the TTL at an hour", async () => {
    const { expiresAt } = await signFileUrl(env, ORIGIN, "sig-1", "recording.mp4", 99_999, 0);
    expect(expiresAt).toBe(new Date(3600 * 1000).toISOString());
  });
});
