# Shared feature model and product terminology

This guide harmonizes **65 meaningful features across15 products plus the screenshot/written baseline**. It preserves differences between recording modes, agent interfaces, hosting paths and release states. The full product/feature/vendor-term mapping is in `feature-evidence.csv`; this guide explains how to interpret it and gives a readable family comparison. Research date: **24October2026 America/Indianapolis**. All product behavior is documentation or selected public-source inspection, without hands-on testing.

## 1. The evidence model

A review has several independent kinds of evidence. Pixel video shows appearance and sequence. Narration states desired behavior. Frames and drawn marks direct attention. DOM/MHTML describes page structure; an accessibility tree supplies semantic roles/names. Selectors and bounds can locate targets at a moment. Framework hints may point to a source file. Events, logs and network requests explain behavior. Execution recordings can expose historical variables. None alone proves the final intended request, the current source revision, or a successful change.

The matrix therefore does not add these into a numerical feature score. A passive replay product can be excellent at historical failure analysis while being a poor primary intake for a narrated design batch. A clear written list can preserve final intent better than a richer capture while taking more human time. Compare total accepted work in the same task, then explain which evidence channels account for the difference.

### State and evidence rules

| Dimension | Values and interpretation |
|---|---|
| Capability | **supported:** within the stated scope; **partial:** restricted mode/coverage or substantial external step; **unsupported:** explicit negative or inspected implementation lacks it; **unknown:** reviewed sources do not establish it; **not-applicable:** concept does not apply to that row. |
| Evidence | **code-inspected:** relevant implementation read, not executed; **documented:** primary docs/reference; **marketing:** vendor positioning without enough behavioral specification; **inferred:** reasoned workflow conclusion, not product fact; **not-established:** scope consulted but conclusion unresolved. |
| Release | **shipped:** presented as available in current docs; **beta:** preview/experimental; **roadmap:** explicitly future; **unknown:** availability unresolved; **source-snapshot:** inspected personal source at pinned commit; **workflow-definition:** deliberately specified baseline. |
| Runtime validation | Every row is **no hands-on test**. A supported/documented/shipped cell is not measured reliability. Agent-generated dashboards, proof captions or successful API examples do not establish accepted code. |
| Unit of comparison | Product cells describe native or explicitly integrated capability with prerequisites. Baseline cells describe a manually assembled workflow. Manual request authoring is a partial functional substitute for automated extraction; writing effort remains visible. |

Operational rows **O01–O03** record cost/entitlement, platform/setup and service/data dependencies. They are not additional feature scores. Each matrix cell points to a stable evidence ID such as `CLIPY-F28`; that row supplies the source and vendor term. URLs separated by ` | ` are jointly necessary sources. Unknown rows cite the reviewed scope, not proof of absence.

## 2. Concise family comparison

| Feature family | Strong or distinctive examples | Boundary that changes this decision |
|---|---|---|
| Deliberate narrated capture | Context Recorder, Jam, Clipy, Vidmatic, ThinkRun, CaptureCat, Loom; BrowserStack and OpenReplay Spot add technical capture. | One long batch differs from a short single bug. Loom agent mode has a5 minute cap; Marker replay is not narrated pixel video. [L01], [M-REPLAY], [OR01] |
| Historical/passive evidence | Replay recorded execution; Sentry/OpenReplay DOM replay; Jam/BrowserStack/Marker pre-report buffers; screenpipe/Breadcrumb memory. | Pixels, DOM mutations, runtime state and event-driven desktop images are separate evidence models. [RP07], [SE11], [SP01], [B01] |
| Grounding and diagnosis | Context Recorder selectors/source hints; Replay DOM/runtime/source; browser diagnostics in Jam/Marker/BrowserStack/Clipy; Chrome live AX/network/performance. | A timestamped frame is not a selector, and a selector is not a source commit. Framework-specific introspection may not work equivalently for Solid. [CR-PAGE], [RP05], [CD02] |
| Editing and corrections | CaptureCat video composition/two clocks; Clipy transcript/revision edits; Loom transcript editing; Context Recorder nondestructive cuts/notes. | Undoing a cut, revising text and canceling a requirement are different operations. Original assets can survive edits. [C-TOOLS], [CL-MCP], [L09], [CR-EDITS] |
| Request extraction | Clipy AREC, Loom Action Plan, Vidmatic issue-intelligence; ThinkRun claims; screenpipe ticket playbook. | A plan/row is not final authoritative intent. Determine whether later corrections, duplicates and withdrawn requests survive. [CL-AREC], [L01], [V-ISSUE], [TR-LLMS], [SP09] |
| Retrieval and memory | Selective MCP frames/transcripts in direct tools; Clipy library memory; Breadcrumb scopes/rules; screenpipe history; Sentry search. | A human viewer, a text-only MCP response and a model-visible image tool are not equivalent. [J01], [B01], [SP03], [SE08] |
| Agent action and proof | Jam CLI, Clipy proof, Vidmatic workstreams/demos; Replay QA and Sentry Seer; Chrome live inspection. | Driver-attested proof and agent-reported done require the same external acceptance check. [J21], [CL-PROOF], [V-WORK], [RP13], [SE07] |
| Team intake and task handling | Marker widget/tracker/audits; BrowserStack SDK; Jam recording links; Vidmatic queues; Loom Jira; Clipy integrations. | More workflow management can add friction for one developer; one issue with many asks may suffice. [MCP-M], [B-SDK], [J01], [V-QUEUE], [L01], [CL-SHARE] |
| Local control and hosting | Context Recorder local; CaptureCat local/AGPL; ThinkRun local native host; screenpipe/Breadcrumb local history; OpenReplay selfhost. | Local media, local ASR, local model inference and selfhosting are separate decisions. [CR-CLOUD], [C-HOST], [TR-LOCAL], [SP05], [B04], [OR15] |
| Privacy and portability | Channel masks, payload sanitizers, access controls, retention and exports vary across all modes. | Blur is not removal from transcript/DOM/logs/originals. Downloadable video is not a full diagnostic archive. [CR-BUNDLE], [B-MASK], [M-LINKS], [CL-SEC] |
| Unique review surfaces | Context Recorder spatial scroll canvas; CaptureCat rendered contact sheets; Breadcrumb rules; Replay time travel; Marker accessibility scans. | Keep these distinct even when they are not decisive for the central narrated batch. [CR-README], [C-TOOLS], [B01], [RP07], [MCP-M] |

