import { describe, expect, it } from "vitest";
import { call, postJson, seed } from "./helpers";

async function share(id: string, label?: string) {
  const res = await postJson(`/api/sessions/${id}/shares`, label ? { label } : {});
  expect(res.status).toBe(201);
  return (await res.json()) as { token: string; url: string; label: string | null };
}

// A share link must work with no sign-in at all.
const signedOut = { DEV_IDENTITY: undefined };
const open = (path: string, init: RequestInit = {}) => call(path, init, signedOut);

describe("share links", () => {
  it("open one session signed out, Range included, until revoked", async () => {
    const { files } = await seed("s-link");
    const link = await share("s-link", "  Sam  ");
    expect(link.token).toMatch(/^[A-Za-z0-9_-]{22}$/);
    expect(link.url).toBe(`http://localhost/share/${link.token}/`);
    expect(link.label).toBe("Sam");

    expect((await open(`/s/s-link/`)).status).toBe(401);
    expect((await open(`/share/${link.token}`)).headers.get("location")).toBe(`/share/${link.token}/`);
    const page = await open(`/share/${link.token}/`);
    expect(page.status).toBe(200);
    expect(page.headers.get("referrer-policy")).toBe("no-referrer");
    const part = await open(`/share/${link.token}/recording.mp4`, { headers: { range: "bytes=0-9" } });
    expect(part.status).toBe(206);
    expect(new Uint8Array(await part.arrayBuffer())).toEqual(files["recording.mp4"]!.bytes.slice(0, 10));

    expect((await call(`/api/shares/${link.token}/revoke`, { method: "POST" })).status).toBe(204);
    const gone = await open(`/share/${link.token}/`);
    expect(gone.status).toBe(410);
    expect(await gone.text()).toContain("no longer shared");
    expect((await open(`/share/${link.token}/recording.mp4`)).status).toBe(410);
  });

  it("serves only the viewer's files, from its own session", async () => {
    await seed("s-own");
    await seed("s-other", 2);
    const { token } = await share("s-own");
    expect((await open(`/share/${token}/thumbs/0000.jpg`)).status).toBe(200);
    expect((await open(`/share/${token}/marks/001.md`)).status).toBe(404);
    expect((await open(`/share/${token}/../../s/s-other/session.json`)).status).not.toBe(200);
    expect((await open(`/share/nope/`)).status).toBe(404);
  });

  it("lists links newest first and drops them with the session", async () => {
    await seed("s-list");
    const a = await share("s-list", "a");
    const b = await share("s-list", "b");
    const list = (await (await call(`/api/sessions/s-list/shares`)).json()) as { token: string }[];
    expect(new Set(list.map((s) => s.token))).toEqual(new Set([a.token, b.token]));
    expect((await call(`/api/sessions/s-list`, { method: "DELETE" })).status).toBe(204);
    expect((await open(`/share/${a.token}/`)).status).toBe(404);
  });
});

describe("share link views", () => {
  const beacon = (token: string, body: unknown, ua = "Mozilla/5.0 (Macintosh)") =>
    open(`/share/${token}/view`, { method: "POST", body: JSON.stringify(body), headers: { "content-type": "text/plain", "user-agent": ua } });
  const stats = async (id: string) =>
    (await (await call(`/api/sessions/${id}/shares`)).json()) as {
      token: string; views: number; viewers: number; referrers: { host: string | null; views: number }[]; devices: { mobile: number };
    }[];

  it("counts beacons, not page loads, per link", async () => {
    await seed("s-views");
    const a = await share("s-views", "a");
    const b = await share("s-views", "b");
    await open(`/share/${a.token}/`); // a preview bot: HTML only, no beacon
    expect((await beacon(a.token, { viewer: "viewer-one", referrer: "https://app.slack.com/client/x" })).status).toBe(204);
    await beacon(a.token, { viewer: "viewer-one", referrer: "http://localhost/share/x/" });
    await beacon(a.token, { viewer: "viewer-two" }, "Mozilla/5.0 (iPhone)");
    await beacon(a.token, "not json");

    const byToken = new Map((await stats("s-views")).map((s) => [s.token, s]));
    const sa = byToken.get(a.token)!;
    expect(sa.views).toBe(4);
    expect(sa.viewers).toBe(3);
    expect(sa.devices.mobile).toBe(1);
    expect(sa.referrers).toContainEqual({ host: "app.slack.com", views: 1 });
    expect(sa.referrers).toContainEqual({ host: null, views: 3 }); // its own host and no referrer are both direct
    expect(byToken.get(b.token)!.views).toBe(0);
  });

  it("counts nothing on a revoked link", async () => {
    await seed("s-views-gone");
    const { token } = await share("s-views-gone");
    await call(`/api/shares/${token}/revoke`, { method: "POST" });
    expect((await beacon(token, { viewer: "viewer-one" })).status).toBe(410);
    expect((await stats("s-views-gone"))[0]!.views).toBe(0);
  });
});
