**Decision.** Build a native Swift Chrome DevTools Protocol (CDP) capture service that connects to the user's already-running Chrome profile through Chrome 144+'s consent-based remote-debugging flow. Keep the existing extension for semantic page context, marks, and lightweight performance observers. Make complete network metadata and sparse performance counters the connected recording default; add an explicitly armed, bounded trace around a reproduction and a separate short browser-wide diagnostic mode. Preserve raw evidence locally, calibrate Chrome and page clocks to the recorder's first video frame, and derive compact, source-linked explanations around marks. Show those explanations in the existing Sessions timeline and Markdown; use DevTools and Perfetto for deep inspection. Do not build a second chrome.debugger transport first: current extension trust restrictions exclude key profiling capabilities and restrict trace scope. Validate native consent and installed-browser capabilities in a small acquisition prototype, then ship the capabilities in independent stages. Record actual coverage and distinguish observed evidence from proposed causes throughout the capture and analysis workflow.

# Full Chrome tracing in Context Recorder

Research date: **October 28, 2026**, America/Indianapolis.  
Application evidence: **byronwall/context-recorder at 1d9f29d4b38c8c964b948b9ba244289947476b9e**.  
Mode: **Design**. Repository integration belongs to Claude.

## Access and evidence status

The attached source packet was readable; all **22 file payloads** matched their declared byte counts and SHA-256 prefixes, totaling **204,612 bytes**. GitHub access at the exact application commit also worked. Five small supplemental sources were retrieved at that same commit to resolve video timing, edit composition, and cloud packaging. This is a complete review of the supplied scope and those additions, **not a full-repository review or a runnable checkout**. No design-deciding source remained inaccessible. Static analysis, source verification, a characterization of existing Python edit functions, and synthetic fixture arithmetic were executed. No Chrome recording, signed macOS build, consent interaction, performance benchmark, heap capture, extension installation, or Context Recorder cloud-bundle upload was executed.

“Fact” means directly supported by the cited source. “Inference” means a conclusion from sources. Capture behavior, limits chosen for this product, UI, algorithms, rates, and milestones below are **proposals unless explicitly described as checked**. Current upstream Chromium source is stronger than an outdated API summary, but is not proof that the same revision is installed on this Mac.

## 1. What the baseline provides—and what the design must preserve

### 1.1 Existing integration points

| Baseline evidence | What is implemented | Consequence for this design |
| --- | --- | --- |
| extension/manifest.json; background.js: connect, send, handle [R02], [R03], [R04] | MAIN-world page script plus isolated relay; localhost WebSocket; 20-second heartbeat; 200-message reconnect queue; no debugger permission or recording lifecycle messages. | Retain the semantic bridge. Give new observer batches recording/document identities and loss reporting. Bulk trace bytes should travel directly to Swift. |
| extension/page.js: record, recordRequest, snapshot [R05] | A 60-entry ring; snapshot returns its last 40; streams clicks, navigation, warnings/errors, and failed or ≥3,000 ms fetch/XHR calls. | Successful fast traffic is missing from the session stream. Add canonical CDP Network records; retain existing event compatibility. |
| BrowserBridge.start / handle [R07] | Whole-message JSON decoding; maximum WebSocket message size **128 MiB**, intended for MHTML; page events dispatch to the main queue. | The limit is a ceiling, not a suitable trace-chunk size. Native capture avoids moving traces through this path. |
| RecorderController.init / addMark / stop [R08] | Page events receive an offset on app arrival. Live Chrome marks request a snapshot and MHTML. Stop clears the active session before asynchronous processing. | Use occurrence timestamps, separate recorder-induced work, and keep a closing capture owner alive until trace drain finishes. |
| Recorder.currentOffset / stream callback [R23] | Offset is host-clock time minus the first complete video frame's presentation timestamp. | This is the master clock. Session.startedAt and the folder name are not video zero. |
| process_session.py: resolve, map_points, kept_pieces, map_marks [R13] | Raw evidence remains unchanged; derived output is projected into edited time; marks preserve source provenance. | Add interval projection and source identity for performance evidence. Never calculate request latency on compressed edited time. |
| SessionData; EventLog.build; SessionTimeline [R14], [R15], [R16] | Optional-compatible decoding, point events, five-second display folding, one shared playhead. | Add lazy performance data and compact interval lanes. Do not turn PageEvent into a raw trace model. |
| CloudBundle.build / writeLogs / inputHash [R24] | Explicit file selection, edited-time flattening, content hashes; an MHTML-specific budget. | Introduce a separate performance export budget and include analysis sidecars in change detection. |

Two details prevent misleading comparisons:

- Existing fetch duration ends when the fetch promise resolves, generally at response headers; XHR duration ends at loadend. They are not interchangeable with a complete CDP response interval. The fetch error preview is truncated to 800 characters **after** clone().text() reads the body. [R05] (`recordRequest` and patched fetch/XHR)
- The historical manual audit reports useful measurements, including a distorted run with two debugger connections and a late-installed long-task observer. Its observations belong to its earlier audit baseline, c6d17cd; they are neither measurements of this proposal nor proof that all old recommendations remain unfixed. Automate its investigative workflow, not its historical implementation assumptions. [R17], [R18], [R19], [R20]

### 1.2 Product boundary

The central workflow is: **record a walkthrough → flag a moment → inspect its browser evidence alongside narration and video → give an agent a specific investigation → repeat the flow after a fix**.

The full raw trace is a supporting artifact. The product's distinct value is the link between a complaint, a visible UI target, the observed browser work, a source location when supported, and the original moment. This does not require a general monitoring service, framework-wide replay, a new database server, or a native copy of every DevTools panel.

## 2. Ranked question 1: capture mechanism

### 2.1 A current capability that changes the answer

**Fact.** Chrome's documented 144+ flow allows a debugging client to request access to an already-running profile after the user enables remote debugging at chrome://inspect/#remote-debugging. Chrome asks permission for a new connection and displays an automation banner. This is distinct from the older launch-switch flow. [S01], [S02]

**Source-supported inference.** A Swift app can use this connection without shipping MCP, Puppeteer, or Node. Current Chrome's approval server writes the browser WebSocket endpoint to the two-line DevToolsActivePort file; the official MCP implementation reads it and connects directly. Approval-mode HTTP discovery deliberately returns 404, so polling /json/version is the wrong discovery implementation for this mode. The signed app's file access and exact consent behavior still require a macOS prototype. [S03], [S04], [S05]

**Fact from upstream code.** Approved remote WebSocket connections use the normal trusted DevTools client. Blink carries that trust into V8. Ordinary unpacked debugger extensions are untrusted; V8 wires Profiler and HeapProfiler only for fully trusted clients. [S04], [S06], [S07], [S08], [S09], [S41]

This is why the decision is native CDP plus the semantic extension, rather than “add debugger permission and capture everything.”

### 2.2 Capture-options comparison

