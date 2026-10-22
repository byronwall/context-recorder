import { beforeAll, describe, expect, it } from "vitest";
import { parseRange } from "../src/files";
import { call, seed, shaOf, type FileSet } from "./helpers";
import type { Manifest } from "../src/manifest";

let files: FileSet;
let manifest: Manifest;
beforeAll(async () => {
  ({ files, manifest } = await seed("f-1", 500));
});

const video = () => files["recording.mp4"]!.bytes;

describe("GET /s/:id/<path>", () => {
  it("serves a whole file with type, ETag and Accept-Ranges", async () => {
    const res = await call("/s/f-1/recording.mp4");
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toBe("video/mp4");
    expect(res.headers.get("etag")).toBe(`"${shaOf(manifest, "recording.mp4")}"`);
    expect(res.headers.get("accept-ranges")).toBe("bytes");
    expect(res.headers.get("cache-control")).toBe("private, no-cache");
    expect(new Uint8Array(await res.arrayBuffer())).toEqual(video());
  });

  it("answers bytes=a-b with 206 and the slice", async () => {
    const res = await call("/s/f-1/recording.mp4", { headers: { range: "bytes=100-199" } });
    expect(res.status).toBe(206);
    expect(res.headers.get("content-range")).toBe(`bytes 100-199/${video().length}`);
    expect(res.headers.get("content-length")).toBe("100");
    expect(new Uint8Array(await res.arrayBuffer())).toEqual(video().slice(100, 200));
  });

  it("answers open-ended and suffix ranges", async () => {
    const n = video().length;
    const open = await call("/s/f-1/recording.mp4", { headers: { range: `bytes=${n - 10}-` } });
    expect(open.status).toBe(206);
    expect(new Uint8Array(await open.arrayBuffer())).toEqual(video().slice(n - 10));
    const suffix = await call("/s/f-1/recording.mp4", { headers: { range: "bytes=-5" } });
    expect(suffix.status).toBe(206);
    expect(suffix.headers.get("content-range")).toBe(`bytes ${n - 5}-${n - 1}/${n}`);
    expect(new Uint8Array(await suffix.arrayBuffer())).toEqual(video().slice(n - 5));
  });

  it("answers an unsatisfiable range with 416", async () => {
    const res = await call("/s/f-1/recording.mp4", { headers: { range: `bytes=${video().length}-` } });
    expect(res.status).toBe(416);
    expect(res.headers.get("content-range")).toBe(`bytes */${video().length}`);
  });

  it("answers a matching If-None-Match with 304 and pins immutable caching with ?v=", async () => {
    const etag = `"${shaOf(manifest, "session.json")}"`;
    expect((await call("/s/f-1/session.json", { headers: { "if-none-match": etag } })).status).toBe(304);
    const pinned = await call(`/s/f-1/session.json?v=${shaOf(manifest, "session.json")}`);
    expect(pinned.headers.get("cache-control")).toContain("immutable");
  });

  it("answers HEAD with headers only", async () => {
    const res = await call("/s/f-1/recording.mp4", { method: "HEAD" });
    expect(res.status).toBe(200);
    expect(res.headers.get("content-length")).toBe(String(video().length));
  });

  it("serves manifest.json from D1, exactly as pushed", async () => {
    const res = await call("/s/f-1/manifest.json");
    expect(res.status).toBe(200);
    expect(await res.text()).toBe(JSON.stringify(manifest));
  });

  it("404s paths outside the manifest and 400s traversal", async () => {
    expect((await call("/s/f-1/nope.txt")).status).toBe(404);
    expect((await call("/s/f-1/pages/m2-big.mhtml")).status).toBe(404);
    expect((await call("/s/f-1/a%2F..%2Fsession.json")).status).toBe(400);
  });
});

describe("viewer, redirects, library", () => {
  it("serves the viewer at /s/:id/ with no embedded data", async () => {
    const res = await call("/s/f-1/");
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toContain("text/html");
    expect(await res.text()).toContain("/*__SESSION_DATA__*/null");
    expect((await call("/s/missing/")).status).toBe(404);
  });

  it("redirects /s/:id and /v/:id to /s/:id/", async () => {
    const s = await call("/s/f-1");
    expect(s.status).toBe(301);
    expect(s.headers.get("location")).toBe("/s/f-1/");
    const v = await call("/v/f-1");
    expect(v.status).toBe(302);
    expect(v.headers.get("location")).toBe("/s/f-1/");
  });

  it("lists sessions on the library page", async () => {
    const res = await call("/");
    const html = await res.text();
    expect(html).toContain("Title of f-1");
    expect(html).toContain('href="/s/f-1/"');
    expect(html).toContain('src="/s/f-1/thumbs/0000.jpg"');
    expect(html).toContain('data-delete="f-1"');
  });
});

describe("parseRange", () => {
  it("handles edge cases", () => {
    expect(parseRange(null, 10)).toBeNull();
    expect(parseRange("bytes=0-0", 10)).toEqual({ offset: 0, length: 1 });
    expect(parseRange("bytes=5-100", 10)).toEqual({ offset: 5, length: 5 });
    expect(parseRange("bytes=-100", 10)).toEqual({ offset: 0, length: 10 });
    expect(parseRange("bytes=0-1,4-5", 10)).toBeNull();
    expect(parseRange("bytes=7-3", 10)).toBeNull();
    expect(parseRange("bytes=10-", 10)).toBe("unsatisfiable");
  });
});
