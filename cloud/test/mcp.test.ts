import { Client, StreamableHTTPClientTransport } from "@modelcontextprotocol/client";
import { env } from "cloudflare:workers";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import type { AppEnv } from "../src/env";
import { toBase64 } from "../src/frames";
import { mediaFrames, mediaFrameUrl } from "../src/frames/media";
import { nearestThumb } from "../src/frames/thumbs";
import { call, ORIGIN, seed, type FileSet } from "./helpers";
import type { Manifest } from "../src/manifest";

let client: Client;
let files: FileSet;
let manifest: Manifest;

type Content = { type: string; text?: string; data?: string; mimeType?: string };
const texts = (r: { content: unknown }) => (r.content as Content[]).filter((c) => c.type === "text").map((c) => c.text!);
const images = (r: { content: unknown }) => (r.content as Content[]).filter((c) => c.type === "image");
const b64 = (path: string) => toBase64(files[path]!.bytes.slice().buffer as ArrayBuffer);

beforeAll(async () => {
  ({ files, manifest } = await seed("mcp-1", 800));
  client = new Client({ name: "test", version: "1.0.0" });
  const transport = new StreamableHTTPClientTransport(new URL(`${ORIGIN}/mcp`), {
    // Requests built inside the Worker have no Host header; real ones always do.
    fetch: (input, init) => {
      const headers = new Headers(init?.headers);
      headers.set("host", "localhost");
      return call(new Request(input, init).url, { ...init, headers });
    },
  });
  await client.connect(transport);
});

afterAll(async () => {
  await client?.close();
});

