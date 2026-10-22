import { createExecutionContext, waitOnExecutionContext } from "cloudflare:test";
import { env } from "cloudflare:workers";
import type { AppEnv } from "../src/env";
import { sha256Hex } from "../src/http";
import { handleRequest } from "../src/index";
import type { Manifest } from "../src/manifest";

export const ORIGIN = "http://localhost";

export async function call(path: string, init: RequestInit = {}, envOverride: Partial<AppEnv> = {}): Promise<Response> {
  const request = new Request(path.startsWith("http") ? path : ORIGIN + path, init);
  const ctx = createExecutionContext();
  const res = await handleRequest(request, { ...env, ...envOverride } as AppEnv, ctx);
  await waitOnExecutionContext(ctx);
  return res;
}

export const postJson = (path: string, body: unknown) =>
  call(path, { method: "POST", headers: { "content-type": "application/json" }, body: typeof body === "string" ? body : JSON.stringify(body) });

export type FileSet = Record<string, { bytes: Uint8Array; type: string }>;

const enc = (s: string) => new TextEncoder().encode(s);

/** Deterministic pseudo-random bytes so a "video" has a stable hash per seed. */
export function bytes(n: number, seed = 1): Uint8Array {
  const out = new Uint8Array(n);
  let x = seed * 2654435761;
  for (let i = 0; i < n; i++) {
    x = (x * 1103515245 + 12345) >>> 0;
    out[i] = x >>> 24;
  }
  return out;
}

export function sessionJson(id: string) {
  return {
    name: id,
    folder: "",
    duration: 6,
    segments: [{ source: ".", start: 0, end: 6, editedStart: 0 }],
    sourceDurations: { ".": 6 },
    marks: [
      {
        index: 1,
        kind: "screenshot",
        offsetSeconds: 1.5,
        screenshot: "screenshots/001.png",
        image: "screenshots/001.png",
        frame: "frames/001.jpg",
        narration: "The button is misaligned.",
        context: { appName: "Safari", bundleID: "com.apple.Safari", browserURL: "https://example.com/", browserTitle: "Example" },
        browser: { pageFile: "pages/m1.mhtml", hovered: { selector: "button.save", text: "Save" } },
      },
      {
        index: 2,
        kind: "mark",
        offsetSeconds: 4.2,
        image: "frames/002.jpg",
        frame: "frames/002.jpg",
        narration: "",
        context: { appName: "Xcode", bundleID: "com.apple.dt.Xcode", windowTitle: "Project" },
        browser: { pageFile: "pages/m2-big.mhtml" },
      },
    ],
  };
}

/** A small cloud copy (docs/cloud-sessions.md §1) for session `id`. `variant` changes the video's bytes. */
export function makeFiles(id: string, variant = 1): FileSet {
  return {
    "session.json": { bytes: enc(JSON.stringify(sessionJson(id))), type: "application/json" },
    "recording.mp4": { bytes: bytes(64 * 1024, variant), type: "video/mp4" },
    "drawings.json": {
      bytes: enc(JSON.stringify([{ id: "d1", file: "drawings/d1.png", start: 1, end: 3 }])),
      type: "application/json",
    },
    "drawings/d1.png": { bytes: bytes(300, 50), type: "image/png" },
    "thumbs/0000.jpg": { bytes: bytes(200, 100), type: "image/jpeg" },
    "thumbs/0001.jpg": { bytes: bytes(200, 101), type: "image/jpeg" },
    "thumbs/0002.jpg": { bytes: bytes(200, 102), type: "image/jpeg" },
    "thumbs/0003.jpg": { bytes: bytes(200, 103), type: "image/jpeg" },
    "screenshots/001.png": { bytes: bytes(500, 200), type: "image/png" },
    "frames/001.jpg": { bytes: bytes(400, 201), type: "image/jpeg" },
    "frames/002.jpg": { bytes: bytes(400, 202), type: "image/jpeg" },
    "marks/001.md": { bytes: enc("## 001\n"), type: "text/markdown" },
    "pages/m1.mhtml": { bytes: bytes(1000, 300), type: "multipart/related" },
  };
}

export async function makeManifest(id: string, files: FileSet, extra: Partial<Manifest> = {}): Promise<Manifest> {
  return {
    format: 1,
    sessionId: id,
    title: `Title of ${id}`,
    recordedAt: "2026-10-21T23:54:37-04:00",
    duration: 6,
    markCount: 2,
    video: { path: "recording.mp4", width: 1280, height: 800 },
    thumbs: { interval: 2, count: 4, pattern: "thumbs/%04d.jpg", width: 480 },
    poster: "thumbs/0000.jpg",
    skippedPages: [{ path: "pages/m2-big.mhtml", size: 12345678 }],
    inputHash: "0".repeat(64),
    files: await Promise.all(
      Object.entries(files).map(async ([path, f]) => ({ path, size: f.bytes.length, sha256: await sha256Hex(f.bytes), type: f.type })),
    ),
    ...extra,
  };
}

/** PUT a blob. Requests built inside the Worker don't get content-length automatically; real clients send it. */
export const putBlob = (sha: string, data: Uint8Array) =>
  call(`/api/blobs/${sha}`, { method: "PUT", body: data, headers: { "content-length": String(data.length) } });

/** The Mac's push: push → PUT each missing blob → commit. */
export async function pushSession(manifest: Manifest, files: FileSet) {
  const pushRes = await postJson(`/api/sessions/${manifest.sessionId}/push`, manifest);
  if (pushRes.status !== 200) throw new Error(`push ${pushRes.status}: ${await pushRes.text()}`);
  const { missing } = (await pushRes.json()) as { missing: string[] };
  const bySha = new Map(manifest.files.map((f) => [f.sha256, files[f.path]!.bytes]));
  for (const sha of missing) {
    const res = await putBlob(sha, bySha.get(sha)!);
    if (res.status !== 204) throw new Error(`put ${sha} ${res.status}: ${await res.text()}`);
  }
  const commitRes = await postJson(`/api/sessions/${manifest.sessionId}/commit`, manifest);
  if (commitRes.status !== 200) throw new Error(`commit ${commitRes.status}: ${await commitRes.text()}`);
  return { missing, commit: (await commitRes.json()) as { url: string; manifestSha256: string } };
}

export async function seed(id: string, variant = 1) {
  const files = makeFiles(id, variant);
  const manifest = await makeManifest(id, files);
  await pushSession(manifest, files);
  return { files, manifest };
}

export const shaOf = (m: Manifest, path: string) => m.files.find((f) => f.path === path)!.sha256;

export async function inR2(sha: string): Promise<boolean> {
  return (await env.BUCKET.head(`blobs/${sha}`)) !== null;
}
