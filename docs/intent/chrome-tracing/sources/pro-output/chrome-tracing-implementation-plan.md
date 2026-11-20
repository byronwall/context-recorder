# Chrome tracing implementation plan

**Design baseline:** `byronwall/context-recorder` at `1d9f29d4b38c8c964b948b9ba244289947476b9e`. **Research date:** October 28, 2026, America/Indianapolis. This is a proposed implementation plan for Claude to review and integrate. No app code, extension installation, commits, pull requests, live recordings or Context Recorder cloud-bundle uploads were made during this mission.

## Chosen architecture

Build one native Swift CDP capture owner connected, with Chrome's consent, to the everyday browser profile through the current Chrome 144+ remote-debugging approval flow. Keep the MV3 extension for semantic page context, existing page events and lightweight PerformanceObserver evidence. The native connection owns target attachment, complete network recording, counters, bounded traces and optional diagnostic profiles. The recorder's first complete video frame establishes media zero. Both paths preserve event timestamps and calibrated clock metadata instead of stamping events when they arrive. Native summaries stay synchronized with the existing video/marks/narration timeline; raw traces open in DevTools or Perfetto for expert inspection.

Treat native approval-mode endpoint discovery as a bounded prototype inside M2 before shipping that capture mode. The current proposed integration reads the two-line `DevToolsActivePort` descriptor and connects to its browser WebSocket; it must not assume `/json/version` discovery works in approval mode. Ordinary command-line port debugging remains an optional separate-profile diagnostic route; it is not the everyday-profile default. Do not add an MCP/Node runtime merely to obtain a WebSocket endpoint.

`chrome.debugger` is deferred as a capture backend. Its restricted domains/tracing scope and debugger ownership behavior do not earn a second production pipeline when the native consent route can expose full CDP. This does not remove the extension or its current behavior.

### Nonnegotiable data contracts

- Every capture has a stable `captureId`, source session identity, Chrome version/protocol metadata, target scope, tier, clock domains, requested versus available capabilities, start/stop reason, actual covered intervals and explicit loss/incompleteness flags.
- Raw captured evidence remains in original source time. Edited/joined playback receives projections, not destructive timestamp rewrites. Raw profiles and browser-wide traces stay local by default.
- Native clock origin is `Recorder.startPTS`, the first complete screen sample. `Session.startedAt`, the folder timestamp and event delivery time cannot substitute for it.
- Chrome timestamps, page `performance` timestamps, wall times and Swift host times are separate domains. Record units explicitly, retain calibration samples and report uncertainty.
- Full raw data never goes into `session.json`. It carries only optional compact references, availability and mark summaries. Older sessions without these fields continue to work.
- The native CDP WebSocket writes trace/profile bytes directly to the capture store. The extension's existing 128 MiB WebSocket ceiling is unrelated to this bulk path; `BrowserBridge` continues to carry semantic/observer messages only.
- Ordinary cloud Push carries a compact edited-time derivative. Raw trace/body/heap exports require a distinct explicit action.
- Capture overhead, missing targets, protocol errors, buffer loss, disconnected intervals and recorder-owned work are evidence, not reasons to fabricate zero-valued metrics.
- One owner coordinates the browser-wide trace. Do not run standalone `Profiler.start` sampling alongside trace CPU sampling.

## Proposed file contracts

All files below are additive beneath the existing session folder. Names are recommended module contracts, not claims that files already exist.

| New session file | Format and purpose |
| --- | --- |
| `performance/manifest.json` | Versioned capture inventory, capture IDs, modes, requested/actual scope, Chrome/protocol/parser versions, per-file hashes, lifecycle state, redaction policy and omissions. Written atomically. |
| `performance/clock.jsonl` | Clock domains and calibration observations: source clock/unit, Chrome/page stamp, host-clock bracket, first-video origin, wall anchor for display, residuals and fitted mapping segments. Append-only. |
| `performance/targets.jsonl` | Target/session/frame/document lifecycle, tab association where available, origin labels, execution contexts, attachment status, related-worker attribution and coverage gaps. |
| `performance/network.jsonl` | Normalized request/redirect-hop records, timing phases, cache/service-worker flags, priorities, initiator references, transfer counters and terminal state. Stable identity includes capture/session/request/hop. Bodies are separate and omitted by default. |
| `performance/observations.jsonl` | Original-time page PerformanceObserver records plus semantic input/navigation/mark associations, observer support and recorder-owned intervals. |
| `performance/metrics.jsonl` | Timestamped target-scoped counters at 1 Hz in T1; optional lower-frequency memory summaries with exact metric semantics. |
| `performance/coverage.jsonl` | Start/stop, disabled/unsupported domains, target gaps, backpressure, ring overwrite, trace loss, export omission and detach/reconnect intervals. |
| `performance/index.json` | Compact summaries, original-time bounds, target lookup, stable event references and lazy detail paths. No full trace events or bodies. Includes schema/parser versions and source hashes. |
| `performance/findings.jsonl` | Derived findings with method/version, measured values, evidence IDs, confidence/limitations and original-time interval. |
| `performance/marks/<stableId>.json` | Small per-mark evidence package, selected interaction/window, findings and links to source records. A stable ID must survive play-order renumbering in a join. |
| `performance/trace/0001.trace.json.gz` | Finalized Chrome JSON trace for one bounded capture. Store its acquisition metadata and actual interval in the manifest. Temporary unfinalized files use a different suffix and never masquerade as complete traces. |
| `performance/trace/0002.pftrace` | Broad native protobuf trace, or a declared supported-format fallback. Preserve the actual returned encoding; do not rename JSON as protobuf. |
| Optional later `performance/cpu/*.cpuprofile` | Native standalone CPU profiles only in an explicit mode without simultaneous trace CPU sampling. |
| Optional later `performance/heap/*` | Diagnostic allocation samples or heap artifacts, clearly separate from lightweight heap-usage counters; local-only by default. |
| `performance/exports/network.har` | Optional on-demand HAR derived from the canonical network ledger, with explicit omissions and CDP-specific extensions where useful. |

An interval index record should distinguish original measurement from display projection. Example fields: `eventId`, `captureId`, `sourceSessionId`, `targetId`, `clockId`, `sourceStartUs`, `sourceEndUs`, `originalDurationUs`; projections add `segmentOccurrence`, `editedStartUs`, `editedEndUs`, `clippedLeft`, `clippedRight`. Native/cloud derivatives may use different playable origin IDs, while retaining source evidence IDs as provenance. A single event can have more than one projected piece.

Raw CDP events may arrive out of order across domains. A normalized record is not final until its lifecycle and available extra-info events have been reconciled, or a bounded finalization timeout marks it incomplete. Preserve unknown/missing fields distinctly from zero.

## M1 — Lightweight performance evidence and trustworthy timestamps

**Shippable outcome:** every new recording can show long tasks, long animation frames, slow interactions, layout shifts and resource summaries alongside existing page context, with visible coverage and reliable source timestamps. This milestone works without native CDP access.

### Files and modules

