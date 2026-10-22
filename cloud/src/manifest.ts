import { HttpError } from "./http";

/** Contract §1: manifest.json (format 1). */
export interface ManifestFile {
  path: string;
  size: number;
  sha256: string;
  type?: string;
}
export interface Manifest {
  format: 1;
  sessionId: string;
  title: string;
  recordedAt: string;
  duration: number;
  markCount: number;
  video?: { path: string; width?: number; height?: number };
  thumbs?: { interval: number; count: number; pattern: string; width?: number };
  poster?: string;
  skippedPages?: { path: string; size: number }[];
  inputHash?: string;
  files: ManifestFile[];
  [key: string]: unknown;
}

export const SESSION_ID = /^[A-Za-z0-9._-]{1,100}$/;
export const SHA256 = /^[0-9a-f]{64}$/;

export function isValidPath(path: unknown): path is string {
  if (typeof path !== "string" || !path || path.length > 1024) return false;
  if (path.startsWith("/") || path.includes("\\") || path.includes("\0")) return false;
  return path.split("/").every((seg) => seg !== "" && seg !== "." && seg !== "..");
}

export function assertSessionId(id: string): void {
  if (!SESSION_ID.test(id)) throw new HttpError(400, "invalid session id");
}

/** Validates a manifest for session `id`. Throws HttpError(400) with the first problem found. */
export function parseManifest(value: unknown, id: string): Manifest {
  const bad = (msg: string): never => {
    throw new HttpError(400, `invalid manifest: ${msg}`);
  };
  if (!value || typeof value !== "object" || Array.isArray(value)) bad("not an object");
  const m = value as Record<string, unknown>;
  if (m.format !== 1) bad("format must be 1");
  if (m.sessionId !== id) bad("sessionId does not match the URL");
  if (typeof m.title !== "string") bad("title must be a string");
  if (typeof m.recordedAt !== "string") bad("recordedAt must be a string");
  if (typeof m.duration !== "number" || !Number.isFinite(m.duration) || m.duration < 0) bad("duration must be a number ≥ 0");
  if (!Number.isInteger(m.markCount) || (m.markCount as number) < 0) bad("markCount must be an integer ≥ 0");
  if (m.poster !== undefined && !isValidPath(m.poster)) bad("poster must be a relative path");
  if (!Array.isArray(m.files)) bad("files must be an array");
  const seen = new Set<string>();
  for (const [i, f] of (m.files as unknown[]).entries()) {
    if (!f || typeof f !== "object") bad(`files[${i}] is not an object`);
    const file = f as Record<string, unknown>;
    if (!isValidPath(file.path)) bad(`files[${i}].path is not a relative path`);
    if (file.path === "manifest.json") bad("manifest.json must not list itself");
    if (seen.has(file.path as string)) bad(`duplicate path ${file.path}`);
    seen.add(file.path as string);
    if (!Number.isSafeInteger(file.size) || (file.size as number) < 0) bad(`files[${i}].size must be an integer ≥ 0`);
    if (typeof file.sha256 !== "string" || !SHA256.test(file.sha256)) bad(`files[${i}].sha256 must be lowercase hex`);
    if (file.type !== undefined && typeof file.type !== "string") bad(`files[${i}].type must be a string`);
  }
  return m as unknown as Manifest;
}

export const contentTypeOf = (f: { type?: string }): string => f.type || "application/octet-stream";