## 3. Shared taxonomy

The following definitions are the column contract. Qualifications in the CSV narrow a supported/partial state; they are not optional footnotes.

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

## 4. Vendor terms mapped to the shared model

The tables below give the decision-relevant mapping for every selected product. The evidence CSV contains the exhaustive65-row mapping for each, including unknowns and explicit negatives. Combining several terms in one row here does not imply their capture or access paths are identical.

### Context Recorder

| Product term → normalized feature | Preserved behavior and limitation |
|---|---|
| Marks/region shots → F03/F14/F28 | Deliberate evidence, not semantic request IDs; review marks inherit historical context without a new live DOM snapshot. [CR-SESSION], [CR-REVIEW] |
| Saved page/MHTML; component/source hints → F11/F15 | Static page archive and heuristic framework/dev attributes, not DOM replay or a full AX tree; Solid source hints require instrumentation. [CR-BG], [CR-PAGE] |
| Cuts/joins/notes → F25/F26 | Source and edited clocks, nondestructive originals; notes are omitted by inspected web/cloud Markdown despite local parity. [CR-EDITS], [CR-MD] |
| Canvas → F55; Find → F32 | Spatial scroll review is documented; native Find is distinct from missing web Find. Canvas analyzer itself was not in packet. [CR-README], [CR-VIEWER] |
| Cloud MCP → F35/F36/F65 | Six read tools; nearby thumbnails by default, separately exposed drawing data, optional exact adapter, skipped-page reporting. [CR-MCP], [CR-BUNDLE] |
| Product Grid export → F42/F44 | Session/mark nodes with retained external status; no request-to-PR/acceptance model. [CR-PGM] |

### Jam

| Product term → normalized feature | Preserved behavior and limitation |
|---|---|
| Video Jam/screenshot/Instant Replay → F01/F03/F04/F12 | Pixel recording, stills and retrospective DOM reconstruction differ. Instant Replay excludes video MCP tools. [J01], [J02], [J04] |
| User events/console/network/metadata → F10/F16–18/F54 | Rich diagnostic reads; exact mode and initialization limits apply. [J01], [J07], [J08] |
| Transcript/chapters/frame tools → F09/F32/F36 | Time-linked speech and selective images; frame extraction requires supported video backend. [J01] |
| Recording Links/Jam.js → F62 | External intake, with path-specific redaction/consent conditions; not ordinary local capture. [J01], [J13] |
| CLI proof/Playwright import → F40/F41/F57 | Capture evidence while the real check drives the connected browser; external driver/assertions remain necessary. [J21], [J22] |

### Clipy

| Product term → normalized feature | Preserved behavior and limitation |
|---|---|
| AREC → F27/F28/F37/F65 | Structured requests/plan, source quotes, keymoments and explicit gaps; open format does not make linked media permanently available. [CL-SPEC] |
| Key moments/click targets → F03/F14 | Coordinates/frames/labels, with Mac AX role/name when exposed; not full recorded DOM/AX trees. [CL-AGENT] |
| Browser diagnostics/full network detail → F16–18/F54 | Opt-in Chrome/agent paths; capped payloads accessible separately, excluded from AREC summary. [CL-BUG] |
| replace_transcript/expectedRevision → F26/F31 | Ingest API key/local path; stale text edit protection, not semantic canceled-request reconciliation or app-target freshness. [CL-MCP], [CL-SEC] |
| search_memory/imported context → F33/F34/F52 | Library retrieval across recorded and imported knowledge; not all-day passive capture. [CL-MCP] |
| Proof → F40/F41/F57 | Driver-attested media/captions; external tests establish correctness. Hosted OAuth lacks recording-ingest power. [CL-PROOF], [CL-SEC] |

### Vidmatic