- Modify `extension/page.js` and `extension/relay.js`; introduce small plain-JavaScript `extension/performance.js` and, if a MAIN-world observer bridge is needed, `extension/performance-relay.js`. Preserve current selector/component/source capture. No npm build or Node runtime is required.
- Modify `extension/background.js` to understand capture start/stop, capture IDs, document IDs and sequenced observer batches; avoid using its existing 200-message count queue for bulk evidence.
- Modify `extension/manifest.json` for a separate observer content-script entry with desired frame coverage and frame/document provenance. Keep existing `page.js`/`relay.js` semantic snapshot injection top-frame-only. Do not turn `all_frames` on for those existing listeners: multiple frames answering the same snapshot request would race. Route existing snapshot/region requests with `chrome.tabs.sendMessage(tabId, request, {frameId: 0})`, and keep their programmatic injection at frame 0. The observer relay uses distinct message types and never answers snapshot/region requests.
- Modify `Sources/ContextRecorder/Recorder.swift` to publish a safe first-frame/host-clock anchor; `BrowserBridge.swift` for versioned capture-control and clock exchange messages; `RecorderController.swift` for start/stop ownership; `Session.swift` or a new `PerformanceCaptureStore.swift` for append-only files.
- Add `scripts/process_performance.py` (stdlib-first) and call it from `scripts/process_session.py`; extend `Library/SessionData.swift` with optional performance metadata, and add a small native summary surface without changing existing Page events.
- Add the minimum original-time-to-playback projection helper now, with shared Python/Swift fixtures and the active edit-map fingerprint. Even M1 findings must split at cuts, retain original durations and distinguish joined sources. Keep legacy mark boundary semantics separate. If the user edits before a derived index is refreshed, hide stale performance coordinates behind an Updating state or reproject from original records; never display them against the new video clock. M5 extends this foundation to complete cloud/export roundtrips.
- Add a minimal export guard in `Cloud/CloudBundle.swift` while full performance cloud support is pending: ordinary Push does not accidentally copy raw files or leave newly added local-only performance references in the flattened bundle. It records `not-exported` availability for performance. M5 enables the compact derivative; until then existing cloud video/marks/page events remain shippable.
- Update `scripts/build-app.sh` resource packaging for the new Python/plain-JavaScript files. Use the existing Swift/Python toolchain; avoid a hidden Node runtime dependency in capture, processing or installation.

### Capture behavior

1. Start an explicit capture epoch after a video origin exists; data acquired before the origin may be kept as labeled pre-roll but cannot be guessed into the video timeline.
2. Negotiate supported observer entry types. Collect supported `resource`, `navigation`, `paint`, `longtask`, `long-animation-frame`, `event` with `durationThreshold: 16`, `first-input`, `largest-contentful-paint`, `layout-shift`, `mark` and `measure` entries, with bounded per-type buffers and records of unsupported entries. Keep arbitrary User Timing `detail` payloads off by default. Do not use arbitrary page marks as trustworthy recorder calibration markers; names must be namespaced and recorded separately. Include the extension sender's tab/frame/document identity and the page clock identity on every observer batch; document replacement starts a new page-clock epoch.
3. Use Event Timing's grouping/rounding semantics and explicit per-document visibility/navigation state; a mark-local interaction latency is not automatically a page-level INP score. LCP is a navigation/lifecycle metric, not a generic route-transition duration. Preserve resource Timing-Allow-Origin restrictions and unknown timing/byte values.
4. Tag recorder snapshot/MHTML/region work, because a mark currently triggers live DOM inspection and MHTML capture. Keep the normal mark behavior, but separate its perturbation from the preceding app interaction.
5. Keep failed/slow fetch/XHR, console, navigation and click capture working. When a future CDP capture is active, canonical-source selection will prevent duplicate presentation without deleting original provenance.

### New files and format

Ship `manifest.json`, `clock.jsonl`, `observations.jsonl`, `coverage.jsonl` and a small `index.json` in `performance/`. `session.json` gains an optional performance reference and per-mark availability, not an embedded observer event dump. Each observer record includes document/frame identity, original `startTime`/duration, clock identity and arrival timestamp separately.

### Checks and exact expected values

- **First-frame clock fixture:** video origin is host time `1000.000000 s`; calibrated mapping is `hostSeconds = chromeSeconds + 900`. Chrome event `105.250000 s` must map to source video `5.250000 s`. A wall-clock adjustment of +3600 s must not change this result.
- **Delayed delivery fixture:** the same event arrives when the video offset is `7.000000 s`; its source time remains `5.250000 s`, and receipt time is separately `7.000000 s`.
- **Single interaction fixture:** Event Timing entry has `startTime=12000`, `processingStart=12040`, `processingEnd=12180`, `duration=240` (milliseconds). Expected input delay `40 ms`, processing `140 ms`, presentation delay estimate `60 ms`, total `240 ms`. If entries are grouped by interaction ID, do not sum repeated event durations into a new total.
- **Observer unsupported fixture:** absent `long-animation-frame` support produces `unsupported`, not `0 frames` or `0 ms`. Late injection marks pre-injection coverage unavailable even when buffered entries recover some past records.
- **Mixed-session fixture:** queued event for capture A arriving during capture B must never enter B's original-time stream.
- **Existing behavior fixture:** old `session.json` with no performance fields loads; clicks, warnings, errors, snapshots and failed requests still appear as before.
- **Frame-routing fixture:** a top frame and two permitted child frames each emit one observer batch, producing three distinct frame/document records. A mark snapshot/region request goes only to frame 0 and gets exactly one top-frame response; neither observer relay responds. A disallowed/restricted child frame is recorded as unavailable, not silently represented by the parent's observations.
- **Edited-observer fixture:** a source long task at `[9.900,10.100) s`, with kept segments `[0,10)` and `[20,30)`, has one visible piece `[9.900,10.000)` but retains original duration `200 ms`, not `100 ms`. A cut changes the edit fingerprint; an old index must not render at stale coordinates during reprocessing.
- **Recorder perturbation fixture:** a synthetic recorder MHTML interval from `5.300–5.550 s` stays labeled recorder activity; a preceding app interaction at `5.000–5.240 s` retains its original latency and attribution.

These are proposed tests. The mission did not run observers or an extension.

### README update

Update **Chrome extension (page context)** with capture support/limitations, script injection timing, frame scope and existing behavior. Add **Performance capture → Lightweight** and extend **Session output** with the new files and source-clock explanation. Correct the statement about never recording input values: the current `describe()` can read `target.value`, and the implemented policy must match the documentation.

### Main risk

Late injection, different document time origins and observer visibility restrictions can create apparently complete but partial evidence. Explicit coverage and clock metadata are the release criterion; lack of deep CPU attribution is an honest limit of this milestone.

## M2 — Native consent connection and complete network capture

**Shippable outcome:** record full selected-tab request waterfalls, cache/priority/initiator metadata, console/exception data and 1 Hz performance counters from the everyday Chrome profile, while the extension supplies page semantics. No trace recording is required for this milestone to be useful.

### Bounded prototype before production connection

