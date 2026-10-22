import { HttpError } from "../http";
import type { Manifest } from "../manifest";
import type { Store } from "../store";
import { toBase64, type Frames } from "./index";

/** Path and time of the thumbnail nearest to `time`, or null when the manifest has no thumbnails. */
export function nearestThumb(manifest: Manifest, time: number): { path: string; time: number } | null {
  const t = manifest.thumbs;
  if (!t || !(t.count > 0) || !(t.interval > 0)) return null;
  const i = Math.min(t.count - 1, Math.max(0, Math.round(time / t.interval)));
  const path = t.pattern.replace(/%0?(\d*)d/, (_, width: string) => String(i).padStart(Number(width || 0), "0"));
  return { path, time: i * t.interval };
}

export function thumbFrames(store: Store): Frames {
  return {
    name: "thumbs",
    async frameAt({ id, manifest, time }) {
      const thumb = nearestThumb(manifest, time);
      if (!thumb) throw new HttpError(404, "this session has no thumbnails");
      const got = await store.readFileBytes(id, thumb.path);
      if (!got) throw new HttpError(404, `thumbnail ${thumb.path} is not in the session`);
      return { time: thumb.time, mimeType: got.file.type || "image/jpeg", data: toBase64(got.bytes), source: thumb.path };
    },
  };
}