| Product term → normalized feature | Preserved behavior and limitation |
|---|---|
| Issue intelligence → F03/F09/F28 | Timed speech, every mark and its image; arbitrary-frame retrieval is not inferred. [V-INTEL] |
| workstream_from_video/issue_intel → F27/F28/F40 | Agent-served skills create one issue with R1..Rn rows and agent-found file/line anchors; code was not independently scanned by the service. [V-ISSUE] |
| add_issue → F42 | Different skill can create up to10 issues; default one-recording/one-issue behavior is preserved. [V-MCP] |
| Agent Workstreams/dispatcher → F44/F62/F64 | Routing/stages/requirement reports and parallel lanes; state comes from the agent, including failures to report. [V-WORK], [V-QUEUE] |
| before_after/record/auto-implement-beta → F41/F57 | Agent-made demos and beta implementation orchestration; no independent acceptance guarantee. [V-DEMOS], [V-SKILLS] |

### ThinkRun

| Product term → normalized feature | Preserved behavior and limitation |
|---|---|
| Local mode/native host → F45/F46 | Free local capture/control without account; cloud analysis and configured-key action sync are separate. [TR-LOCAL], [TR-CLI] |
| Recordings/browserState → F01/F09/F10/F11/F16/F17 | Video, timed analysis, actions, optional DOM and diagnostics; analysis is preview. Metadata version is not proven app-build identity. [TR-REC] |
| claims/evidenceRefs/evidenceCoverageByClaim → F27/F28/F30/F65 | Confidence/coverage/contradictions distinguish narrated-only claims from corroboration. [TR-LLMS] |
| snapshot/evaluate/browser commands → F13/F14/F19/F39 | Current live AX/DOM and browser control, not historical execution replay. [TR-CLI] |
| prove-it/before-after/tasks → F41/F57/F64 | Agent workflows and execution status/cancel; not a withdrawn-request ledger. Public MIT skills do not establish selfhostable service. [TR-LLMS], [TR-SKILLS] |

### CaptureCat

| Product term → normalized feature | Preserved behavior and limitation |
|---|---|
| Local Whisper/OCR library → F09/F34/F45/F46 | On-device transcription and sampled OCR; transient text can be missed. [C-OCR], [C-MCP] |
| Source time/output time; render frames/contact sheets → F08/F25/F36 | Two clocks preserve edited evidence interpretation; up to16-frame contact sheet; output appearance may differ from original. [C-TOOLS] |
| Edit batches/undo/annotations → F24–26 | Video/edit validation is not semantic request revision handling. Manual blur retains originals. [C-TOOLS], [C-BLUR] |
| USB device capture → F07 | Tethered iPhone/iPad capture, not wireless touch telemetry. [C-MOBILE] |
| Selfhosting/custom S3 → F47/F59 | Full AGPL backend path versus media-only S3; transcript/comments/metadata may remain hosted in S3 mode. [C-HOST], [C-STORAGE] |

### Loom Record for Agent

| Product term → normalized feature | Preserved behavior and limitation |
|---|---|
| Action Plan → F27/F28/F42 | Separate tasks with instructions, quotes, keyframes/time; open beta, paid AI tier,5 minute agent-mode cap. [L01] |
| Selection/freehand → F03/F24 | Visual intent, not proven DOM identity/source mapping. Agent-mode camera disabled. [L01] |
| Developer context → F16/F17 | Console and request/response metadata; full response data still described as in development. [L02] |
| Loom MCP/Atlassian/TWG → F35/F38 | Metadata, transcripts, actions and selected writes; linked Atlassian site required. Arbitrary frames/raw diagnostic MCP parity unestablished. [L03] |
| Transcript/video editing and collaboration → F25/F26/F43 | Broader product features remain distinct from regeneration/cancellation semantics in agent mode. [L05], [L09] |

### Marker.io

| Product term → normalized feature | Preserved behavior and limitation |
|---|---|
| Session Replay Videos → F04/F12 | Up to2.5 minutes DOM reconstruction, not raw mic narration; canvas/WebGL/ShadowDOM limitations. [M-REPLAY] |
| Console/network recorder → F16–18 | Rich fetch/XHR headers/bodies; other transport classes not automatically included. [M-NET], [M-CONSOLE] |
| MCP → F35/F36/F38/F44 | Issues/context/log entries/screenshots/status; underlying capture still plan-gated. [MCP-M] |
| Accessibility monitoring → F61 | Audits/issues, not an accessibility-tree export. [MCP-M] |
| Widget/tracker sync/CSV → F42/F51/F62 | Integrated intake and task workflow; hosted diagnostic links are not complete attached archives. [M-LINKS], [M-CSV] |

### BrowserStack Bug Capture

| Product term → normalized feature | Preserved behavior and limitation |
|---|---|
| Screen recording/Replay → F01/F02/F04/F12 | Narrated pixels versus two-minute rrweb buffer; trim documented for Replay, not every video. [B-FAQ], [B-INSTANT] |
| Developer tools → F10/F16–18 | Console/storage/network and selected-entry links; capped text bodies, transport limits. [B-DEV], [B-NET] |
| Markers/comments → F03/F43 | Human-added organization and discussion, not multiple-request extraction. [B-CUSTOM] |
| E2E Helper → F57 | Starter scripts for test frameworks; engineer/agent supplies assertions and runs them. [B-DEV] |
| SDK/redaction → F48/F62 | Intake and metadata scrubbing; screenshots/video explicitly outside redaction coverage. Platform-wide MCP cannot be assigned to this product without evidence. [B-SDK], [B-MASK] |

