# Cloud sessions: format, API and sign-in

The reference that the Mac app (`Sources/ContextRecorder/Cloud/`), the Worker (`cloud/`) and the shared viewer
(`scripts/viewer.html`) are built against. Code comments cite its sections as "§N". Change it here first,
then in code. Running and deploying the Worker is in [cloud/README.md](../cloud/README.md); why it's built
this way is in [docs/intent/cloud-sessions/](intent/cloud-sessions/shape-brief.md).

## 1. The cloud copy (format 1)

A folder written by `CloudBundle` on the Mac. Everything in it is in **edited time**: cuts and joins are
already flattened into one video, so nothing downstream knows about `edits.json`. It is laid out as a session
recorded **without edits**, so a Mac that downloads it (§7) has an ordinary session that it can edit and process
again (`process_session.py`) and get the same marks back.

```text
<bundle>/
  manifest.json          described below; never listed in its own `files`
  index.html             viewer.html with session + cloud data embedded, for file:// playback; NOT in `files`
  session.json           the processed session.json, rewritten for the flattened video (see below)
  recording.mp4          H.264 + AAC, always fast start (moov before mdat). Unedited: copied as is, or remuxed losslessly (passthrough) when moov is at the end. Edited/joined: EditMap.composition export
  drawings.json          [{ "id": "<uuid>", "file": "drawings/<uuid>.png", "start": 12.0, "end": 15.0 }]
  drawings/<uuid>.png    transparent PNG at the video's pixel size, one per drawing (Annotation.Renderer)
  annotations.json       the same drawings as editable shapes: one per drawing window, source ".", edited time
  thumbs/0000.jpg …      480 px wide JPEG every `thumbs.interval` seconds; thumb i is at time i * interval
  frames/NNN.jpg  screenshots/NNN.png   each mark's frame and screenshot, NNN = its play-order index
  annotations/frames-NNN.png|json …     a marked-up image and its drawing, under the name processing uses
  marks/*.md  session.md
  marks.jsonl  activity.jsonl  browser.jsonl  transcript.json   the raw logs, rewritten in edited time
  pages/*.mhtml          saved pages within budget max(10 MB, video size / 2), smallest first
  pages/*.error.txt      for each page left out: "Left out of the cloud copy (12 MB)"
```

Never included: `audio.wav`, `process.log`, `edits.json`, the local `viewer.html`, `exports/`, `session-info.json`,
cut marks.

- `marks.jsonl` is `session.json`'s marks without the fields processing derives (`frame`, `image`, `sourceFrame`,
  `sourceImage`, `narration`) or adds for edits (`sourceOffsetSeconds`, `sourceSession`, `rawSession`, `rawIndex`).
- `activity.jsonl` and `browser.jsonl` are `session.json`'s mapped lists. `transcript.json` is each source's
  transcript mapped like `process_session.py`'s `map_sentences` (a sentence survives when more than half of it is
  kept; word times are mapped, words inside cuts dropped). An unedited session's transcript is copied as is.
- `annotations.json`: a drawing that a cut splits gets one shape per window. The first keeps its id, the others
  get ids derived from it, so pushing again doesn't change the file.

### `session.json` rewrite