Implement a disposable native connection spike in the existing Swift toolchain. On the installed supported Chrome build, verify the user-facing `chrome://inspect/#remote-debugging` approval flow, the descriptor location and two-line content, WebSocket connection/approval ordering, denial/cancel/disconnect behavior, browser version, `Target` capabilities and coexistence with ordinary DevTools. Treat `/json/*` discovery as unavailable in approval mode unless observed otherwise. Read the descriptor only for the selected Chrome user-data directory; do not guess by trying unrelated browser profiles.

**Completion decision:** once native approval plus selected-tab Network/Runtime events work in the everyday profile, integrate the small Swift WebSocket client. If this installed Chrome cannot support the flow, keep M1 shippable, explain the exact upgrade/enablement step, and validate manual trace/HAR import as the next useful slice. A deliberately separate debugging profile remains an optional diagnostic path. Evaluate a limited `chrome.debugger` backend only if it solves that concrete blocker, with its restrictions named; do not silently call it full capture. Do not revert to Chrome launch flags against the default profile or install a heavyweight runtime. A failed spike is evidence for the remaining implementation choice, not a request for outside demand.

### Files and modules

- Add `Sources/ContextRecorder/ChromeCDP.swift` for CDP request IDs, response routing, event dispatch, WebSocket lifecycle and protocol error handling using `URLSessionWebSocketTask`.
- Add `ChromeCaptureCoordinator.swift`, `ChromeTargets.swift`, `PerformanceCaptureStore.swift` and small normalized-network/sanitizer modules. Keep these separate from SwiftUI state.
- Modify `RecorderController.swift` to own start/stop/drain and capture IDs; add capture controls to `Library/RecordingViews.swift` and setup explanation in `Library/ChromeExtensionSheet.swift` or a focused Chrome diagnostics sheet. Keep `ChromeExtension.swift` responsible for extension installation, not native CDP ownership.
- Modify `scripts/process_performance.py`, `Library/SessionData.swift`, `Library/EventLog.swift` and later `SessionTimeline.swift` for derived request rows and summary counts. Do not put CDP events through `BrowserBridge.onEvent`.
- Update extension message schema only where a tab/document association or semantic event needs a CDP identity correlation.

### Capture behavior

- Connect once per recording capture to the browser endpoint; run capability/version checks and choose an explicit selected-tab scope. Preserve unrelated browser activity outside the scoped normalized index. Trace-wide scope is a separate later mode.
- Attach selected top-level targets and their related frames/workers with flat sessions. Use recursive related-target discovery where needed, and publish coverage for shared/service workers whose attribution cannot be confined to one tab. Do not pause new targets as a default capture mechanism.
- Enable `Network`, `Page`, `Runtime`, `Log`, `Audits` and `Performance` where supported on each relevant target. Use `Performance.enable` with `timeDomain: "timeTicks"`; capture Target/runtime execution-context lifecycle and poll `Performance.getMetrics` at 1 Hz. Keep `Profiler`, `HeapProfiler` and `Tracing` off in T1. Optional `Runtime.getHeapUsage` belongs to a declared memory diagnostic policy. Do not turn cache off, bypass service workers, throttle CPU/network or alter app execution during ordinary recording.
- Calibrate native host time against the `Timestamp` metric from native-bracketed `Performance.getMetrics` after `Performance.enable(timeDomain: "timeTicks")`. Retain host send/receive brackets, the returned timestamp and Chrome build; this selected implementation pairs the metric's TimeTicks clock with Network monotonic seconds. Missing Timestamp or a mismatched observed epoch is a capability failure, not permission to substitute `Date.now()`. Calibrate each document's `performance.now()`/time origin separately, and use recorder-namespaced trace markers to link page and trace clocks.
- Collect request/response timing, redirect hops, cache and service-worker flags, protocol, priorities/changes, available initiator metadata, failure/cancellation, data/encoded-transfer counters and response metadata. Script initiator stacks require the documented `Debugger` enablement; T1 must not promise them when that optional attribution is off. Reconcile `requestWillBeSentExtraInfo`/`responseReceivedExtraInfo` even when their ordering differs from base events. Preserve effective and wire status when revalidation exposes both, and do not double-count `dataReceived` bytes on top of terminal `loadingFinished.encodedDataLength`.
- Headers follow a versioned safe-value allowlist and sensitive-name suppression before JSONL persistence, including extra-info cookie structures and raw header-text aliases. Bodies are off. WebSocket events keep connection/timing/direction/opcode/payload-byte metadata without content; CDP's named “frame” object represents a whole message, and its size is not wire traffic. Optional selected textual bodies have proposed caps of 256 KiB/resource, 5 MiB/minute and 20 MiB/session; selected socket text previews have caps of 4 KiB/message and 1 MiB/session. Skip binary/uploads/media/auth endpoints by default. These are retained-content limits, not guarantees against larger upstream allocations. Never offer a blanket credential-dump mode.
- Where CDP emits console or network events also seen by the extension, use one canonical presentation source while retaining source IDs. An inability to map a page patch event to a CDP request is unresolved evidence, not permission to deduplicate by URL alone.

### New files and format

Add `targets.jsonl`, `network.jsonl`, `metrics.jsonl`; extend `manifest.json`, `clock.jsonl`, `coverage.jsonl`, `index.json`. Preserve redirect identity as `(captureId, cdpSessionId, requestId, redirectHop)`. A terminal network record distinguishes `finished`, `failed`, `canceled`, `captureEnded`, `targetDetached` and `unknown`.

### Checks and exact expected values

- **Network fixture:** request starts at Chrome `1000.100 s`, response headers at `1000.300 s`, finishes `1000.500 s`; expected total `400 ms`, headers-arrival time from request start `200 ms`. If timing phases report `sendEnd=12 ms` and `receiveHeadersStart=200 ms`, request-send-end to first-header latency is `188 ms`. Never call the whole `400 ms` server time.
- **Missing phase fixture:** DNS/connect values of `-1` yield unavailable/reused phases, not a measured `0 ms` DNS/connect cost.
- **Redirect fixture:** one CDP request ID reused across a 302 hop and a 200 destination creates two hop records sharing one chain ID. Counts show one redirect chain and two HTTP requests; initiating stack lineage is preserved.
- **Identity fixture:** target sessions X and Y both emit requestId `17`. Expected two distinct requests, even with identical URLs and timestamps.
- **Cache fixture:** disk-cache response and service-worker response remain distinct flags; a zero-byte Resource Timing entry alone cannot establish cache use. A canceled response with unknown terminal transfer size is incomplete, not a complete response of the advertised Content-Length.
- **Sanitizer fixture:** headers with case variants of `Authorization`, `Cookie`, `Set-Cookie`, `Proxy-Authorization` and configured token headers do not appear in stored sanitized metadata. Synthetic secret `s3cr3t` must be absent from exported network/mark records. Allowed query value `sort=date` may survive while `token` is represented as redacted. Preserve redaction facts/counts so data absence is explainable.
- **WebSocket fixture:** a 6-byte text message delivered in one CDP WebSocket event contributes one message event and six content bytes; payload string is absent with capture off. Do not infer underlying WebSocket frame fragmentation or protocol/wire overhead from this CDP object.
- **Lifecycle fixture:** opening DevTools, closing a tab, killing/restarting Chrome and declining consent produce explicit coverage changes; extension clicks/errors keep working. No automatic loop repeatedly reopens permission dialogs.
- **Overhead experiment:** record a fixed user flow with M1 only and M2 enabled, at least five repetitions each in alternating order. Report timing/CPU/file size differences descriptively with workload/build/cache state; do not convert these results into a universal overhead guarantee.

