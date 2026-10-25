# Narrated review: product comparison

Keep Context Recorder for its personal workflow. Compare existing products before expanding its capture or editing features.
Jam and Clipy are the first adoption candidates. Vidmatic is a strong alternative for an issue-based workflow.
This is a research recommendation. No comparative trial has run.

The research covers 15 products, one written baseline, and 65 shared feature concepts.
Start with the [feature guide](feature-guide.md), then compare the [matrix](feature-matrix.csv).
Read the [full comparison](feature-comparison.csv) for each cell's qualifications and sources.
The [product table](products.csv) contains prices, platforms, setup, and service dependencies.
The [comparison plan](../../intent/narrated-review-comparison/implementation-plan.md) defines the next decision and conditional work.

## Landscape and strongest uses

| Product | Strongest relevant role | Main boundary |
| --- | --- | --- |
| Context Recorder | Local narration, marks, source hints, canvas, Product Grid, optional cloud MCP | Marks are evidence. The agent must still recover final requests and verify changes. |
| Jam | Browser diagnostics, timed transcript and frames, agent access, recorded test evidence | Ordinary video and Instant Replay expose different agent tools. |
| Clipy | Structured requests, plan, timed evidence, and explicit capture gaps through AREC | Local media still permits cloud processing of derived text and interactions. |
| Vidmatic | One recording to several asks, source anchors, work stages, and demo links | The agent finds code anchors and reports status. Neither proves correctness. |
| ThinkRun | Local capture and browser control, with optional cloud analysis | Analysis is preview. Local and cloud paths have different limits and recipients. |
| CaptureCat | Local capture, editing, transcription, OCR, and agent frame tools | Request interpretation and source mapping still need an external workflow. |
| Loom Record for Agent | Tasks linked to quotes, frames, and times | Agent mode has a five-minute limit. A twelve-minute review needs several clips. |
| Marker.io | Website intake, diagnostics, tracker workflow, accessibility monitoring | DOM replay differs from narrated pixel video. |
| BrowserStack Bug Capture | Narrated capture and technical logs, with retrospective replay | Product-specific transcript and MCP coverage remain unresolved in this research. |
| Replay.io | Historical execution investigation and separate QA tools | Runtime diagnosis does not supply the reviewer's intended change. |
| Sentry | Production errors, traces, releases, replay, and issue assistance | Replay data and summarized agent output differ from original video and frames. |
| OpenReplay, including Spot | Self-hosted replay plus deliberate screen capture | Spot narration and frame access through project-session MCP need proof. |
| screenpipe | Searchable screen and audio history, with agent context retrieval | Event-based images differ from continuous video and browser diagnostics. |
| Innerloop Breadcrumb | Local history, meetings, memories, and agent rules | Screen text is not DOM context. Image tools still carry a development label. |
| Chrome DevTools MCP | Current browser inspection, target selection, and verification | Historical narration and intent must come from another source. |
| Screenshots plus instructions | Clear final requests and selected evidence | Count writing, image selection, clarification, and verification time. |

Jam documents timed visual and diagnostic reads. Its test-recording command can retain the check's exit code.
Clipy's AREC format links extracted requests to evidence and states capture gaps.
Vidmatic documents one issue with a row per ask and agent-found code anchors.
These are substantial alternatives to another custom handoff system.
[Jam MCP](https://jam.dev/docs/jam-mcp), [test recording](https://jam.dev/docs/cli-e2e-tests),
[AREC specification](https://clipy.online/spec), [Vidmatic workflow](https://www.vidmatic.ai/docs/recording-to-issue).

## What still merits work

Source inspection confirms that typed notes and review origin survive native/Python Markdown but disappear from web/cloud Markdown.
This can remove a review correction from agent context. A small parity repair has clear value while sessions remain useful.
See `Library/MarkText.swift:markdown`, `scripts/process_session.py:mark_markdown`,
`scripts/viewer.html:markdownFor`, and `cloud/src/markdown.ts:markdownFor`.

The cloud `get_session` response contains mark Markdown, rather than the complete transcript and event history.
Agents need the raw session and transcript when requests occur between marks.
Default frame retrieval selects nearby thumbnails. Drawings are separate.
See `cloud/src/mcp/server.ts` and `cloud/src/frames/thumbs.ts`.

Input values can enter captured element text through `extension/page.js:describe`.
Crops and drawings can coexist with originals, full frames, narration, logs, or saved pages.
Treat each export channel separately. A recording hash does not identify the source build.

## Decision and limits

Use total human effort through accepted changes as the adoption measure.
Include missed requests, canceled instructions, wrong targets, clarification, repair, and failed verification.
The plan proposes four isolated runs with five real changes. It does not rank products by PR count.

Keep personal utility separate from commercial claims. Canvas, local files, and Product Grid can justify personal retention.
Narration, MCP, extracted asks, code links, and proof already exist elsewhere. Their presence alone does not establish differentiation.

Avoid Breadcrumbs as the public name. Innerloop's adjacent Breadcrumb creates a credible confusion risk.
That is a product identity judgment, not legal clearance. It does not change the personal utility decision.
[Innerloop documentation](https://innerloop.works/breadcrumb/mcp).

Published prices and limits are research snapshots, not verified account entitlements.
Jam's paid duration claims conflict. Loom's agent limit differs from ordinary paid recording.
Clipy's local mode still requires internet access and sends derived context for processing.
[Jam pricing](https://jam.dev/pricing), [Loom agent mode](https://support.atlassian.com/loom/docs/record-for-agent/),
[Clipy local mode](https://clipy.online/docs/local-recording).

The workflow blog and private prior review were inaccessible to Pro. It used Byron's supplied workflow account.
No native capture, competitor trial, account connection, installation, or purchase ran.
All 16 recommendation dispositions are in the [plan](../../intent/narrated-review-comparison/implementation-plan.md).
The [validation record](validation.md) separates local checks from unverified research claims.
[Source conversation](https://chatgpt.com/c/6add7517-fa5c-83ea-a835-b48d3709a763).
