# OpenTelemetry-aware recording: research capture

Status: proposal for review, October 24, 2026. This capture authorizes no implementation.

## Source and intent

The user asked to preserve an architecture review and its idea in Context Recorder.
The source is a supplied ChatGPT response associated with [this conversation](https://chatgpt.com/c/6adb4135-57a0-83e9-9c9a-039962b4e67a).
The conversation itself was inaccessible and was not independently read. The user supplied
`Pasted text(20261024-044343).txt` instead (Library ID `libfile_fbbb7cd57434819187dfc247bf31861d`, reported size 11,219 bytes).
The [source copy](sources/response.txt) contains the full response text relayed by the parent after it retrieved the attachment.
It is a text transcription with a terminal newline, not a byte-verified download of the attachment in this checkout.
Its favicon links, bare domain names, and `+1` are copied presentation remnants, not substantive citations.

The proposed job is to record a web-app failure, inspect the operation that failed, and seek to
what the user saw. A waterfall could connect a Save click to an application operation, its
nested HTTP request, and an error. The source's Save example is conceptual, not captured evidence.
The value hypothesis is that combining video, narration, page context, and real spans makes
failure review easier. Demand, feasibility, overhead, and improved diagnosis remain unmeasured.

This is a small research capture following the repository's separation of source evidence,
[current code observations](#current-repository-evidence), and proposals. It does not create
an implementation initiative or change the existing [session-editing intent](../../intent/session-editing/intent-brief.md).
That older document uses “trace” to mean a recording session; any future UI must distinguish
that usage from an OpenTelemetry distributed trace.

## Useful architecture to retain

Keep three evidence types distinct:

| Proposed observation | Useful result | Honest limit |
| --- | --- | --- |
| Decode compatible OTLP/HTTP exports from the page | Exported span identity, hierarchy, timing, status, attributes, events, links, resource and instrumentation scope | Only spans actually present in observable exports; sampling, late injection and dropped exports leave gaps |
| Inspect outgoing W3C `traceparent` | Associate a request with a trace and caller span ID | Correlation metadata does not provide a completed span, duration, server tree, or proof that a span was recorded |
| Existing request, interaction and browser-timing hooks | Broad contextual timeline when native telemetry is missing | Inferred operations must retain that label and must not acquire fabricated OTel identity |

The source proposes fetch first, with XHR and `sendBeacon` compatibility; configurable endpoint
recognition; JSON, binary Protobuf and gzip decoding; and copying outgoing bodies without
consuming or modifying the app's request. These are candidate mechanisms, not working capture paths.
A standard wire format can reduce SDK-specific integrations, but JSON and Protobuf still need
separate decoding paths and transport/body-form validation.

A dedicated `telemetry.jsonl` is a reasonable candidate for keeping raw span intervals separate
from point events. Preserve source timestamps, provenance, resource/scope, span links, and source
recording identity; derive video-relative times during processing. Keep nanoseconds as exact
values rather than JavaScript floating-point epoch numbers. The source's TypeScript interface
is illustrative: it omits links and resource/scope despite proposing their capture, and its
`otel.span` type includes `inferred`. A future schema must resolve those differences and separate
capture mechanism from evidence kind. No schema is adopted here.

The proposed viewer adds a Traces inspector, hierarchical waterfall, error/filter controls,
span attributes/events, click-to-seek, and a small timeline lane. Selecting a mark could show
spans overlapping that moment. Orphan spans, missing parents, partial traces, and clipped visible
pieces must stay understandable. Native, portable HTML, and cloud views need an explicit scope
choice; existing viewers do not automatically gain support for a new file.

## Current repository evidence

Static inspection at fetched `origin/main` commit `1d9f29d4b38c8c964b948b9ba244289947476b9e`.
These are code observations, not runtime or performance results.

| Source claim | Verified code and qualification |
| --- | --- |
| Page hooks and early injection exist | [page.js](../../../extension/page.js) wraps fetch/XHR, history, console and interaction handlers; [manifest.json](../../../extension/manifest.json) declares `MAIN` at `document_start`. The manifest does not enable all-frame injection. |
| A ring holds recent events; failed/slow requests stream | `RING_SIZE = 60`, `SLOW_MS = 3000`, `recordRequest` in `page.js`. Ordinary successful requests remain in the ring; these wrappers read bounded error response snippets, not outgoing export bodies or trace headers. No beacon hook is present there. |
| The transport pipeline exists | [relay.js](../../../extension/relay.js) forwards page messages to [background.js](../../../extension/background.js), which sends them to the local WebSocket in [BrowserBridge.swift](../../../Sources/ContextRecorder/BrowserBridge.swift). Background events already gain `tabId`; frame/document identity and telemetry batching are additional work. Its disconnected queue caps at 200 messages and drops the oldest. |
| Native receipt determines the recording offset | `bridge.onEvent` in [RecorderController.swift](../../../Sources/ContextRecorder/RecorderController.swift) uses `recorder.currentOffset()` and calls `Session.addBrowserEvent`. [Session.swift](../../../Sources/ContextRecorder/Session.swift) appends that offset and the event to `browser.jsonl`. Page events also carry `Date.now()` as `t`, but there is no demonstrated span-clock calibration. |
| Processing consolidates and remaps page events | [process_session.py](../../../scripts/process_session.py) loads browser JSONL, uses `map_points` for edits/joins, and writes session data and the portable viewer. Points inside cuts drop out. That policy cannot preserve an interval crossing a cut. Existing sentence mapping has a speech-specific survival rule, not a span contract. |
| Source-aware edit infrastructure exists | [Edits.swift](../../../Sources/ContextRecorder/Library/Edits.swift) models kept source segments and source/edited-time conversion. It is a useful basis for interval intersections, not evidence of telemetry interval support. |
| Timeline and portable/cloud viewers exist | [SessionTimeline.swift](../../../Sources/ContextRecorder/Library/SessionTimeline.swift) has a Page lane. [SessionData.swift](../../../Sources/ContextRecorder/Library/SessionData.swift) decodes `BrowserEntry`/`PageEvent` with no span fields. [viewer.html](../../../scripts/viewer.html) renders page events; [CloudBundle.swift](../../../Sources/ContextRecorder/Cloud/CloudBundle.swift) embeds that template into `index.html`. No telemetry file, waterfall or dedicated span model was found in the inspected capture/processing/viewer paths. |

The source's pipeline assessment is supported. Its conclusion that changes are “manageable”
and require no recording-architecture rework remains an estimate. Persistence, clocks, bounded
transport, decoding, edit semantics, and all intended export/read paths still require proof.

## Primary technical checks

Checked October 24, 2026; these links replace the source's decorative citation remnants.

- [OTLP specification, HTTP and JSON encoding](https://opentelemetry.io/docs/specs/otlp/#otlphttp): HTTP supports binary Protobuf and JSON; content types are `application/x-protobuf` and `application/json`. Trace exports default to `/v1/traces`, but paths are configurable. Gzip is allowed. JSON IDs use hex, enums use integers, and 64-bit timestamp fields encode as decimal strings. Endpoint/content type alone is insufficient to establish a valid trace payload.
- [W3C Trace Context](https://www.w3.org/TR/trace-context/#traceparent-header): `traceparent` carries version, trace ID, parent ID and flags. The parent ID identifies the request as known by the caller. A sampled flag is not a guarantee that a trace was recorded. The source's “client span ID” example needs this qualification.
- [OpenTelemetry JS SDK 2.x migration guide](https://github.com/open-telemetry/opentelemetry-js/blob/main/doc/upgrade-to-2.x.md#-tracing-sdk-api-changes): `BasicTracerProvider.addSpanProcessor` was removed in favor of constructor options. This supports avoiding a design based on dynamically attaching to SDK internals; it does not prove passive interception works across exporters.

## Risks and open choices

- **Visibility:** Promise only observable page exports. Workers, uninstrumented apps, unsupported transports, restricted pages, frames and code that saved original network functions can evade these hooks. Backend-only spans need an explicitly supplied integration/backend source. The optional integration mode is deferred, not implicitly enabled.
- **Clock and lifetime:** Batches may arrive long after span completion or after Stop. Calibrate page epoch/monotonic time to the video's clock with uncertainty, navigation/reload and recording boundaries in mind. Define late-export acceptance and clock-jump behavior. Never position a span solely at export receipt time.
- **Cuts and joins:** Intersect original intervals with each kept source segment; visible pieces should retain original duration/identity and disclose clipping. Define zero-length and boundary behavior. Use source recording plus trace/span identity to avoid collisions across joined recordings. Repeated exports need deduplication without losing legitimate updates or gaps.
- **Privacy and trust:** Site opt-in, attribute allowlisting/redaction and byte/record limits must precede persistence. URLs, exceptions and nested attributes can carry secrets. Page-origin messages are untrusted input; a source marker is not authentication. Cap decompressed size, nesting, attributes, queue bytes and work, and report drops. Local storage does not make cloud/portable export sanitized.
- **Overhead and compatibility:** Copying Request/stream/Blob/typed-array bodies, decoding and decompression may be expensive or interfere with requests. Observer failure must leave original requests and responses intact. Measure main-thread work and recording impact; count-based queues and a large bridge message limit are not telemetry budgets.
- **Product boundary:** Which sites and manual/application spans make this useful? Is a trace-backend link plus the existing page lane sufficient? Which viewer must work first, and what telemetry may leave the local session? No user answer or implementation approval is inferred.

## Bounded validation ideas, only after separate authorization

Start with one small instrumented test page and fixed expected spans: nested Save operation,
fetch request, exception, and a deliberately delayed export. Compare a no-observer recording
with an observer prototype. Define clock-error and overhead budgets before judging the result.

| Proof | Evidence needed for a decision |
| --- | --- |
| Capture without interference | JSON fetch export yields the expected IDs, parents, exact timestamps and error; original collector bytes, response and app behavior are unchanged. Include Request input, malformed/oversized bodies, duplicate batches and ordinary successful requests. |
| Timing and edits | Delayed exports land at operation time; cut-crossing spans yield correct visible pieces and seeks. Joined recordings with colliding IDs stay separate. Include navigation, clock changes, out-of-session spans and Stop-before-export. |
| Privacy and pressure | Synthetic canary credentials are absent from every persisted/exported form. Unsupported bodies fail safely; burst and decompression cases remain within predeclared budgets and show loss counters. No real private recordings are needed. |
| Compatibility and usefulness | Add XHR, beacon, Protobuf/gzip, custom paths and frame/worker negative cases only as explicit follow-ups. A basic waterfall makes one real diagnostic task easier than existing events plus a backend link. |

Retain the source's JSON-first experiment and optional integration concept. Revise its phase
order: privacy/limits, source identity, deduplication and interval rules are foundation concerns,
not “polish” after a viewer ships. Defer broad transport support, cloud export and richer filters
until a small proof is useful. Reject universal automatic-tracing or production-readiness claims
without measured evidence. None of these experiments ran in this documentation PR.

[Validation and source-copy integrity](validation.md)