All browser checks and experiments are proposed.

### README update

Add **Performance capture → Connect Chrome** and **Capture scope** with the approval dialog, selected-tab/related-target semantics, denial/recovery, and normal DevTools interaction. Document that ordinary capture preserves cache/service-worker/throttling state. Add network file format and sensitive-data policy to **Session output** and **Cloud**.

### Main risk

The current consent endpoint can differ from conventional port-debugging discovery, and target/session topology can change across navigation and workers. The spike must prove installed-build behavior before production capture promises; target coverage remains explicit after it ships.

## M3 — Bounded deep traces and external viewing

**Shippable outcome:** capture a short real Chrome performance trace aligned with the video and open it in DevTools or Perfetto. It is useful immediately even before all native analyses exist.

### Files and modules

- Extend `ChromeCaptureCoordinator.swift`; add `ChromeTracing.swift`, `TraceClockCalibration.swift`, `TraceFileWriter.swift` and an external-viewer export action.
- Add a bounded parser/adapter under `scripts/trace/` or `scripts/process_performance.py` that reads supported trace events incrementally, preserves unknown records in raw storage and emits compact known summaries.
- Extend recording controls with **Arm trace**, **Capture around mark**, and **Diagnostic trace** states, actual retained coverage and remaining duration. Use the existing recording lifecycle; stop must finalize or declare incomplete evidence.
- Modify `Session.swift`/capture manifest and `RecorderController.stop`, `stopForQuit` for bounded finalization. Do not rely on `pageCaptureFolder`'s single mutable folder pointer for trace drains.
- Add the raw trace/manifest references to native session details and the file-open action. Avoid a heavy trace-analysis runtime at this milestone.

### Capture behavior

- T2 is an armed selected-target-session trace with a requested 64 MiB circular buffer, `recordContinuously`, JSON/gzip `ReturnAsStream`, and preset D below. The arm has one fixed deadline 60 s after it started. A mark at arm-relative time `t` requests capture end at `min(t + 10, 60)` seconds, with nominal 10 s prehistory; nearby marks share the capture and may extend its requested end only within that original deadline. At elapsed 58 s, only a 2 s post-mark tail remains. Do not reset the 60 s lifetime on each mark. Actual available history comes from retained trace bounds/loss metadata, not a wall-time promise.
- When T2 was not armed, a mark can start forward recording or request a repeat of the interaction. The UI and Markdown must say pre-mark deep evidence is unavailable.
- T2 collection is not tab-private: the root connection's attached-process set, browser/GPU processes and shared processes can contain other activity. Preserve actual observed process/target scope; filtering a native summary does not sanitize the raw trace.
- T3 is a distinct explicit browser-root diagnostic window, nominally 30 s, at most 60 s, with requested 256 MiB buffer, `recordUntilFull`, `streamFormat: "proto"`, `streamCompression: "none"`, `ReturnAsStream`, preset B and declared scope. Stop early when the chosen buffer-pressure policy triggers. This is not a circular ring. Preserve `.pftrace` bytes without expanding them to JSON merely for storage. If gzip is selected instead, filename and compression metadata must identify the actual bytes. If protobuf is unavailable, record the selected format fallback; do not relabel it protobuf. Basic raw capture/export can ship in M3; richer native protobuf findings wait for the optional M6 processor.
- Negotiate category availability with `Tracing.getCategories`, record exact effective config, and mark unsupported/excluded categories. An advertised category name is not proof that a required event appeared in this capture; missing required events disable the dependent finding and expose unavailable coverage. Requested buffer sizes/periods are policy values, not guarantees of effective Chrome retention.
- Use one coordinated CDP tracing owner, and never end a trace owned by a competing DevTools/other client. `ReportEvents` is not a guaranteed live feed. For `ReturnAsStream`: `Tracing.end` → `Tracing.tracingComplete` → repeated `IO.read` at proposed 256 KiB chunks until `eof` → `IO.close`. Handle `base64Encoded` correctly. Event delivery and chunk boundaries are not source-time boundaries. After `tracingComplete`, a requested rearm may begin with a distinct capture ID; any overlap with the preceding stream drain must retain distinct stream handles, writers and original session owners. Expose the drain/rearm gap.
- Keep the tracing lease at app level across both active and closing recording captures. Starting recording B while capture A is still awaiting `tracingComplete` may start B's video/T0/T1, but cannot call `Tracing.start` for B; show that tracing is finishing. Release A's acquisition lease only after its `tracingComplete` or an explicit disconnected/error state establishes the capture ended. After `tracingComplete`, B can acquire the lease while A's IO stream drains to A's original file. Per-recording WebSocket objects must not accidentally create two independent lease owners.
- Write partial raw files until verified drain completion, then atomically commit the artifact and hash. Keep `transportComplete`, Chrome `dataLossOccurred`, and parser status separate: a complete raw download can contain a wrapped/incomplete trace or an unsupported parser schema. A completely drained `.pftrace` must finalize and be externally viewable even before a native protobuf parser exists; JSON validity/analysis status is likewise a separate flag. Disconnect/timeout/crash leaves recoverable partial data and an incomplete capture status; never label a repaired prefix complete.
- At video Stop, retain an independent closing-capture owner and original session destination while waiting for trace completion/drain. Use a proposed **12 s post-video drain deadline** for normal processing: once it expires, process video/marks with explicit incomplete-performance state; an ongoing bounded drain may later finalize its original capture and trigger a derived-data revision. Do not block the UI or route late bytes to a new recording. On application quit, wait at most the same configured deadline, then close available streams/connections best-effort and persist incomplete status; no process is promised to keep draining after quit. The 12 s value is a product policy requiring measurement, not an API limit.
- Keep original CDP timestamps and explicit clock mappings. Trace JSON microseconds are not wall-clock microseconds. User/mark clock markers link to source time; calibration residuals, discontinuities and lost intervals remain visible.
- Native transport bypasses the extension bridge's 128 MiB message ceiling. Bound native queued bytes and decoded-parser memory separately from Chrome buffers. Set the proposed retained-deep-artifact budget to **1 GiB per session**; stop or decline additional deep capture at that budget, preserving video and T0/T1 with an omission record. The 64/256 MiB browser buffers do not bound JSON expansion or Python object graphs. Use incremental parsing off the main actor, not an unbounded `json.load`.

The following preset lists match the report and are part of the standalone implementation contract. Request only the installed browser's advertised subset and record omissions. Optional `Debugger` enablement in T2 may enrich initiator/script metadata; it is not implicit in T1.

