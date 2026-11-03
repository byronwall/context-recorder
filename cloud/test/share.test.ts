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
