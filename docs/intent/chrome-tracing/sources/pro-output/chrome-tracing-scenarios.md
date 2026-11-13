# Chrome tracing: ranked analysis scenarios

Research date: **October 28, 2026**, America/Indianapolis. Repository baseline: **`byronwall/context-recorder` at `1d9f29d4b38c8c964b948b9ba244289947476b9e`**.

## Recommended order

Build a small number of precise, connected explanations around the recording's marks. The useful result is a reviewer selecting a moment, seeing the relevant browser work on the same clock, and copying a bounded, source-linked investigation into Claude or Codex.

| Rank | Reviewer question | Deliverable in the app |
| --- | --- | --- |
| 1 | Why did this interaction feel slow? | Input-to-next-paint breakdown, with a separate application-completion interval. |
| 2 | Which requests delayed this result? | Mark-scoped waterfall with observed dependencies, cache state, priorities, and incomplete requests. |
| 3 | Which script or rendering work occupied the main thread? | Long-task and long-frame lanes with exclusive time and honest source attribution. |
| 4 | What should the coding agent investigate at this mark? | Compact evidence bundle connecting narration, UI target, timing, and source locations. |
| 5 | Is the app making unnecessary repeated requests? | Duplicate candidates and polling groups, with range/revalidation exclusions. |
| 6 | What jumped, and is repeated rendering work involved? | Layout-shift clusters, affected elements, and repeated style/layout work. |
| 7 | Did the fix improve the same flow? | Aligned before/after steps and paired metrics under comparable capture conditions. |
| 8 | Does memory remain higher after repeating and closing this flow? | Memory and DOM trends, with an explicit route to deeper retention investigation. |

This ordering is a design judgment for Byron's narrated walkthrough workflow. It is not a claim from a user study. The prior repository audit already demonstrates value from reconstructing network cost: its recorded session had 75 image requests and 9.939 MB of frame/screenshot assets, while metadata transferred 79.5 KB. That audit also explains that a late-installed long-task observer cannot rule out startup long tasks. Those are the **prior audit's reported observations**, not measurements repeated for this assignment. [Repository: `docs/research/session-performance/audit.md`, “What happens after the click,” “Evidence and limits”](https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/docs/research/session-performance/audit.md).

## Rules shared by every scenario

### Evidence is separate from interpretation

Every finding records four fields:

- **Observed:** an event, counter, duration, or protocol state directly present in captured evidence.
- **Association:** temporal overlap, matching document/target/selector, or an explicit causal link; identify which.
- **Hypothesis:** the implementation behavior that would explain the observation.
- **Next check:** the smallest concrete inspection or rerun that could confirm or reject it.

“This request overlaps the wait” is weaker than “the instrumented completion measure lists this request as a prerequisite.” An initiator stack identifies where a request began; it does not by itself prove that a later paint awaited its response. A main-thread trace can expose scheduling and rendering work, but a complete dependency graph through arbitrary application promises, workers, server computation, and paints is not available automatically.

### Scope and time remain explicit

- Preserve source identity: `sourceSessionId`, `captureId`, target/session identity, document or navigation identity, and raw event identity. A request key includes the CDP session and redirect hop; a browser's `requestId` alone is insufficient.
- Analyze against **raw source time**. Store any displayed edited time as a projection through `segments`; cut intervals do not disappear from the source evidence. For a joined recording, each source retains its own calibration and document identities.
- Display gaps, detached targets, absent categories, unsupported observers, source-map failures, and dropped data. An unavailable metric is `null` with a reason, never zero.
- A range crossing a cut can show separate retained fragments of an event. Keep its original duration and label the visible fragment duration; do not report a faster request because the user removed its middle.
- Mark association is adjustable. Prefer a selected interaction or step. A “nearest preceding interaction” suggestion requires the same selected tab/document and a displayed search window; it is not silently accepted as causation.

The existing pipeline already has source and edited mark offsets, source-session identifiers, and ordered playback segments in `SessionData`/`SessionMark`. The proposed performance model should use those concepts rather than invent a second timeline. The current Events log folds matching summaries for display; analysis must use raw evidence rather than those folded rows. [Repository: `Sources/ContextRecorder/Library/SessionData.swift`, `SessionData`, `SessionMark`](https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Library/SessionData.swift); [repository: `Sources/ContextRecorder/Library/EventLog.swift`, `EventLog.build`, `foldWindow`](https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Library/EventLog.swift).

### Fixture convention

**All excerpts and numerical results below are synthetic worked examples. They were created to specify expected behavior; they are not captured sessions, browser experiments, benchmark results, or evidence that an implementation already works.** Omitted protocol fields are omitted for readability. A normalized row is explicitly labeled when it is not a literal Chrome trace event.

The multi-object `jsonl` excerpts use **JSON Lines: one complete JSON object per line**. They are readable excerpts, not complete importable trace files. Observer entries, CDP envelopes, and normalized ledger records retain their labeled schemas; production files should not silently mix them. For fixtures containing Chrome trace events, `ts` and `dur` are microseconds. The synthetic calibration is:

