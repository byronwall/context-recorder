---
title: "Cloud sessions — build contract"
slug: "cloud-sessions"
phase: build
status: current
last_updated: "2026-10-22"
---

# Cloud sessions — build contract

The single source of truth that the Mac app (`Sources/`), the Worker (`cloud/`) and the shared viewer
(`scripts/viewer.html`) are built against. Change it here first, then in code.

## 1. The cloud copy (format 1)

A folder written by `CloudBundle` on the Mac. Everything in it is in **edited time**: cuts and joins are
already flattened into one video, so nothing downstream knows about `edits.json`.

```text
<bundle>/
  manifest.json          described below; never listed in its own `files`
  index.html             viewer.html with session + cloud data embedded, for file:// playback; NOT in `files`
  session.json           the processed session.json, rewritten for the flattened video (see below)
  recording.mp4          H.264 + AAC. Unedited sessions: copied as is. Edited/joined: EditMap.composition export
  drawings.json          [{ "id": "<uuid>", "file": "drawings/<uuid>.png", "start": 12.0, "end": 15.0 }]
  drawings/<uuid>.png    transparent PNG at the video's pixel size, one per drawing (Annotation.Renderer)
  thumbs/0000.jpg …      480 px wide JPEG every `thumbs.interval` seconds; thumb i is at time i * interval
  marks/*.md  frames/*.jpg  screenshots/*.png (annotated copy where one exists)
  transcript.json  session.md  activity.jsonl  browser.jsonl  marks.jsonl
  pages/*.mhtml          saved pages within budget max(10 MB, video size / 2), smallest first
```

Never included: `audio.wav`, `process.log`, `edits.json`, `annotations.json`, the local `viewer.html`, `exports/`.

### `session.json` rewrite

- `segments` becomes `[{ "source": ".", "start": 0, "end": <duration>, "editedStart": 0 }]`.
- `sourceDurations` becomes `{ ".": <duration> }`, `duration` is the flattened video's duration.
- `folder` becomes `""` (the viewer uses relative paths). Mark `image`/`frame`/`pageFile` stay relative.
- Mark, transcript, activity and browser times are already edited time from processing; keep them.
- Marks whose `browser.pageFile` was skipped keep the field; `manifest.skippedPages` tells readers it's absent.

### `manifest.json`

```json
{
  "format": 1,
  "sessionId": "2026-10-21_23-54-37",
  "title": "Session name or the folder timestamp",
  "recordedAt": "2026-10-21T23:54:37-04:00",
  "duration": 40.6,
  "markCount": 4,
  "video": { "path": "recording.mp4", "width": 2880, "height": 1800 },
  "thumbs": { "interval": 2, "count": 21, "pattern": "thumbs/%04d.jpg", "width": 480 },
  "poster": "thumbs/0000.jpg",
  "skippedPages": [{ "path": "pages/m3-24.mhtml", "size": 12345678 }],
  "inputHash": "<sha256 hex of the local inputs: session.json, edits.json, annotations.json, recording.mp4 size+mtime, …>",
  "files": [
    { "path": "recording.mp4", "size": 31234567, "sha256": "<hex>", "type": "video/mp4" }
  ]
}
```

`sessionId` matches `^[A-Za-z0-9._-]{1,100}$`. `path` is relative, `/`-separated, with no `..` and no leading `/`.

## 2. Worker HTTP API

One Worker. Every route passes through `Identity` except `/share/*` (checked against D1, milestone 6).

- **Identity, production:** verify `Cf-Access-Jwt-Assertion` (RS256) against
  `https://<ACCESS_TEAM_DOMAIN>/cdn-cgi/access/certs` with `aud` = `ACCESS_AUD`. Service-token requests carry the
  same header. **Dev:** if `DEV_IDENTITY` is set, that string is the identity and no JWT is required.
- **Storage:** content-addressed. R2 key `blobs/<sha256>`. D1 holds each session's current manifest. A file
  is served by looking its path up in the manifest. Blobs no manifest references are deleted at commit/delete.

