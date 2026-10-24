# Large session: network and UX audit

Audit date: October 23, 2026, America/Indiana/Indianapolis.
Session: `2026-10-23_16-08-41`, 12:44.696, 44 marks.
Site: https://context-recorder-cloud.byron-711.workers.dev/
Code reviewed: checkout commit `c6d17cd`. The deployed revision was not verified.

The viewer uses partial MP4 requests. It does not download the full bundle when opened.
The largest avoidable opening cost is the mark images, including images inside collapsed details.
Keep the current MP4 range architecture. Fix image loading and cache use first.

## Measured transfer and timing

All sizes below use decimal MB. Transfers are Chrome HAR `_transferSize`, including response overhead.
Totals include this session's requests only. Browser extensions and favicon requests are excluded.
Canceled or suspended responses can have incomplete accounting. These are browser measurements, not packet captures.

| Stage | Session transfer | Video transfer | Observed result |
| --- | ---: | ---: | --- |
| Cold opening, paused | 10.498 MB | 0.366 MB | DOMContentLoaded 209 ms; load 1.682 s |
| After 18.913 seconds of playback, then pause | 16.245 MB cumulative | 6.079 MB cumulative | Buffered through 33.559 s; 286 frames, zero dropped |
| After test seeks | 17.394 MB cumulative | 7.228 MB cumulative | Separate ranges near requested times |
| Warm reload | 0.640 MB | 0.504 MB | DOMContentLoaded 317 ms; load 1.222 s |

The first run had much longer delays with two debugger connections active.
Those timings are excluded from the table. A new run used DevTools as the measurement interface.
The clean run had browser cache disabled and no network throttle. This was not a cold CDN test.
The warm run restored normal browser caching.

The first contentful paint was about 252 ms in the clean run.
The session JSON arrived about 386 ms after navigation began. The manifest arrived around 321 ms.
The drawings index arrived around 389 ms. The populated viewer must wait for all three JSON responses.
The load event is not a precise measurement of viewer readiness because the module has a top-level await.

The native `playing` event followed `play` by 1.6 ms after metadata was available.
This is event latency, not a precise first-presented-frame measurement.
The first playback buffer sample appeared about 579 ms after play.

## What happens after the click

1. Chrome navigates to `/s/<id>/`. Existing Cloudflare Access authentication permits the request.
2. `serveViewer()` checks the session in D1 and serves the shared HTML asset.
3. The HTML already contains a video with `src="recording.mp4"` and `preload="metadata"`.
4. The module requests `session.json`, `manifest.json`, and `drawings.json` in parallel.
5. The module waits for all JSON responses, then renders the header, timeline, and mark list.
6. `setupCloud()` assigns the poster, configures drawings, and installs timeline hover previews.
7. The browser loads mark images. Full screenshots and frames load even while their details are hidden.

The clean trace contained 81 session requests: one HTML, two video, three JSON, and 75 image requests.
The 75 images included 44 frames, 29 screenshots, the poster, and one hover thumbnail.
The hover thumbnail was incidental pointer activity and is not required by initial rendering.
Frame and screenshot assets alone total 9.939 MB before HTTP overhead.

The JSON requests transferred 79.5 KB combined. `session.json` expands to 941.8 KB; the manifest expands to 102.3 KB.
Both used zstd compression. The drawings index was four bytes and contained no drawings.
The session had 180 transcript lines, 31 activity records, and 205 browser events.

The metadata payload is small on the wire. It is not the main bandwidth problem here.
It is still fully parsed and held in memory. Much of the session data belongs to mark context.
No long tasks were recorded by the installed observer, but installation followed initial rendering.
That result does not prove startup has no long tasks.

## How the video loads

The video is **134,615,724 bytes**, 1920 × 1080.
Its average file bitrate is about **1.41 Mbit/s**, including audio and container overhead.
The recorder config requests H.264 at 4 Mbit/s with keyframes at most two seconds apart.
The actual file average is lower; the configured target is not measured output bitrate.

Initial requests:

```text
Range: bytes=0-
206 Content-Range: bytes 0-134615723/134615724

Range: bytes=134250496-
206 Content-Range: bytes 134250496-134615723/134615724
Content-Length: 365228
```

Chrome stopped the first response early and fetched about 365 KB from the tail.
This pattern strongly suggests MP4 metadata at the end of the file. The MP4 atoms were not parsed directly.
The unedited upload path copies the source MP4. Only edited exports explicitly enable network optimization.

On playback, Chrome requested `bytes=196608-` and received about 5.712 MB during the captured stage.
Its response advertised 134.419 MB. Chrome did not consume that entire advertised range.
It buffered ahead, suspended, and resumed as playback advanced.

`206` does not imply a fixed small chunk. These requests are open-ended ranges.
Chrome controls how much it reads and when it cancels, suspends, or makes another request.
This is progressive MP4 delivery, not HLS or DASH segment streaming.