### Replay.io

| Product term → normalized feature | Preserved behavior and limitation |
|---|---|
| Replay Browser/time travel → F19 | Historical execution/state, not just a video or mutation player; browser compatibility conditions apply. [RP02], [RP07] |
| Debugging MCP → F11/F14–19/F35/F36 | Selective screenshots, elements, sources, execution and network data; React-specific features are not Solid component parity. [RP05] |
| Replay QA reports → F28/F40–42/F44 | Evidence-linked failures, source causal chains, tracker/PR/version context and status; QA does not generate patch. [RP13] |
| Journeys/polish passes → F41/F57/F61/F64 | Runs/reruns, functional/visual/accessibility checks; separate QA API/auth from debugger. [RP12], [RP14] |

### Sentry

| Product term → normalized feature | Preserved behavior and limitation |
|---|---|
| Web/mobile Replay → F07/F12/F20 | Web DOM reconstruction and native mobile capture are distinct; correlate production errors/traces/releases. [SE11], [SE14], [SE01] |
| search_replays/get_replay_details → F33/F35 | Public-source MCP projection is text and capped activity/errors/traces, without frame images. Source existence does not prove deployed availability. [SE08], [SE09] |
| CLI replay download → F37/F51 | Current rrweb JSON export, not original web pixel video; separate rendering can reconstruct it. [SE15], [SE16] |
| Seer → F40/F41/F58/F64 | Diagnosis, plan, PR and bounded checks on issues; not narrated design-batch intake. [SE07] |
| User Feedback → F62; mutation warning → F65 | Feedback may attach buffered replay; cap warning exposes one coverage failure, not universal completeness. [SE01], [SE03] |

### OpenReplay

| Product term → normalized feature | Preserved behavior and limitation |
|---|---|
| Session Replay → F05/F12/F16–20/F56 | Instrumented passive sessions with analytics; SDK network/sanitization settings are specific to this path. [OR05], [OR07], [OR08] |
| Spot → F01/F02/F10/F16–18 | Deliberate Chromium screen/mic and diagnostics, project-independent and usable without app SDK. [OR01] |
| MCP/replay player → F35/F36 | Session/analytics retrieval and human player; Spot retrieval/model-visible images remain unproven. [OR03] |
| E2E export → F57 | Generated action scripts are not executed acceptance checks. [OR09] |
| Selfhost/AI → F47/F58/F59 | Selfhost core/MCP exists; built-in AI currently Cloud Serverless, with private compute future. [OR04], [OR15] |

### screenpipe

| Product term → normalized feature | Preserved behavior and limitation |
|---|---|
| Screen/audio history → F05/F06/F09/F34 | Event-driven screenshots, accessibility/OCR and speech; exported MP4 does not imply continuous original video. [SP01] |
| Agent tools/MCP → F13/F33/F35/F36 | History search, frame/context retrieval and accessibility content; no assumed browser logs/payloads. [SP02], [SP03] |
| Meeting-to-engineering-tickets → F27/F28/F30 | Prompted extraction with sources/open questions/acceptance; later engineering must reproduce and verify. [SP09] |
| Meeting notes/scheduled prompts → F26/F63 | Edit matching existing notes and persistent task instructions; historical audio/transcript import not supported by meeting guide. [SP08] |
| Local models/privacy filter/sync → F45–50/F59 | Separate local/cloud/enclave/sync data paths; source-commercial licensing and team sharing require qualification. [SP05], [SP06], [SP10] |

### Innerloop Breadcrumb

| Product term → normalized feature | Preserved behavior and limitation |
|---|---|
| Moments/chapters/grab → F08/F32/F34/F35 | Historical window tree and screen-text boxes; neither full DOM nor browser AX parity. [B01] |
| screen_get/screen_open → F36 | Explicitly in development with overdue ETA; actual image-tool release unresolved, despite current text tools. [B01] |
| Meeting tools → F09/F33 | Local meeting recall; Zoom current, other meeting-platform support future in reviewed docs. [B03] |
| Memories/scopes/rules/AI sessions → F38/F63 | Editable persistent context and coding-agent continuity; not immutable request/evidence provenance. [B01] |
| Local encrypted store → F45/F46/F49/F59 | Local models/store with downloads; audio deleted after transcription; selected cloud AI receives queried context. [B04], [B05] |

### Chrome DevTools MCP

| Product term → normalized feature | Preserved behavior and limitation |
|---|---|
| take_snapshot → F13/F14/F31 | Current AX tree and ephemeral target IDs; reacquire after rerender. Not a recorded DOM snapshot by itself. [CD02] |
| Screenshot/evaluate/network/performance → F16–20/F36/F39 | Live inspection and control; historical narrated intent comes from another source. [CD02] |
| screencast_start/stop → F01 | MP4 capture is experimental, requires explicit flag and ffmpeg; no established narration/transcript pipeline. [CD08] |
| Emulation/auto-connect → F07/F21/F39 | Host Chrome emulation differs from native device/other engine; existing profile access needs explicit browser permission. [CD04], [CD05] |
| Lighthouse/redact headers → F61/F48 | Scoped audits/redaction; screenshot pixels/body secrets require separate review; telemetry/CrUX controls are separate. [CD06], [CD08], [CD01] |