| Method & path | Body → response |
| --- | --- |
| `POST /api/sessions/:id/push` | manifest JSON → `{ "missing": ["<sha256>", …] }` (blobs R2 doesn't have yet) |
| `PUT /api/blobs/:sha256` | raw bytes (≤ 90 MB) → `204`. The Worker verifies the hash; mismatch → `400` |
| `POST /api/blobs/:sha256/uploads` | → `{ "uploadId" }` (R2 multipart, for files > 90 MB) |
| `PUT /api/blobs/:sha256/uploads/:uploadId/:partNumber` | raw part bytes → `{ "etag" }` |
| `POST /api/blobs/:sha256/uploads/:uploadId/complete` | `{ "parts": [{ "partNumber", "etag" }] }` → `204` |
| `POST /api/sessions/:id/commit` | manifest JSON → `{ "url": "<origin>/s/<id>/", "manifestSha256" }`. `409` + `{ missing }` if any blob is absent. Upserts D1, then GCs orphan blobs |
| `GET /api/sessions` | → `[{ id, title, recordedAt, duration, markCount, size, poster, pushedAt }]`, newest recording first |
| `GET /api/sessions/:id` | → `{ ...row, manifest }` or `404` |
| `DELETE /api/sessions/:id` | → `204`; removes the row and orphaned blobs |
| `GET /s/:id/` | the viewer (`viewer.html` from Worker static assets, no embedded data) |
| `GET /s/:id/<path>` | the file from the manifest, with `Content-Type` from the manifest, `Range` support (206), `ETag` = sha256, immutable caching. `manifest.json` is served from D1 |
| `GET /v/:id` | `302` → `/s/:id/` |
| `GET /` | library page |
| `/mcp` | MCP (section 4) |

`manifestSha256` is the sha256 of the manifest JSON exactly as the Mac sent it.

## 3. Viewer modes (`scripts/viewer.html`)

1. **Embedded (today):** `const DATA = /*__SESSION_DATA__*/null;` is replaced with the session JSON. If
   `DATA.cloud` is present it holds `{ "manifest": {…}, "drawings": […] }` — this is what `index.html` in a
   bundle uses on `file://`.
2. **Fetched:** when `DATA` is `null`, the viewer fetches `session.json`, `manifest.json` and `drawings.json`
   relative to the page (that's how `/s/:id/` works), then renders the same way.

With cloud data present the viewer: plays `recording.mp4` straight through (single segment), overlays each
drawing PNG between `start` and `end` scaled to the video box, shows thumbnail hover on the timeline from
`manifest.thumbs`, says "page not uploaded" for marks whose page is in `skippedPages`, and makes
**Copy as Markdown** use relative/cloud URLs instead of `DATA.folder`. Without cloud data, behaviour is
unchanged.

## 4. MCP tools (`/mcp`, stateless `createMcpHandler`)

- `list_sessions()` — the `GET /api/sessions` rows.
- `get_session(id)` — summary plus every mark as Markdown (same text as Copy as Markdown).
- `get_mark(id, index)` — that mark's Markdown, plus image content: screenshot and full frame.
- `get_frame(id, time)` — image content for that moment in edited time (no drawings), plus the drawings
  showing at that time as a list. `get_frames(id, from, to, count≤8)`.
- `get_file_url(id, path, ttlSeconds≤3600)` — `<origin>/f/<id>/<path>?exp=…&sig=…`, HMAC-SHA256 with
  `SIGNING_SECRET`; `/f/*` bypasses Identity but checks the signature and expiry.
- `Frames` port: `thumbs` adapter (nearest thumbnail; default) and `media` adapter (Media Transformations
  `/cdn-cgi/media/mode=frame,time=<t>s,width=1280/<signed source url>`), chosen by `FRAMES=thumbs|media`.

## 5. Mac push

- `CloudClient(baseURL, headers)`: `push` → upload each missing blob (PUT, or multipart above 90 MB) → `commit`.
  Headers carry `CF-Access-Client-Id` / `CF-Access-Client-Secret` when configured.
- Configuration: cloud URL in `UserDefaults` (`cloudURL`); service token id/secret in the Keychain
  (service `ContextRecorder.Cloud`). The CLI also reads `CR_CLOUD_URL`, `CR_CLOUD_CLIENT_ID`, `CR_CLOUD_CLIENT_SECRET`.
- After a commit, write `<session>/exports/cloud.json`:
  `{ "url", "manifestSha256", "inputHash", "pushedAt" }`. "Out of date" = current `inputHash` ≠ recorded one.
- CLI: `--cloud-bundle <session> <out-folder>` and `--push <session> [--cloud <url>]`.
