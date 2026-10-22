import type { AppEnv } from "../env";
import { HttpError } from "../http";
import { signFileUrl } from "../signing";
import { toBase64, type Frames } from "./index";

/** The Media Transformations URL for one frame of a source video URL. */
export function mediaFrameUrl(origin: string, sourceUrl: string, time: number, width = 1280): string {
  return `${origin}/cdn-cgi/media/mode=frame,time=${Math.max(0, time).toFixed(2)}s,width=${width}/${sourceUrl}`;
}

export function mediaFrames(env: AppEnv, fetcher: typeof fetch): Frames {
  return {
    name: "media",
    async frameAt({ id, manifest, time, origin }) {
      const video = manifest.video?.path || "recording.mp4";
      // Signed from a 5-minute boundary so repeated calls share one URL, letting Media Transformations
      // cache the frame; the link stays valid 5–10 minutes.
      const step = 300_000;
      const { url: source } = await signFileUrl(env, origin, id, video, 600, Math.floor(Date.now() / step) * step);
      const res = await fetcher(mediaFrameUrl(origin, source, time));
      if (!res.ok) throw new HttpError(502, `Media Transformations returned ${res.status}`);
      return {
        time,
        mimeType: res.headers.get("content-type")?.split(";")[0] || "image/jpeg",
        data: toBase64(await res.arrayBuffer()),
        source: `${video} @ ${time.toFixed(2)}s (media)`,
      };
    },
  };
}