### Screenshots plus written instructions

| Baseline term → normalized feature | Preserved behavior and limitation |
|---|---|
| Numbered requests and image references → F03/F27/F28 | Human supplies decomposition and final wording; count authoring/revision effort. |
| Explicit canceled/superseded text → F29/F30 | Human resolves intent deliberately; no automated interpretation is credited. |
| Files/attachments → F35–37/F45/F51 | Portable, selected evidence; no missing video frame can be recovered afterward. |
| Checklist/PR/test links → F40/F41/F44 | Manually or agent-maintained outcome record; same independent acceptance gate as every product. |

## 5. Important differences that a checkbox would hide

**Time:** recording time, original source time, edited output time, transcript token time, browser event time and current verification time need labels. Context Recorder joins/remaps time and flattens cloud output; CaptureCat explicitly exposes source/output clocks; Clipy distinguishes speech from driver captions. A future adapter should retain original evidence identifiers and transforms instead of overwriting old times with a new movie offset. [CR-EDITS], [CR-BUNDLE], [C-TOOLS], [CL-SPEC]

**Grounding:** pixels/click coordinates → DOM selector or AX node → source hint → current repository file are increasingly different assertions. A recorded selector can match the wrong instance after rerender. A file hint can reference transformed or stale source. A code-search result produced by an agent is an inference, even if a product displays it beside the frame. Preserve source of the assertion and refresh the current target before changing it. [CR-PAGE], [V-ISSUE], [CD02]

**Corrections:** a transcript edit may fix recognition; a note may add intent; a later spoken instruction may withdraw earlier work. Keeping text revisions is necessary for some workflows but does not automatically decide precedence. The review should produce explicit final requests, canceled/superseded state and unresolved questions. The model is a proposal, not evidence that every vendor lacks a configurable equivalent. [CL-MCP], [CR-MD], [V-INTEL]

**Proof:** a movie can show a successful path while missing a failed edge condition. A check exit code can be from the wrong browser. A workstream card can reflect an agent's report. A shared acceptance checklist tied to the tested head/build is the common outcome model; vendor proof is supporting evidence. [J21], [CL-PROOF], [V-WORK]

**Privacy:** cuts, masks, crops, SDK filters, local processing, encryption, access scope, expiring links and deletion affect different channels. A recorder can preserve unredacted originals while showing a blurred derivative. A local connector can deliver sensitive output to a remote model. A custom bucket can store video while metadata remains hosted. Avoid collapsing them into “private.” [CR-BUNDLE], [C-STORAGE], [CL-LOCAL], [OR08]

## 6. Complementary combinations and integration boundaries

| Combination | Useful division of responsibility | First boundary to prove |
|---|---|---|
| Jam + existing coding agent + Chrome/Playwright driver | Diagnostic capture, selective evidence, code implementation, current-app proof. | The proof command and recorder observe the same browser/build; every request has an acceptance result. [J21], [CD02] |
| Clipy AREC + agent + small request sidecar | Native extracted requests/evidence with explicit final intent/acceptance additions. | Preserve AREC source times, private access and captions' provenance; do not duplicate its format without need. [CL-SPEC], [CL-SEC] |
| Vidmatic + repository agent + independent checks | One issue/many asks, agent code anchors, stage/demo reporting. | Reviewer resolves later instruction conflicts; CI/report status agrees with real acceptance. [V-ISSUE], [V-WORK] |
| Context Recorder or CaptureCat + existing agent/browser tools | Local capture/control and ordinary files, with external decomposition/verification. | Full transcript and notes reach the agent; edit clocks and source files remain resolvable. [CR-MCP], [CR-MD], [C-TOOLS] |
| ThinkRun local capture/browser + cloud analysis only when needed | Free local evidence/control, optional richer AI interpretation. | Confirm API-key synchronization and exact cloud recipients before treating a run as local. [TR-CLI], [TR-PRIV] |
| Deliberate narration + Replay/Sentry/OpenReplay | Intent from the review, diagnostic explanation from runtime/production evidence. | Link exact reproduction/session, app build and time; avoid implying a related URL proves the same execution. [RP05], [SE01], [OR03] |
| OpenReplay Spot + OpenReplay MCP | Potential single selfhosted capture/replay ecosystem. | Demonstrate Spot transcript/frame availability through the chosen agent; current project/MCP scope leaves this unresolved. [OR01], [OR03] |
| Breadcrumb/screenpipe + deliberate capture | Recover forgotten context and decisions while using explicit review for authoritative requests. | Distinguish remembered discussion from final instruction; limit retrieved history to relevant evidence. [B01], [SP09] |