```text
raw source seconds = (trace ts - 10,000,000) / 1,000,000
CDP monotonic timestamp seconds = 10 + raw source seconds
PerformanceEntry startTime milliseconds = 1,000 × raw source seconds
```

The last relationship is deliberately chosen for these fixtures; real document time origins differ and must be calibrated. No fixture's alignment precision should be read as a claim about achievable live precision.

## 1. Why did this interaction feel slow?

**Question.** “When I pressed Apply, was the delay before my handler ran, inside the handler, or after it returned? Did the spinner appear promptly even though the result took longer?”

### Data needed

- Event Timing entries: `interactionId`, `name`, `startTime`, `processingStart`, `processingEnd`, `duration`, document identity, and captured target description when available.
- Trace main-thread tasks, event dispatch, style/layout/paint, frame or presentation evidence when present; existing click target and narration.
- Optional application `performance.mark`/`measure` entries describing result readiness. A reviewer can instead mark the visible completion in video, with video-frame uncertainty disclosed.
- Coverage: when the observer was installed, its threshold, supported fields, trace interval, and alignment uncertainty.

### Method

Group entries by document and nonzero `interactionId`. Use the largest event duration in an interaction rather than summing `pointerdown`, `pointerup`, and `click`. For that representative event compute input delay, handler processing, and approximate presentation remainder. Associate overlapping main-thread work, distinguishing an existing task that delayed input from work dispatched by the interaction.

Use “observed interaction latency” for a recording fragment. INP is a page-lifecycle metric with interaction-count and outlier rules; the worst captured mark is not automatically a valid page INP. Event Timing's presentation remainder is approximate, and its durations are coarsened. Configure `durationThreshold: 16` for new event observation; late `buffered` observation cannot recreate every short event that was never retained. [W3C Event Timing draft, usage example and observer processing](https://w3c.github.io/event-timing/); [Chrome/web.dev INP definition](https://web.dev/articles/inp).