```text
# Preset D: focused interaction detail
devtools.timeline
disabled-by-default-devtools.timeline
disabled-by-default-devtools.timeline.frame
disabled-by-default-devtools.timeline.stack
disabled-by-default-devtools.target-rundown
disabled-by-default-devtools.v8-source-rundown
disabled-by-default-v8.cpu_profiler
blink.user_timing
blink.console
loading
navigation
rail
latencyInfo
v8.execute
v8
cc

# Preset B: D plus broad browser diagnostics
renderer.scheduler
blink
cppgc
gpu
viz
input
netlog
disabled-by-default-memory-infra
```

Use `Tracing.start.traceConfig.includedCategories` for the effective preset, `excludedCategories: ["*"]`, and `traceBufferSizeInKb: 65536` for T2 or `262144` for T3. Buffer-usage reporting is requested every 1000 ms. Standard trace CPU sampling is already in D/B, and memory-infra hooks are in B; explicit memory dumps, heap diagnostics and rendering pictures remain opt-in. Exclude `disabled-by-default-v8.cpu_profiler.hires`, `disabled-by-default-devtools.v8-source-rundown-sources`, `disabled-by-default-devtools.screenshot` and wildcard-enabled disabled categories by default. Explicit rendering detail may add the exact categories `disabled-by-default-devtools.timeline.invalidationTracking`, `disabled-by-default-devtools.timeline.layers`, `disabled-by-default-devtools.timeline.picture`, `disabled-by-default-blink.graphics_context_annotations` and `disabled-by-default-layout_shift.debug` only when advertised and needed; persist the effective strings in the manifest. Treat `blink_gc` only as an advertised legacy alternative to the current `cppgc` category, not an unconditional extra.

### New files and format

Add `performance/trace/0001.trace.json.gz` and broad `performance/trace/0002.pftrace`, each with a separate temporary partial path. Manifest records actual format/compression, effective categories, source-time extent, buffer policy, transport/parser/loss state and hash. Store any raw CPU-profile events within the trace as captured. Standalone `.cpuprofile` is an explicit later mode, not a second simultaneous sampler. On-demand HAR export is derived from `network.jsonl` and never replaces that ledger.

### Checks and exact expected values

- **Stream fixture:** three reads contain byte chunks `abc`, `de`, `f` with the third EOF=true. Expected final decoded bytes `abcdef`, length 6; three chunks in order; one IO.close. Complete each pending CDP command ID only once; a duplicate response cannot append twice. Do not blindly retry a stateful `IO.read` after an ambiguous transport failure and assume it replays the same bytes. A base64 chunk `YWJj` decodes to `abc`, not four literal characters. All bytes are written by the native path; no trace chunks appear on `BrowserBridge`.
- **Trace-time fixture:** calibration maps Chrome trace `ts=105250000 µs` to source `5.250000 s` under M1's clock fixture. `dur=120000 µs` remains `120 ms`. Different trace captures with the same PID/TID do not share identity automatically.
- **Synthetic task fixture:** a `RunTask` lasting `120 ms` contains a `FunctionCall` `90 ms`, `Layout` `20 ms`, and 10 ms unclassified remainder, without overlap. Expected long-task count 1; long-task total 120 ms; long-task blocking over 50 ms 70 ms; exclusive known categories sum 110 ms and unknown 10 ms. Do not sum the parent and children into 230 ms. Nested children of FunctionCall must likewise use exclusive/union accounting.
- **Loss fixture:** mark at source `40 s`, requested window `[30,50]`, actual retained trace starts at `34 s`. Output states requested prehistory 10 s, available prehistory 6 s and missing interval `[30,34)`. It must not synthesize absent events or claim no work occurred there.
- **Unarmed fixture:** a mark at `40 s` starts trace at `40.050 s`. Deep evidence before `40.050` is unavailable, even if lightweight observers exist before it.
- **Fixed-expiry fixture:** arm starts at source 0; marks occur at 56 and 58 s. Stop remains source 60 s. The second mark has at most 2 s tail; it must not extend acquisition to 68 s. Record a nominal requested `[48,68]` window and the actual retained intersection ending at 60, including any prehistory loss.
- **Drain fixture:** Stop at `60.000 s`, tracingComplete at `60.200`, final IO EOF at `60.500`. Completion is declared at finalization, with recording stop time and data arrival separate. The file still belongs to the stopped session if a new recording starts during drain.
- **Cross-recording lease fixture:** B starts while A is stopping at host 60.100; A emits `tracingComplete` at 60.200 and EOF at 60.500. B emits no `Tracing.start` before 60.200. It may begin acquisition after 60.200 while A's remaining chunks still write only A's file. B's T0/T1/video need not wait for A's EOF.
- **Deadline fixture:** video stops at source 60 s; final IO EOF has not arrived by 72 s. Normal processing proceeds with incomplete performance. EOF at host time corresponding to source 74 s finalizes only the closing capture, then publishes a new derived revision; it does not move capture timestamps or rewrite the next session. If the app quits at the deadline instead, partial metadata remains and late completion is not promised.
- **Artifact-budget fixture:** a session already retains exactly 1 GiB of deep artifacts. A new deep capture is declined/stopped with a budget coverage record, while T0/T1/video remain enabled; raw JSON expansion limits are tested separately.
- **Format/analysis fixture:** a complete protobuf stream with parser support absent becomes a hashed `.pftrace` with `transportComplete=true` and analysis `unsupported`, and the external-open action remains available. It does not stay `.partial` merely because native findings are unavailable. A complete JSON stream with a parser error preserves the raw artifact and independently reports invalid/unsupported analysis.
- **External-viewer acceptance:** load a real produced trace into both DevTools Performance and Perfetto; select a named marker and compare its mapped source-video offset. Preserve a small golden trace plus observed browser/version metadata after this real test. Until executed, compatibility of the exact generated container is proposed.
- **Perturbation experiment:** repeat the fixed flow with T1 and T2/T3, collect raw/compressed MiB/minute, Chrome/app CPU, dropped video frames and input timing. State cache, target count, trace categories and whether DevTools was open. Budgets in the report remain planning estimates until measured.

### README update

Add **Performance capture → Deep traces**, explicit armed/unarmed behavior, nominal versus actual retained windows, browser-wide diagnostic scope, finalization/partial recovery and **Open in DevTools / Perfetto**. Extend **Session output** with raw trace format and local-only status.

### Main risk

Trace category names and event schemas evolve; tracing can perturb the workload and circular buffers may retain much less history than expected. The feature must expose actual coverage and measured overhead, with a versioned parser and raw export that remain useful when one native analysis is unsupported.

## M4 — Mark-centered analysis, native lanes and agent handoff

**Shippable outcome:** selecting a mark answers what was slow, shows the relevant waterfall and main-thread evidence, and copies a concise, evidence-linked Markdown package for Claude/Codex. External deep viewers remain available.

### Files and modules

- Expand `scripts/process_performance.py` into explicit deterministic analyses, with one versioned method per finding. Keep trace-schema adapters separate from scenario heuristics.
- Add `Library/PerformanceStore.swift` (lazy indexes/details), `PerformanceLane.swift`, `PerformanceMarkDetail.swift`; modify `SessionData.swift`, `SessionModel.swift`, `SessionTimeline.swift`, `EventLog.swift`, `MarkDetail.swift`, `MarkText.swift` and the relevant canvas hover/model lookup.
- Update `scripts/process_session.py:mark_markdown`, `scripts/viewer.html` and `cloud/src/markdown.ts` together so Markdown formatters have equivalent values and limitations. Add a compact `performance` section to mark data consumed by `cloud/src/mcp/server.ts` rather than making an agent download/parse a whole trace to read a mark. Native/local handoff ships now; full cloud performance export activates in M5. Until then keep the M1 export guard, suppress dangling raw/detail links in copied Markdown, and state that performance evidence was not exported.

