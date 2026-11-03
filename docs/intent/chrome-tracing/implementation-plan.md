---
title: "Chrome tracing — implementation plan"
slug: "chrome-tracing"
phase: plan
status: planned
last_updated: "2026-10-28"
---

# Chrome tracing — implementation plan

Research: [summary and dispositions](../../research/chrome-tracing/summary.md). Pro's full plan, with schemas and about 60 fixture values, is kept as reference in [sources/pro-output/chrome-tracing-implementation-plan.md](sources/pro-output/chrome-tracing-implementation-plan.md). Scenario specs and worked examples are in [sources/pro-output/chrome-tracing-scenarios.md](sources/pro-output/chrome-tracing-scenarios.md).

## Plan at a glance

The goal is to capture as much Chrome tracing data as a recording can hold, on the same clock as the video, and then explain marks with it.

The app talks to the everyday Chrome directly over CDP. You turn on remote debugging once at `chrome://inspect/#remote-debugging`, and Chrome asks to allow each connection. Raw data goes straight from Swift to `performance/` in the session folder, not through the extension bridge. The extension keeps doing page context.

The biggest risk is the connection itself: endpoint discovery, the consent prompt, and what a signed app may read. M0 proves that in a day. Every later milestone leaves a working app.

| Milestone | Ships |
| --- | --- |
| M0. Connection spike | App connects to the running Chrome, records Network events and one trace to disk |
| M1. Network log and metrics on every recording | `network.jsonl`, `metrics.jsonl`, `clock.jsonl`; Network lane; HAR export |
| M2. Deep traces | Arm, mark-window and stop; `trace/NNNN.json.gz`; Open in Perfetto/DevTools |
| M3. Mark findings and agent handoff | Scenarios 1–4: interaction breakdown, waterfall, main-thread work, Markdown block |
| M4. Observers, duplicates, layout shifts | In-page fallback without CDP; scenarios 5–6 |
| M5. Cuts, joins and cloud | Interval projection; compact cloud summary |
| M6. Broad diagnostics, memory, compare | Browser-wide trace, memory trend, before/after |

## Shared rules

- **Clock.** Video zero is `Recorder.startPTS`. Every new record keeps the time it happened in its own clock (Chrome monotonic seconds, trace µs, page ms) plus the mapping in `clock.jsonl`. Arrival time is stored separately when useful.
- **Raw stays raw.** Original files are never rewritten. Edited time is a projection made in processing.
- **Unknown is not zero.** A missing metric is `null` with a reason, and coverage gaps are written to `coverage.jsonl`.
- **Findings have four parts:** observed, association, hypothesis, next check. Overlap is never written as cause.
- **Sensitive values.** Before writing anything, drop the values of `Cookie`, `Set-Cookie`, `Authorization`, `Proxy-Authorization` and headers whose names contain `token`, `key` or `secret`. Keep the header name. Bodies are off by default. Raw traces stay local.

## M0 — Connection spike

**Goal:** prove that the signed app can attach to the everyday Chrome and get trusted CDP.

