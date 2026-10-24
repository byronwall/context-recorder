import { McpServer, type CallToolResult } from "@modelcontextprotocol/server";
import { z } from "zod";
import type { AppEnv } from "../env";
import { framesFor, toBase64, type Frames } from "../frames";
import { HttpError } from "../http";
import type { Manifest } from "../manifest";
import { cloudURL, fmt, markdownFor, sessionMarkdown, type SessionJson } from "../markdown";
import { MAX_TTL_SECONDS, signFileUrl } from "../signing";
import type { Store } from "../store";

/**
 * MCP tools (docs/cloud-sessions.md §4). One McpServer per request (stateless). Everything an agent gets is read
 * from the same Store the viewer uses, so tool output matches what /s/:id/ shows.
 */
export interface McpDeps {
  env: AppEnv;
  store: Store;
  origin: string;
  frames?: Frames;
}

interface Drawing {
  id: string;
  file: string;
  start: number;
  end: number;
}

type Content = CallToolResult["content"][number];
const text = (t: string): Content => ({ type: "text", text: t });
const ok = (...content: Content[]): CallToolResult => ({ content });
const fail = (message: string): CallToolResult => ({ isError: true, content: [text(message)] });

async function guard(fn: () => Promise<CallToolResult>): Promise<CallToolResult> {
  try {
    return await fn();
  } catch (e) {
    if (e instanceof HttpError) return fail(e.message);
    console.error(e);
    return fail("internal error");
  }
}