The server passes the requested byte range to `BUCKET.get()` and returns the response stream.
It does not read the whole video into an ArrayBuffer before responding.
No service worker, JavaScript blob download, or client-side full-video fetch appears in the viewer.

## Seeking and pausing

Native scrubber tests first touched the middle and end of the recording.
A separate controlled test set the video's time to 600 seconds through the Console.
This separates media behavior from pointer placement.

| Seek | Time from `seeking` to `seeked` | Additional reported transfer |
| --- | ---: | ---: |
| 10:00, outside the playback buffer | 188 ms | 0.630 MB across four video requests |
| Back to 0:10 | 593 ms | 0.251 MB across four video requests |

The ten-minute seek requested bytes around offsets 108.17–108.76 MB.
It did not transfer the missing nine minutes sequentially.
The picture became available before all related range activity stopped.

Returning to 0:10 still made requests despite a reported buffered span of 0–33.559 seconds.
Do not promise that buffered footage always seeks without network activity.
Browser cache state, track availability, decoding, and media internals can affect this behavior.
The test had cache disabled, so the return-seek cost is not representative of every normal visit.

The paused player did not keep downloading the remaining 128 MB during the observed idle period.
Its playback buffer remained at 33.559 seconds before further seeks.
After the ten-minute seek, it fetched a small amount of nearby media while still paused, then suspended.
Pausing is not an immediate zero-network guarantee. It did stop well short of downloading the full file.

`seekable` covered the entire duration while `buffered` covered small, separate spans.
The full seekable duration means the server supports random access. It does not mean the video is downloaded.

## What the 165.5 MB contains

| Asset group | Files | Stored MB | Needed when |
| --- | ---: | ---: | --- |
| Video | 1 | 134.616 | Metadata at opening; ranges during playback and seeking |
| Timeline JPEGs | 383 | 10.391 | Poster and individual hover positions |
| Saved MHTML pages | 44 | 8.277 | Explicit saved-page navigation |
| Mark frames | 44 | 7.959 | Selected mark detail; currently requested at opening |
| Screenshot PNGs | 29 | 1.980 | Selected screenshot detail; currently requested at opening |
| Session JSON | 1 | 0.942 | Current viewer startup |
| Other data and Markdown | 50 | 1.377 | Export, processing, or explicit file access |
| **Total** | **552** | **165.542** | Not one initial download |

The total is the sum of manifest-listed files. The separately stored manifest is not part of that sum.
MHTML pages and the full set of 383 timeline thumbnails were not downloaded at opening.
Most source/export files were not requested by the viewer.

## Code findings and recommended order

**P2 — Load mark detail images only when needed. Highest expected gain; small change.**

`scripts/viewer.html:renderList()` creates thumbnail and detail image elements for every mark.
The list thumbnail has `loading="lazy"`, but detail images have ordinary `src` attributes.
`display:none` on `.detail` does not prevent these image requests.
The capture recorded 75 hidden image elements as complete.

Assign detail image sources on first selection. Use the existing 480-pixel timeline JPEGs for list previews.
They already exist, so a new image service or thumbnail pipeline is unnecessary.
Retain original screenshots and full frames for the selected mark and zoom view.
Deduplicate preview requests where several marks use the same timeline thumbnail.

Acceptance: initial requests contain no original frames or screenshots before selection.
The selected detail still opens at full quality. Opening the list should need roughly tens or hundreds of KB of images.
That estimate is a target, not a measured optimized build.
At 10 Mbit/s, today's 9.939 MB image payload alone has a theoretical transfer floor near eight seconds.

**P2 — Use the immutable caching support already present. Small change.**

`cloud/src/files.ts` supports `?v=<sha256>` with private, one-year immutable caching.
The manifest already includes the hashes. Viewer image and video URLs do not use them.
Normal paths use `private, no-cache`, so repeat requests must revalidate.

The warm trace contained 81 session requests and 76 responses with status 304.
Images transferred only 37.4 KB, but each request still reached the serving path.
Use versioned URLs for stable image assets and media from the current manifest.
Keep the manifest revalidated so a pushed session can expose new hashes.
The explicit JSON fetch cache option also forces revalidation; review it when pinning JSON URLs.

Acceptance: a second visit reuses unchanged images without a network revalidation per image.
Repushing changed bytes produces changed URLs. Verify video seeks under normal cache settings.

**P2 — Reduce MP4 metadata and seek request overhead. Medium change, after images.**

The initial tail request costs another round trip and about 365 KB.
Edited exports set `shouldOptimizeForNetworkUse = true`; unedited recordings are copied unchanged.
Verify atom placement, then remux unchanged recordings for fast start during cloud bundle creation.
Avoid a lossy re-encode just to move container metadata.
Preserve text readability and measure the new metadata, first-frame, and seek traces.

Acceptance: metadata can load from the beginning without a tail probe.
Do not require fewer total bytes without measuring; moving metadata changes location, not necessarily size.

**P2 — Show useful loading and recovery states. Small change.**