describe("MCP tools against a seeded bucket", () => {
  it("lists the six tools", async () => {
    const { tools } = await client.listTools();
    expect(tools.map((t) => t.name).sort()).toEqual(["get_file_url", "get_frame", "get_frames", "get_mark", "get_session", "list_sessions"]);
  });

  it("list_sessions returns the API rows", async () => {
    const r = await client.callTool({ name: "list_sessions", arguments: {} });
    const rows = JSON.parse(texts(r)[0]!) as { id: string; title: string }[];
    expect(rows.find((x) => x.id === "mcp-1")?.title).toBe("Title of mcp-1");
  });

  it("get_session returns the summary and every mark as Markdown with absolute URLs", async () => {
    const r = await client.callTool({ name: "get_session", arguments: { id: "mcp-1" } });
    const [summary, md] = texts(r);
    expect(summary).toContain("Viewer: http://localhost/s/mcp-1/");
    expect(md).toMatch(/^# Title of mcp-1\n\n## 001 · 0:01 · The button is misaligned\./);
    expect(md).toContain("![mark 1](http://localhost/s/mcp-1/screenshots/001.png)");
    expect(md).toContain("- **Video:** `http://localhost/s/mcp-1/recording.mp4` @ 1.5s");
    expect(md).toContain("- **Saved page:** `http://localhost/s/mcp-1/pages/m1.mhtml`");
    expect(md).toContain("- **Saved page:** not uploaded (`pages/m2-big.mhtml` is only in the local session)");
    expect(md).toContain("## 002 · 0:04 · Project");
  });

  it("get_session reports an unknown session as a tool error", async () => {
    const r = await client.callTool({ name: "get_session", arguments: { id: "nope" } });
    expect(r.isError).toBe(true);
  });

  it("get_mark returns the Markdown, the screenshot and the full frame", async () => {
    const r = await client.callTool({ name: "get_mark", arguments: { id: "mcp-1", index: 1 } });
    expect(texts(r)[0]).toMatch(/^## 001 · 0:01/);
    const imgs = images(r);
    expect(imgs.map((i) => i.data)).toEqual([b64("screenshots/001.png"), b64("frames/001.jpg")]);
    expect(imgs.map((i) => i.mimeType)).toEqual(["image/png", "image/jpeg"]);
    const two = await client.callTool({ name: "get_mark", arguments: { id: "mcp-1", index: 2 } });
    expect(images(two)).toHaveLength(1); // image === frame: sent once
    expect((await client.callTool({ name: "get_mark", arguments: { id: "mcp-1", index: 9 } })).isError).toBe(true);
  });

  it("get_frame returns the nearest thumbnail and the drawings showing (start ≤ t < end)", async () => {
    const r = await client.callTool({ name: "get_frame", arguments: { id: "mcp-1", time: 2.2 } });
    expect(images(r)[0]!.data).toBe(b64("thumbs/0001.jpg"));
    expect(texts(r)[0]).toContain("d1: drawings/d1.png");
    const atEnd = await client.callTool({ name: "get_frame", arguments: { id: "mcp-1", time: 3 } });
    expect(texts(atEnd)[0]).toContain("No drawings showing");
    expect((await client.callTool({ name: "get_frame", arguments: { id: "mcp-1", time: 99 } })).isError).toBe(true);
  });

  it("get_frames returns evenly spaced frames, capped at 8", async () => {
    const r = await client.callTool({ name: "get_frames", arguments: { id: "mcp-1", from: 0, to: 6, count: 4 } });
    expect(images(r).map((i) => i.data)).toEqual([b64("thumbs/0000.jpg"), b64("thumbs/0001.jpg"), b64("thumbs/0002.jpg"), b64("thumbs/0003.jpg")]);
    const tooMany = await client.callTool({ name: "get_frames", arguments: { id: "mcp-1", from: 0, to: 6, count: 9 } });
    expect(tooMany.isError).toBe(true);
  });

  it("get_file_url returns a signed URL that serves the file", async () => {
    const r = await client.callTool({ name: "get_file_url", arguments: { id: "mcp-1", path: "marks/001.md", ttlSeconds: 60 } });
    const url = texts(r)[0]!.split("\n")[0]!;
    expect(url).toMatch(/^http:\/\/localhost\/f\/mcp-1\/marks\/001\.md\?exp=\d+&sig=/);
    const res = await call(url, {}, { DEV_IDENTITY: undefined });
    expect(await res.text()).toBe("## 001\n");
    expect((await client.callTool({ name: "get_file_url", arguments: { id: "mcp-1", path: "nope" } })).isError).toBe(true);
    expect((await client.callTool({ name: "get_file_url", arguments: { id: "mcp-1", path: "recording.mp4", ttlSeconds: 7200 } })).isError).toBe(true);
  });
});

describe("2025-era (legacy) clients", () => {
  const rpc = (body: unknown, extra: Record<string, string> = {}) =>
    call("/mcp", {
      method: "POST",
      headers: { host: "localhost", "content-type": "application/json", accept: "application/json, text/event-stream", ...extra },
      body: JSON.stringify(body),
    });
  const parse = async (res: Response) => {
    const t = await res.text();
    const data = t.includes("data:") ? t.split("\n").find((l) => l.startsWith("data:"))!.slice(5) : t;
    return JSON.parse(data);
  };

  it("initialize then tools/call statelessly", async () => {
    const init = await rpc({
      jsonrpc: "2.0", id: 1, method: "initialize",
      params: { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "legacy", version: "1" } },
    });
    expect(init.status).toBe(200);
    expect((await parse(init)).result.serverInfo.name).toBe("context-recorder-sessions");
    const listed = await rpc({ jsonrpc: "2.0", id: 2, method: "tools/call", params: { name: "list_sessions", arguments: {} } }, { "mcp-protocol-version": "2025-06-18" });
    expect(listed.status).toBe(200);
    expect((await parse(listed)).result.content[0].text).toContain("mcp-1");
  });
});

describe("Frames adapters", () => {
  it("nearestThumb rounds to the nearest interval and clamps", () => {
    const m = { thumbs: { interval: 2, count: 4, pattern: "thumbs/%04d.jpg" } } as Manifest;
    expect(nearestThumb(m, 0)).toEqual({ path: "thumbs/0000.jpg", time: 0 });
    expect(nearestThumb(m, 2.9)).toEqual({ path: "thumbs/0001.jpg", time: 2 });
    expect(nearestThumb(m, 3.1)).toEqual({ path: "thumbs/0002.jpg", time: 4 });
    expect(nearestThumb(m, 100)).toEqual({ path: "thumbs/0003.jpg", time: 6 });
    expect(nearestThumb({} as Manifest, 1)).toBeNull();
  });

  it("media builds a Media Transformations URL over a signed source", async () => {
    let requested = "";
    const fakeFetch = (async (input: RequestInfo | URL) => {
      requested = String(input);
      return new Response(new Uint8Array([1, 2, 3]), { headers: { "content-type": "image/jpeg" } });
    }) as typeof fetch;
    const frames = mediaFrames(env as AppEnv, fakeFetch);
    const frame = await frames.frameAt({ id: "mcp-1", manifest, time: 12.5, origin: "https://sessions.example.com" });
    expect(requested).toMatch(
      /^https:\/\/sessions\.example\.com\/cdn-cgi\/media\/mode=frame,time=12\.50s,width=1280\/https:\/\/sessions\.example\.com\/f\/mcp-1\/recording\.mp4\?exp=\d+&sig=/,
    );
    expect(frame.data).toBe(btoa("\x01\x02\x03"));
    expect(mediaFrameUrl("https://o", "https://o/f/x/v.mp4?exp=1&sig=s", 1)).toBe("https://o/cdn-cgi/media/mode=frame,time=1.00s,width=1280/https://o/f/x/v.mp4?exp=1&sig=s");
  });
});
