import type { AppEnv } from "../env";
import type { Manifest } from "../manifest";
import type { Store } from "../store";
import { mediaFrames } from "./media";
import { thumbFrames } from "./thumbs";

/**
 * Frames port (docs/cloud-sessions.md §4): an image of the flattened video at an edited-time moment, without drawings.
 *  - `thumbs` (default): the nearest pushed thumbnail (480 px wide, every `thumbs.interval` seconds).
 *  - `media`: Cloudflare Media Transformations extracting a frame from a signed recording.mp4 URL.
 *    Needs a zone on Cloudflare with transformations enabled, so it waits for a custom domain.
 */
export interface Frame {
  /** The time the image actually shows (the thumbnail's time for `thumbs`). */
  time: number;
  mimeType: string;
  /** Base64 image bytes. */
  data: string;
  /** Where the image came from, for the agent: a session path or a description. */
  source: string;
}

export interface FrameRequest {
  id: string;
  manifest: Manifest;
  time: number;
  origin: string;
}

export interface Frames {
  readonly name: "thumbs" | "media";
  frameAt(req: FrameRequest): Promise<Frame>;
}

export function framesFor(env: AppEnv, store: Store, fetcher: typeof fetch = fetch): Frames {
  return env.FRAMES === "media" ? mediaFrames(env, fetcher) : thumbFrames(store);
}

export function toBase64(bytes: ArrayBuffer): string {
  const u8 = new Uint8Array(bytes);
  let bin = "";
  for (let i = 0; i < u8.length; i += 0x8000) bin += String.fromCharCode(...u8.subarray(i, i + 0x8000));
  return btoa(bin);
}