### Analysis and UI behavior

- Start with the highest-value scenarios in the scenarios report: preceding interaction/next-paint breakdown, request waterfall and delay phases, long-task/script attribution, duplicate/chatty requests, layout-shift/render-work correlation. Per-mark summary is the common output contract, not a separate opaque score.
- Select the likely preceding user interaction by target, document and time window. Expose the chosen interaction and let the user select a different one. Narration and proximity establish intent/correlation, not proof of a causal dependency.
- Build a causal graph only where trace IDs, initiator relationships, explicit async links or scheduling relationships support an edge. Label inferred edges and unresolved spans. Do not call “last request to complete” the critical path without evidence.
- Native timeline uses compact overview lanes and lazy detail: input/long-task bands, network activity, layout shifts, optional memory trend, capture gaps. All share `model.seek` and the existing playhead. Do not recreate all DevTools tracks in SwiftUI.
- Events tab receives derived findings and capture-state changes, with raw IDs accessible. Existing five-second summary folding cannot be reused for request deduplication.
- Canvas badges query the video time under the pointer. They do not imply a stitched canvas image was visible all at once, or merge evidence from unrelated source sessions.
- Agent Markdown includes measured values, source file/line quality, evidence IDs/time window, selected interaction, capture tier/config, hypotheses, unknowns and a concrete next code investigation. Any source-map location remains distinguished from generated bundle coordinates.

### New files and format

Ship `findings.jsonl` and `marks/<stableId>.json`; enrich `index.json` with event references and compact lane buckets. The `session.json` addition stays bounded and references detail files; it does not include CPU stacks for the entire session.

### Checks and exact expected values

- M1's 240 ms interaction fixture produces the same 40/140/60 ms breakdown in native mark detail, `marks/*.md`, `session.md`, browser Copy as Markdown and the cloud MCP formatter given the same synthetic compact input. Real push/download/MCP parity is the M5 integration check, after cloud export is enabled.
- M3's 120 ms task fixture reports one long task and 70 ms over the 50 ms threshold; nested spans are never double counted. Script attribution `90 ms` is labeled traced execution or sampled attribution according to its actual source.
- **Duplicate request fixture:** three overlapping same-origin GET requests for the same normalized cache key start at `1.000`, `1.010`, `1.020 s` and each transfers 1000 measured bytes, with no redirect/retry/range/body differences. Output identifies one candidate group of 3, 2 extra requests and 2000 candidate redundant bytes. It says “candidate”; server effects, authentication and cache semantics may still make them necessary.
- **False-duplicate fixture:** byte-range requests for `0–999` and `1000–1999`, or POSTs with differing body fingerprints, are not classified as interchangeable duplicate requests.
- **Layout-shift fixture:** shifts 0.10 at 1.0 s, 0.20 at 1.5 s and 0.40 at 3.0 s, all eligible, produce separate session windows and a maximum window sum of 0.40 under the stated CLS session-window algorithm; a `hadRecentInput=true` shift is excluded from CLS but may still be displayed as a user-visible movement. Native views must label mark-local sums separately from lifecycle CLS.
- **Causality fixture:** a request overlaps a 200 ms interaction but has no supported dependency edge; output may show overlap, not “request caused the 200 ms delay.” A missing frame/presentation event must not be replaced with an exact paint timestamp from a 15 fps screenshot.
- **Source fixture:** missing source map yields generated URL:line with “source map unavailable”; it does not invent a TypeScript file. Existing DOM source hints can appear separately as a candidate component context.
- **UI fixture:** selecting a finding at 5.250 source seconds seeks the correct edited playback offset; opening details fetches that detail file only. Keyboard selection/filtering matches existing Events/Marks behavior.

### README update

Extend **Sessions window** with new lanes, capture gaps and performance mark details; **Marking up a recording afterwards** with available historical evidence versus unavailable live capture; **Canvas** with time-based performance badges; and **Copy as Markdown / agent handoff** with the evidence/unknowns contract.

### Main risk

Correlation can be presented as causation too easily. Release criteria require honest confidence, unknown spans and source-map quality, with reproducible deterministic findings rather than a one-number health score.

## M5 — Correct edits, joins, cloud bundles and downloaded sessions

**Shippable outcome:** cuts and joins preserve every performance fact's original meaning while the native/cloud timeline stays synchronized. Ordinary Push adds compact useful evidence without uploading giant raw traces or cut-out activity.

### Files and modules

- Modify `scripts/process_session.py` and shared `scripts/process_performance.py` interval projection; extend `Sources/ContextRecorder/Library/Edits.swift` and shared edit fixtures to make the boundary policy explicit.
- Modify `Cloud/CloudBundle.swift:build`, `writeLogs`, `inputHash`, content-type/manifest construction; extend its self-test fixtures. Update the selected cloud pull/reprocessing integration so derived performance survives downloads lacking raw traces.
- Update `cloud/src/manifest.ts` with optional performance summary/omission metadata; `cloud/src/files.ts` only if new selected file serving behavior is needed; `cloud/src/markdown.ts`, `cloud/src/mcp/server.ts` and `scripts/viewer.html` for lazy summary/details.
- Update `docs/cloud-sessions.md` first as the existing format contract requests. Remove the stale `cloud/README.md` “rewrite logs” future item; pinned code already rewrites logs into flat time.

### Projection and export policy

- Compute measurements in original source time. Split intervals at cuts, preserve source event ID and original duration, and give each displayed piece a segment occurrence. Do not compress a causal chain into one artificially faster interaction.
- At joins, namespace captures/targets/PIDs/TIDs/request IDs by source session. Never join a network request or memory trend across unrelated original recordings.
- Resolve the mismatch between the half-open documentation and the inclusive endpoint implementations in Python and Swift together. M1's new performance interval/instant-event projection uses half-open membership. Preserve existing user marks through an explicitly named `legacy-inclusive` point-mapping policy until a deliberate mark-schema migration is implemented; final user marks at the last source endpoint remain visible under that policy. Do not silently convert old marks to half-open membership or claim an inverse mapping at a cut boundary is unique. Add shared exact fixtures before any future point-policy change.
- Respect actual AVComposition placement when track tails truncate requested segments. Current edit values have millisecond precision and composition requests timescale 600; derive/validate final exported playable coordinates rather than promising microsecond visual identity.
- Keep raw local traces unchanged. Cloud receives a new compact edited-time derivative and an export origin; raw source provenance is metadata, not an absolute filesystem link. No ordinary cloud file may contain an excluded cut interval merely because it was nearby in a raw trace.
- Proposed separate performance budget: at most **2 MiB** of uncompressed summary/index/detail JSON; index at most **256 KiB**, each mark detail at most **64 KiB**. Count actual UTF-8 bytes. Deterministically prioritize visible mark findings and coverage before optional detail; never cut a JSON byte stream mid-object. Report omitted details and keep the retained summary truthful.
- Existing MHTML budget remains a distinct policy: `max(10 MiB, video bytes/2)`. It is not a budget for traces or the whole bundle. Raw trace/profile/body/heap data is omitted from ordinary Push. Optional selected raw slices use a separate explicit export action with a displayed size and sensitivity scope.
- Hash performance inputs, parser/method/schema version and export policy in cloud freshness. If raw sidecars change and the index or policy changes, the cloud copy must become out of date.
- A downloaded compact session must retain derived findings when raw trace files are absent. Reprocessing may reproject already-normalized source records; it must not erase them or claim it reran deep analyses from unavailable raw evidence.