| Option | Data and coverage | Everyday-profile fit, cost, and decision |
| --- | --- | --- |
| **Native Swift, consented existing-profile CDP** | Browser-root Tracing plus selected-target Network, Performance, Profiler, HeapProfiler, Page, Runtime, Log and Audits; explicit frame/worker sessions. Broad Chrome process evidence is possible. | **Build after a bounded prototype.** No changed launch or alternate profile. User enables the feature and approves connection; automation banner remains. Native code owns transport/drain. Cost follows selected instrumentation, not the fact that Swift is the client. [S01], [S02], [S03], [S04], [S05], [S06], [S07], [S08], [S09] |
| **Extension chrome.debugger** | Network/Performance/Page/Runtime/Log/Audits and restricted Tracing. Current ordinary-extension access does not guarantee Profiler or HeapProfiler. Multi-tab sessions and recursive child attachment are needed. | **Defer a second backend.** Works with everyday Chrome, but needs debugger permission and its warning bar. DevTools opening may detach it. Current trace trust/process restrictions prevent claiming browser-wide completeness. [S07], [S08], [S09], [S10], [S11] |
| **Swift CDP through --remote-debugging-port or --remote-debugging-pipe** | Broad CDP capability in a deliberately launched test browser/profile. Port mode can use ordinary HTTP discovery. | **Defer as diagnostic fallback.** Since Chrome 136 these switches are ignored for the default data directory unless a nonstandard user-data directory is supplied. Relaunch/profile changes damage reproduction fidelity for the intended workflow. [S12] |
| **chrome://tracing / official Perfetto Chrome capture** | Broad browser tracing, many internal categories, and cross-tab evidence; mature inspection. The official Perfetto extension has special trust absent from an arbitrary unpacked extension. | **Support manual trace import.** Same-profile manual capture can avoid a relaunch, but adds another start/stop UI and alignment task. Perfetto desktop documentation does not promise long-trace mode; closing its recording UI can lose capture. [S07], [S13] |
| **--trace-startup and related switches** | Chrome startup and early-process work, including events that a late page observer misses. Format and categories are configuration-dependent. | **Defer.** Requires changing launch behavior; useful for startup failures, not ordinary narrated walkthroughs. Specify format explicitly; do not assume a .json filename changes a protobuf trace into JSON. [S14] |
| **PerformanceObserver and in-page APIs** | Resource/navigation timing, input latency entries, long tasks, long animation frames, paint/LCP/layout-shift observations, user timings; optional isolated-page memory estimate. | **Build the recording baseline.** No debugger bar and no launch changes. Small when bounded. Limited by document/worker API exposure, timing permissions, late injection and observer retention; cannot supply arbitrary CPU stacks or browser/GPU work. [S15], [S16], [S17], [S18], [S19], [S20], [S21] |
| **chrome.webRequest** | Request lifecycle and some headers/request-body information across permitted targets; WebSocket handshake only. No response bodies, CPU profile or rendering trace. In-memory cache hits can be invisible. | **Defer.** No debugger infobar, but host permissions and serialization still cost resources. MV3 retains observational webRequest; the main removed capability is ordinary blocking access. It would add another partial network implementation. [S22] |
| **DevTools-panel extension / getHAR** | Network-panel HAR log, completed-request callbacks, separately requested response content. Inspected-window scope; requests before DevTools opens can be missing. | **Import HAR; defer a custom panel.** Does not require launch flags, but requires DevTools open and another extension surface. Supplies no CPU/layout tracing itself. [S23] |

### 2.3 Exact domain policy

| Domain | Role in the chosen native path | Ordinary chrome.debugger comparison |
| --- | --- | --- |
| Network | Default connected request ledger, headers after sanitization, timing, priorities/cache, failures, WebSocket-message metadata. | Available, but only for targets actually instrumented. |
| Performance | One-second metrics samples with per-target scope and resets. | Available; a metrics stream is not a CPU profile. |
| Runtime | Context identities, exception/console records, calibrated page-clock queries, optional heap usage; no automatic object traversal. | Available. getHeapUsage is isolate-wide, not exact per-DOM ownership. |
| Page | Frame tree, lifecycle/navigation identifiers and document installation points. | Available; does not replace all worker attachment. |
| Log | Browser-generated log entries relevant to attached targets. | Available; retain provenance where Runtime overlaps. |
| Audits | Browser issue records when enabled; useful context for CORS or loading problems. | Available; this is not a Lighthouse audit run or performance score. |
| Tracing + IO | One coordinated trace, then bounded stream drain and file close. | Allowed, but untrusted sources/processes are restricted. |
| Profiler | Explicit standalone CPU profile when requested instead of trace CPU sampling. | Current canonical docs omit it; trusted-client source excludes the ordinary extension case. |
| HeapProfiler | Explicit allocation sampling or retention diagnosis, later milestone. | Current trusted-client restriction prevents relying on it. |
| Target + Debugger | Discover/attach frames/workers; optional script metadata, initiator stacks and source maps. Debugger is enabled only where its added attribution is requested. | Target/Debugger are available, but browser-root privileges differ. |

These are command-level policies, not an instruction to enable every domain everywhere. Network's current schema says script initiator stacks require Debugger to be enabled. Do not promise that stack when the lightweight policy omits Debugger. The selected-target metrics and memory fields must be probed rather than assumed from protocol version 1.3 alone. [S24], [S25], [S26], [S27], [S28], [S42]

**Conflicting documentation:** an older indexed variant of the official debugger reference still lists Profiler. The current canonical list and the current V8 trust gate support the restriction above; the installed Chrome build must still be capability-probed. Do not treat a stale domain list or protocol version number as proof that a command is available. [S09], [S08], [S45]

### 2.4 Target ownership and scope

Use **one native browser WebSocket per recording**, with one target registry and an app-level trace-ownership lease spanning active and closing captures. Starting another recording must not start a competing trace while the prior owner is still tracing. After the old `tracingComplete`, a new capture can begin while the old IO stream drains into its original session file.

- Default CDP network scope is the selected app tab, its frame descendants, and explicitly associated workers. Keep the tab across same-target navigation. “Add current tab” expands the recorded set visibly; do not awaken every dormant tab.
- Identify same-process frames through execution contexts and frame IDs. Attach out-of-process iframes and dedicated workers using flattened sessions, installing the appropriate domains on each. Recursively register child targets. Use waitForDebuggerOnStart:false; report the race before installation instead of pausing production behavior.
- Treat service/shared workers separately. A worker can predate the page, serve multiple clients, restart, or outlive it. Use explicit related-target discovery and ownership evidence where supported. If a service-worker response is visible but its internal fetch is not, record that distinction.
- Preserve request keys as recording/capture + CDP session + requestId + redirect hop. Preserve document identity separately from URL, because several tabs and navigations can share it.
- **T2 trace collection is not tab-private.** Current target tracing operates over the connection's root-session process set; previously attached targets can contribute, and trusted capture also includes browser/GPU processes. Shared processes can contain unrelated work. Filter the *analysis* to the selected tab and store the actual process/target scope. Browser-root T3 is explicitly broader. [S10], [S26], [S29]

No “complete worker coverage” badge should be inferred merely because setAutoAttach succeeded.

### 2.5 MV3 lifetime and manual DevTools

Current Chrome documentation states that active debugger sessions keep extension service workers alive from Chrome 118; WebSocket traffic extends lifetime from Chrome 116. The baseline's heartbeat is therefore useful for its small semantic bridge. A worker can still be terminated by reload, crash, browser shutdown, or user action. An offscreen document is not necessary solely to defeat an active-debugger idle timeout. [S11]

The chosen native data path also avoids making raw traces depend on that worker. If the extension restarts, native network/trace capture can continue while semantic evidence shows a gap.

Manual DevTools inspection can coexist with the documented native connection. **Simultaneous Performance trace recording is different:** current Chromium has one CDP tracing owner. A competing trace must yield a visible conflict state; never stop someone else's trace or repeatedly reattach after denial. The repository's historical dual-debugger audit is reason to benchmark observer effects, not evidence that all concurrent inspector use always fails. [S01], [S10], [R17]

## 3. Ranked question 2: what to collect and at what level

### 3.1 Capture tiers and planning rates

The following are **engineering estimates, not measured rates or Chrome guarantees**. They assume one foreground SPA, roughly 50–300 requests and 30–120 meaningful interactions per minute, ordinary DOM size, one main renderer and few workers, no large bodies, and no trace screenshots/source contents. A hot animation loop, hundreds of workers, huge console output or media-message traffic can exceed them.