The shell initially shows a generic title, empty timeline, and empty list until JSON finishes.
`Promise.all()` makes optional manifest and drawing work part of the startup gate.
There is no explicit app-level loading status or seek status.
Native video controls supply some buffering feedback, but the surrounding viewer does not explain its state.

Reserve the player dimensions and show a short loading state until session data is ready.
Make optional drawing failure visible without losing the rest of the viewer.
Do not silently treat every manifest error as a local-format session.
Add a retry or sign-in recovery link to the existing fatal-load screen.
Do not add a global progress percentage without a meaningful total.

**P2 — Make marks and timeline actions accessible. Small to medium change.**

Native video controls worked with keyboard input. The global `j` shortcut selected and expanded a mark.
Transcript navigation also worked. These are useful existing paths.
Mark cards, transcript rows, pins, and custom timeline targets are click handlers on divs.
They lack native keyboard activation and useful exposed action semantics.
The tablist contains buttons without tab roles, selection state, or tab-panel relationships.

Use native buttons for discrete seek and select actions. Add proper tab state and selected-mark state.
Keep visible focus. Check the global Space handler on focused buttons; it currently overrides their normal action.
Acceptance: users can reach and open a specific mark using Tab and Enter, without knowing `j` and `k`.

**P2 — Improve narrow-screen prioritization. Medium change.**

At 375 × 671, the wrapped header uses substantial vertical space.
The player and four timeline lanes come next, then two context panels, then the mark list.
Finding a mark requires scrolling past this material. Dense pins and events become difficult pointer targets.
The seven ruler labels also compete for a narrow width.

Place the mark/transcript controls nearer the player on narrow screens. Reduce header statistics and ruler ticks.
Keep the native scrubber as the precise time control. Treat the timeline lanes as an overview at this size.
The desktop view has good simultaneous video and mark access; preserve that arrangement.

**P3 — Preserve location and reduce list truncation. Small change.**

Selected mark and video position are held in JavaScript only. Reload resets the viewer to time zero.
Mark titles and context are single-line ellipses. Selecting a mark reveals more content, but list scanning loses detail.
Store the selected mark or time in the URL. Give the list enough wrapped text to identify the target.
The All sessions link is clear and should stay.

## Changes that are not justified yet

No HLS/DASH pipeline, video proxy, adaptive bitrate system, pagination service, or CDN cache redesign is needed first.
The existing range path supports the primary task and performed well on this connection.
Keep JSON together at this scale unless slower-device traces show parsing or rendering costs.
If mark context grows substantially, load selected-mark detail separately while keeping the index small.
Avoid splitting 79.5 KB of compressed startup JSON into many requests without evidence.

## UX scorecard

These are heuristic scores supported by the sampled session, not user-study results.

| Category | Score / 5 | Coverage | Reason |
| --- | ---: | --- | --- |
| Orientation and navigation | 4 | Medium | Clear session counts, tabs, and return link; position is lost on reload |
| Desktop review workflow | 4 | Medium | Video, marks, and context are available together |
| Loading and data efficiency | 2 | High for this session | Hidden original images dominate opening transfer |
| Playback and seeking | 4 | Medium | Partial loading, quick far seek, no dropped frames in the short sample |
| Accessibility | 2 | Medium | Native player and shortcuts work; custom seek/select controls lack semantics |
| Narrow-screen workflow | 2 | Medium | Player fits, but marks sit far below the initial viewport |
| Failure recovery | Untested live | Low, code only | Fatal JSON error exists; optional errors can disappear silently |

## Evidence and limits

Evidence files (kept local, not committed):

- `cold-summary.json`, `play-summary.json`, `seek-summary.json`, `warm-summary.json`: sanitized request and header summaries.
- `bundle-inventory.json`: sizes and counts from the live manifest.
- `media.json`: resource timings, media events, snapshots, and image state.
- `desktop-mark.png`, `narrow.png`: rendered layout evidence.

Raw HAR files remain under `/private/tmp/session-{cold,play,seek,warm}.har`.
They contain session response bodies. They were not committed or uploaded.
The reusable scripts are `scripts/audit-session.js` and `scripts/summarize-session-har.py`.
Capture instructions are in `scripts/audit-session.md`.

Coverage: one large session out of three listed sessions; opening, playback, pause, far seek, return seek,
warm reload, mark shortcut, transcript tab, desktop, and one narrow viewport.
No full-length watch, throttled-network run, offline failure, auth expiry, mobile hardware, or server CPU profile was tested.
No claim is made about exact TCP/QUIC wire bytes or R2 billing bytes.
Initial-load media events predate observer installation; opening results use HAR and retained performance entries.

The browser's normal cache setting and desktop viewport were restored. DevTools was closed.
Only local audit tools and evidence were added. The deployed app was not changed.

Browser behavior references:
[HTML media loading standard](https://html.spec.whatwg.org/multipage/media.html),
[Chrome video performance guidance](https://web.dev/learn/performance/video-performance),
[HTTP range requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Range_requests).
These explain why preload is a hint and an advertised range does not imply full consumption.