### New files and format

Cloud `performance/index.json`, optional bounded `performance/marks/<stableId>.json` and optional bounded detail files carry flattened playable coordinates, original evidence IDs, source availability and omissions. Add optional manifest performance metadata without breaking format-1 old clients; bump the internal bundle-output fingerprint when output semantics change. Do not include capture secrets or the original local folder path.

### Checks and exact expected values

- **Executed baseline characterization:** importing the packet's Python edit functions with kept source ranges `[0,10]` and `[20,30]` produced `to_edited(10)=10`, `to_edited(20)=10`, and `to_source(10)=(".",20)`. The source comment says half-open but current point implementation includes both ends. This was checked by this mission; it was not an application test.
- **Proposed interval fixture:** original event `[9,21]` with kept `[0,10)`, `[20,30)` projects to `[9,10)` and `[10,11)`; original duration is 12 s, visible duration 2 s. Both displayed pieces retain the same event ID, different segment occurrences and clipping flags. New performance instant event at source 10 is excluded; source 20 maps to edited 10. A legacy user mark at source 10 remains at edited 10 with its original source offset/policy; a final legacy user mark at source 30 remains at edited 20. This documented compatibility exception does not make the new performance intervals closed.
- **Repeated-source fixture:** if the edit list contains the same source interval twice, a source event appears twice in playback with distinct projection IDs. Original evidence and measured duration remain one fact.
- **Join identity fixture:** source A requestId `17` and source B requestId `17` remain two requests. Clock mappings and process names cannot bridge the join.
- **Cloud byte fixture:** a final encoded index of exactly 256 KiB plus 28 final details of exactly 64 KiB equals 2 MiB and fits. A 29th 64 KiB detail is omitted with an explicit reason. Metadata included in these encoded files counts toward their measured byte sizes; fixture padding may be used to establish exact encoded sizes.
- **MHTML budget characterization fixture:** a 40 MiB video implies 20 MiB page budget under existing `CloudBundle`; no raw trace becomes eligible merely because it fits that budget.
- **Cut privacy fixture:** a secret URL/request appears only in cut source `[10,20)`. It is absent from cloud index/detail/Markdown and any selected raw slice. A mark requiring missing evidence says local-only/unavailable.
- **Freshness fixture:** alter only a performance source/index hash or parser version; expected `inputHash` differs and the UI says the cloud copy is out of date. Rebuild unchanged inputs deterministically and expected hash remains unchanged.
- **Roundtrip fixture:** join → cut → cloud bundle → download → reprocess yields identical visible mark offsets, finding IDs/values and availability flags. Raw availability remains false if not uploaded. Restoring cuts on the downloaded flattened copy cannot resurrect original cut source evidence that was never included.
- **Viewer loading check:** opening the cloud session requests the compact index only when performance is displayed and no raw trace/profile/body files automatically. Selecting mark 3 fetches its detail, not all mark details.

### README update

Update **Edited sessions**, **Joining sessions**, **Cloud**, **Session output** and **Open cloud copy / agent handoff** with original-versus-playback time, derived-only cloud exports, budgets, omissions, raw export action and download/reprocessing behavior. Update `docs/cloud-sessions.md` and `cloud/README.md` to agree with implementation.

### Main risk

Flattened cloud playback can erase source identities or unintentionally include cut-out evidence. End-to-end source/edited/cloud roundtrip fixtures, strict export selection and explicit local-only provenance are required before this milestone ships.

## M6 — Memory trends, explicit diagnostics and optional large-trace analysis

**Shippable outcome:** identify suspicious memory-growth patterns across repeated actions and offer a controlled deeper recording when the lightweight trend warrants it. A rising line is a lead, not a proven leak.

### Files and modules

- Extend `ChromeCaptureCoordinator.swift`, `PerformanceCaptureStore.swift`, optional `ChromeMemoryDiagnostics.swift` and trace/profile export actions.
- Add memory trend normalization and findings to `scripts/process_performance.py`; add a lazily loaded memory lane/details and evidence text in the same Markdown generation paths as M4.
- Extend schemas with metric kind, target/process coverage, garbage-collection visibility, sampling interval and diagnostic settings.
- If actual large/protobuf investigations require it, add an optional pinned Perfetto `trace_processor` executable adapter with versioned queries and golden-trace fixtures. It is a local invoked analysis binary, not a Node/MCP dependency, database server or always-running service. M3 capture/external viewing remains useful without it.

### Behavior and boundaries

- Keep ordinary memory evidence to supported target-scoped counters/heap usage; identify exactly whether a number is JavaScript heap used/total, DOM nodes, documents, frames or a cross-origin-isolated user-agent memory result. None is interchangeable with Chrome's total process resident memory.
- Compare repeated action cycles and post-action settled minima when available. Record GC observations without forcing GC during ordinary recording. Do not call natural sawtooth peaks a leak.
- Provide optional diagnostic allocation sampling or selected heap snapshots only after the user explicitly selects the mode. These can pause/perturb the page and contain application data; keep artifacts local/private and label the run's measurement configuration.
- If a standalone CPU profile is requested, use `Profiler` on the chosen target without simultaneous trace CPU sampling. Preserve source-map completeness, profile start/end and sample interval; sampled percentages are estimates, not exact statement timing.
- Avoid adding a permanent heavyweight runtime. A bundled optional analysis tool earns adoption only if native/Python parsing cannot provide needed attribution and real fixture results justify the footprint.

### New files and format

Metrics/findings extend existing sidecars. Optional `performance/heap/*` sampling profiles/heap snapshots and `performance/cpu/*.cpuprofile` carry explicit format/Chrome-version/configuration entries in the manifest and are omitted from ordinary cloud Push. Use actual producer formats and extensions rather than inventing a `.pftrace` wrapper for JSON. Optional trace-processor results become ordinary versioned findings/index records, retaining the raw protobuf file and its hash as evidence.

### Checks and exact expected values