MB means decimal megabytes; MiB is used for binary buffer limits. Compressed sizes are only planning ranges. Tiers are incremental except where the table states a different trace preset.

| Tier and user control | Exact collection policy | Estimated stored rate, cost, and exclusions |
| --- | --- | --- |
| **T0 — Page context**, active for recordings even without CDP | Existing semantic events/snapshots; observers: navigation, resource, paint, largest-contentful-paint, layout-shift, event with `durationThreshold: 16`, first-input, longtask, long-animation-frame, mark, measure. Feature-detect each; observer callbacks batch bounded records. No CDP. | **0.05–0.5 MB/min JSON**, roughly 0.02–0.2 MB/min gzip. Expected lowest incremental CPU cost; still measure DOM attribution work. Excludes full network headers/bodies, CPU stacks, browser/GPU traces and universal memory measurement. Existing video/MHTML sizes are additional. |
| **T1 — Browser detail**, default once connected for this recording | T0 + Target, Page, Runtime, Log, Audits, Network; Performance.enable(timeTicks) and getMetrics every 1 s on selected targets. Cache/body settings remain unchanged. No Tracing/Profiler/HeapProfiler. | **0.5–5 MB/min JSON**, roughly 0.1–1.5 MB/min gzip, excluding payload opt-ins. Request count/header size drives growth. No JS sample profile, full task tree, screenshots or heap snapshots. |
| **T2 — Arm deep**, then reproduce and mark | T1 + one target-session Tracing capture with preset D below; IO drain; optional Debugger metadata/initiator-stack enrichment. Request 10 s pre-mark and 10 s post-mark when available; fixed 64 MiB ring and hard 60 s capture lifetime. | **10–100 MB/min JSON-equivalent**, roughly 2–25 MB/min gzip. CPU sampling and trace hooks are material overhead. Actual retained history is byte-limited; no guaranteed prehistory and no retroactive detail when unarmed. Excludes high-resolution sampling, source contents, paint pictures, screenshots and heap object capture. |
| **T3 — Broad diagnostic**, explicit short action | T1 + browser-root Tracing with preset B below. Default 30 s, maximum 60 s, 256 MiB configured buffer. Preset B includes standard CPU sampling and memory-infra category hooks. Detailed rendering capture, explicit memory dumps and heap diagnostics require additional selection. | Plan for **10–150 MB/min native .pftrace**, or **50–500 MB/min JSON-equivalent** if JSON export is selected. These are loose sizing hypotheses. Scope and perturbation are largest. Excludes OS-wide macOS scheduler capture, packet payload capture and every disabled-by-default category unless specifically selected. |

A two-minute T1 recording is therefore provisionally on the order of 1–10 MB before compression, plus existing assets. A 20-second T2 capture provisionally adds about 3.3–33.3 MB JSON-equivalent. The fixture plan requires measuring actual distributions before these estimates appear as product promises.

The proposed product budgets are **64/256 MiB trace buffers, 1 GiB of retained deep artifacts per session by default, and separate decoded-parser limits**. The Chrome buffer does not cap JSON expansion, disk output, or a Python object graph. Stop or decline additional deep capture at the artifact budget; keep video and T0/T1 working and explain the omitted detail.

### 3.2 Exact trace category presets

Use Tracing.getCategories first. Persist requested, available, enabled and missing categories with the Chrome revision. Do not substitute an unavailable category silently. If a required category is absent, disable its dependent finding or label the capture reduced-capability. An advertised category alone does not prove that every required event or field was emitted. These are intentionally selected subsets of current DevTools/Chromium categories, not an assertion that every installed version emits every field. [S25], [S30], [S31], [S32]

**Preset D — detailed app interaction:**

```text
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
```

**Preset B — broad browser diagnostic:** D plus these advertised categories:

```text
renderer.scheduler
blink
cppgc
gpu
viz
input
netlog
disabled-by-default-memory-infra
```

Treat blink_gc only as an advertised legacy alternative; current V8 categories use cppgc. Additional **explicit rendering-detail preset**, when useful:

```text
disabled-by-default-devtools.timeline.invalidationTracking
disabled-by-default-devtools.timeline.layers
disabled-by-default-devtools.timeline.picture
disabled-by-default-blink.graphics_context_annotations
disabled-by-default-layout_shift.debug
```

Exclude by default disabled-by-default-v8.cpu_profiler.hires, disabled-by-default-devtools.v8-source-rundown-sources, disabled-by-default-devtools.screenshot and arbitrary wildcard-enabled disabled categories. Metadata-only script rundown is distinct from bundled source content. Debugging a paint issue can justify picture capture; video already provides the normal visual context.

Proposed T2 configuration:

```json
{
  "transferMode": "ReturnAsStream",
  "streamFormat": "json",
  "streamCompression": "gzip",
  "bufferUsageReportingInterval": 1000,
  "traceConfig": {
    "recordMode": "recordContinuously",
    "traceBufferSizeInKb": 65536,
    "includedCategories": ["<the enabled subset of preset D>"],
    "excludedCategories": ["*"]
  }
}
```

The placeholder above is a specification shorthand, not a runnable command. The implementation expands D after capability discovery. T3 defaults to `recordUntilFull`, `traceBufferSizeInKb: 262144`, `streamFormat: "proto"` and `streamCompression: "none"`, with a 30 s timer and early stop if reported buffer pressure reaches the chosen threshold. Its memory-heavy trace need not be JSON-expanded just to preserve it. If a later export compresses protobuf, name and inventory the actual compressed format.

**Temporal policy:** an arm expires 60 s after starting. A mark at elapsed t ends capture at min(t+10,60); the UI reports a shortened tail near expiry. Rapid marks share the same capture and can extend its requested end only up to that fixed 60 s deadline. After tracingComplete, the app may rearm when requested; drain/rearm gaps remain explicit. Starting an unarmed deep capture records subsequent reproduction only.

Current CDP describes a future JSON deprecation without a removal version. Keep the format adapter replaceable; do not assert JSON has already disappeared. ReportEvents is not a guaranteed live feed, and ReturnAsStream becomes available after trace completion. [S10], [S25], [S27]

### 3.3 Observer meaning and limits

Install lightweight observation at document_start, gated to recording policy. Record install time, supportedEntryTypes, document/visibility transitions, dropped/buffer-limited entries, and whether a result includes buffered pre-recording data. Records before video zero can be retained as explicitly labeled context, not presented as recorded video.

- Resource/navigation timing gives useful phases and sizes, but cross-origin exposure depends on timing permission and some fields can remain unavailable. Zero bytes can mean restricted visibility; it is not automatically a cache hit. Service-worker client timing does not reveal all work done inside the worker. [S15]
- Event Timing is configured with `durationThreshold: 16`. Its presentation duration is coarsened; default retained entries use a 104 ms threshold. Group by document/interactionId and label a fragment's result “observed interaction latency,” rather than claiming a complete page INP. [S16]
- Long Tasks and LoAF identify different boundaries. LoAF provides script-entry and forced-style/layout attribution where exposed; it does not produce a full function call graph. The October 2026 editor draft contains new style/layout split fields; probe them individually. [S17], [S18]
- LCP is a load-oriented observation whose lifecycle can finish at input/visibility changes. A later SPA route or reviewer mark does not automatically start a new standard LCP measurement. CLS-style grouping and interaction metrics must retain their observation scope. [S19], [S20]
- measureUserAgentSpecificMemory requires the appropriate secure isolated context and may wait for or induce garbage collection. Keep it in an explicit memory investigation, never a routine per-mark call. Do not change the app's isolation headers just to obtain a number. [S21]