A minimal proposed handoff record can use one existing file with: request ID; final wording; status; original evidence URLs/local paths and time domains; unresolved questions; captured and current source/build facts with provenance; change reference; check command/result; observed evidence; human acceptance. Begin with existing vendor exports and agent workflow. An adapter is justified only when an actual boundary causes repeated loss or extra effort.

## Sources

URLs below were accessed24October2026 America/Indianapolis; exact code claims use pinned Context Recorder links. Full claim locators and evidence/release states are in `feature-evidence.csv`.

[B-CUSTOM]: https://www.browserstack.com/docs/testing-toolkit/bug-capture/reports/customize "Bug Capture markers/comments/deep links; accessed 2026-10-24"
[B-DEV]: https://www.browserstack.com/docs/testing-toolkit/bug-capture/reports/developer-tools "Bug Capture synchronized logs and E2E helper; accessed 2026-10-24"
[B-FAQ]: https://www.browserstack.com/docs/live/bug-capture/FAQ "Bug Capture FAQ with explicit limits; accessed 2026-10-24"
[B-INSTANT]: https://www.browserstack.com/docs/testing-toolkit/bug-capture/working/browser-extension/replays "Bug Capture rolling two-minute buffer; accessed 2026-10-24"
[B-MASK]: https://www.browserstack.com/docs/testing-toolkit/bug-capture/reports/sensitive-info "Bug Capture redaction boundaries; accessed 2026-10-24"
[B-NET]: https://www.browserstack.com/docs/testing-toolkit/bug-capture/troubleshoot/network-recording "Bug Capture network payload limits; accessed 2026-10-24"
[B-SDK]: https://www.browserstack.com/docs/testing-toolkit/bug-capture/working/web-sdk/options "Bug Capture SDK options and data hooks; accessed 2026-10-24"
[B01]: https://innerloop.works/breadcrumb/mcp "Breadcrumb MCP; accessed 2026-10-24"
[B03]: https://innerloop.works/breadcrumb "Breadcrumb product; accessed 2026-10-24"
[B04]: https://innerloop.works/privacy "Innerloop privacy; accessed 2026-10-24"
[B05]: https://innerloop.works/terms "Innerloop terms; accessed 2026-10-24"
[C-BLUR]: https://capturecat.so/docs/editing/privacy "CaptureCat visual blur limitations; accessed 2026-10-24"
[C-HOST]: https://capturecat.so/docs/self-hosting "CaptureCat AGPL self-hosting architecture; accessed 2026-10-24"
[C-MCP]: https://capturecat.so/docs/ai-agents "CaptureCat MCP overview and safety; accessed 2026-10-24"
[C-MOBILE]: https://capturecat.so/docs/recording/iphone-and-ipad "CaptureCat tethered iOS capture; accessed 2026-10-24"
[C-OCR]: https://capturecat.so/docs/library "CaptureCat local sampled OCR search; accessed 2026-10-24"
[C-STORAGE]: https://capturecat.so/docs/custom-storage "CaptureCat S3 storage boundary; accessed 2026-10-24"
[C-TOOLS]: https://capturecat.so/docs/ai-agents/tools "CaptureCat MCP tools and two clocks; accessed 2026-10-24"
[CD01]: https://github.com/ChromeDevTools/chrome-devtools-mcp "Chrome DevTools MCP repository; accessed 2026-10-24"
[CD02]: https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/tool-reference.md "Chrome DevTools MCP tools; accessed 2026-10-24"
[CD04]: https://developer.chrome.com/docs/devtools/agents/use-cases/emulation "Chrome emulation; accessed 2026-10-24"
[CD05]: https://developer.chrome.com/docs/devtools/agents/use-cases/auto-connect "Chrome auto-connect; accessed 2026-10-24"
[CD06]: https://developer.chrome.com/docs/devtools/agents/use-cases/lighthouse-audit "Chrome Lighthouse agent audits; accessed 2026-10-24"
[CD08]: https://developer.chrome.com/docs/devtools/agents/get-started/configuration "Chrome DevTools MCP configuration; accessed 2026-10-24"
[CL-AGENT]: https://clipy.online/for-agents "Clipy for agents; accessed 2026-10-24"
[CL-AREC]: https://clipy.online/docs/arec "Clipy AREC; accessed 2026-10-24"
[CL-BUG]: https://clipy.online/docs/bug-capture "Clipy bug capture; accessed 2026-10-24"
[CL-LOCAL]: https://clipy.online/docs/local-recording "Clipy local recording; accessed 2026-10-24"
[CL-MCP]: https://clipy.online/docs/mcp "Clipy MCP; accessed 2026-10-24"
[CL-PROOF]: https://clipy.online/docs/proof "Clipy proof of agent work; accessed 2026-10-24"
[CL-SEC]: https://clipy.online/docs/security "Clipy agent security; accessed 2026-10-24"
[CL-SHARE]: https://clipy.online/docs/teams/sharing "Clipy sharing; accessed 2026-10-24"
[CL-SPEC]: https://clipy.online/spec "AREC 1.3 specification; accessed 2026-10-24"
[CR-BG]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/extension/background.js "extension/background.js; accessed 2026-10-24"
[CR-BUNDLE]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Cloud/CloudBundle.swift "Sources/ContextRecorder/Cloud/CloudBundle.swift; accessed 2026-10-24"
[CR-CLOUD]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/docs/cloud-sessions.md "docs/cloud-sessions.md; accessed 2026-10-24"
[CR-EDITS]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Library/Edits.swift "Sources/ContextRecorder/Library/Edits.swift; accessed 2026-10-24"
[CR-MCP]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/cloud/src/mcp/server.ts "cloud/src/mcp/server.ts; accessed 2026-10-24"
[CR-MD]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/cloud/src/markdown.ts "cloud/src/markdown.ts; accessed 2026-10-24"
[CR-PAGE]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/extension/page.js "extension/page.js; accessed 2026-10-24"
[CR-PGM]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Export/PgmExport.swift "Sources/ContextRecorder/Export/PgmExport.swift; accessed 2026-10-24"
[CR-README]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/README.md "README.md; accessed 2026-10-24"
[CR-REVIEW]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Library/Review.swift "Sources/ContextRecorder/Library/Review.swift; accessed 2026-10-24"
[CR-SESSION]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Session.swift "Sources/ContextRecorder/Session.swift; accessed 2026-10-24"
[CR-VIEWER]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/scripts/viewer.html "scripts/viewer.html; accessed 2026-10-24"
[J01]: https://jam.dev/docs/jam-mcp "Jam MCP; accessed 2026-10-24"
[J02]: https://jam.dev/docs/video "Jam video recording; accessed 2026-10-24"
[J04]: https://jam.dev/docs/instant-replay "Jam Instant Replay; accessed 2026-10-24"
[J07]: https://jam.dev/docs/devtools "Jam DevTools; accessed 2026-10-24"
[J08]: https://jam.dev/docs/custom-logs "Jam custom logs; accessed 2026-10-24"
[J13]: https://jam.dev/docs/auto-blur "Jam auto-blur; accessed 2026-10-24"
[J21]: https://jam.dev/docs/cli-e2e-tests "Jam end-to-end tests; accessed 2026-10-24"
[J22]: https://jam.dev/docs/cli-fix-a-bug "Jam fix from link; accessed 2026-10-24"
[L01]: https://support.atlassian.com/loom/docs/record-for-agent/ "Loom Record for agent; accessed 2026-10-24"
[L02]: https://support.atlassian.com/loom/docs/capture-console-and-network-logs/ "Loom bug-report logs; accessed 2026-10-24"
[L03]: https://support.atlassian.com/loom/docs/loom-mcp-tools/ "Loom MCP; accessed 2026-10-24"
[L05]: https://support.atlassian.com/loom/docs/download-your-loom-video/ "Loom download video; accessed 2026-10-24"
[L09]: https://support.atlassian.com/loom/docs/correct-your-transcript/ "Loom transcript correction; accessed 2026-10-24"
[M-CONSOLE]: https://help.marker.io/en/articles/1669763-console-logs "Marker.io console capture; accessed 2026-10-24"
[M-CSV]: https://help.marker.io/en/articles/7003114-export-issues-to-csv "Marker.io CSV export; accessed 2026-10-24"
[M-LINKS]: https://help.marker.io/en/articles/14430683-why-are-console-logs-network-requests-and-replays-linked-instead-of-attached "Marker.io integration attachment boundary; accessed 2026-10-24"
[M-NET]: https://help.marker.io/en/articles/6562135-network-requests "Marker.io network recorder; accessed 2026-10-24"
[M-REPLAY]: https://help.marker.io/en/articles/6673880-session-replay-videos "Marker.io session replay limitations; accessed 2026-10-24"
[MCP-M]: https://help.marker.io/en/articles/14034657-mcp-integration-model-context-protocol "Marker.io MCP tool reference; accessed 2026-10-24"
[OR01]: https://docs.openreplay.com/en/spot/ "OpenReplay Spot documentation; accessed 2026-10-24"
[OR03]: https://docs.openreplay.com/en/mcp/capabilities/ "OpenReplay MCP capabilities; accessed 2026-10-24"
[OR04]: https://docs.openreplay.com/en/mcp/setup/ "OpenReplay MCP setup; accessed 2026-10-24"
[OR05]: https://docs.openreplay.com/en/session-replay/ "OpenReplay session replay; accessed 2026-10-24"
[OR07]: https://docs.openreplay.com/en/sdk/network-options/ "OpenReplay network options; accessed 2026-10-24"
[OR08]: https://docs.openreplay.com/en/sdk/sanitize-data/ "OpenReplay data sanitization; accessed 2026-10-24"
[OR09]: https://docs.openreplay.com/en/session-replay/generate-e2e-test/ "OpenReplay E2E export; accessed 2026-10-24"
[OR15]: https://docs.openreplay.com/en/ai/ "OpenReplay AI; accessed 2026-10-24"
[RP02]: https://docs.replay.io/reference/replay-runtimes/replay-chrome "Replay Browser; accessed 2026-10-24"
[RP05]: https://docs.replay.io/reference/replay-mcp/tools "Replay MCP tool reference; accessed 2026-10-24"
[RP07]: https://docs.replay.io/reference/time-travel/how-does-time-travel-work "Replay time travel mechanism; accessed 2026-10-24"
[RP12]: https://docs.replay.io/reference/replay-qa/api "Replay QA API; accessed 2026-10-24"
[RP13]: https://docs.replay.io/reference/replay-qa/bug-reports "Replay QA bug reports; accessed 2026-10-24"
[RP14]: https://docs.replay.io/reference/replay-qa/polish-passes "Replay QA polish passes; accessed 2026-10-24"
[SE01]: https://github.com/getsentry/sentry-docs/blob/d9269600b50af1e957e32799d5618d53812c7734/docs/product/session-replay/replay-details.mdx "Sentry Replay Details; accessed 2026-10-24"
[SE03]: https://github.com/getsentry/sentry-docs/blob/d9269600b50af1e957e32799d5618d53812c7734/docs/platforms/javascript/common/session-replay/configuration.mdx "Sentry Replay Configuration; accessed 2026-10-24"
[SE07]: https://github.com/getsentry/sentry-docs/blob/d9269600b50af1e957e32799d5618d53812c7734/docs/product/ai-in-sentry/seer/autofix/index.mdx "Sentry Seer Autofix; accessed 2026-10-24"
[SE08]: https://github.com/getsentry/toolkit/blob/8461c2ac3fbf5638639442fd3885b13aa065ab78/packages/mcp-core/src/tools/catalog/get-replay-details.ts "Sentry MCP replay detail implementation; accessed 2026-10-24"
[SE09]: https://github.com/getsentry/toolkit/blob/8461c2ac3fbf5638639442fd3885b13aa065ab78/packages/mcp-core/src/tools/catalog/search-replays.ts "Sentry MCP replay search implementation; accessed 2026-10-24"
[SE11]: https://www.sentry.help/en/articles/13964404-session-replay-faq-web "Sentry web replay FAQ; accessed 2026-10-24"
[SE14]: https://sentry.io/changelog/session-replay-for-mobile-is-now-generally-available/ "Sentry mobile replay GA; accessed 2026-10-24"
[SE15]: https://sentry.io/changelog/sentry-cli-0-47-0 "Sentry CLI 0.47 changelog; accessed 2026-10-24"
[SE16]: https://cli.sentry.dev/commands/replay/ "Sentry CLI replay commands; accessed 2026-10-24"
[SP01]: https://docs.screenpipe.com/architecture "Screenpipe architecture; accessed 2026-10-24"
[SP02]: https://docs.screenpipe.com/mcp-server "Screenpipe MCP; accessed 2026-10-24"
[SP03]: https://docs.screenpipe.com/claude-code "Screenpipe Claude Code tools; accessed 2026-10-24"
[SP05]: https://docs.screenpipe.com/privacy-data-flow "Screenpipe privacy data flow; accessed 2026-10-24"
[SP06]: https://docs.screenpipe.com/privacy-filter "Screenpipe privacy filter; accessed 2026-10-24"
[SP08]: https://docs.screenpipe.com/meeting-intelligence "Screenpipe meeting intelligence; accessed 2026-10-24"
[SP09]: https://docs.screenpipe.com/meeting-to-engineering-tickets "Screenpipe engineering-ticket playbook; accessed 2026-10-24"
[SP10]: https://github.com/screenpipe/screenpipe/blob/main/README.md "Screenpipe source README; accessed 2026-10-24"
[TR-CLI]: https://thinkrun.ai/docs/cli "ThinkRun CLI; accessed 2026-10-24"
[TR-LLMS]: https://thinkrun.ai/llms.txt "ThinkRun machine-readable docs; accessed 2026-10-24"
[TR-LOCAL]: https://thinkrun.ai/docs/local-mode "ThinkRun local mode; accessed 2026-10-24"
[TR-PRIV]: https://thinkrun.ai/privacy "ThinkRun privacy; accessed 2026-10-24"
[TR-REC]: https://thinkrun.ai/docs/recordings "ThinkRun recordings API; accessed 2026-10-24"
[TR-SKILLS]: https://github.com/dundas/thinkrun "ThinkRun skills source; accessed 2026-10-24"
[V-DEMOS]: https://www.vidmatic.ai/docs/demos "Vidmatic before/after and demo dependencies; accessed 2026-10-24"
[V-INTEL]: https://www.vidmatic.ai/docs/what-your-agent-receives "Vidmatic timed transcript and mark images; accessed 2026-10-24"
[V-ISSUE]: https://www.vidmatic.ai/docs/recording-to-issue "Vidmatic multi-ask issue workflow; accessed 2026-10-24"
[V-MCP]: https://www.vidmatic.ai/docs/mcp "Vidmatic exact MCP tools and permissions; accessed 2026-10-24"
[V-QUEUE]: https://www.vidmatic.ai/docs/change-request-queue "Vidmatic queued request routing; accessed 2026-10-24"
[V-SKILLS]: https://www.vidmatic.ai/docs/skills "Vidmatic skills and beta status; accessed 2026-10-24"
[V-WORK]: https://www.vidmatic.ai/docs/agent-workstreams "Vidmatic workstream reporting limitations; accessed 2026-10-24"