- `segments` becomes `[{ "source": ".", "start": 0, "end": <duration>, "editedStart": 0 }]`.
- `sourceDurations` becomes `{ ".": <duration> }`, `duration` is the flattened video's duration.
- `folder` becomes `""` (the viewer uses relative paths). `hiddenMarks` becomes `[]`.
- Each mark's `frame`, `image`, `sourceFrame`, `sourceImage` and `screenshot` point at the play-order files above
  (`image`/`frame` at the marked-up copy where one exists). The edit fields listed above are dropped. `pageFile`
  stays relative; a joined session's pages go in `sources/<source>/…`.
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
  "inputHash": "<sha256 hex of a bundle-format version and the local inputs: session.json, edits.json, annotations.json, recording.mp4 size+mtime, …>",
  "machine": "Studio",
  "files": [
    { "path": "recording.mp4", "size": 31234567, "sha256": "<hex>", "type": "video/mp4" }
  ]
}
```

`sessionId` matches `^[A-Za-z0-9._-]{1,100}$`. `path` is relative, `/`-separated, with no `..` and no leading `/`.
`machine` (optional, ≤ 200 characters) is the pushing Mac's name (`Host.current().localizedName`); older pushes
don't have it.

Drawings that a cut splits into separate windows get one `drawings.json` entry per window, sharing a PNG.

## 2. Worker HTTP API

One Worker. Every route passes through `Identity` (§6) except `/f/*` (signed URLs, §4) and the OAuth
endpoints the provider owns.
- **Storage:** content-addressed. R2 key `blobs/<sha256>`. D1 holds each session's current manifest. A file
  is served by looking its path up in the manifest. Blobs no manifest references are deleted at commit/delete.

| Method & path | Body → response |
| --- | --- |
| `POST /api/sessions/:id/push` | manifest JSON → `{ "missing": ["<sha256>", …] }` (blobs R2 doesn't have yet) |
| `PUT /api/blobs/:sha256` | raw bytes (≤ 90 MiB, `Content-Length` required) → `204`. The Worker verifies the hash; mismatch → `400` |
| `POST /api/blobs/:sha256/uploads` | → `{ "uploadId" }` (R2 multipart, for files > 90 MB) |
| `PUT /api/blobs/:sha256/uploads/:uploadId/:partNumber` | raw part bytes → `{ "etag" }` |
| `POST /api/blobs/:sha256/uploads/:uploadId/complete` | `{ "parts": [{ "partNumber", "etag" }] }` → `204` |
| `POST /api/sessions/:id/commit` | manifest JSON → `{ "url": "<origin>/s/<id>/", "manifestSha256" }`. `409` + `{ missing }` if any blob is absent. Optional `If-Match: "<manifestSha256>"`: replace only that version, else `412` + `{ current: <session row + manifestSha256> }` and nothing changes. Upserts D1, then GCs orphan blobs |
| `GET /api/sessions` | → `[{ id, title, recordedAt, duration, markCount, size, poster, pushedAt, machine }]`, newest recording first; `machine` is the manifest's, or `null` |
| `GET /api/sessions/:id` | → `{ ...row, manifest }` or `404` |
| `DELETE /api/sessions/:id` | → `204`; removes the row and orphaned blobs |
| `GET /s/:id/` | the viewer (`viewer.html` from Worker static assets, no embedded data) |
| `GET /api/sessions/:id/files/<path>` | the same as `GET /s/:id/<path>`, for apps: `/api/*` passes Access to the Worker's bearer check, while `/s/*` stays behind Access (a bearer request there gets Access's login redirect) |
| `GET /s/:id/<path>` | the file from the manifest, with `Content-Type` from the manifest, `Range` support (206), `ETag` = sha256 and `Cache-Control: private, no-cache` (add `?v=<sha256>` for immutable caching). `manifest.json` is served from D1 |
| `GET /v/:id` | `302` → `/s/:id/` |
| `GET /` | library page: sessions, plus signed-in apps with Sign out |
| `GET /api/me`, `GET /api/grants`, `POST /api/grants/:id/revoke` | sign-in (§6) |
| `/mcp` | MCP (section 4) |

`manifestSha256` is the sha256 of the manifest JSON exactly as the Mac sent it. `POST` bodies must be JSON:
`text/plain`, form and multipart bodies get `415`, because those skip the browser's CORS preflight.

## 3. Viewer modes (`scripts/viewer.html`)

1. **Embedded:** the `/*__SESSION_DATA__*/null` token in `const DATA = …` is replaced with the session JSON. If
   `DATA.cloud` is present it holds `{ "manifest": {…}, "drawings": […] }` — this is what `index.html` in a
   bundle uses on `file://`.