export function buildMcpServer(deps: McpDeps): McpServer {
  const { env, store, origin } = deps;
  const frames = deps.frames ?? framesFor(env, store);
  const server = new McpServer({ name: "context-recorder-sessions", version: "1.0.0" });

  const base = (id: string) => `${origin}/s/${encodeURIComponent(id)}/`;

  async function loadSession(id: string): Promise<{ manifest: Manifest; session: SessionJson }> {
    const row = await store.getSession(id);
    if (!row) throw new HttpError(404, `no session ${id}`);
    const manifest = JSON.parse(row.manifestText) as Manifest;
    const session = (await store.readFileJson<SessionJson>(id, "session.json")) ?? {};
    return { manifest, session };
  }

  async function drawingsAt(id: string, time: number): Promise<Drawing[]> {
    const all = (await store.readFileJson<Drawing[]>(id, "drawings.json")) ?? [];
    // Same rule as the viewer: a drawing shows while start ≤ t < end.
    return all.filter((d) => d && d.start <= time && time < d.end);
  }

  async function image(id: string, path: string | undefined, label: string): Promise<Content[]> {
    if (!path) return [];
    const got = await store.readFileBytes(id, path);
    if (!got) return [text(`${label}: ${path} is not in the cloud copy.`)];
    return [text(`${label}: ${path}`), { type: "image", data: toBase64(got.bytes), mimeType: got.file.type || "image/png" }];
  }

  async function frameContent(id: string, manifest: Manifest, time: number): Promise<Content[]> {
    const [frame, drawings] = await Promise.all([frames.frameAt({ id, manifest, time, origin }), drawingsAt(id, time)]);
    const lines = [
      `Frame at ${time.toFixed(2)}s (${fmt(time)}) from ${frame.source}${Math.abs(frame.time - time) > 0.01 ? `, which shows ${frame.time.toFixed(2)}s` : ""}. Drawings are not included in the image.`,
      drawings.length
        ? `Drawings showing at this time:\n${drawings.map((d) => `- ${d.id}: ${d.file} (${d.start.toFixed(2)}–${d.end.toFixed(2)}s)`).join("\n")}`
        : "No drawings showing at this time.",
    ];
    return [text(lines.join("\n")), { type: "image", data: frame.data, mimeType: frame.mimeType }];
  }

  server.registerTool(
    "list_sessions",
    {
      title: "List sessions",
      description: "All pushed Context Recorder sessions, newest recording first: id, title, recordedAt, duration (s), markCount, size (bytes), poster, pushedAt, machine (the Mac that pushed it).",
      annotations: { readOnlyHint: true },
    },
    () =>
      guard(async () => {
        const rows = await store.listSessions();
        return { content: [text(JSON.stringify(rows, null, 2))], structuredContent: { sessions: rows } };
      }),
  );

  server.registerTool(
    "get_session",
    {
      title: "Get session",
      description: "A session's summary plus every mark as Markdown (the viewer's Copy as Markdown). Times are seconds into the (edited) video.",
      inputSchema: z.object({ id: z.string().describe("Session id from list_sessions") }),
      annotations: { readOnlyHint: true },
    },
    ({ id }) =>
      guard(async () => {
        const { manifest, session } = await loadSession(id);
        const ctx = { base: base(id), manifest };
        const summary = [
          `Session ${id}: "${manifest.title}"`,
          `Recorded ${manifest.recordedAt}; ${fmt(manifest.duration)} (${manifest.duration.toFixed(1)}s); ${manifest.markCount} marks.`,
          `Viewer: ${base(id)}`,
          `Video: ${cloudURL(ctx, manifest.video?.path || "recording.mp4")}`,
          "Use get_mark for a mark's images, get_frame/get_frames for any moment, get_file_url for a fetchable link to any file.",
        ].join("\n");
        return ok(text(summary), text(sessionMarkdown(session, ctx)));
      }),
  );

  server.registerTool(
    "get_mark",
    {
      title: "Get mark",
      description: "One mark's Markdown plus its images: the screenshot (or annotated frame) and the full video frame.",
      inputSchema: z.object({ id: z.string(), index: z.number().int().describe("The mark's index, as in get_session") }),
      annotations: { readOnlyHint: true },
    },
    ({ id, index }) =>
      guard(async () => {
        const { manifest, session } = await loadSession(id);
        const mark = (session.marks || []).find((m) => m.index === index);
        if (!mark) return fail(`session ${id} has no mark ${index}`);
        const content: Content[] = [text(markdownFor(mark, { base: base(id), manifest }))];
        content.push(...(await image(id, mark.image, mark.screenshot && mark.image === mark.screenshot ? "Screenshot" : "Image")));
        if (mark.frame && mark.frame !== mark.image) content.push(...(await image(id, mark.frame, "Full frame")));
        return ok(...content);
      }),
  );

  server.registerTool(
    "get_frame",
    {
      title: "Get frame",
      description: "An image of the video at a moment (seconds, edited time) without drawings, plus the drawings showing then.",
      inputSchema: z.object({ id: z.string(), time: z.number().min(0) }),
      annotations: { readOnlyHint: true },
    },
    ({ id, time }) =>
      guard(async () => {
        const { manifest } = await loadSession(id);
        if (time > manifest.duration) return fail(`time ${time} is past the end (${manifest.duration}s)`);
        return ok(...(await frameContent(id, manifest, time)));
      }),
  );

  server.registerTool(
    "get_frames",
    {
      title: "Get frames",
      description: "Up to 8 evenly spaced frames between `from` and `to` (seconds, edited time, inclusive).",
      inputSchema: z.object({
        id: z.string(),
        from: z.number().min(0),
        to: z.number().min(0),
        count: z.number().int().min(1).max(8).default(4),
      }),
      annotations: { readOnlyHint: true },
    },
    ({ id, from, to, count }) =>
      guard(async () => {
        const { manifest } = await loadSession(id);
        const end = Math.min(Math.max(from, to), manifest.duration);
        const start = Math.min(from, to, end);
        const n = count ?? 4;
        const times = n === 1 ? [start] : Array.from({ length: n }, (_, i) => start + ((end - start) * i) / (n - 1));
        const parts = await Promise.all(times.map((t) => frameContent(id, manifest, t)));
        return ok(...parts.flat());
      }),
  );

  server.registerTool(
    "get_file_url",
    {
      title: "Get file URL",
      description: `A signed link to one file of the session (e.g. recording.mp4, marks/001.md, pages/….mhtml) that works without signing in until it expires (at most ${MAX_TTL_SECONDS}s).`,
      inputSchema: z.object({
        id: z.string(),
        path: z.string().describe("Path from the session's manifest files"),
        ttlSeconds: z.number().int().min(1).max(MAX_TTL_SECONDS).default(900),
      }),
      annotations: { readOnlyHint: true },
    },
    ({ id, path, ttlSeconds }) =>
      guard(async () => {
        if (!(await store.getSession(id))) return fail(`no session ${id}`);
        if (path !== "manifest.json" && !(await store.getFile(id, path))) return fail(`${path} is not in session ${id}`);
        const signed = await signFileUrl(env, origin, id, path, ttlSeconds ?? 900);
        return { content: [text(`${signed.url}\nExpires ${signed.expiresAt}`)], structuredContent: signed };
      }),
  );

  return server;
}
