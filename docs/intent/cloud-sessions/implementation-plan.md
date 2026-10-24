---
title: "Cloud sessions — implementation plan"
slug: "cloud-sessions"
phase: plan
status: built
last_updated: "2026-10-22"
---

# Cloud sessions — implementation plan

## Where it landed (2026-10-22)

| Milestone | Status |
| --- | --- |
| 1. The cloud copy plays from disk | Built. `--self-test cloud-bundle` checks every exported frame against `EditMap` within one frame |
| 2. Push to a local cloud and browse it | Built |
| 3. Agents read sessions locally over MCP | Built |
| 4. Live on your domain | Live on `workers.dev`, not a custom domain: Byron kept `byroni.us` at Namecheap. The Media Transformations spike waits for a zone, so frames come from thumbnails |
| 5. Agents from anywhere | Built differently: the Worker is its own OAuth server, with Access guarding `/authorize`. That one sign-in also replaced the Mac's Access service token |
| 6. Sharing and lifecycle | Not started |

What changed from the plan:
- **Sign-in:** OAuth sign-in (browser, refresh tokens) replaced the service token. Pasting a token ID and secret into Cloud Settings was too much friction.
- **Where the sign-in is kept:** a 0600 file, not the Keychain. With a self-signed app, Keychain items are tied to one build, so every rebuild prompted.

The durable reference is [docs/cloud-sessions.md](../../cloud-sessions.md), and operations are in
[cloud/README.md](../../../cloud/README.md). The plan below is kept as written.

## Plan at a glance

The biggest risk isn't Cloudflare. It's whether a session survives the move out of the app: cuts, joins, drawings and mark times all have to still line up. So the first milestone proves the **cloud copy** on disk, with no network. The app writes a self-contained folder: one flattened video, drawing overlays, `session.json` and thumbnails, and the shared viewer plays it from `file://`. If timings match the app there, nothing downstream has to understand edits at all.

After that, Cloudflare comes in one dependency at a time. Storage and the viewer run on `wrangler dev` (local R2 and D1, a dev identity in place of Access). Next is MCP against that same local Worker, using a thumbnail-based frame fake. Then the real account, domain and Access, with a small spike on Media Transformations. Live OAuth for agents follows, and sharing and lifecycle details come last. Every milestone leaves a working system. Until M4, all of it runs on your Mac.

The pushback that changes the build: flatten on the Mac and keep the cloud simple, and build MCP before a ZIP. The shape brief explains both.

## Implementation strategy

- **First proof:** `--cloud-bundle` turns a real edited, annotated session into a folder that the shared viewer plays with matching times.
- **Primary seams:** the *cloud copy format* (`manifest.json` plus files) between the Mac and the cloud. Inside the Worker: `Store` (R2), `Identity` (Access JWT, or dev), and `Frames` (Media Transformations, or nearest thumbnail).
- **Fast local loop:** `swift run ContextRecorder --library tmp/ --self-test cloud-bundle` for the Mac side. `pnpm --dir cloud test` (vitest with `@cloudflare/vitest-pool-workers`) and `pnpm --dir cloud dev` for the Worker.
- **Local dependencies:** Miniflare's R2, D1 and KV. A synthetic edited session built from `CanvasTool` fixtures, plus your real sessions copied into `tmp/`.
- **Live confirmation:** one push of a real session to your domain. One frame fetched through Media Transformations. One frame fetched by Claude Code over remote MCP, and one by a cloud agent.
- **Rollout and rollback:** everything is additive. The push writes only `exports/cloud.json` in the session folder. The cloud can be wiped and pushed again from the Macs, and the button is hidden until a cloud is configured.

### Material dependency proof strategy

```text
cloud copy on disk (no network)                       M1
  → Worker on wrangler dev: Miniflare R2/D1, dev identity  M2–M3
  → live: zone, R2, D1, Access, service token, MT spike    M4
  → live OAuth MCP from two agent homes                    M5
```

Access, Media Transformations and OAuth aren't present locally. Each sits behind one seam with a fake (dev identity, nearest thumbnail, OAuth turned off in dev). Each is confirmed live once, never relied on from mocks alone.

## Milestone 1: The cloud copy plays from disk

This milestone proves the format and the parity question without Cloudflare. It deliberately leaves out uploading.

- **Change — `CloudBundle` in `Sources/ContextRecorder/Cloud/`**
  - The video: an unedited session copies `recording.mp4` as is. Edited and joined sessions export `EditMap.composition` with `AVAssetExportSession` (H.264 and AAC, the input Media Transformations expects).
  - The drawings: each drawing in `annotations.json` becomes a transparent PNG through `Annotation.Renderer`. `drawings.json` gives each one's start and end in edited time, mapped with `EditMap.toEdited`.
  - It copies `session.json`, `marks/`, `session.md`, the images (annotated copies where they exist), `transcript.json` and the `.jsonl` logs. Saved pages go in, smallest first, within a budget of max(10 MB, half the video); skipped pages are listed in the manifest.
  - Thumbnails: a 480 px JPEG every 2 s, written to `thumbs/`, for timeline hover and the frames fallback.
  - `manifest.json`: the format version, session id, title, duration, and every file's path, size and SHA-256. It also holds an `inputHash` of the local inputs, used for the "out of date" check.
- **Change — Shared viewer**
  - `scripts/viewer.html` keeps embedded data for the local `viewer.html`, and can also fetch `session.json` beside it. It gains a drawings overlay (PNG per entry, scaled to the video box) and thumbnail hover on the timeline.