2. **Fetched:** when `DATA` is `null`, the viewer shows "Loading session…" and fetches `session.json` and
   `manifest.json` relative to the page (that's how `/s/:id/` works), then renders the same way. Only a `404`
   for `manifest.json` means a local-format session; any other failure (status, network, non-JSON such as an
   expired Access sign-in) shows the error screen with **Retry** and **Sign in again**. `drawings.json` loads
   after the first render; if it fails, a note under the player says the video plays without drawings.

With cloud data present the viewer: plays `recording.mp4` straight through (single segment), overlays each
drawing PNG between `start` and `end` scaled to the video box, shows thumbnail hover on the timeline from
`manifest.thumbs`, says "page not uploaded" for marks whose page is in `skippedPages`, and makes
**Copy as Markdown** use absolute URLs built from the page's location instead of `DATA.folder`. Served from
`/s/:id/`, its eyebrow links to the library. Without cloud data, behaviour is unchanged.

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

- `CloudClient(baseURL, auth)`: `push` → upload each missing blob (PUT, or multipart above 90 MB) → `commit`.
  Every request carries `Authorization: Bearer` from the saved sign-in (§6).
- Uploads share one pool of 8 requests in flight, at most 3 of them multipart parts (64 MB each in memory).
  Each request waits a round trip through the Worker (token, D1, R2), so a long session's hundreds of
  thumbnails sent one at a time can take minutes; parts complete once all of a file's parts are in.
- Each push times its phases (the bundle's build phases, then Checking, Uploading, Committing). The CLI
  prints them on a `took` line and the app logs them with `NSLog` (`log show --predicate 'process == "ContextRecorder"'`).
- Configuration: cloud URL in `UserDefaults` (`cloudURL`). The CLI also reads `CR_CLOUD_URL` and `CR_CLOUD_TOKEN`.
- After a commit, write `<session>/exports/cloud.json`:
  `{ "url", "manifestSha256", "inputHash", "pushedAt" }`. "Out of date" = current `inputHash` ≠ recorded one.
- Every commit sends `If-Match` with the recorded `manifestSha256` (from the last push or a download, §7). A `412`
  means another Mac pushed since: the app asks **Replace the cloud copy?** (naming that Mac and when) and
  **Replace Cloud Copy** commits again without `If-Match`.
- CLI: `--cloud-bundle <session> <out-folder>`, `--push <session> [--cloud <url>] [--force]` (`--force` skips
  `If-Match`), `--cloud-list`, `--pull <id> [--into <library-folder>]`, and
  `CR_CLOUD_URL=… --cloud-snapshot <library-folder> <out-folder>` (§7).
- Headless commands run the app's run loop with activation prohibited, so nothing shows or takes focus and SwiftUI's
  `ImageRenderer` (drawings, snapshots) has a real main thread.

## 6. Sign-in

The Worker is an OAuth 2.1 authorization server (`@cloudflare/workers-oauth-provider`). One mechanism serves
the Mac app and MCP agents.

- **Endpoints:** `/.well-known/oauth-authorization-server`, `/.well-known/oauth-protected-resource`,
  `POST /register` (RFC 7591 dynamic registration, public clients allowed), `GET /authorize`, `POST /token`
  (authorization_code with PKCE S256, refresh_token).
- **`/authorize`** stays behind Cloudflare Access, so the person is whoever Access says (the email in the Access
  JWT). It shows a consent page naming the client and its redirect host; **Allow** completes the grant with
  props `{ "email" }`. Every other OAuth path is bypassed in Access and guarded by the Worker.
- **Tokens:** access tokens last 1 hour. Refresh tokens last 365 days from sign-in and expire after 90 days
  unused. Registered clients don't expire.
- **Who is calling (Identity):** in order — `Authorization: Bearer <access token>` (via
  `OAUTH_PROVIDER.unwrapToken`); the Access JWT header; the `CF_Authorization` cookie (browser requests to
  bypassed paths; non-GET requires a same-origin `Origin`); `DEV_IDENTITY` in dev.
- **`/mcp`** requires a bearer token (the provider answers 401 with `WWW-Authenticate` for discovery).
- **`GET /api/me`** → `{ "id": "<email>", "via": "oauth" | "access" | "dev" }`.
- **Devices:** the library page lists your grants (client name, created) with **Sign out** per grant
  (`POST /api/grants/:id/revoke`, cookie or bearer).

### The Mac app

- Client name `Context Recorder (<host name>)`, redirect URI `contextrecorder://oauth/callback`, public client
  (`token_endpoint_auth_method: none`). It registers once per cloud URL and keeps the `client_id`.
- Sign-in uses `ASWebAuthenticationSession` with PKCE. The refresh token, access token, its expiry, the
  client id and the cloud URL are kept as JSON in `~/Library/Application Support/ContextRecorder/cloud-auth.json`
  (0600, folder 0700). Not the Keychain: an app signed without an Apple team gets a Keychain item tied to one
  build, so every rebuild prompted. Nobody types or sees the tokens.
- Signing in again on the same Mac replaces that Mac's previous grant (`revokeExistingGrants`).
- Each request sends `Authorization: Bearer`. On a 401 or within 60 s of expiry it refreshes once; if
  the refresh fails, it reports "Sign in again" and keeps the address.
- The CLI uses the same saved sign-in. A local dev Worker never gets it. `CR_CLOUD_TOKEN` (an access token) overrides it for scripts.

## 7. Mac pull (sessions from another Mac)

Same account, another Mac: the app lists what's in the cloud and downloads a session on request. It reads
`GET /api/sessions` and `GET /api/sessions/:id/files/<path>` with the saved sign-in (§6). Not `/s/*`: that is behind
Access, which answers an app's bearer request with its login redirect.

- **Listing:** the sidebar's **In the Cloud** section shows each cloud session with no library folder named its
  `id`: poster (`GET /api/sessions/:id/files/<poster>`), title, `machine` and mark count, with Download in a fixed slot that turns into
  a progress ring. It is hidden when there's no cloud, signed out, or nothing to show. It refreshes when the sidebar
  appears, when the app becomes active, after sign-in and when the cloud address changes.
- **Download (`CloudPull`):** read `GET /api/sessions/:id/files/manifest.json` (exactly as pushed, so its sha256 is the cloud's
  `manifestSha256`), then fetch every file in `files` with `Range` requests of 32 MB into
  `<library>/.<id>.partial/` (hidden, so the library scan skips it). A file already there with the right size and
  sha256 is skipped, a short one is continued, and every file is checked against its sha256. Paths with `..`, and
  `exports/…` or `session-info.json`, are refused. When all are in, the folder is renamed to `<library>/<id>`.
  A server that ignores `Range` (200) still works: the file starts over whole.
- **Afterwards:** `session-info.json` gets the manifest's `title` (when it isn't the id) and
  `"downloaded": { "machine", "cloud", "at" }`, and `exports/cloud.json` records the downloaded `manifestSha256`
  with the local `inputHash`, so the session shows as current (badge: *Downloaded from <machine>*). Because the
  copy is laid out as an unedited session (§1), editing it, adding marks and processing it again all work. Pushing
  it replaces the cloud copy only if no other Mac pushed since (`If-Match`, §5).
- **Library folder:** `~/Movies/ContextRecorder`, or the `--library` folder in dev runs.
- **Checking the UI without a window:** `CR_CLOUD_URL=<url> ContextRecorder --cloud-snapshot <library> <out>` draws
  the section's rows with `ImageRenderer` before, during and after a real download of the first cloud-only session,
  through the same path as the button. AppKit-backed controls can't be drawn that way, so the Download button shows
  as its icon.