Collect mark/measure names and timing by default, but omit arbitrary detail payloads unless enabled. Reserve a recorder namespace and keep those calibration entries out of application hot-spot rankings. No continuous DOM MutationObserver or framework patch is necessary to deliver these tiers.

### 3.4 Network fidelity and content policy

T1 keeps complete request **metadata for its observed targets**, including successful requests. The canonical ledger must handle redirects, out-of-order extra-info, cache/service-worker responses, failure, unfinished requests, late attachment and priority changes. Do not clear cache, bypass service workers, replay requests or apply throttling during a natural recording.

Use CDP field meanings directly: ResourceTiming.requestTime is seconds; its relative phases are milliseconds. Preserve unavailable phase values as unavailable. Preserve both effective response status and wire status where extra-info exposes a 304 revalidation. Do not equate Content-Length with downloaded bytes. Use loadingFinished.encodedDataLength for completed-request accounting; do not add the same dataReceived totals again. [S24]

**Local personal-tool defaults:**

| Data | Default retention | Explicit diagnostic option |
| --- | --- | --- |
| Request/response headers | Keep a versioned safe-value allowlist: content type/encoding/length, cache control, age, range/content-range, validators and selected server-timing metrics. Sanitize URL-valued headers and free-text descriptions. Preserve omitted-header names/counts where useful. | User-selected additional values for selected origins, with a clear sensitive-artifact flag. |
| Cookie, Set-Cookie, Authorization, Proxy-Authorization, API/session keys and token-like fields | Remove values before network/observer JSONL persistence and before console diagnostics. Case-insensitive handling, including extra-info cookie structures and raw header-text aliases. | Do not offer a blanket credential-dump mode. Debug authentication using presence, scheme and failure evidence first. |
| URLs/query/body equality | Preserve origin/path and approved semantic query values. Strip credentials/fragments and sensitive values. Use a local keyed equality digest where duplicate analysis needs hidden values. Never export the key. | Per-origin approved query/body fields, with an artifact policy record. |
| Request/response bodies | No body persistence. Do not call getRequestPostData/getResponseBody routinely. Avoid automatic fetch clone reading when CDP owns the request. | Selected textual requests only: proposed 256 KiB/resource, 5 MiB/minute, 20 MiB/session retained-content budget. Skip binary/uploads/media/auth endpoints. Redact structured values; label truncation/unavailability. |
| WebSocket messages | Connection/open/close, direction, opcode, timestamp and payload-byte count. Drop payload immediately. CDP's “frame” object actually represents a whole message; do not call its size wire traffic. | Selected socket text previews, proposed 4 KiB/message and 1 MiB/session. Binary contents stay excluded by default. |
| Raw traces, CPU profiles, heap artifacts, MHTML | Local diagnostic artifacts with provenance and sensitivity metadata; default no cloud/agent raw attachment. | Explicit selection of a raw artifact or sanitized excerpt; disclose its true scope and omissions. |

Body limits are retention policies, not guarantees that Chrome or the transport never allocated a larger response. Configure bounded browser resource buffers, skip known oversized resources, handle eviction, and discard oversized responses safely. Do not use interception merely to obtain bodies; it changes the behavior being measured.

**Raw trace exception:** raw means the original bytes returned by Chrome. Arbitrary trace arguments, script URLs, console entries and heap strings can contain sensitive information. A header sanitizer cannot certify those bytes as sanitized. Prefer restricted categories/argument filtering when compatible, keep original raw artifacts local, and create separately identified export projections. The regular Push action must not upload them.

The new policy must also cover existing channels. The README's “input values are never recorded” statement is not enforced everywhere: page.js:describe uses target.innerText || target.value and is used for focused/input elements. Fix that extraction path as part of observer work; sanitize props, selected text, console previews and URLs without pretending all MHTML becomes secret-free. [R01], [R05]

### 3.5 CPU and memory diagnostic additions

Use trace CPU sampling for normal T2. Offer a standalone .cpuprofile only for an explicit selected-target run: Profiler.enable, setSamplingInterval(1000), start, stop; preserve nodes, sample IDs and timeDeltas. Do not run two independent CPU samplers by default.

For memory, begin with sparse counters and lifecycle-aware trends. An explicit allocation investigation can use HeapProfiler.startSampling with a documented interval such as 32,768 bytes, then stopSampling; label it sampled allocation/retention evidence. Heap snapshots require a separate action and stream addHeapSnapshotChunk to disk. Keep exact object-retainer analysis in DevTools initially. Tracing.requestMemoryDump can add a light dump to a deliberate memory trace when supported; it is not a heap object snapshot. No forced garbage collection during an ordinary walkthrough. [S25], [S28]

## 4. Ranked question 3: storage, time alignment, cuts, joins and cloud

### 4.1 Proposed session files

Keep recording.mp4, browser.jsonl, marks.jsonl and the current outputs. Add a versioned performance directory:

| File | Format and role |
| --- | --- |
| performance/manifest.json | Schema/capture IDs, selected tiers, Chrome/extension/parser versions, requested/observed scope, artifact hashes/sizes, policies and completion/loss state. |
| performance/clock.jsonl | First-frame host anchor, calibration exchanges/models, page origins and epoch transitions, uncertainty. |
| performance/targets.jsonl | Target/frame/context/document/worker identities, attachment/lifecycle events and relationships. |
| performance/network.jsonl | Sanitized original-time request lifecycle/normalized ledger records; redirects and partial requests retained. |
| performance/observations.jsonl | Bounded page PerformanceEntry records and semantic associations. |
| performance/metrics.jsonl | Sparse target/isolate-scoped counters, units, resets and missing reasons. |
| performance/coverage.jsonl | Attachment, observer installation, trace gaps, transport loss, discarded payloads and recorder-owned activity. |
| performance/trace/0001.trace.json.gz | Initial T2 raw compatibility artifact, immutable once complete. |
| performance/trace/0002.pftrace | Broad native protobuf artifact, or format fallback; preserve exactly the returned format. |
| performance/cpu/*.cpuprofile; performance/heap/* | Explicit standalone profiles, sampled heap profiles or snapshots only. |
| performance/index.json | Compact overview, coverage, artifact references, navigation/mark links and precomputed buckets. |
| performance/findings.jsonl; performance/marks/*.json | Deterministic findings, their supporting evidence IDs and bounded per-mark details. |
| performance/exports/network.har | On-demand derived HAR, not the canonical storage format. Include an omission/capability record and schema extensions where needed. |

Use stable source-session and evidence IDs; the mark's displayed sequential number is not its long-lived identifier. Each projected occurrence records its source, capture and edit-segment occurrence. Evidence lookups must not depend on EventLog's display-folded summary.

Example proposed derived interval:

```json
{
  "schemaVersion": 1,
  "eventId": "A:c1:cdp-s4:r17:hop0",
  "sourceSessionId": "A",
  "captureId": "c1",
  "clockId": "chrome-monotonic-1",
  "sourceStartUs": 9000000,
  "sourceEndUs": 21000000,
  "originalDurationUs": 12000000,
  "kind": "request",
  "availability": "complete-observed-request",
  "projections": [
    {"segmentOccurrence": 0, "editedStartUs": 9000000, "editedEndUs": 10000000, "clippedRight": true},
    {"segmentOccurrence": 1, "editedStartUs": 10000000, "editedEndUs": 11000000, "clippedLeft": true}
  ]
}
```

Store integer microseconds for derived local intervals and retain original clock values/units. For protobuf nanoseconds and long-running clocks, preserve lossless integer representations across JavaScript boundaries. “Complete observed request” does not assert that all browser work was captured.

### 4.2 Acquisition and durability

Network/observer append streams use bounded queues and off-main writers. Native traces never traverse the 128 MiB semantic bridge.

For each trace: start → record → end → wait for tracingComplete → read IO stream in proposed 256 KiB chunks until eof → close stream → finalize artifact hash/metadata. Keep its original session/capture owner through this sequence. A trace's dataLossOccurred flag, transport completion and parser completion are separate fields. A successfully downloaded file can still contain a wrapped, incomplete trace. A completely drained protobuf artifact can be finalized and opened externally while native analysis remains unavailable.

Write temporary artifacts with a partial suffix and rename only after verified drain completion. On crash/timeout, preserve partial state and identify what remains usable; do not forge a valid complete trace. A proposed 12 s post-video drain deadline lets normal processing continue with an explicit incomplete-performance state, with later successful analysis triggering a revision. This deadline must be measured and adjusted; it is not an API limit.

The raw trace and index parser belong off the SwiftUI main actor. JSON analysis needs an incremental event reader and resource limits, not unbounded json.load of expanded traces. A later optional pinned Perfetto trace_processor binary earns its place for protobuf/large-trace SQL and complex nesting. It is an optional local analysis executable, not a new always-running runtime or service. Before that adapter ships, .pftrace capture/viewing is useful, but protobuf-derived native findings remain unavailable. [S25], [S27], [S33], [S34]

### 4.3 Clock model

**Master:** the recorder's host clock, with zero at its first complete video frame PTS. Expose that anchor from Recorder, preserving CMTime's value/timescale. Current page events use arrival-time offsets and must gain a new occurrence-time path; historical sessions keep their old timing precision. [R08], [R09], [R23]

Maintain mappings for:

1. Chrome/CDP monotonic time, typically seconds for Network.
2. Trace timestamps, microseconds for legacy JSON; actual trace clock plus clock snapshots for protobuf.
3. Each document's PerformanceEntry time in milliseconds relative to its own time origin.
4. Swift host-clock time and video offset.
5. Edited playback time, derived only after source alignment.

Do not assume these epochs match because all increase monotonically. Date.now, wallTime and the session folder timestamp are useful for human labels and coarse import alignment, not the precision mapping. W3C explicitly distinguishes monotonic time from adjustable wall-clock time; Perfetto represents multiple clock domains explicitly. [S35], [S36]

**Proposed calibration:**

- On an attached renderer session at connection/start, enable `Performance` with `timeDomain: "timeTicks"`, then bracket `Performance.getMetrics` and read its `Timestamp` metric. Record native send h0, native receive h1 and that browser reading c. Current Blink implements this metric and Network event timestamps with `base::TimeTicks` seconds since the same origin; this is checked implementation evidence, not a permanent cross-version protocol guarantee. Validate each target/epoch. Use the lowest-round-trip valid sample for an initial offset; retain the others as evidence. [S42], [S43], [S44]
- Fit hostSeconds = a × chromeSeconds + b. Initially use a=1; accept a drift fit only when multiple anchors support it. Record residuals, round-trip bounds and epoch changes rather than rounding uncertainty away.
- In each relevant document, bracket a Runtime evaluation that returns performance.timeOrigin and performance.now while emitting a unique recorder user-timing marker at the captured page timestamp. Match that marker in the final trace. Tracing.recordClockSyncMarker is an additional cross-check when its emitted representation is supported, not an assumption that all clocks are already identical.
- Repeat a small calibration batch periodically and at navigation/target replacement/resume. If timing discontinuity or large residual appears, start a new mapping epoch and mark the uncertain interval.
- Map occurrence time before appending normalized offsets; retain arrival time separately for transport diagnostics.

**Synthetic example:** h0=5000.000 s, h1=5000.004 s, c=1000.010 s gives b=3999.992 s when a=1. With video host zero 4990.000 s, a trace event corresponding to c=1005.010 s maps to video 15.002 s. Half round-trip is 2 ms before additional clock-resolution/processing uncertainty. This arithmetic was checked; those values are not an achieved latency claim.

Do not imply the video proves sub-frame presentation. Baseline capture is 15 fps, and timeline hover previews use half-second cache keys with ±0.25 s tolerance. Trace measurements can be more precise than the displayed picture. Store and show both measurement uncertainty and visual corroboration limits. [R16] (`FramePreviews`), [R23]

### 4.4 Cuts and joins

For each kept segment j, with source interval [a_j,b_j) and edited start E_j, map a source point t to E_j+t−a_j only in that segment. An interval [u,v) becomes each positive intersection:

```text
left  = max(u, a_j)
right = min(v, b_j)
display = [E_j + left - a_j, E_j + right - a_j)
```

Preserve **original duration**, **visible duration**, clipping flags and segment occurrence. A source request [9,21) across kept segments [0,10),[20,30) retains 12 s actual duration and has display fragments [9,10),[10,11): 2 s visible. Never join those fragments into a newly measured 2 s request.

**Executed baseline characterization:** existing Python to_edited includes both endpoints despite a half-open comment. Source 10 and source 20 both map to edited 10 in that fixture, while to_source(10) returns source 20. Existing Swift uses the same inclusive toEdited behavior. New performance interval membership should be half-open, with coordinated Swift/Python boundary fixtures and an explicit final-point convention for user marks; do not silently rewrite historical mark semantics. [R13] (`to_edited`, `kept_pieces`), [R25] (`EditMap`)

Repeated source segments create multiple display occurrences. Joined recordings namespace every clock, request and process by source/capture. No causal edge crosses a source-session boundary just because PIDs or request IDs match.

Derived findings are computed against original evidence, then projected. If a cut hides a required cause, show “supporting interval cut from playback” locally. The cloud projection omits cut evidence and records the missing context. Final AV composition placement must be checked against the edit map: baseline saves millisecond edits and composes with timescale 600 and track intersections, so arithmetic metadata alone is not a proof of exact output-frame placement. [R25]

### 4.5 Cloud bundle

**Fact:** the existing `max(10 MiB, videoBytes / 2)` budget applies to MHTML pages, not the whole bundle or logs. CloudBundle already rewrites logs into edited time; the “known gap” note in cloud/README is stale relative to this baseline implementation. [R21], [R24], [R26]

Proposed defaults:

- Add a **separate 2 MiB performance-package budget**. Keep the overview index ≤256 KiB and each mark-detail payload ≤64 KiB.
- session.json carries only the performance schema, compact availability/summary and index reference. The cloud viewer fetches the overview lazily and individual evidence details on selection.
- Spend budget on coverage plus concise findings first, then selected-mark evidence, then optional bucket detail. If something does not fit, record original/exported counts and omission reasons; do not silently imply complete analysis.
- Raw traces, HAR bodies, CPU profiles, heap artifacts, WebSocket contents and source maps remain absent from ordinary Push. Offer an explicit selected-artifact/slice export later, with a separately displayed byte size and sensitivity flag.
- Flatten playable timestamps to the exported video. Retain source evidence IDs and source offsets as provenance, without dangling sibling-directory links or exposing hidden cut intervals.
- Include performance artifact hashes, analysis version and export-policy version in CloudBundle.inputHash. A newly computed finding must make the cloud copy out of date.
- A downloaded summary-only session must preserve its derived findings when reprocessed without raw traces. Availability should say derived-only, not erase the findings or report zero events.

A 40 MiB video keeps its existing 20 MiB MHTML page budget. The proposed 2 MiB performance package is independent. A 100 MiB raw trace is excluded by default, not quietly squeezed into the MHTML allowance.

## 5. Ranked question 4: analyses worth building

The companion **chrome-tracing-scenarios.md** fully specifies eight scenarios, each with exact data requirements, a method, UI placement, agent Markdown, and a worked synthetic excerpt.

| Rank | Capability | Why it is worth building |
| --- | --- | --- |
| 1 | Explain input-to-next-paint and separate result completion | Directly addresses a narrated complaint without confusing feedback latency with an asynchronous result. |
| 2 | Per-mark network waterfall and evidenced dependencies | Automates the manual audit's most useful work; includes success, cache, priorities, ranges and unfinished requests. |
| 3 | Long tasks/LoAF with exclusive attribution | Identifies where main-thread work sits without double-counting nested slices or inventing missing functions. |
| 4 | Compact per-mark agent evidence package | Turns captured detail into a small, actionable handoff with evidence IDs and a validation step. |
| 5 | Duplicate/chatty request candidates | Finds unnecessary parallel loads or polling while excluding distinct ranges, revalidation and unsupported POST equivalence. |
| 6 | Layout shifts and repeated rendering work | Grounds “the page jumped” in visible displacement and browser work; avoids unsupported framework-rerender counts. |
| 7 | Paired before/after flow comparison | Makes the tool useful after the first diagnosis; retains comparable capture/cache/data conditions. |
| 8 | Repeated-flow memory growth | Flags retention candidates and provides a route to deliberate heap analysis without labeling every rising counter a leak. |

The first useful native explanation does not require a perfect causal graph. It should separate **observed facts**, **associations**, **hypotheses**, and **next checks**. A request finishing last is not necessarily a prerequisite; a shifted element can be a victim; a sampled hot frame is not an exact execution-duration count.

**Worked design outcomes:** the scenario fixtures distinguish 240 ms initial feedback from 800 ms result readiness; 700 ms network-active union from 800 ms summed request durations; and a 120 ms task from 250 ms of incorrectly summed parent/child slices. They also retain unknown attribution, partial worker coverage and absent GC evidence. Syntax/arithmetic checks were executed; implementation and live-browser correctness were not.

## 6. Ranked question 5: native viewing and established trace tools

**Build both, with distinct responsibilities.**

### Native Sessions window

Keep one playback clock and the existing marks/transcript/events workflow. Add:

- A compact **Responsiveness** lane for interactions and long-task/LoAF intervals, with visible trace/observer gaps.
- A **Network** overview with in-flight activity; selecting a mark expands a local waterfall.
- A sparse **Memory** lane only when data exists and the user enables it.
- A mark **Performance evidence** section: up to three ranked findings, source links, relevant interval, coverage, clock uncertainty and Copy as Markdown.
- Events filters for performance findings and capture coverage. Preserve raw request identity even when display rows fold.
- Canvas badges that resolve through the canvas item's existing source-time mapping. Do not assign one timestamp to an entire stitched column.

The index reader must be lazy and range-oriented. Thousands of raw trace events should not become individual SwiftUI views. Existing SessionTimeline.Canvas rendering and one playhead are appropriate foundations. [R14], [R15], [R16]

### DevTools and Perfetto

- Offer **Reveal trace / Open instructions for DevTools** for JSON trace files and standalone profiles. DevTools already handles flame charts, source maps and heap inspection. A raw CDP trace may not contain all metadata included in a DevTools-authored recording, so validate import rather than promising identical Insights. [S37], [S38]
- Offer **Open in Perfetto** for broad traces and protobuf. Start with explicit file selection/opening. A later local HTTP handoff can send bytes through Perfetto's postMessage interface and focus the calibrated range. Never upload to a public bucket to make a link work.
- Perfetto's documented deep-link coordinates use its normalized trace timestamps in nanoseconds; convert through the artifact's time mapping, not by multiplying edited video seconds. Local file:// cannot use the same postMessage workflow. The API's client-side trace handling does not mean arbitrary “Share trace” services have the same policy. [S33], [S39], [S40]
- Avoid a bidirectional embedded Perfetto integration in the first release. A native summary plus reliable export is independently valuable. Consider embedding only if switching tools repeatedly interrupts review.

Keep raw exports in original trace time. Supply a tiny context note with mark/source time, calibrated raw trace interval and evidence IDs. Rewriting all trace timestamps into an edited movie can break async relations, metadata and external-tool assumptions.

## 7. Ranked question 6: build sequence and decision gates

The companion **chrome-tracing-implementation-plan.md** supplies file-level changes, schemas, exact fixture expectations, README changes, and risk for each milestone. The intended order is:

1. **M1: recording-aware lightweight observers and a clock/provenance contract.** Ship useful latency/LoAF/resource evidence with current video and page context.
2. **M2: prototype and ship native consented CDP network/metrics.** Verify the installed Chrome/macOS path, then deliver a complete observed-target network ledger and waterfall.
3. **M3: bounded deep trace acquisition and external viewing.** Ship arm/stop/drain/coverage and raw artifacts without waiting for every analysis.
4. **M4: precise native findings and agent handoff.** Ship the highest-value scenarios over a supported trace/observer subset.
5. **M5: cuts/joins/cloud performance projection.** Extend source identity, package budgets, lazy viewing and downloaded-summary preservation.
6. **M6: explicit broad/memory diagnostics and optional large-trace analysis.** Retain mature external tools for heavy object/trace exploration.
7. **M7: paired before/after comparison.** Ship evidence of a fix under declared comparable conditions.

The implementation plan may place foundational edit projection earlier where a milestone exposes intervals; no shipped milestone may knowingly place performance facts at the wrong edited time.

The acquisition prototype is a technical uncertainty gate, **not a demand gate**. If native consent fails on the actual Mac, retain M1, expose the precise failure, and validate manual trace/HAR import as a usable next slice. Evaluate a limited debugger extension only if it resolves that concrete blocker; do not silently relabel it full capture.

### Measurement plan, still proposed

Use the user's real SPA and a deterministic local fixture page. Record the uninstrumented recorder, T0, T1, T2, and each optional diagnostic under comparable cache/viewport/data states. Alternate order and repeat; report all runs.

Measure wall time for fixed interactions, recorder video-frame gaps, process CPU, peak memory, capture/data-loss gaps, raw/compressed bytes per minute and stop-drain latency. Provisional acceptance targets are ≤5% median step-time inflation for T1 and ≤15% for ordinary T2 across repeated runs, with no material new recorder frame loss. These are product goals, not existing results; a result outside them should reduce category/attribution cost rather than be hidden.

Check DevTools-open coexistence separately from simultaneous Performance recording. Repeat across OOPIF navigation, worker restart, app/extension disconnect, browser restart and a mark near trace expiry. Normal cache remains normal; forced cold-cache runs are separate experiments.

## 8. Open questions and the evidence needed to settle them

- **Installed Chrome/macOS consent behavior:** record the actual browser version/revision, signed-app file access and denied/approved handshake. Upstream HEAD is not a compatibility promise.
- **Actual trace costs and 10-second retention:** measure this SPA's enabled-category volume and ring loss. Keep estimated rates out of marketing/UI guarantees until then.
- **Observed process and worker coverage:** prove the specific selected-tab/OOPIF/worker fixture, including a pre-existing shared/service worker. Process filtering is not tab privacy.
- **Clock error under load and resume:** measure calibration residuals and first-frame/video correspondence. Show uncertainty when an exact association cannot be justified.
- **Useful source attribution in the user's builds:** generated URLs may be the only available location; verify source-map/build matching and selected content retention.
- **How often broad/heap diagnostics are needed:** counters and ordinary T2 can ship first. Add the optional Perfetto processor or richer memory UI when concrete investigations need them.

None requires pausing this research deliverable or inventing results. They are the first implementation measurements.

## 9. Evidence ledger and files read

### Application source inventory

All application URLs below are fixed at the requested commit. All 22 packet files were read across the research work. The five supplemental files were fetched at the same ref; four implementation files were read in full, and the cloud-format document's relevant format/API/upload sections were read. Proposed integration targets absent from this set are named as implementation locations, not asserted to have been fully reviewed.

| Ref | Path and principal symbols/sections |
| --- | --- |
| [R01] | README.md — Chrome extension, Session output, Edited sessions, Cloud, Layout |
| [R02] | extension/manifest.json |
| [R03] | extension/background.js — connect, send, handle, capturePage, injectInto |
| [R04] | extension/relay.js — page/extension relay and response timeout |
| [R05] | extension/page.js — record, describe, recordRequest, snapshot, sourceFor |
| [R06] | extension/popup.js — refresh, showTab, renderTabState |
| [R07] | Sources/ContextRecorder/BrowserBridge.swift — start, request, handle |
| [R08] | Sources/ContextRecorder/RecorderController.swift — init, start, stop, addMark |
| [R09] | Sources/ContextRecorder/Session.swift — startedAt, addBrowserEvent |
| [R10] | Sources/ContextRecorder/ContextProbe.swift — capture, chromeActiveTab |
| [R11] | Sources/ContextRecorder/ChromeExtension.swift — install, isOlder, openExtensionsPage |
| [R12] | Sources/ContextRecorder/ActivityLog.swift — start, sample |
| [R13] | scripts/process_session.py — resolve, to_edited, kept_pieces, map_points, main |
| [R14] | Sources/ContextRecorder/Library/SessionData.swift — SessionData, SessionMark, PageEvent |
| [R15] | Sources/ContextRecorder/Library/EventLog.swift — build, foldWindow |
| [R16] | Sources/ContextRecorder/Library/SessionTimeline.swift — lanes, pageDots, FramePreviews |
| [R17] | docs/research/session-performance/audit.md — historical results and limits |
| [R18] | scripts/summarize-session-har.py — summarize |
| [R19] | scripts/audit-session.js — installed observers/media snapshots |
| [R20] | scripts/audit-session.md — manual capture procedure |
| [R21] | cloud/README.md — viewer/Markdown/MCP layout, stale log-rewrite note |
| [R22] | docs/research/chrome-tracing/pro-prompt.md — packet's mission copy |
| [R23] | Supplemental Sources/ContextRecorder/Recorder.swift — first-frame PTS, currentOffset |
| [R24] | Supplemental Sources/ContextRecorder/Cloud/CloudBundle.swift — build, writeLogs, inputHash |
| [R25] | Supplemental Sources/ContextRecorder/Library/Edits.swift — EditMap, composition, SessionJoin |
| [R26] | Supplemental docs/cloud-sessions.md — bundle/edit/file/upload contracts |
| [R27] | Supplemental cloud/src/manifest.ts — parseManifest |

### Current primary research

The most decisive implementation sources were pinned to **Chromium bd5fd3a6666e35fc8a3012dea3bdcbbb126dc45d**, **V8 f8802c4babe09a209e10e17beff30628d5bc76d6**, **Chrome DevTools MCP 63170b11a2fa74d5ceea757194d7b25f3e145f68**, **CDP ebca9061ecc4c77b7d6b5b8f7b8afe19dc3ab9ed**, and **DevTools frontend 1212f1bf37d47640deaef2911db0be022637c89d**. These are upstream source snapshots, not an observed installed browser build. The Chromium UTC date rolls into October 29 while remaining October 28 in Indianapolis.

| Ref | Source and decisive use |
| --- | --- |
| [S01], [S02] | Chrome 144 consent announcement/current setup — existing-profile connection and user-visible consent/banner |
| [S03]–[S09] | Chromium/MCP/V8 source — endpoint discovery, approval, trust and domain restrictions |
| [S10], [S29] | Chromium tracing implementation/process monitor — restricted sources, session scope, single ownership and stop/drain |
| [S11], [S12] | Chrome extension lifecycle and Chrome 136 launch changes |
| [S13], [S14] | Perfetto desktop Chrome workflow and current startup-switch source |
| [S15]–[S21] | W3C/Chrome observer, web-vital and memory definitions |
| [S22], [S23] | Official webRequest and DevTools HAR APIs |
| [S24]–[S28] | Current CDP schemas — network, tracing, target, IO, JS profiling |
| [S30]–[S32] | DevTools/Chromium/V8 category definitions |
| [S33], [S34] | Perfetto formats and local trace analysis |
| [S35], [S36] | High Resolution Time and Perfetto clock synchronization |
| [S37]–[S40] | DevTools/Perfetto viewing, export and local handoff |
| [S41] | Chromium remote-client default trust implementation |
| [S42]–[S44] | Performance protocol and Blink implementations — explicit metrics/Network clock probe |
| [S45] | Older indexed official debugger reference — conflicting Profiler listing |

[R01]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/README.md
[R02]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/extension/manifest.json
[R03]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/extension/background.js
[R04]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/extension/relay.js
[R05]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/extension/page.js
[R06]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/extension/popup.js
[R07]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/BrowserBridge.swift
[R08]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/RecorderController.swift
[R09]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Session.swift
[R10]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/ContextProbe.swift
[R11]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/ChromeExtension.swift
[R12]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/ActivityLog.swift
[R13]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/scripts/process_session.py
[R14]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Library/SessionData.swift
[R15]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Library/EventLog.swift
[R16]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Library/SessionTimeline.swift
[R17]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/docs/research/session-performance/audit.md
[R18]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/scripts/summarize-session-har.py
[R19]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/scripts/audit-session.js
[R20]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/scripts/audit-session.md
[R21]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/cloud/README.md
[R22]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/docs/research/chrome-tracing/pro-prompt.md
[R23]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Recorder.swift
[R24]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Cloud/CloudBundle.swift
[R25]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Library/Edits.swift
[R26]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/docs/cloud-sessions.md
[R27]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/cloud/src/manifest.ts

[S01]: https://developer.chrome.com/blog/chrome-devtools-mcp-debug-your-browser-session
[S02]: https://developer.chrome.com/docs/devtools/agents/get-started/configuration
[S03]: https://github.com/chromium/chromium/blob/bd5fd3a6666e35fc8a3012dea3bdcbbb126dc45d/chrome/browser/devtools/remote_debugging_server.cc
[S04]: https://github.com/chromium/chromium/blob/bd5fd3a6666e35fc8a3012dea3bdcbbb126dc45d/content/browser/devtools/devtools_http_handler.cc
[S05]: https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/63170b11a2fa74d5ceea757194d7b25f3e145f68/src/BrowserManager.ts
[S06]: https://github.com/chromium/chromium/blob/bd5fd3a6666e35fc8a3012dea3bdcbbb126dc45d/third_party/blink/renderer/core/inspector/devtools_session.cc
[S07]: https://github.com/chromium/chromium/blob/bd5fd3a6666e35fc8a3012dea3bdcbbb126dc45d/chrome/browser/extensions/api/debugger/debugger_api.cc
[S08]: https://github.com/v8/v8/blob/f8802c4babe09a209e10e17beff30628d5bc76d6/src/inspector/v8-inspector-session-impl.cc
[S09]: https://developer.chrome.com/docs/extensions/reference/api/debugger
[S10]: https://github.com/chromium/chromium/blob/bd5fd3a6666e35fc8a3012dea3bdcbbb126dc45d/content/browser/devtools/protocol/tracing_handler.cc
[S11]: https://developer.chrome.com/docs/extensions/develop/concepts/service-workers/lifecycle
[S12]: https://developer.chrome.com/blog/remote-debugging-port
[S13]: https://perfetto.dev/docs/getting-started/chrome-tracing
[S14]: https://github.com/chromium/chromium/blob/bd5fd3a6666e35fc8a3012dea3bdcbbb126dc45d/components/tracing/common/tracing_switches.cc
[S15]: https://www.w3.org/TR/resource-timing/
[S16]: https://w3c.github.io/event-timing/
[S17]: https://w3c.github.io/longtasks/
[S18]: https://w3c.github.io/long-animation-frames/
[S19]: https://web.dev/articles/lcp
[S20]: https://web.dev/articles/cls
[S21]: https://web.dev/articles/monitor-total-page-memory-usage
[S22]: https://developer.chrome.com/docs/extensions/reference/api/webRequest
[S23]: https://developer.chrome.com/docs/extensions/reference/api/devtools/network
[S24]: https://github.com/ChromeDevTools/devtools-protocol/blob/ebca9061ecc4c77b7d6b5b8f7b8afe19dc3ab9ed/pdl/domains/Network.pdl
[S25]: https://github.com/ChromeDevTools/devtools-protocol/blob/ebca9061ecc4c77b7d6b5b8f7b8afe19dc3ab9ed/pdl/domains/Tracing.pdl
[S26]: https://github.com/ChromeDevTools/devtools-protocol/blob/ebca9061ecc4c77b7d6b5b8f7b8afe19dc3ab9ed/pdl/domains/Target.pdl
[S27]: https://github.com/ChromeDevTools/devtools-protocol/blob/ebca9061ecc4c77b7d6b5b8f7b8afe19dc3ab9ed/pdl/domains/IO.pdl
[S28]: https://github.com/ChromeDevTools/devtools-protocol/blob/ebca9061ecc4c77b7d6b5b8f7b8afe19dc3ab9ed/pdl/js_protocol.pdl
[S29]: https://github.com/chromium/chromium/blob/bd5fd3a6666e35fc8a3012dea3bdcbbb126dc45d/content/browser/devtools/tracing_process_set_monitor.cc
[S30]: https://github.com/ChromeDevTools/devtools-frontend/blob/1212f1bf37d47640deaef2911db0be022637c89d/front_end/models/trace/types/TraceEvents.ts
[S31]: https://github.com/chromium/chromium/blob/bd5fd3a6666e35fc8a3012dea3bdcbbb126dc45d/base/trace_event/builtin_categories.h
[S32]: https://github.com/v8/v8/blob/f8802c4babe09a209e10e17beff30628d5bc76d6/src/tracing/trace-categories.h
[S33]: https://perfetto.dev/docs/getting-started/other-formats
[S34]: https://perfetto.dev/docs/getting-started/command-line-analysis
[S35]: https://www.w3.org/TR/hr-time-3/
[S36]: https://perfetto.dev/docs/concepts/clock-sync
[S37]: https://developer.chrome.com/docs/devtools/performance/save-trace
[S38]: https://developer.chrome.com/docs/devtools/performance/reference/
[S39]: https://perfetto.dev/docs/visualization/deep-linking-to-perfetto-ui
[S40]: https://perfetto.dev/docs/visualization/embedding-api-reference
[S41]: https://github.com/chromium/chromium/blob/bd5fd3a6666e35fc8a3012dea3bdcbbb126dc45d/content/public/browser/devtools_agent_host_client.cc

[S42]: https://github.com/ChromeDevTools/devtools-protocol/blob/ebca9061ecc4c77b7d6b5b8f7b8afe19dc3ab9ed/pdl/domains/Performance.pdl
[S43]: https://github.com/chromium/chromium/blob/bd5fd3a6666e35fc8a3012dea3bdcbbb126dc45d/third_party/blink/renderer/core/inspector/inspector_performance_agent.cc
[S44]: https://github.com/chromium/chromium/blob/bd5fd3a6666e35fc8a3012dea3bdcbbb126dc45d/third_party/blink/renderer/core/inspector/inspector_network_agent.cc
[S45]: https://developer.chrome.com/docs/extensions/reference/api/debugger?authuser=303

## 10. Stable recommendations and dispositions

| ID | Disposition | Recommendation and one-line reason |
| --- | --- | --- |
| **CT-01** | **Build** | Make native consented CDP the full-capture transport; it preserves the ordinary profile and reaches the required trusted capabilities. |
| **CT-02** | **Explore** | Prototype signed-app endpoint discovery, consent and installed-build capabilities first; these are source-supported but unexecuted integration risks. |
| **CT-03** | **Build** | Keep semantic extension context and add bounded recording-aware observers; useful evidence remains available without deep capture. |
| **CT-04** | **Defer** | Do not ship chrome.debugger as a second capture backend unless native acquisition has a concrete blocker; its restricted scope adds lifecycle cost. |
| **CT-05** | **Build** | Capture full observed-target network metadata and sparse metrics by default when connected; this replaces the manual HAR workflow's largest recurring effort. |
| **CT-06** | **Build** | Use one target registry and one trace owner with explicit frame/worker/process coverage; session attachment never proves universal capture. |
| **CT-07** | **Build** | Offer an armed bounded deep trace with actual pre/post coverage; detail cannot be reconstructed after an unrecorded slow moment. |
| **CT-08** | **Build** | Add an explicit short browser-wide diagnostic preset; browser/GPU/network-service context can explain issues outside renderer JS. |
| **CT-09** | **Avoid** | Avoid wildcard all-category, high-resolution, screenshot, body and heap capture as the routine default; costs and scope exceed the ordinary review need. |
| **CT-10** | **Build** | Calibrate occurrence time to first-video-frame host time and retain uncertainty; receipt timestamps and wall-clock subtraction misplace evidence. |
| **CT-11** | **Build** | Keep immutable original artifacts plus source-preserving interval projections; cuts/joins must not falsify latency or create causal edges. |
| **CT-12** | **Build** | Put raw data in sidecars with bounded drain and explicit loss/completion state; session.json and the 128 MiB bridge are unsuitable bulk containers. |
| **CT-13** | **Build** | Produce deterministic mark-centered observations, associations and next checks; this makes coding-agent handoff useful without inventing diagnosis. |
| **CT-14** | **Build** | Render compact native lanes/waterfalls and export to DevTools/Perfetto; synchronized review and mature deep inspection complement each other. |
| **CT-15** | **Build** | Redact operational metadata before persistence and keep raw diagnostic artifacts local by default; local capture and agent/cloud export need distinct policies. |
| **CT-16** | **Build** | Add a separate compact cloud performance budget, hash invalidation and derived-only roundtrip support; existing limits cover MHTML rather than traces. |
| **CT-17** | **Explore** | Add a pinned local Perfetto trace_processor adapter for large/protobuf analysis when the supported JSON/observer index is insufficient. |
| **CT-18** | **Build** | Ship duplicate-request and layout-work findings with exact identities and uncertainty; repeated URLs/layouts alone do not establish redundant loads or rerenders. |
| **CT-19** | **Build** | Provide paired flow comparisons with capture/cache/coverage metadata; a fix should be assessable in the same narrated workflow. |
| **CT-20** | **Explore** | Add explicit allocation sampling and heap-retention investigations after counter trends; heavier measurement needs its own workflow and fidelity checks. |
| **CT-21** | **Defer** | Keep launch flags, startup/system-trace acquisition, webRequest and a custom DevTools panel out of the primary path; support manual imports first. |
| **CT-22** | **Avoid** | Never label a partial trace “all Chrome,” a temporal overlap “root cause,” a memory slope “leak,” or synthetic arithmetic an executed browser experiment. |