- **Change — Checks**
  - `--self-test cloud-bundle` builds a synthetic session with cuts, a join and drawings, then asserts the exported duration, mark times and drawing windows against `EditMap`. The cases are added to `scripts/fixtures/`.

### Desired end state

- `swift run ContextRecorder --cloud-bundle <session> tmp/bundle` writes a folder that plays correctly when opened in a browser.
- For one of your real sessions, edited and annotated, cut points, mark times and drawing windows match the app to within one frame (the first-proof decision rule).

## Milestone 2: Push to a local cloud and browse it

- **Change — Worker in `cloud/`** (TypeScript, Wrangler, Static Assets for the viewer)
  - D1 `sessions` table (id, title, recorded_at, duration, marks, size, manifest, pushed_at). R2 keys `sessions/<id>/<path>`.
  - API: `POST /api/sessions/:id/push` (manifest in, list of files R2 is missing out), `PUT …/files/*` (≤ 90 MB in one request, R2 multipart above that), `POST …/commit` (swaps in the new manifest and removes orphaned files), `GET /api/sessions`, `DELETE /api/sessions/:id`.
  - `GET /s/:id/*` streams from R2 with `Range` support, so the mp4 can seek.
  - `Identity`: in production, verify the `Cf-Access-Jwt-Assertion`. In dev, read `DEV_IDENTITY`. Every route goes through it.
  - Library page: the session list, plus the viewer at `/v/:id`.
- **Change — Push in the app**
  - `CloudClient` sends only the files whose hashes changed, then commits. It records `exports/cloud.json` (url, manifest hash, `inputHash`, pushed_at).
  - The sidebar context menu and toolbar get **Push to Cloud** / **Push Again**, with progress and a "cloud copy out of date" badge when `inputHash` differs.
  - CLI: `--push <session> --cloud http://localhost:8787`, following the `--export-run` pattern.
- **Verification:** vitest covers the push/commit/re-push flow (an unchanged file isn't sent again; a re-push leaves no orphans), Range responses, and delete. A real session goes from the app to `wrangler dev` and plays in the browser pane.

### Desired end state

- Push a session from the app, open `localhost:8787`, and watch it with cuts, drawings and seeking. Push again after a cut, and only the changed files upload.

## Milestone 3: Agents read sessions locally over MCP

- **Change — MCP at `/mcp`** (`createMcpHandler`, stateless)
  - `list_sessions`, `get_session`, `get_mark` (Markdown plus image content), `get_frame`, `get_frames`, `get_file_url` (a signed link that expires after a set time, checked by HMAC in the Worker).
  - `Frames` port: the `thumbs` adapter returns the nearest thumbnail. The `media` adapter (M4) builds `/cdn-cgi/media/mode=frame,time=…` URLs.
- **Verification:** contract tests for each tool against a seeded Miniflare bucket. MCP Inspector, then `claude mcp add --transport http` against `localhost:8787/mcp`, turns one mark into a written summary that includes a frame between marks.

### Desired end state

- Claude Code on this Mac, connected only to the local Worker, can fetch a session's marks and a frame at any time.

## Milestone 4: Live on your domain

- **Change — Account and wiring:** a Cloudflare account, your domain's DNS moved over, a Workers Paid plan, the R2 bucket, D1 and KV, and a deploy with `wrangler deploy`.
- **Change — Access:** a self-hosted app on `sessions.<domain>` allowing your email. A Bypass policy on `/share/*`. A service token for the Mac, stored in the Keychain and sent as `CF-Access-Client-Id/Secret`.
- **Spike — Media Transformations as the frames source**
  - Decision required: use `media` or keep `thumbs` for `get_frame`.
  - Evidence to gather: transformations enabled on the zone; a frame fetched from an mp4 served at a signed `/src/...` path that bypasses Access; latency; cached reruns.
  - Fallback: keep `thumbs`, optionally denser (every 1 s), and return full-resolution mark frames when a time lands near a mark.
- **Verification:** push a real session from the app, then open it on your phone after signing in through Access.

### Desired end state

- Your sessions play at your own address, and nothing is reachable without signing in.

## Milestone 5: Agents from anywhere

- **Change:** `workers-oauth-provider` wraps `/mcp`, with Access for SaaS (OIDC) as the upstream identity provider and tokens kept in KV, following Cloudflare's `remote-mcp-cf-access` template.
- **Verification:** Claude Code on a second machine and a Claude.ai custom connector (or a cloud Claude Code session) each sign in and fetch `get_frame` for the same moment.

### Desired end state

- An agent on a second machine and a cloud agent can each work from a session while the recording Mac is asleep.

## Milestone 6: Sharing and lifecycle

- **Change:** a D1 `shares` table; share and revoke controls in the cloud viewer and the app's session menu; `/share/:token` renders the viewer read-only; a revoked link shows "no longer shared."
- **Change:** trashing a pushed session asks whether to keep or delete the cloud copy. Deleting in the cloud clears `exports/cloud.json` the next time the app checks.
- **Verification:** vitest for share, revoke and expiry; a live check from a signed-out browser.

### Desired end state

- You can send a link and revoke it, and local and cloud deletions behave as you chose.

## Open decisions and spikes

- **Frames source** (the M4 spike). The fallback is the thumbnails already being pushed.
- **Saved-page budget:** half the video, 10 MB minimum. The number is easy to change after a few real pushes.

## Below the cut line

- Canvas view in the cloud; ZIP download for agents; search across sessions and "what happened" Q&A.
- Automatic push; editing anything in the cloud. (A second Mac pulling sessions into its library has since shipped: docs/cloud-sessions.md §7.)
- Cloudflare Stream or HLS encoding; multiple users; a public library.