Keep application-completion latency separate. A quick spinner paint followed by a slow fetch is a useful distinction: INP intentionally concerns initial visual feedback, not the completion of every asynchronous effect. [Chrome/web.dev INP, “What is INP?”](https://web.dev/articles/inp).

### Worked excerpt

Observer entry, plus selected synthetic trace records:

```jsonl
{"entryType":"event","name":"click","interactionId":41,"startTime":10000,"processingStart":10080,"processingEnd":10160,"duration":240}
{"name":"RunTask","cat":"disabled-by-default-devtools.timeline","ph":"X","pid":100,"tid":101,"ts":19990000,"dur":90000}
{"name":"EventDispatch","cat":"devtools.timeline","ph":"X","pid":100,"tid":101,"ts":20080000,"dur":80000,"args":{"data":{"type":"click"}}}
{"name":"Layout","cat":"devtools.timeline","ph":"X","pid":100,"tid":101,"ts":20160000,"dur":50000}
{"name":"Paint","cat":"devtools.timeline","ph":"X","pid":100,"tid":101,"ts":20210000,"dur":5000}
{"entryType":"mark","name":"app:results-ready","startTime":10800}
```

Expected interpretation:

- Raw input time is **10.000 s**. Input delay is **80 ms**, synchronous event processing is **80 ms**, and approximate presentation remainder is **80 ms**: total **240 ms**.
- The preceding 90 ms task overlaps only **80 ms** of input waiting. Attribute that overlap, not its entire duration, to this interaction's delay.
- The 50 ms layout is inside the 80 ms presentation remainder. Do not add it to 240 ms. Paint completion at 10.215 s is not proof of physical display presentation at that instant.
- The application readiness mark is **800 ms** after input. This is a separate metric; it does not replace the 240 ms interaction latency.
- If the mark is at 10.600 s, the UI may suggest interaction 41 within a displayed two-second lookback; the user can select a different interaction.

### UI and agent handoff

- **Timeline:** an Interaction lane showing the three phases, plus a separate ready interval when available. Clicking either seeks the same video playhead.
- **Mark:** “240 ms to next paint; 800 ms to result-ready,” an explicit selected-interaction link, and a short list of overlapping work.
- **Events:** one interaction row that expands into constituent events and source links.
- **Canvas:** a badge on the frame/card containing the input; clicking opens the same mark detail. No independent canvas clock.

```markdown
### Mark 7 — Apply filter responds late
Narration: “It freezes before showing the results.”
Scope: source A, tab t1/document d1, raw 10.000–10.800 s.
Observed: interaction 41 took 240 ms: input delay 80 ms,
handler processing 80 ms, approximate presentation remainder 80 ms.
Application result-ready was 800 ms after input.
Evidence: event e41; trace events task17, dispatch41, layout9, paint9.
Association: task17 overlaps input waiting by 80 ms; layout9 overlaps
the presentation phase. The fetch-to-result dependency is not established.
Next check: inspect the blocking task's source stack and the Apply handler.
Preserve prompt visual feedback while investigating result completion.
```

## 2. Which requests delayed this result?

**Question.** “Did the marked step wait for an API, download, cache revalidation, service worker, connection setup, or main-thread consumption of an already-arrived response?”

### Data needed

Collect `Network.requestWillBeSent`, response/extra-info events, `dataReceived`, `loadingFinished`, `loadingFailed`, cache events, priority changes, response timing, initiator information, and frame/loader/target identity. Preserve request and redirect boundaries. Capture a safe header subset such as content type, cache controls, ETag, range information, and server timing; missing fields remain unknown. A Resource Timing observer is a useful fallback but cannot expose all cross-origin detail without the appropriate timing permission. [CDP Network](https://chromedevtools.github.io/devtools-protocol/tot/Network/); [W3C Resource Timing, cross-origin resources](https://www.w3.org/TR/resource-timing/#sec-cross-origin-resources).

### Method

Construct per-request intervals from protocol timestamps, without assuming extra-info event arrival order. Retain redirect hops, canceled requests, unfinished streams, cache source, initial/final priorities, and changes in priority. Show connection reuse and unavailable phases explicitly. Explain TTFB as waiting for the first response byte, which includes network and server contributions; it is not “backend CPU time.” Only a server-provided timing field supports a narrower backend claim. [Chrome Network reference, timing phases](https://developer.chrome.com/docs/devtools/network/reference/#timing-explanation).

Rank requests overlapping the selected step by observed latency and bytes. Build a dependency view only from evidenced links: redirects, initiators with known relationships, trace flow edges, or application completion instrumentation. Display the longest **evidenced** chain separately from the union of busy network intervals. A request that ends last is not automatically the blocker. Never sum concurrent request durations and call that elapsed delay.

### Worked excerpt

The first request is a literal reduced CDP sequence. The remaining rows are normalized ledger records for compactness.

```jsonl
{"method":"Network.requestWillBeSent","params":{"requestId":"r1","timestamp":40.0,"request":{"url":"https://app.test/api/items","method":"GET","initialPriority":"High"}}}
{"method":"Network.responseReceived","params":{"requestId":"r1","timestamp":40.302,"response":{"status":200,"fromDiskCache":false,"fromServiceWorker":false,"timing":{"requestTime":40.0,"dnsStart":-1,"connectStart":-1,"sendStart":20,"sendEnd":21,"receiveHeadersStart":300,"receiveHeadersEnd":302}}}}
{"method":"Network.loadingFinished","params":{"requestId":"r1","timestamp":40.4,"encodedDataLength":64000}}
{"kind":"request","id":"r2","rawStart":30.100,"rawEnd":30.200,"url":"https://app.test/avatar.png","cache":"disk","encodedDataLength":0}
{"kind":"request","id":"r3","rawStart":30.400,"rawEnd":30.700,"url":"https://app.test/api/details","encodedDataLength":32000}
{"kind":"app-step","rawStart":30.000,"rawEnd":30.800,"requiredChain":["r1","r3"],"dependencySource":"explicit-fixture-instrumentation"}
```

Expected result:

- Durations are **400 ms**, **100 ms**, and **300 ms**. Their sum is 800 ms; the union of network-active intervals is **700 ms**.
- Recorded encoded transfer is **96,000 bytes**. This is the sum of the defined CDP fields, not exact TCP/QUIC wire traffic or billing bytes.
- For r1, send duration is **1 ms**, wait after send through first response header byte is **279 ms**, and the observed remainder from header completion to finish is **98 ms**. The initial 20 ms is pre-send time with insufficient detail here to assign a specific queueing cause.
- The explicit fixture's prerequisite chain r1→r3 covers **700 ms**. Result readiness takes 800 ms, leaving **100 ms** outside that chain. Removing the fixture's explicit dependency annotation must downgrade the chain to a hypothesis, while preserving the same waterfall.
- r2's cache state comes from an observed cache flag. A generic Resource Timing `transferSize: 0` alone would not establish this, especially across origins.

### UI and agent handoff

- **Timeline:** aggregate in-flight request count and bytes, expandable to the selected mark's waterfall.
- **Mark:** request phases, cache badges, priority history, failures, and a “dependency established / inferred / unknown” indicator.
- **Events:** searchable request rows with exact raw durations and source links; keep successful requests available.
- **Canvas:** an unobtrusive network-cost badge attached to the corresponding time range.

```markdown
### Mark 12 — Results require two serial API requests
Observed: /api/items 400 ms; /api/details 300 ms; 96,000 encoded bytes
including the other observed resource. Network-active union: 700 ms.
Evidence: t1/r1/hop0 and t1/r3/hop0; explicit step-ready dependency list.
r1 first-byte wait after send: 279 ms. Server CPU time is unknown.
Hypothesis: the details response could be included in the first response
or prefetched if application semantics permit.
Next check: inspect the data dependency before parallelizing requests.
```

## 3. Which script or rendering work occupied the main thread?

**Question.** “Is the pause expensive JavaScript, forced layout, repeated rendering, garbage collection, or work the recording cannot attribute?”

### Data needed

Use main-thread trace slices and their nesting; CPU sampling when captured; `longtask` and `long-animation-frame` observers; script URLs and source locations; matching source-map identity when available. Keep a source location in generated code if authored mapping cannot be established. The current page snapshot already models component breadcrumbs and source locations, but it does not establish a performance profile for the component. [Repository: `extension/page.js`, `componentChain`, `sourceFor`, `describe`](https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/extension/page.js); [repository: `SessionData.swift`, `SourceLocation`](https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Library/SessionData.swift).

### Method

First identify top-level task intervals on the correct renderer main thread. Compute union durations and exclusive child-subtracted durations; never sum parent and child slices as independent work. Report long-task blocking above 50 ms within the selected interval as a locally defined diagnostic, **not Lighthouse Total Blocking Time**, whose measurement window and purpose differ.

Long Tasks provides coarse container attribution. LoAF can add script-entry attribution and forced-style/layout information, but it is not a complete function profiler. Keep API-reported `blockingDuration`; do not substitute `frame.duration - 50`. Use CPU samples for estimated time in functions and trace intervals for measured slice durations, clearly labeled. [Long Tasks draft](https://w3c.github.io/longtasks/); [Chrome LoAF documentation](https://developer.chrome.com/docs/web-platform/long-animation-frames); [DevTools performance reference, self and total time](https://developer.chrome.com/docs/devtools/performance/reference/).

The October 20, 2026 LoAF editor draft includes separate style/layout durations and additional source fields. Their presence in a draft is not evidence that Byron's Chrome exposes them. Detect each field; support the existing combined forced-style/layout field and retain unavailable splits as `null`. [W3C LoAF editor draft](https://w3c.github.io/long-animation-frames/).

### Worked excerpt

```jsonl
{"name":"RunTask","cat":"disabled-by-default-devtools.timeline","ph":"X","pid":100,"tid":101,"ts":50000000,"dur":120000}
{"name":"FunctionCall","cat":"devtools.timeline","ph":"X","pid":100,"tid":101,"ts":50000000,"dur":100000,"args":{"data":{"functionName":"sortRows","url":"https://app.test/assets/table.js","lineNumber":119,"columnNumber":4}}}
{"name":"Layout","cat":"devtools.timeline","ph":"X","pid":100,"tid":101,"ts":50030000,"dur":20000}
{"name":"Paint","cat":"devtools.timeline","ph":"X","pid":100,"tid":101,"ts":50105000,"dur":10000}
{"name":"RunTask","cat":"disabled-by-default-devtools.timeline","ph":"X","pid":100,"tid":101,"ts":50300000,"dur":60000}
{"entryType":"long-animation-frame","startTime":40000,"duration":140,"renderStart":40100,"styleAndLayoutStart":40100,"blockingDuration":90,"scripts":[{"sourceURL":"https://app.test/assets/table.js","sourceFunctionName":"sortRows","duration":100,"forcedStyleAndLayoutDuration":20}]}
```

Expected result:

- Top-level long tasks are **120 ms** and **60 ms**, total **180 ms**. Their excess over 50 ms is **70 + 10 = 80 ms**.
- In the first task, FunctionCall inclusive duration is **100 ms** and exclusive time after subtracting its nested layout is **80 ms**. Layout is **20 ms**, Paint is **10 ms**, and the remaining task self time is **10 ms**: total **120 ms**.
- Summing the raw slices would give 250 ms for that 120 ms task; the parser must reject that accounting model.
- The LoAF is **140 ms** with API-provided **90 ms blockingDuration**. Its rendering phase starts at **40.100 s**, before the Paint slice at **40.105 s**. The 20 ms layout inside `sortRows` precedes that rendering phase and is forced layout. The excerpt omits other frame work; do not reconstruct LoAF blocking from this partial slice list. The LoAF overlaps the first task and does not add 140 ms to the task total.
- The second task has **60 ms unattributed task work**. A missing stack must not assign it to `sortRows` merely because it is nearby.
- `lineNumber` and `columnNumber` conversion depends on the event schema. Preserve raw values and display a normalized location only after the schema adapter's fixture verifies its indexing.

### UI and agent handoff

- **Timeline:** main-thread busy/long-task lane; LoAF markers overlay rather than double-count it.
- **Mark:** top exclusive contributors, forced-layout time, and unknown time. Open the raw trace in DevTools for full stacks.
- **Events:** filterable long tasks with duration and attribution confidence.
- **Canvas:** a “main thread busy” badge linked to the same interval.

```markdown
### Mark 15 — Sorting holds the main thread
Observed: two long tasks total 180 ms; selected-range blocking above
50 ms is 80 ms. This is not a Lighthouse TBT score.
First task: sortRows has 80 ms exclusive work and contains 20 ms layout;
10 ms paint and 10 ms other task work complete its 120 ms duration.
Evidence: trace task80/call81/layout82/paint83; generated table.js location.
Authored TypeScript mapping: unavailable. Second task attribution: unknown.
Next check: inspect reads after DOM writes in sortRows; verify whether
sorting can move off the main thread or yield without changing order.
```

## 4. What should the coding agent investigate at this mark?

**Question.** “Give the agent the small evidence package needed to work on this complaint without sending an entire raw trace or inventing a diagnosis.”

### Data needed

Join the existing mark, narration, screenshot, hovered/clicked element, source metadata, and recent page problems with the scenario outputs above. Include source intervals, capture tier, target coverage, raw evidence references, omissions, clock uncertainty, and explicit redaction status. This extends the existing mark-oriented Markdown export described in the README; the baseline already stores a mark's browser snapshot and recent page events. [Repository: `README.md`, “Sessions window,” “Marking up a recording afterwards”](https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/README.md); [repository: `extension/page.js`, `snapshot`](https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/extension/page.js).

### Method

Produce deterministic findings from recorded metrics first; optional language generation only explains those findings. Rank up to three findings by relevance to the selected complaint, observed severity, and evidence completeness. Do not create a numeric “causality confidence” from arbitrary weights. Use named evidence strengths and show their basis.

Keep both a compact Markdown section and a machine-readable reference list. The section tells the agent where to inspect, what is observed, what is still unproved, and how to validate a change. Each request, frame, and trace interval is included once even if it was seen by both a page patch and CDP. Deduplication should use explicit source linkage; a URL/time guess can be a candidate match but must not erase potentially distinct requests.

### Worked excerpt

These are normalized proposed index records, referencing the preceding synthetic scenarios:

```jsonl
{"kind":"mark","id":"A:m7","rawTime":10.600,"editedTime":8.600,"selectedInteraction":"A:d1:41","note":"Apply freezes"}
{"kind":"interaction","id":"A:d1:41","rawStart":10.000,"rawEnd":10.240,"durationMs":240,"evidence":["e41","task17","dispatch41","layout9","paint9"]}
{"kind":"request","id":"A:t1:r9:0","rawStart":10.090,"rawEnd":10.700,"durationMs":610,"seenBy":["cdp","page-patch"],"causesReady":"unknown"}
{"kind":"coverage","rawStart":9.500,"rawEnd":11.000,"network":"complete-for-attached-target","trace":"complete-window","cpuSamples":"not-enabled","workerCoverage":"partial"}
```

Expected bundle:

- One interaction finding at **240 ms**, one request at **610 ms**, and **one** request count despite two linked capture sources.
- Mark display time **8.600 s** and source time **10.600 s** are both preserved. Evidence references still point to source A's original recording.
- No CPU hot-function claim, because CPU sampling was disabled and the excerpt contains no attributed function slice.
- No “all browser work captured” claim, because worker coverage is partial.
- The 610 ms request is associated in time; there is no proven relationship to result readiness.

### UI and agent handoff

- **Timeline:** a finding badge at the mark; selecting it highlights the precise supporting intervals.
- **Mark:** “Performance evidence” with three findings, coverage, and Copy as Markdown.
- **Events:** open the cited underlying records instead of a duplicate synthesized error row.
- **Canvas:** reuse the existing mark badge and detail; do not require a new performance canvas.

```markdown
### Mark 7 — Apply freezes
Display 00:08.600; source A 00:10.600; tab t1/document d1.
Observed interaction: 240 ms (80 input / 80 processing / ~80 presentation).
Associated request: GET /api/items, 610 ms, one request.
No request-to-ready dependency was established.
Evidence: A:d1:41; A:t1:r9:0; raw 10.000–10.700 s; screenshot m7.
Source lead: Apply button's captured source location, if present.
Coverage: attached target complete in this window; workers partial;
CPU samples not enabled; sensitive header values omitted.
Next action: inspect the handler and the evidence's preceding long task.
Validation: rerun the same action with the same capture tier and cache state.
```

## 5. Is the app making unnecessary repeated requests?

**Question.** “Are duplicate loaders, repeated mounts, polling, or subscription churn producing avoidable traffic?”

### Data needed

Use successful and failed request ledger rows, initiation times/stacks, method, full request identity before presentation redaction, resource type, cache behavior, validators, range headers, response byte counts, and the selected tab/document. Optional request-body equivalence may improve POST analysis, but its absence must not be replaced with an assumption.

### Method

Group equivalent GET/HEAD candidates by request semantics, document, and a short selected window. Retain meaningful query parameters. For secret query values, use a local keyed digest for equality while omitting the values from exports. Use method, URL equivalence, range, credentials mode when available, and response validator to avoid conflating different requests.

Flag overlapping same-resource requests as **deduplication candidates**; do not declare them redundant until code or semantics supports that conclusion. Separate normal revalidation, retries, image variants, open-ended media ranges, intentional polling, prefetch, and navigation. Repeated URL alone is insufficient. The previous repository audit's MP4 requests demonstrate why a `206` range and an advertised response size cannot be treated as a full duplicate download. [Repository audit, “How the video loads,” “Seeking and pausing”](https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/docs/research/session-performance/audit.md).

For periodic requests, calculate observed intervals and variation. Present the actual window and count, not a projected whole-session cost. A request initiator is an inspection lead; it does not prove a framework remounted a component.

### Worked excerpt

Normalized request ledger; all times are raw source seconds:

```jsonl
{"id":"r1","method":"GET","url":"/api/items?filter=active","start":60.0,"end":60.3,"status":200,"etag":"v42","encodedBytes":12000}
{"id":"r2","method":"GET","url":"/api/items?filter=active","start":60.1,"end":60.4,"status":200,"etag":"v42","encodedBytes":12000}
{"id":"r3","method":"GET","url":"/api/items?filter=active","start":60.2,"end":60.5,"status":200,"etag":"v42","encodedBytes":12000}
{"id":"r4","method":"GET","url":"/api/items?filter=active","start":61.0,"end":61.1,"status":304,"encodedBytes":240}
{"id":"v1","method":"GET","url":"/recording.mp4","range":"bytes=0-","start":60.0,"end":60.2,"status":206}
{"id":"v2","method":"GET","url":"/recording.mp4","range":"bytes=196608-","start":60.2,"end":60.7,"status":206}
{"kind":"poll-group","url":"/api/status","observationWindow":[60,66],"requestStarts":[60,61,62,63,64,65]}
```

Expected result:

- One overlapping GET group, **three requests**, peak concurrency **three**, total **36,000 encoded bytes**.
- If the three requests are semantically interchangeable, deduplication could remove at most two transfers: **24,000 bytes** in this group. Label this a conditional upper bound, not measured savings.
- r4 is a separate cache-validation request, not one of the overlapping duplicate candidates. v1/v2 remain distinct range requests.
- The six polls occurred in the six-second half-open observation interval **[60,66)**: **1 request/second**, with five observed interarrival intervals of exactly one second.
- Unknown POST bodies never produce a definitive duplicate-payload claim.

### UI and agent handoff

- **Timeline:** density spikes and optional polling bands, subordinate to the main waterfall.
- **Mark:** duplicate-candidate groups, exact counts, and exclusion reasons.
- **Events:** a group can fold visually while retaining every raw request and timestamp.
- **Canvas:** a badge only when the group overlaps the selected visible step.

```markdown
### Mark 21 — Three equivalent-looking item loads overlap
Observed: three GET /api/items?filter=active requests within 200 ms;
same validator v42; 36,000 encoded bytes; peak concurrency three.
Candidate savings: at most 24,000 bytes if one response can serve all consumers.
Excluded: the later 304 validation and distinct MP4 byte ranges.
Next check: compare the three initiator stacks and data-loader ownership.
Do not remove polling or retries without checking their intended behavior.
```

## 6. What jumped, and is repeated rendering work involved?

**Question.** “What moved when I said ‘the page jumps,’ and does the trace show expensive repeated style/layout near it?”

### Data needed

Observe `layout-shift` entries with value, `hadRecentInput`, and available source rectangles/element descriptions. Retain frame/document identity and viewport geometry. Add trace style/layout/paint records, LoAF script attribution, narration, and the original video frame. Capture affected-node descriptions immediately; later DOM lookup may point to a changed or removed element.

### Method

Show all observed shifts, but compute the CLS-style burst score only from shifts eligible under the metric. Group with gaps under one second and a maximum five-second window; retain the maximum window sum. Keep scope explicit when observation begins mid-page or misses frames. Do not sum independent frame scores into an invented whole-page CLS. [Chrome/web.dev CLS](https://web.dev/articles/cls).

Separately count style/layout work and its union/exclusive duration in a selected window. Call repeated browser work “repeated layout” or “repeated render work.” It is not a count of React/Solid component rerenders, which requires framework instrumentation or other direct evidence. A moved element may be a victim of an insertion elsewhere, not the root cause.

Use captured node rectangles for optional overlays only when coordinate spaces and frame geometry are known. A screenshot taken later is not proof of the element's position at the shift; default to seeking the recorded video around the event.

### Worked excerpt

Observer entries plus normalized layout slices:

```jsonl
{"entryType":"layout-shift","startTime":2000,"value":0.06,"hadRecentInput":false}
{"entryType":"layout-shift","startTime":2400,"value":0.07,"hadRecentInput":false}
{"entryType":"layout-shift","startTime":2600,"value":0.20,"hadRecentInput":true}
{"entryType":"layout-shift","startTime":3500,"value":0.04,"hadRecentInput":false}
{"entryType":"layout-shift","startTime":3800,"value":0.03,"hadRecentInput":false}
{"kind":"layout-slices","rawStarts":[10.01,10.11,10.21,10.31,10.41,10.51],"durationMsEach":8,"thread":"renderer-main"}
```

Expected result:

- First eligible shift cluster: **0.06 + 0.07 = 0.13**. The 0.20 recent-input shift remains visible but is excluded from this score.
- Gap from 2.400 s to 3.500 s is **1.100 s**, so the second cluster is separate: **0.04 + 0.03 = 0.07**.
- Maximum observed eligible cluster is **0.13**, not 0.20 (sum of all eligible shifts) and not 0.40 (sum of every shift).
- The separate raw [10,11) interval has **six nonoverlapping layout slices totaling 48 ms**. Its framework rerender count is **unknown**.
- A narration line at 2.700 s saying “that jumped” is associated with the earlier shift cluster, not automatically with the unrelated 10–11 s layout burst.

### UI and agent handoff

- **Timeline:** shift diamonds sized by score; a separate style/layout intensity strip when available.
- **Mark:** before/after video seek buttons, affected elements, eligible/excluded shift score, and nearby browser work.
- **Events:** all shifts, including recent-input exclusions, with the reason for each score decision.
- **Canvas:** a jump badge linked to the exact source frame; no claim that a stitched column preserves a single moment's layout.

```markdown
### Mark 4 — Content jumps after the banner arrives
Observed: eligible shifts 0.06 at 2.000 s and 0.07 at 2.400 s;
largest observed burst 0.13. A 0.20 recent-input shift is shown separately.
Affected element: captured #results rectangle, if present in evidence.
Hypothesis: late content insertion above the results displaced them.
Next check: inspect the banner's reserved dimensions and the raw frames.
No framework rerender count or cause has been established.
```

## 7. Did the fix improve the same flow?

**Question.** “Is this version faster for the same action, and did the improvement merely move work elsewhere?”

### Data needed

Pair sessions by manually confirmed flow/step labels, application version, browser version, capture tier/categories, device, viewport, input data, visibility, cache mode, network conditions, and source coverage. Record source-map/build identity and whether CPU or memory diagnostics were enabled. Use raw source intervals, not edited movie lengths. Keep interaction latency and full step completion as distinct metrics.

### Method

Start with a manual “Compare with…” selection and explicit step alignment. Automatic matching can propose candidates from URL route, selector, and mark text; the user confirms them. Compare medians and ranges across a small number of repeated, paired runs; show every observation. For five runs, do not manufacture statistical certainty or a population percentile.

Report changes in interaction latency, outcome latency, encoded bytes, request count, long-task excess, and capture coverage. Refuse a clean improvement badge when the “after” capture lost part of the selected target or used a materially different diagnostic tier. Show confounding changes such as different cache behavior. The repository's prior audit excluded a run with two debugger connections, demonstrating why capture conditions belong in the comparison. [Repository audit, “Measured transfer and timing”](https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/docs/research/session-performance/audit.md).

### Worked excerpt

Normalized records derived from explicitly marked step intervals:

```jsonl
{"kind":"paired-step-metrics","step":"apply-filter","metric":"outcomeLatencyMs","before":[400,420,440,460,480],"after":[240,260,280,300,320]}
{"kind":"paired-step-metrics","step":"apply-filter","metric":"longTaskExcessMs","before":[100,110,120,130,140],"after":[40,45,50,55,60]}
{"kind":"comparison-conditions","captureTierEqual":true,"cacheModeEqual":true,"dataSetEqual":true,"targetCoverageEqual":true,"samplePairs":5}
```

Expected result:

- Median outcome time changes from **440 ms to 280 ms**, a reduction of **160 ms**, or **36.36%** relative to the before median.
- Each paired outcome difference is **−160 ms**. Display the five points and ranges: before **400–480 ms**, after **240–320 ms**.
- Median long-task excess changes from **120 ms to 50 ms**, a reduction of **70 ms** or **58.33%**.
- Label the result “improved in these five paired runs.” Do not claim that the fix caused a 36.36% improvement for all users.
- Changing `targetCoverageEqual` to false must produce “not directly comparable” rather than preserving the improvement badge.

### UI and agent handoff

- **Timeline:** two synchronized step-relative lanes, each retaining its own video playhead and source clock.
- **Mark:** side-by-side metrics and condition differences; paired runs can be expanded.
- **Events:** added/removed request groups and changed long-task contributors.
- **Canvas:** optional paired cards for the same confirmed step, without automatically aligning stitched coordinates.

```markdown
### Compare apply-filter before/after
Five paired runs, same selected capture tier/cache/data set/target coverage.
Median result-ready: 440 → 280 ms (−160 ms, −36.36%).
Median selected-range long-task excess: 120 → 50 ms (−70 ms).
All five observed result-ready differences were −160 ms.
This supports an improvement in this reproduced flow, not a field-wide claim.
Next check: inspect request/byte changes and confirm no work moved after ready.
```

## 8. Does memory remain higher after repeating and closing this flow?

**Question.** “When I open and close the same screen repeatedly, do heap usage and DOM counts return toward baseline, or does retained state keep growing?”

### Data needed

Sample supported `Performance.getMetrics` counters such as `JSHeapUsedSize`, `Nodes`, and `JSEventListeners`, with target/document identity and timestamps. Add garbage-collection trace events when captured, visibility/lifecycle changes, and user-defined cycle boundaries. Track each metric's scope; per-target counters can reflect shared implementation state and must not be blindly summed across sessions.

Optionally call `performance.measureUserAgentSpecificMemory()` in a user-selected memory investigation when available and allowed. It requires the appropriate isolated environment and may wait for garbage collection; the measurement itself can influence collection behavior. Its estimate is not interchangeable with a JS-heap counter. Do not change application isolation headers merely to make the observer work. [CDP Performance](https://chromedevtools.github.io/devtools-protocol/tot/Performance/); [Chrome/web.dev memory measurement guidance](https://web.dev/articles/monitor-total-page-memory-usage).

### Method

Plot raw samples, identify comparable post-cycle idle windows, and compute their local low-water values. If a qualifying GC event is observed, distinguish post-GC samples from merely idle ones. Regress baseline values against elapsed time or cycle count, always displaying sample count. Restart analysis after navigation, renderer replacement, or material scope changes.

Growing low-water values and DOM counts make retention worth investigating; they do not prove a memory leak. Caches and legitimately retained application state can grow. Object retention paths require an explicit deeper investigation with supported heap tooling. Keep heap snapshots and allocation diagnostics out of routine mark capture because their cost and retained content are materially different from counters.

### Worked excerpt

Normalized samples from one target/document, taken after four comparable idle periods; values are decimal bytes:

```jsonl
{"rawTime":0,"cycle":0,"JSHeapUsedSize":40000000,"Nodes":1000,"sampleKind":"idle-low-water","observedGC":false}
{"rawTime":60,"cycle":1,"JSHeapUsedSize":46000000,"Nodes":1300,"sampleKind":"idle-low-water","observedGC":false}
{"rawTime":120,"cycle":2,"JSHeapUsedSize":52000000,"Nodes":1600,"sampleKind":"idle-low-water","observedGC":false}
{"rawTime":180,"cycle":3,"JSHeapUsedSize":58000000,"Nodes":1900,"sampleKind":"idle-low-water","observedGC":false}
```

Expected result:

- Heap low-water observations increase by **18,000,000 bytes** across 180 seconds: **6 MB/minute**, using decimal MB.
- DOM nodes increase by **900**, or **300 nodes/minute**. This is an observed counter trend, not attribution to a particular component.
- The samples are **not confirmed post-GC**. Display “possible retained growth; GC evidence unavailable,” not “18 MB leak.”
- A target/document change invalidates this single-series slope unless the user explicitly compares separate series with compatible metric scope.
- Missing `measureUserAgentSpecificMemory` is `unsupported` or `isolation-required`; it does not become a zero-memory sample.

### UI and agent handoff

- **Timeline:** sparse memory and DOM trends, with cycle/mark boundaries and gap markers.
- **Mark:** “baseline did/did not return in observed window,” the relevant samples, and scope limitations.
- **Events:** lifecycle changes and optional GC events; avoid flooding the ordinary Events tab with every sample.
- **Canvas:** a small cycle summary on selected cards; no claim about memory of a screenshot.

```markdown
### Repeated panel flow — retained-growth candidate
Same target/document; four comparable idle windows over 180 s.
Observed heap low-water values: 40, 46, 52, 58 MB; slope 6 MB/min.
Observed DOM Nodes: 1000, 1300, 1600, 1900; slope 300 nodes/min.
GC completion was not observed. This does not prove a leak.
Next check: repeat the open/close cycle, inspect listener/subscription cleanup,
then use explicit heap-retention tooling if the growth remains reproducible.
```

## Delivery and acceptance boundaries

These scenarios should share one compact index and evidence resolver, not eight separate trace parsers. The native app needs the synchronized lanes, mark summaries, filters, evidence IDs, and source/edited time mapping. Full flame charts and heap-retention graphs can open in established tooling. DevTools can load saved traces and optionally preserve resource content and source maps; those attachments improve offline investigation but increase size and sensitivity. [Chrome DevTools save-trace documentation, updated October 8, 2026](https://developer.chrome.com/docs/devtools/performance/save-trace).

The implementation must prove the following using deterministic fixtures before its conclusions are exposed as automatic findings:

- Scenario 1: `80 + 80 + 80 = 240 ms`; initial feedback stays distinct from `800 ms` outcome completion.
- Scenario 2: `400 + 100 + 300 = 800 ms` of summed request duration but `700 ms` active union and `96,000` recorded encoded bytes.
- Scenario 3: `120 + 60 = 180 ms` task time, `80 ms` long-task excess, and `80 + 20 + 10 + 10 = 120 ms` exclusive accounting for the first task.
- Scenario 4: one linked request captured through two mechanisms remains one request, with both provenance references retained.
- Scenario 5: three overlapping candidates, peak concurrency three, conditional removable bytes at most 24,000; `304` validation and different ranges are separate.
- Scenario 6: maximum observed eligible shift burst `0.13`, six layouts totaling `48 ms`, and unknown framework rerenders.
- Scenario 7: median completion reduction `160 ms`, relative reduction `36.36%`; incompatible coverage suppresses the comparison verdict.
- Scenario 8: heap slope `6 MB/min`, node slope `300/min`, and an explicit absence of GC proof.

Additional acceptance fixtures must cover events spanning cuts, joined sessions with colliding request IDs, cross-origin targets with incomplete coverage, dropped chunks, unsupported observers, out-of-order extra-info events, redirects, unfinished media requests, and secrets removed before agent/cloud export. These are proposed implementation checks. Arithmetic validation of a synthetic example is not validation of Chrome capture, trace parsing, or UI behavior.
