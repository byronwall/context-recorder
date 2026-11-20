# Feature taxonomy

The comparison covers 65 concepts across 15 products and one written workflow baseline.
The definitions below preserve differences between evidence, agent access, and observed results.

Use [feature-matrix.csv](feature-matrix.csv) to compare states across products.
Read [feature-comparison.csv](feature-comparison.csv) for each cell's term, qualification, release, and source.
Use [products.csv](products.csv) for prices, platforms, setup, and service dependencies.
See [feature-guide.md](feature-guide.md) for the practical differences and useful combinations.

Capability states are supported, partial, unsupported, unknown, and not-applicable.
Evidence states are code-inspected, documented, marketing, inferred, and not-established.
Release states describe the source claim. They do not prove successful use.
Every assessment is based on research or static source inspection. No product trial ran.
Unknown does not mean unsupported. Do not rank products by the number of supported cells.

Research: October 24, 2026. Codex reconciliation: October 25, 2026.
[Pro conversation](https://chatgpt.com/c/6add7517-fa5c-83ea-a835-b48d3709a763).
Original reports remain in ignored local storage. These CSV files are reviewed projections.
Codex checked decisive claims, not every external cell. Most cells retain Pro's evidence assessment.
Native Find now has a direct source check in F32. See [validation.md](validation.md).

| ID / concept | Definition | Guardrail |
|---|---|---|
| **F01 — Raw screen video** | Pixel video of a deliberate session, distinct from DOM reconstruction. | Original pixels versus reconstructed DOM. |
| **F02 — Narration audio** | Microphone or spoken instructions captured with the session. | Mic/voice distinct from system audio. |
| **F03 — Selected frames and marks** | Deliberate screenshots, keyframes, timestamps or bookmarks. | Marks need not equal requests. |
| **F04 — Retrospective buffer** | Recover events before the user intentionally starts a report. | Read the mode, prerequisite and evidence qualification. |
| **F05 — Passive session capture** | Continuous or production-user session observation. | Read the mode, prerequisite and evidence qualification. |
| **F06 — Desktop and cross-app scope** | Capture native apps or more than a single instrumented web page. | Read the mode, prerequisite and evidence qualification. |
| **F07 — Mobile capture** | Native mobile apps or device sessions; distinguish mobile browser only. | Read the mode, prerequisite and evidence qualification. |
| **F08 — Synchronized evidence timeline** | Shared timing across visual evidence, narration and diagnostics. | Label original, edited and verification clocks. |
| **F09 — Timed transcript** | Timestamped speech text, with sentence/token precision qualified. | Read the mode, prerequisite and evidence qualification. |
| **F10 — Interaction events** | Clicks, input activity and navigation distinct from video pixels. | Read the mode, prerequisite and evidence qualification. |
| **F11 — DOM snapshot** | Serialized page structure at a moment; MHTML qualifies with limits. | MHTML is static structure, not replay. |
| **F12 — DOM replay** | DOM mutations reconstructed over time, not raw screen video. | Read the mode, prerequisite and evidence qualification. |
| **F13 — Accessibility tree** | Semantic accessibility roles and names exposed as a tree. | Roles/names distinct from DOM/OCR. |
| **F14 — Element grounding** | Selectors, bounds or hit targets connecting a reference to an element. | Capture-time match is not persistent identity. |
| **F15 — Component and source hints** | Framework component or source-file/line context; prerequisites explicit. | Framework and source-map prerequisites matter. |
| **F16 — Console and errors** | Console messages, exceptions, rejections or captured errors. | Read the mode, prerequisite and evidence qualification. |
| **F17 — Network metadata** | Request URL/method/status/timing and request identification. | Read the mode, prerequisite and evidence qualification. |
| **F18 — Network payloads** | Request/response headers or bodies; exact scope and filtering qualified. | Headers, bodies, protocols and caps differ. |
| **F19 — Runtime state debugging** | Inspect recorded variables, execution, stacks or time-travel state. | Read the mode, prerequisite and evidence qualification. |
| **F20 — Performance and trace correlation** | Performance profiles, trace IDs or backend correlation beyond failed requests. | Request duration alone is insufficient. |
| **F21 — Environment context** | Browser/OS/device/viewport/URL/runtime context. | Read the mode, prerequisite and evidence qualification. |
| **F22 — Repository and revision provenance** | Explicit repository, source ref/commit and relation to captured build. | A file hint/hash is not source/build attestation. |
| **F23 — Dependencies and build identity** | Version, lockfile/deployment/feature-flag context or custom build metadata. | API format version is not an app version. |
| **F24 — Visual annotations** | Arrows, region selection, drawn notes or overlays. | Read the mode, prerequisite and evidence qualification. |
| **F25 — Recording edits** | Cuts, trim, joins or rerecording with evidence timing behavior qualified. | Read the mode, prerequisite and evidence qualification. |
| **F26 — Text corrections** | Edit narration/transcript or descriptive notes; distinguish these. | Text edit is not canceled intent. |
| **F27 — Multiple-request extraction** | Separate a narrated batch into distinct actionable requests. | Manual baseline is a functional substitute. |
| **F28 — Request-to-evidence links** | A request refers to exact original quotes/times/frames/events. | Read the mode, prerequisite and evidence qualification. |
| **F29 — Revision and cancellation semantics** | Track superseded/canceled instructions and preserve final intent. | Media undo or execution cancel is different. |
| **F30 — Ambiguity review** | Human clarification/approval of uncertain requests and targets. | Read the mode, prerequisite and evidence qualification. |
| **F31 — Freshness and rerender handling** | Detect source/UI drift and reacquire targets without trusting stale IDs. | Evidence-cache freshness is not app freshness. |
| **F32 — Within-session search** | Find text/events/marks within a recording or session. | Read the mode, prerequisite and evidence qualification. |
| **F33 — Cross-session retrieval** | Search a recording/report library. | Read the mode, prerequisite and evidence qualification. |
| **F34 — OCR and personal memory** | OCR or searchable desktop/meeting memory beyond one review. | Read the mode, prerequisite and evidence qualification. |
| **F35 — Agent read tools** | MCP or equivalent agent-readable API for stored evidence. | MCP/API existence does not imply every evidence channel. |
| **F36 — Agent visual retrieval** | Agent can request useful screenshots/frames with timing or IDs. | Human embedded player is not a returned image. |
| **F37 — Structured portable handoff** | Markdown/JSON or equivalent evidence package outside vendor viewer. | Linked media may still expire or require service. |
| **F38 — Agent write tools** | Agents can comment/change reports or create evidence/tasks. | Read the mode, prerequisite and evidence qualification. |
| **F39 — Live browser inspection** | Agent can inspect/control current application for clarification or verification. | Read the mode, prerequisite and evidence qualification. |
| **F40 — Change and PR links** | Connect evidence/requests to changes, commit or PR references. | Read the mode, prerequisite and evidence qualification. |
| **F41 — Verification results** | Attach test results or before/after proof to changed behavior. | Reported success needs external acceptance. |
| **F42 — Issue-tracker integration** | Native tracker/task exports or two-way integration. | Read the mode, prerequisite and evidence qualification. |
| **F43 — Collaboration** | Comments, shared review, team library or presence. | Read the mode, prerequisite and evidence qualification. |
| **F44 — Task lifecycle** | Assignment/status/resolve/reopen or comparable request management. | Read the mode, prerequisite and evidence qualification. |
| **F45 — Local capture and storage** | Evidence can remain on the machine before explicit sharing. | Read the mode, prerequisite and evidence qualification. |
| **F46 — Local processing** | Transcription/analysis can run locally rather than mandatory cloud. | Server-local processing is not on-device. |
| **F47 — Self-hosted path** | User-controlled hosting or storage; scope and dependencies explicit. | Custom media bucket is not full selfhosting. |
| **F48 — Redaction and sensitive fields** | Pre-capture exclusion or sanitization across evidence channels. | All exported channels and originals matter. |
| **F49 — Retention and deletion** | Retention controls, deletion behavior and limits. | Deletion/archive/backups/trash differ. |
| **F50 — Access and sharing controls** | Auth, scopes, private/public defaults, revocation. | Read the mode, prerequisite and evidence qualification. |
| **F51 — Raw-asset export** | Download original video/images/transcript/data independently. | Read the mode, prerequisite and evidence qualification. |
| **F52 — Import recordings** | Accept existing externally recorded sessions or video. | Read the mode, prerequisite and evidence qualification. |
| **F53 — System audio and webcam** | System sound/meeting audio/camera capture qualified separately. | Credit system sound and camera separately. |
| **F54 — Custom telemetry** | SDK metadata, custom events, user context or instrumentation. | Read the mode, prerequisite and evidence qualification. |
| **F55 — Spatial review and canvas** | Scroll mosaics, spatial navigation or time-machine review. | Read the mode, prerequisite and evidence qualification. |
| **F56 — Session analytics** | Aggregate patterns, funnels, frustration signals or usage analytics. | Viewer analytics differ from production funnels. |
| **F57 — Test automation** | Agent-driven capture/test execution or generated tests. | Generated test is not executed test. |
| **F58 — AI diagnosis and triage** | AI summaries, root-cause hypotheses or prioritization, not proof. | Read the mode, prerequisite and evidence qualification. |
| **F59 — Cloud and AI data recipients** | Where evidence/derived text goes; AI-training claims qualified. | Descriptive data flow, not a privacy score. |
| **F60 — Narrated batch completion** | Whole workflow through understood requests, reviewed accepted changes. | No tested completion outcome in this research. |
| **F61 — Accessibility audits** | Check accessibility defects or standards; distinct from reading an accessibility tree. | Audit differs from AX-tree access. |
| **F62 — External intake and routing** | Let other people submit capture/feedback and route it to a workspace/project. | Read the mode, prerequisite and evidence qualification. |
| **F63 — Persistent agent memory and rules** | Cross-session rules, scoped instructions or editable memory controlling later agent context. | History retrieval differs from persistent rules. |
| **F64 — Agent work orchestration** | Queues, dispatch, stages or parallel work beyond a single evidence read. | Agent-reported progress is not correctness. |
| **F65 — Capture coverage and uncertainty disclosure** | Expose dropped/missing evidence, provenance or unsupported capture paths explicitly. | Known missing data is different from known absence. |
