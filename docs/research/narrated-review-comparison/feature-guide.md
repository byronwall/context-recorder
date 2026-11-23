# Compare features by their behavior

Use the [taxonomy](feature-taxonomy.md) for 65 feature definitions.
The [comparison CSV](feature-comparison.csv) retains every product's term, qualification, evidence state, release state, and source.
The [product CSV](products.csv) records practical costs and dependencies.
No product was tested. Supported means the cited source establishes the stated scope, not measured reliability.

## Shared model

| Feature family | Common concepts | Differences to preserve |
| --- | --- | --- |
| Capture, F01–F10 | Video, narration, marks, replay buffers, desktop/mobile scope, timing, transcript, actions | Pixel video, DOM reconstruction, and event-based screenshots preserve different evidence. |
| Grounding, F11–F23 | DOM, accessibility, targets, source hints, console/network, runtime, traces, environment, source/build | Coordinates are not selectors. Selectors are not source commits. A source hint does not prove the running build. |
| Review and intent, F24–F31 | Drawings, edits, text corrections, request extraction, evidence links, cancellation, ambiguity, freshness | Correcting a transcript differs from withdrawing a request. Media undo does not establish final intent. |
| Retrieval and agent work, F32–F44 | Search, memory, read/write tools, frames, portable output, live browser, changes, checks, trackers | A human player does not prove model-visible images. Reported completion differs from accepted behavior. |
| Control and portability, F45–F52 | Local capture/processing, self-hosting, redaction, deletion, access, export/import | Local video can coexist with cloud text processing. Custom storage does not establish full self-hosting. |
| Additional capabilities, F53–F65 | Audio/camera, telemetry, canvas, analytics, tests, triage, recipients, audits, routing, rules, orchestration, gaps | Generated tests differ from executed checks. Accessibility audits differ from accessibility-tree access. |

F60 records whole-workflow coverage. Its state does not claim a successful comparative run.
Some broad concepts need qualifiers. F53 separates system audio from camera in each record.
F31 distinguishes transcript revision checks from current application freshness in each record.

## Vendor terms and distinct strengths

| Product terminology | Shared meaning | Distinction |
| --- | --- | --- |
| Context Recorder marks, saved pages, canvas, cloud MCP | Deliberate evidence, static MHTML, spatial review, selective retrieval | A mark can contain several asks. A later review mark has no new live page snapshot. |
| Jam video, Instant Replay, frame tools, CLI proof | Pixel capture, retrospective DOM replay, selective visual reads, recorded checks | Video-only tools are unavailable for Instant Replay. The check must drive the recorded browser. |
| Clipy AREC, key moments, transcript revisions, proof | Structured requests and evidence, text correction, driver-produced proof | Revision guards protect text edits. They do not establish canceled-request semantics or build identity. |
| Vidmatic issue intelligence, workstreams, demos | Timed asks with agent-found anchors, task stages, proof links | One recording produces one issue with several asks. Status comes from the agent. |
| ThinkRun claims, coverage, local host, browser commands | Evidence-linked interpretation, capture gaps, local control, live inspection | Cloud analysis is preview. Execution cancellation differs from withdrawal of a spoken request. |
| CaptureCat source/output time, contact sheets, local OCR | Edited evidence clocks, selected frames, searchable screen text | Preserve both time domains. Self-hosting and a custom media bucket have different scopes. |
| Loom Action Plan, selection, agent prompt | Tasks with quotes, images, and times | Five-minute agent recordings can fragment a long review. Drawing does not establish source mapping. |
| Marker.io Session Replay Videos, widget, MCP | Reconstructed DOM, external intake, issue reads and writes | Replay is not raw narrated video. Hosted diagnostic links are not a complete portable archive. |
| BrowserStack Replay, Developer Tools, E2E Helper | Retrospective replay, technical logs, starter test scripts | Generated scripts still need assertions and execution. Metadata masking does not cover every pixel. |
| Replay Browser, Debugging MCP, Replay QA | Recorded execution, historical source/state, separate QA reports and reruns | Debugging and QA have distinct interfaces. Intended changes still need narration or writing. |
| Sentry Replay, Seer, replay downloads | Production sessions, diagnosis/change assistance, rrweb export | rrweb data is not original pixel video. Text agent output differs from frame retrieval. |
| OpenReplay Session Replay, Spot, MCP | Passive replay, deliberate capture, session/analytics access | Spot is not project-bound. Spot-to-MCP visual access remains unresolved. |
| screenpipe history, frame tools, ticket playbook | Event-based screen/audio memory, retrieval, prompted request extraction | A playbook does not prove correct extraction or accepted fixes. |
| Breadcrumb moments, chapters, grab, scopes/rules | Window/text history, context retrieval, persistent agent guidance | Text boxes are not DOM parity. Image tools retain a development label. |
| Chrome DevTools snapshots, network, performance, screencast | Live accessibility targets, diagnostics, current-app checks, experimental video | Target handles need refreshing after interface changes. Historical intent stays external. |
| Written requests, screenshots, checklist | Human decomposition, selected evidence, explicit acceptance | Credit clear final wording. Charge all thinking, selection, writing, and correction time. |

The CSV attaches feature-specific sources to these mappings.
Decisive examples were also checked against [Jam](https://jam.dev/docs/jam-mcp),
[Clipy](https://clipy.online/spec), [Vidmatic](https://www.vidmatic.ai/docs/recording-to-issue),
[Loom](https://support.atlassian.com/loom/docs/record-for-agent/), and [Breadcrumb](https://innerloop.works/breadcrumb/mcp).

## Useful combinations

| Combination | Purpose | Boundary to check |
| --- | --- | --- |
| Jam plus existing coding agent and browser tools | Diagnostics, implementation, current-app checks | Test and recorder observe the same browser and build. |
| Clipy plus existing agent and a request list | Structured evidence with reviewed final intent | Linked media remains accessible. Corrections and canceled asks remain explicit. |
| Vidmatic plus repository agent and independent checks | Several asks in one issue, change links, stage reports | Agent status agrees with observed acceptance. |
| Context Recorder or CaptureCat plus existing agent | Local capture, ordinary files, external interpretation | Complete transcript and typed notes reach the agent. Edited times remain clear. |
| Deliberate narration plus Replay, Sentry, or OpenReplay | Intended change plus focused runtime evidence | Both sources refer to the relevant session and build. |
| Breadcrumb or screenpipe plus deliberate review | Recover forgotten context and decisions | Historical discussion does not silently replace final instructions. |

Do not build a universal adapter before a transfer fails in practice.
Start with original evidence links, final wording, change references, check results, and human acceptance in an ordinary file.

## Selection coverage and gaps

Pro also screened LogRocket, Playwright MCP, BugHerd, Usersnap, Gleap, Screentack, Rec, and Cap.
It reserved slots for closer narrated-agent products and representative runtime, memory, and live-inspection alternatives.
This is not a claim that the excluded tools lack MCP or useful capabilities.
Pro reported short recording limits for BugHerd and Usersnap; these were not independently checked during reconciliation.
Use an already-adopted excluded product when it removes setup or integration work.

There are 244 unknown feature assessments out of 1,040, about 23.5%.
Unknowns particularly affect availability, capture modes, agent projections, and final cancellation/acceptance behavior.
The comparison preserves them instead of treating them as unsupported.
Eight screened alternatives sit outside the 15-product comparison cap.
