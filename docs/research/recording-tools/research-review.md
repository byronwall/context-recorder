# Recording tools: research and repository gaps

Research cutoff: October 13, 2026. Independent checks: October 14, 2026.
Repository baseline: `6c74158ca96abd36819d2a58f75bacdc44107bb0`.

The strongest proposal is to improve the existing local review workflow. Fix output accuracy before adding another editor.
Search and selected handoff deserve a small value test. Reuse speech, image, and video tools for occasional specialist tasks.
This recommendation assumes personal product and bug review. Byron has not yet selected that outcome over communication or dictation.

Start with the [shape brief](../../intent/recording-tools/shape-brief.md).
The [full report](pro-output/recording-tools-report.md) contains 32 products and 18 detailed profiles.
The [matrix](pro-output/recording-tools-matrix.csv) compares 46 features across six categories.
The [gap analysis](pro-output/recording-tools-gap-analysis.md) records 16 findings with source anchors and rejection tests.

## Product landscape

Each product appears once. BrowserStack Bug Capture includes the former Bird Eats Bug product.
Strengths below describe supported workflows, not measured speed or reliability.
Category totals come from the research matrix, not a representative market sample.

| Category and products | Common strengths | Limits and tradeoffs |
| --- | --- | --- |
| Screen and narrated video: Loom, Screen Studio, CleanShot X, Cap, OBS Studio, ScreenFlow, Camtasia Editor, macOS Screenshot/QuickTime | All eight document microphone narration. Seven document system audio and webcam capture. Local files and portable output are common. | Production tools optimize presentation. Browser diagnostics vary. Sharing, editing, and export can depend on plans or modes. |
| Bug reporting: Jam, BrowserStack Bug Capture, Marker.io, BugHerd, Userback | All five support screenshots, links, and integrations. Four document image annotation and console evidence. | A linked report is not a portable diagnostic archive. Technical context often depends on browser instrumentation or hosted access. |
| Speech: Wispr Flow, Superwhisper, FluidVoice, VoiceInk, MacWhisper, Apple Dictation | All six document app dictation. Five document post-capture transcription. Four document native offline core operation. | Model choice, cloud settings, correction effort, and insertion focus are separate concerns. These products do not establish a video-review workflow. |
| Still images and overlays: Shottr, Camtasia Snagit, Presentify, ScreenBrush, ShareX | Focused arrows, labels, crops, drawing, and keyboard workflows reduce explanation effort. | Still-image editing, live drawing, and safe masking differ. A crop or overlay does not sanitize the original recording. ShareX is Windows-focused. |
| Guides and demos: Scribe, Tango, Guidde, Arcade | All four document screenshots, annotations, and sharing. Three have native portable output; one is partial. | A step guide serves instruction. It need not preserve failed states, original speech, or developer evidence. Desktop/export features often have paid gates. |
| Adjacent workflows: Descript, Screenpipe, Replay.io, Frame.io | Respectively: transcript-led video editing, searchable computer history, execution debugging, and media review. | These solve different jobs. Combining them into one roadmap would add unrelated capture, storage, editing, and collaboration costs. |

The matrix has **1,050 unknown cells out of 1,472**: 71.3%.
Unknown means unverified, not absent. Many cells concern features outside a product's main category.
Resolved cells have source IDs, but many share a broad product-level source set.
Use the matrix to find candidates. Check a feature's exact plan, platform, and mode before adopting it.

## What tools do well, and where they fall short

Current products increasingly connect capture to a useful output: a share link, edited clip, guide, issue, or agent prompt.
The useful comparison is the complete task, including correction and handoff.
Feature counts alone obscure whether the recipient can understand and use the result.

Independent primary-source checks confirmed these decisive examples:

| Product | Confirmed capability and boundary | Implication |
| --- | --- | --- |
| Loom | Agent mode combines speech, keyframes, selected regions, drawing, interaction events, and browser diagnostics. It is a paid beta with five-minute recordings and camera disabled. [Official guide](https://support.atlassian.com/loom/docs/record-for-agent/) | Narrated evidence for agents is already a competing workflow. Local control must earn its value. |
| Screen Studio | Captions use local Whisper or Apple recognition. Users can correct and export the transcript. Apple recognition requires macOS 26. [Captions](https://screen.studio/guide/captions) | Local speech plus polished video is available. No measured quality advantage over this repo is established. |
| Wispr Flow | Dictation inserts cleaned text into the active field. Transcription requires internet access. [Help](https://docs.wisprflow.ai/articles/2772472373-what-is-flow) | Useful for writing notes; distinct from preserving recorded narration. |
| Superwhisper | Dictation pastes into other apps. Mac setup needs microphone and Accessibility permissions; modes can use local or cloud models. [Quickstart](https://superwhisper.com/docs/get-started/quickstart) | Test insertion and correction effort separately from recognition accuracy. |
| MacWhisper | The current product includes systemwide dictation as well as transcription. [Product page](https://www.macwhisper.com/) | Treating it as file-transcription-only would miss a direct speech alternative. |
| Marker.io | Screenshots and summaries reach integrations. Full logs, requests, and replay remain linked to Marker.io. [Export boundary](https://help.marker.io/en/articles/14430683-why-are-console-logs-network-requests-and-replays-linked-instead-of-attached) | A ticket can depend on continued access to the original service. |
| Jam | Recording Links need no recipient installation. Logs require a connected domain and installed scripts. Its guide documents blur limits during load and resize. [Recording Links](https://jam.dev/docs/recording-links) | Low capture friction does not mean every mode captures diagnostics or masks every frame. |
| Shottr | Raster tools act on the base image. Added captures and annotation layers need rasterization first. [FAQ](https://shottr.cc/kb/faq) | Verify the exported derivative; do not infer masking from the editor view. |
| Scribe | Paid plans include desktop capture, screenshot editing, and PDF/HTML/Markdown export. Conflicting Team price blocks remain visible. [Pricing](https://scribe.com/pricing) | Procedural documentation is a strong alternative. No disputed numeric price drives this recommendation. |
| Frame.io | Comment exports can follow the current search, filters, and sort order. [Comments guide](https://help.frame.io/en/articles/9105278-comments-panel-overview) | Selected review content can have an explicit export contract. |

These are documented strengths and restrictions. No current comparative hands-on study ran.
Historical user reports in the original report identify test cases, not present failure rates.
The research does not establish a universal winner for speech accuracy, speed, or reliability.

## Verified repository gaps

Local inspection checked the decisive code paths. All 48 packet file hashes match their recorded inputs.
All six absence searches reproduced Pro's counts. Seventy cited path/range/symbol locators resolve in the unchanged baseline.
An absence search narrows the inspected scope; it does not prove all possible implementations are absent.

| Priority | Finding | Direct code evidence and limit |
| --- | --- | --- |
| First | Input values can enter structured context, contrary to README wording. | [`describe`](../../../extension/page.js) uses `innerText || value`; click, change, focus, and hover paths can call it. No personal session was inspected. |
| First | Portable HTML loses later notes and review labels. | [`MarkText.swift`](../../../Sources/ContextRecorder/Library/MarkText.swift) includes them. [`viewer.html`](../../../scripts/viewer.html) title, visible detail, and copied Markdown omit them. Its sentence selection also differs. |
| First | Missing transcription can look silent; initial processing ignores exit status. | [`process_session.py`](../../../scripts/process_session.py) returns no transcript when the recognizer is missing. [`main.swift`](../../../Sources/ContextRecorder/main.swift) calls completion regardless of status. [`Review.swift`](../../../Sources/ContextRecorder/Library/Review.swift) already checks status. |
| Next, conditional | Selected marks can carry broader content. | [`PgmExport.swift`](../../../Sources/ContextRecorder/Export/PgmExport.swift) includes crop full frames and the complete session transcript. PGM uses local mode; this is not evidence of remote transmission. |
| Next, conditional | Text retrieval is missing from the inspected review surfaces. | [`SidePanel.swift`](../../../Sources/ContextRecorder/Library/SidePanel.swift), the Library files, and HTML provide navigation and type filters. No app-level text query was found. Benefit remains unmeasured. |
| Qualify when used | Times, tabs, and source locations have different confidence. | Review frame extraction discards returned actual time. Extension reconnects drain queued events. [`sourceFor`](../../../extension/page.js) supports explicit source attributes and labels transformed React paths. No event-frequency or timing test ran. |
| Defer unless blocked | Target selection, system audio, pause, image annotation, transcript correction, clips, and spatial reconstruction. | [`Recorder.swift`](../../../Sources/ContextRecorder/Recorder.swift) selects the main display, requests 15 fps, caps width at 1920, and disables system audio. A region still is not region video. Other absence scopes are in the gap analysis. |

The loopback bridge accepts an empty Origin or an extension Origin. It binds to `127.0.0.1`.
That supports a narrow local peer-policy review. It does not establish internet exposure or justify account infrastructure.

The app already has useful notes, review marks, crops, transcript seeking, source clues, local export, and a UI harness.
The earlier canvas proposal remains a separate unproven direction. Research does not replace or approve it.

## Recommendation dispositions

“Adopt” means include in the proposal. It does not approve or implement a change.
Every original recommendation has one disposition below. No dependency on a new service is accepted.

| ID | Disposition | Reason and destination |
| --- | --- | --- |
| RT-01 | Adopt | Preserve raw evidence and existing review. Invariants in the shape and proof plan. |
| RT-02 | Adopt, narrowed | Correct collection claims and test explicit output scope. Reject a blanket sanitized-export promise. Export policy stays open. |
| RT-03 | Adopt | Fix existing note/provenance/time semantics before adding views. Proposed plan milestone 1. |
| RT-04 | Adopt | Reuse current subprocess/retry seams for truthful outcomes. Proposed milestone 2; no queue service. |
| RT-05 | Investigate | Compare full retrieval-to-handoff time against current review plus editor Find. Proposed milestone 3 is a decision spike. |
| RT-06 | Investigate | Test delayed screenshots, stale tabs, and supplied Solid source attributes. Add labels or metadata only where needed. |
| RT-07 | Investigate | Try one specialist for the chosen task. Preserve originals. No install, purchase, or integration in this run. |
| RT-08 | Defer | Preserve the prior canvas vision. Require value beyond a useful simple board and actual patch-to-frame evidence. |
| RT-09 | Defer | Require a recurring blocked capture task. Evaluate one target/audio feature, not a capture rewrite. |
| RT-10 | Adopt | Reject default cloud-team, always-on, autonomous issue, global dictation, and full-editor expansion. Reopen only with changed intent. |

The original ordering is guidance, not a technical dependency graph.
Note parity and processing-state repairs can stand alone. Neither proves search value.
The detailed app expansion plan stops at the product and export-policy decisions.

## Validation and remaining limits

- Eight downloads collected; seven archive members safely checked and compared with standalone copies.
- CSV and JSON parsed; counts, states, recommendation dependencies, source IDs, hashes, and repo anchors checked.
- [Package results](package-validation.json) and [collection hashes](collection-manifest.json) preserve the results.
- Ten primary product pages were independently checked for the decisive claims above.
- No Pro follow-up was required. No missing deliverable prevented integration.
- No native build, capture, provider, permission, UI, performance, recovery, or timed task test ran.
- Synthetic proofs in the [implementation plan](../../intent/recording-tools/implementation-plan.md) remain unrun.

Before app expansion, choose the primary job, recipient/data scope, and acceptable benefit for added maintenance.
The suggested 20% time gain and four-of-six faster task pairs are unapproved trial criteria, not measured results.

## Original package

Preserved from the [Pro session](https://chatgpt.com/c/6acef979-eca8-83e9-96b7-0d6d69f3935c):
[ZIP](pro-output/recording-tools-research.zip), [report](pro-output/recording-tools-report.md),
[matrix](pro-output/recording-tools-matrix.csv), [gaps](pro-output/recording-tools-gap-analysis.md),
[sources](pro-output/recording-tools-sources.md), [recommendations](pro-output/recording-tools-recommendations.json),
[proof plan](pro-output/recording-tools-proof-plan.md), and [manifest](pro-output/recording-tools-manifest.json).
Original dates and text remain unchanged. Local qualifications belong in this review.