- Add a `--cdp-spike` command-line mode (like the existing self-test modes). It reads `~/Library/Application Support/Google/Chrome/DevToolsActivePort`. Line 1 is the port and line 2 is the browser WebSocket path. It connects with `URLSessionWebSocketTask`.
- Call `Browser.getVersion` and `Target.getTargets`, attach to the active tab (`Target.attachToTarget`, `flatten: true`), and call `Network.enable`. Print 10 s of request events.
- Start `Tracing.start` with `transferMode: "ReturnAsStream"` and preset D (see Pro's plan §M3). Stop after 5 s, drain with `IO.read`, and write `spike.trace.json.gz`.
- Try `Profiler.enable` to confirm trusted access.

**Done when:** the consent prompt appeared and was approved, events printed, and the trace opens in [Perfetto UI](https://ui.perfetto.dev) and the DevTools Performance panel. Record the Chrome version, prompt behavior on reconnect, and whether the sandboxed app could read the file.

**If it fails:** write down the exact failure. The fallback order is: (1) a dedicated debugging profile launched with `--remote-debugging-port` and `--user-data-dir`; (2) `chrome.debugger` in the extension, with its limits named. Do not ship either as "full capture".

**Main risk:** the app's file access to Chrome's profile folder, and the prompt repeating on every connection.

## M1 — Network log and metrics on every recording

**Ships:** when Chrome is connected, every recording has the full request log for the recorded tab, not only failed or slow fetches.

Files and modules:
- `Sources/ContextRecorder/Chrome/ChromeCDP.swift`: WebSocket, command IDs, event dispatch.
- `Sources/ContextRecorder/Chrome/ChromeCapture.swift`: attaches at record start to the active tab and auto-attaches to its frames and workers (`Target.setAutoAttach`, `waitForDebuggerOnStart: false`). It also attaches to a tab you switch to during the recording. Enables `Network`, `Page`, `Runtime`, `Log` and `Performance` (`timeDomain: "timeTicks"`). Polls `Performance.getMetrics` at 1 Hz.
- `RecorderController.swift`: starts and stops the capture with the recording. A short "Chrome" status sits on the record card: connected, waiting for approval, or off.
- `Session.swift` or a small `PerformanceStore.swift`: append-only writers for `performance/*.jsonl`.
- `scripts/process_performance.py`, called from `process_session.py`: builds `performance/index.json` (per-mark request lists, lane buckets) and `exports/network.har` on demand.
- `Library/SessionData.swift`, `SessionTimeline.swift`: a Network lane (in-flight count) and a request list in mark detail.

Session files: `performance/manifest.json`, `clock.jsonl`, `targets.jsonl`, `network.jsonl` (one line per request hop, key `session:requestId:hop`), `metrics.jsonl`, `coverage.jsonl`, `index.json`.

Clock: at attach and every 30 s, send `Performance.getMetrics` and record host send time, host receive time, and Chrome's `Timestamp`. Use the lowest round-trip sample for `host = chrome + b`. Store all samples.

Checks (few, on likely failures):
- Clock fixture: host video zero 1000.000 s, `b = 900`. Chrome 105.250 s maps to video 5.250 s, whatever time the event arrived.
- Redirect and identity: one `requestId` across a 302 and a 200 gives two hop records. The same `requestId` in two sessions gives two requests.
- Redaction: synthetic `Authorization: s3cr3t` and `Cookie` values never appear in `network.jsonl`.

README: add **Performance capture → Connect Chrome** (enable remote debugging, the prompt, the banner) and the new session files.

Main risk: request records arrive out of order (`ExtraInfo` events). Close each record on `loadingFinished` or `loadingFailed`, or mark it `unfinished` at stop.

## M2 — Deep traces

**Ships:** a real Chrome performance trace around the moment you mark, lined up with the video, that opens in Perfetto or DevTools.

- **Arm trace** (button on the record bar and the menu bar menu; hotkey to be chosen) starts `Tracing.start` with preset D, `recordContinuously` and a 64 MiB buffer. The arm lasts at most 60 s.
- A mark while armed asks to stop 10 s later, capped at the 60 s arm limit. The retained history is whatever the ring held. Write the real covered interval to the manifest; never promise the 10 s.
- Stop: `Tracing.end` → wait for `tracingComplete` → `IO.read` until `eof` → `IO.close`. Write `trace/0001.json.gz.partial`, then rename. If the recording stops first, finish the drain into the same session folder.
- Write a clock marker: at trace start, call `performance.mark("context-recorder:clock")` through `Runtime.evaluate` and record its host time, so the trace maps to video time.
- Mark detail gets **Open in Perfetto** and **Reveal Trace in Finder** (for DevTools). The Perfetto handoff can start as "open ui.perfetto.dev and drop the file". Add the postMessage handoff only if dropping the file gets tedious.
- **Decide here (CT-17):** parse traces with Perfetto `trace_processor` (SQL; also reads `.pftrace`) or a streaming Python reader. Try `trace_processor` on the M0 and M2 traces. Pick it if it answers scenarios 1–3 in a few queries.

Checks: a stream-drain fixture (chunks `abc`, `de`, `f` with eof gives `abcdef`, one `IO.close`); a covered-interval fixture (mark at 40 s, ring starts at 34 s gives 6 s of history, reported as such).

README: **Performance capture → Deep traces**, what arming does, and the browser-wide note: a tab trace can still contain other processes' work.

Main risk: tracing overhead and how much history 64 MiB holds. Measure both on your real app and write the numbers into this plan.

## M3 — Mark findings and agent handoff

**Ships:** select a mark and see what was slow, then copy a short Markdown block that an agent can act on.

Build Pro's scenarios 1–4 (specs and worked numbers in the scenarios file):
1. **Interaction breakdown:** input delay, handler time, and time to the next paint, kept apart from "result ready".
2. **Waterfall:** requests in the mark window, with cache, priority, phases and unfinished requests. Report the active union separately from the summed durations.
3. **Main-thread work:** long tasks with exclusive time by category and script URL. Use source-map locations only when they resolve.
4. **Agent block:** up to three findings, evidence IDs, coverage, and the next check. It goes into `marks/*.md`, `session.md`, Copy as Markdown and the cloud MCP mark text.

Files: `scripts/process_performance.py` (findings to `findings.jsonl` and `marks/<id>.json`); `Library/PerformanceLane.swift` and a performance section in `MarkDetail.swift`; `process_session.py:mark_markdown`; `scripts/viewer.html`; `cloud/src/markdown.ts`.

Checks: Pro's scenario 1 fixture (80 + 80 + 80 = 240 ms, ready at 800 ms) and scenario 3 fixture (a 120 ms task gives 70 ms over the 50 ms threshold; parent and child are not summed to 230 ms).

Main risk: overlap reads as cause. Keep the four-part wording in every surface.

## M4 — Observers, duplicates and layout shifts

- Add a small `extension/performance.js` that runs `PerformanceObserver` for `long-animation-frame`, `event` (`durationThreshold: 16`), `layout-shift`, `resource`, `paint`, `largest-contentful-paint`, `mark` and `measure`. It sends batches with the page's `timeOrigin`. These cover recordings without CDP and add script attribution from long animation frames (LoAF).
- Fix `page.js:describe` so it never reads `target.value` for inputs. Then the README sentence is true.
- Scenario 5, duplicates: overlapping same-key GETs flagged as candidates. Exclude ranges, `304` revalidations and POSTs with different bodies.
- Scenario 6, layout shifts: bursts by session window, the affected elements, and layout work in the same window.

## M5 — Cuts, joins and cloud

- Project intervals at cuts: each kept piece has its own projection, and every piece keeps the original duration. New performance intervals use half-open membership. Existing marks keep today's inclusive mapping.
- Namespace everything by source session in joins.
- Cloud Push: a compact `performance/index.json` plus mark details (keep under about 2 MiB). Raw traces stay local. Add performance hashes to `CloudBundle.inputHash`.
- Fix the stale "known gap" line in `cloud/README.md:106`.

Check: event `[9, 21)` with kept segments `[0, 10)` and `[20, 30)` gives two pieces, `[9, 10)` and `[10, 11)`, with original duration 12 s.

## M6 — Broad diagnostics, memory, compare

- **Diagnostic trace:** browser-wide, preset B, 30 s, `.pftrace`. Use it for GPU, network service and browser-process problems.
- **Memory trend:** from the 1 Hz metrics, compare settled minima across repeats. Report a "growth candidate", never a leak. Heap snapshots stay in DevTools.
- **Compare:** two sessions of the same flow, matched by step. Show absolute and percent changes with the capture settings side by side.

## Open decisions

- **Prompt per connection:** keep one CDP connection open while the app runs, or connect per recording? M0 measures how often Chrome prompts.
- **Tabs:** the active tab at record start plus tabs you switch to (default), or every tab?
- **Analysis engine:** `trace_processor` or Python, decided in M2.
- **Arm hotkey:** pick one with M2. ⌃⌥R, ⌃⌥M and ⌃⌥S are taken.

## Below the cut line

`chrome.debugger` backend, `webRequest`, a custom DevTools panel, startup traces, response bodies by default, heap snapshots in the app, an embedded Perfetto view, and Pro's cross-recording trace lease. Revisit any of these only for a concrete failure.