- **Sawtooth fixture:** post-action used heap samples 30, 45, 31 MiB do not satisfy a monotonic retained-growth rule; show peak 45 MiB and recovery to 31 MiB, with no leak verdict.
- **Growth fixture:** three comparable settled minima at source times 0, 60, 120 s are 32, 40, 48 MiB. Trend slope is 8 MiB/min, retained-growth candidate +16 MiB over two minutes. Without heap-retainer evidence the verdict is “growth candidate,” not “memory leak in component X.”
- **Target reset fixture:** navigation/renderer restart resets the trend segment. A new heap of 5 MiB is not a 43 MiB collection attributed to the old process.
- **Cross-origin memory fixture:** unsupported `measureUserAgentSpecificMemory`/isolation requirements yield unavailable; do not alter the application's headers to force it on.
- **Diagnostic fixture:** enabling heap diagnostics marks the run incomparable to a normal run unless comparison explicitly accounts for changed configuration. Private payload strings from heap artifacts never enter ordinary cloud/Markdown output.
- **Sampler ownership fixture:** CPU profile mode and trace CPU sampling cannot both acquire the same sampler ownership; the UI resolves the mode explicitly and the manifest records the selected mechanism.

### README update

Add **Performance capture → Memory and diagnostic profiles**, metric definitions, capture perturbation, local-only artifact policy, and interpretation of growth candidates versus confirmed retention.

### Main risk

Counter scope, garbage collection and capture-induced retention can create false leak claims. Make the lightweight trend independently useful, and keep heavy diagnostics explicit and exploratory until real repeated-flow traces validate the method.

## M7 — Compare before/after recordings of the same flow

**Shippable outcome:** select two comparable sessions or multiple matched repetitions, align equivalent actions, and compare measured outcomes with configuration differences visible. It supports the user's “record a problem, fix it, record again” workflow.

### Files and modules

- Add a small comparison model/processor under `scripts/` or the existing performance analysis module; add `Library/PerformanceComparison.swift` and a session-selection action.
- Extend manifest/index schema with flow labels, build/revision supplied by the user or app, viewport/device/Chrome metadata, cache/throttle state, capture tier/categories and target completeness.
- Add comparison Markdown export using the same evidence IDs and limitations; keep baseline sessions immutable.

### Matching and reporting

- Match explicit flow/step labels first, then target origin/route, semantic interaction selector and user-confirmed correspondence. Do not use narration similarity alone as an authoritative match.
- Compare original-time metrics within each corresponding interaction/window. Cuts and joins only change presentation and must not shorten either run's latency or network duration.
- Show differences in absolute units and percentages together, with sample count and capture configuration. A single before/after pair is descriptive evidence; it does not prove the code change caused the difference.
- Prefer matched repeated runs with comparable cache state and no competing profiler. Report medians and the individual samples; separate cold/warm and T1/T2/T3 runs. Flag observer/target/trace coverage differences and suppress a numeric comparison when one metric is unavailable.

### New files and format

Write a separate comparison artifact (for example `performance-comparisons/<comparisonId>.json` plus Markdown) that references immutable session/capture IDs and hashes, matched steps, metrics, configuration differences and method version. Do not write comparison-specific changes into raw session traces.

### Checks and exact expected values

- **Paired example:** before interaction durations `[240,250,260] ms`, after `[160,170,180] ms`; medians 250 and 170 ms; absolute change −80 ms; relative change −32%. Label 3 observations each and preserve individual values.
- **Single-pair example:** 400→300 ms gives −100 ms/−25%, reported as this pair's difference without confidence/causal language.
- **Invalid comparison fixture:** before uses cold cache and T1; after uses warm cache with CPU sampling. Output lists both differences and says the runs are not directly comparable; it does not headline a performance win.
- **Missing metric fixture:** before has complete trace, after has no long-task coverage. Result is unavailable for that metric, not 100% improvement.
- **Join fixture:** user selects a joined session with two source runs; comparison uses one explicitly selected source/step pair, not a combined clock or averaged unrelated recordings.

### README update

Add **Compare recordings** under **Sessions window**: matching flows, selecting cold/warm state, repeat counts, before/after limitations and comparison Markdown output.

### Main risk

The tool can easily reward a different cache state, viewport or recording configuration instead of a better implementation. Configuration-aware matching and modest statistical claims are part of the feature, not optional warnings.

## Implementation sequencing and completion criteria

M1 is useful and complete on its own. M2 adds full network evidence after proving the installed Chrome consent route. M3 produces real usable traces before native deep analysis exists. M4 turns those traces into high-value mark handoffs. M5 makes edits/cloud sharing faithful. M6 and M7 add diagnostic depth and feedback after fixes without making initial adoption wait for them.

Each milestone should land with its own documented file schema, parser version, fixture expectations and real capture evidence for the browser behavior it claims. Runtime experiments are proposed until the implementer executes them. No adoption study, outside-customer demand gate, enterprise permission system, cross-browser layer or general APM product is needed.

## Evidence and current-source links

Repository evidence is detailed in the report and the pinned baseline. Decisive local integration points: `Recorder.swift:currentOffset/stream`; `RecorderController.swift:init/start/stop/stopForQuit/addMark`; `BrowserBridge.swift:start/handle`; `Session.swift:addBrowserEvent`; `process_session.py:resolve/to_edited/kept_pieces/map_points/mark_markdown/main`; `SessionData.swift:SessionData/PageEvent`; `EventLog.swift:build`; `SessionTimeline.swift:Lane/pageDots`; `Edits.swift:EditMap/SessionJoin`; `CloudBundle.swift:build/writeLogs/inputHash`; `docs/cloud-sessions.md`.

API references for implementer verification: [Chrome agent connection configuration](https://developer.chrome.com/docs/devtools/agents/get-started/configuration), [Chrome debugging-switch changes](https://developer.chrome.com/blog/remote-debugging-port), [CDP Target](https://chromedevtools.github.io/devtools-protocol/tot/Target/), [CDP Network](https://chromedevtools.github.io/devtools-protocol/tot/Network/), [CDP Tracing](https://chromedevtools.github.io/devtools-protocol/tot/Tracing/), [CDP IO](https://chromedevtools.github.io/devtools-protocol/tot/IO/), [CDP Profiler](https://chromedevtools.github.io/devtools-protocol/tot/Profiler/), [CDP HeapProfiler](https://chromedevtools.github.io/devtools-protocol/tot/HeapProfiler/), [CDP Performance](https://chromedevtools.github.io/devtools-protocol/tot/Performance/), [CDP Runtime](https://chromedevtools.github.io/devtools-protocol/tot/Runtime/), [Performance Timeline](https://www.w3.org/TR/performance-timeline/), [Event Timing](https://www.w3.org/TR/event-timing/). These are live references; the shipped capture records the actual Chrome/protocol version and effective feature set rather than claiming tip-of-tree availability.

## Final implementation status

- Access: exact scoped source packet plus pinned supplemental clock/edit/cloud source available.
- Executed in this mission: static analysis, source payload verification, current primary-source research by the report team, and the small baseline Python edit-function characterization described in M5.
- Proposed: every milestone, capture experiment, UI change, new schema, native connection, trace parser and acceptance check above. No browser capture or app build established performance/compatibility measurements here.
- Open implementation questions: actual installed Chrome build and approval-mode behavior; practical trace category availability/retention/overhead; desired set of captured tabs; body/frame opt-in policy; real trace fixtures for source-map/worker attribution. The chosen plan provides defaults and concrete prototype checks so these do not block M1.
