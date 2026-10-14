# Context Recorder — repository-grounded gap analysis

**Status:** static research and conditional proposals; no implementation approval.  
**Repository:** `byronwall/context-recorder`  
**Immutable baseline:** `6c74158ca96abd36819d2a58f75bacdc44107bb0`  
**Research/access date:** 2026-10-13, America/Indiana/Indianapolis

## Decision

Preserve the existing local evidence-and-review loop. Correct misleading collection/output behavior, then prove whether a small **find → inspect → note → select → hand off** workflow saves meaningful effort. The first useful work is not a new recorder, dictation engine or canvas. The ranked recommendations are RT-01 through RT-10 in the JSON companion; the proposed validation sequence is in the proof plan.

This conclusion is conditional on personal bug/product review being the primary outcome. Polished communication and general dictation favor specialist reuse instead. No larger roadmap is approved by documenting an absent feature.

## Access and inspected scope

GO for the requested static gap analysis: the authorized packet identifies the requested repository/ref; required files are readable; connected GitHub exposed the same baseline README; current web research is available. All **48 packet sections** matched supplied byte counts and SHA-256 hashes: **47 baseline files plus one local research prompt**. The separate uploaded brief is byte-identical to that prompt section.

The packet is selected source, not a runnable checkout or a complete Git tree. It omits binary assets, dependencies, personal recordings and build output. Absence is therefore stated only within the named inspected scope. No local checkout path was accessed, no repository file was changed, and no branch, commit or PR was created.

## Reading the classifications

- **implemented:** a concrete code path exists. This is not a runtime pass.
- **partial:** a useful capability exists but its scope, semantics or end-to-end behavior is incomplete.
- **absent within inspected scope:** no implementation was located in the named files after search and manual path inspection; not a claim about unseen files.
- **proposed only:** research/design exists without an implementation in the baseline.
- **unknown:** available evidence cannot establish behavior or value.

“Gap” includes a correctness mismatch, discovery problem, untested path or product-boundary choice. It does not always mean an additional feature should be built.

## Current capability matrix


| Capability | Classification / boundary | Repository evidence |
| --- | --- | --- |
| Stack/platform | **implemented** — Swift/SwiftUI macOS 26, Python processor, plain JavaScript extension. Full-tree package absence is not independently audited. | [R001](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Package.swift#L1-L20) |
| Screen + optional microphone capture | **implemented** — Main display and configured H.264/AAC path; runtime permissions and capture success unrun. | [R002](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Recorder.swift#L21-L80) |
| System audio | **absent within inspected scope** — Explicit capturesAudio=false, not merely an undocumented option. | [R002](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Recorder.swift#L21-L80) |
| Window/alternate-display video and capture pause | **absent within inspected scope** — Main target and start/stop only in A02; playback pause and still regions do not count. | [R002](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Recorder.swift#L21-L80) [R024](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionView.swift#L190-L244) |
| Hotkeys, floating panel and shortcut help | **implemented** — Avoid claiming the app has no discoverable controls; permission/conflict outcomes untested. | [R003](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/HotKeys.swift#L5-L44) [R022](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L65-L74) |
| Local post-recording transcription | **implemented** — Cached local parakeet-mlx via ffmpeg; exact installed model/version and accuracy unknown. | [R007](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L56-L96) |
| Global dictation, live captions and transcript editing | **absent within inspected scope** — No insertion/live-caption/editor path in A03. Notes and post-stop STT remain separate. | [R023](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionData.swift#L62-L66) [R007](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L56-L96) |
| Raw token timing / native sentence projection | **partial** — Raw tokens exist; native model and UI expose sentence timing, not token editor. | [R007](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L56-L96) [R023](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionData.swift#L62-L66) |
| Review marks, crop stills and typed notes | **implemented** — Recorded context reused, no new historical DOM; deletion restricted to review marks. | [R004](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108) [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) |
| Image arrows/text editor and irreversible masking | **absent within inspected scope** — A04 found selection and decorative drawing, not a dedicated artifact annotation/redaction model. | [R024](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionView.swift#L190-L244) |
| Timeline, transcript seeking and hover previews | **implemented** — One player, time-based navigation and bounded preview cache; no performance result implied. | [R017](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SidePanel.swift#L265-L310) [R021](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionLibrary.swift#L102-L122) |
| Text search across findings/transcript | **absent within inspected scope** — A01 scope has no text query; existing mark-kind filter is not search. | [R017](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SidePanel.swift#L265-L310) |
| Browser event diagnostics | **implemented** — Bounded events, failed/slow request subset and body truncation. Not a complete network trace. | [R010](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L9-L31) |
| DOM/source hints and code opening | **partial** — Live snapshots and file paths exist; precision depends on dev metadata; Solid needs supplied attributes. | [R009](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168) [R010](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L9-L31) |
| Saved MHTML / historical DOM replay | **partial** — On-demand snapshots exist; continuous DOM or execution replay does not. | [R025](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L134-L137) |
| Input exclusion and comprehensive privacy | **partial** — Some value collection is reachable despite the claim; local storage is not redaction. | [R011](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L194-L215) [R015](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) |
| Time/identity provenance | **partial** — Different clocks and delayed exposure paths; no exact simultaneous-context guarantee. | [R013](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L23-L31) [R014](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L366-L420) |
| Native library rename/trash/notes | **implemented** — Names and source-protective UI paths exist; runtime verification unrun. | [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) [R021](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionLibrary.swift#L102-L122) |
| Portable viewer / equivalent copied findings | **partial** — Folder-based portability exists; HTML omits notes/review labels and uses a different sentence rule. | [R006](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/viewer.html#L295-L334) [R018](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294) |
| Selected, local Product Grid export | **partial** — Local CLI and owned-image update checkpoints exist; subset selection still includes broader session material. | [R015](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) |
| Processing retry/status/recovery | **partial** — Review path checks status; initial path does not. Full media crash recovery remains unknown. | [R008](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L473-L484) [R021](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionLibrary.swift#L102-L122) |
| Video clip exporter and hosted share workflow | **absent within inspected scope** — MP4 and local folder outputs exist, but no inspected clip-range or remote collaboration service. | [R018](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294) [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) |
| Spatial reconstructed video canvas | **proposed only** — Four prior research documents; no canvas analyzer or measured geometric proof. | [R019](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/docs/research/video-to-canvas/design.md#L3-L10) |
| Regression/UI checks | **implemented** — Transcript script and native harness exist; personal fixture prepare not executed. | [R020](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/check-transcript.py#L1-L16) |
| Performance, reliability and user value | **unknown** — Static cache/queue choices are not measurements; no media/provider/UI trial. | [R021](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionLibrary.swift#L102-L122) [R020](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/check-transcript.py#L1-L16) |


## Credit the foundation before ranking additions

Context capture, time-linked review, local artifacts and later review marks are already implemented. The source button, cropped review frame, typed note, library name, keyboard help and PGM update mapping should not be rediscovered as missing features. Raw evidence can outlive one UI or hosted account. PGM uses direct process arguments and `--local`; its checkpointed mappings and preservation of user-owned edits are meaningful existing safeguards. [R004](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108) [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) [R009](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168) [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) [R021](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionLibrary.swift#L102-L122)

The combination remains useful, but **uniqueness is not established**. Loom now documents developer diagnostics and agent-ready keyframe prompts; Jam supplies screen-plus-diagnostics workflows; Replay supplies deeper execution evidence; Screenpipe supplies broader local history. Context Recorder’s strongest conditional boundary is deliberate, personal, local review with inspectable originals—not simply “video plus context.” [S006](https://support.atlassian.com/loom/docs/capture-console-and-network-logs/) [S007](https://support.atlassian.com/loom/docs/record-for-agent/) [S028](https://jam.dev/) [S090](https://docs.replay.io/reference/replay-cli/commands) [S087](https://github.com/screenpipe/screenpipe)

## Ranked gaps

Priorities are research judgments for one developer, not commitments or estimated implementation hours. P0 protects truth/source integrity; P1 tests or improves the core local task; P2 is conditional parity/reuse; P3 is exploratory; Below cut means no current task justifies implementation. G16 is an uncertainty gate alongside each change, not a late claim that testing is unnecessary.


| ID / priority | Finding | Type / current status |
| --- | --- | --- |
| G01 / P0 | Truthful input exclusion and sensitive-content boundaries | correctness / data minimization; partial |
| G02 / P0 | Native, Markdown and portable HTML disagree about notes and time | implemented-path divergence; partial |
| G03 / P0 | Processing failure can look like silence or endless processing | failure-state / recovery gap; partial |
| G04 / P1 | Search across notes, transcript and context | retrieval feature gap; absent within inspected scope |
| G05 / P1 | Selected handoff is not selected content | scope / portability gap; partial |
| G06 / P1 | Artifact time and temporal association need honest labels | provenance / precision gap; partial |
| G07 / P1 | Browser connection, session freshness and tab identity | discoverability / context attribution gap; partial |
| G08 / P2 | Source links need honest framework-specific confidence | grounding boundary, not wholesale absence; partial |
| G09 / P2 conditional | Display/window selection, system audio and recording pause | capture parity gap; partial |
| G10 / P2 conditional | Visual arrows and masking are not the existing crop tool | annotation feature gap / reuse candidate; absent within inspected scope |
| G11 / P2 conditional | Transcript correction and general dictation are separate opportunities | speech workflow boundary; absent within inspected scope |
| G12 / P2 conditional | Portable clip and evidence handoff beyond local paths | extraction / recipient access gap; partial |
| G13 / P3 proof only | Spatial storyboard / video-to-canvas | exploratory product direction; proposed only |
| G14 / Below cut | Continuous DOM or execution replay | desirable omission unless a distinct debugging task appears; absent within inspected scope |
| G15 / Below cut | Cloud collaboration and autonomous issue/agent workflows | desirable omission / product-boundary choice; absent within inspected scope |
| G16 / P1 proof gate | Reliability, performance and test coverage are not established by source | untested implementation, not feature absence; unknown |


<a id="g01"></a>
### G01 — Truthful input exclusion and sensitive-content boundaries

**Classification:** partial · correctness / data minimization · P0

**Affected task:** Capture a product bug without unexpectedly collecting unrelated input text.

**Repository basis:** [R011](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L194-L215) [R010](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L9-L31) [R015](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) [R012](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/BrowserBridge.swift#L26-L50)

**Competitor comparison:** [S038](https://help.marker.io/en/articles/9657817-sensitive-data-masking) [S039](https://help.marker.io/en/articles/12383990-data-privacy-security-overview) [S064](https://shottr.cc/kb/faq) (accessed 2026-10-13; documentation unless the linked ledger record labels an observation/report).

**Search/inspection scope:** A04_drawing_redaction; trace describe → change ring / focused snapshot → stored mark; inspect full export payload, not only screenshot crop.

**Practical impact:** README and brief claim input values are excluded, but the supplied implementation can read target.value. A password/text field can reach the same description path. This is a static counterexample to the categorical claim; no real personal value or exploit was captured. Props, selection, URLs, response bodies, saved pages and original pixels remain separate sensitive surfaces.

**Cost and risk:** Small for a truthful label and obvious field exclusion; medium for explicit per-artifact controls. Comprehensive automatic redaction is a large, unproven project. Removing too much context can make a bug impossible to diagnose. Do not add an enterprise security platform.

**Smallest proposed improvement:** First correct the contract and exclude input/textarea/select value-derived text in the structured-description path. Make detailed context optional where useful. Treat originals as private and export a previewed derivative with a stated content scope. Never label a whole session safe merely because a crop is masked.

**Proof that can reject it:** Synthetic canaries in a password/text input must not appear in structured descriptions after the proposed exclusion. Separately enumerate canaries in props, selection, URL, body, MHTML and pixels. Reject any “sanitized export” label if included payloads contain a prohibited canary; retain local-private-only output instead. Preserve a benign selector/source fixture to detect over-redaction.

**Decision:** Improve the real collection boundary and the wording; do not promise comprehensive privacy. This is not authorization for a security rewrite.


<a id="g02"></a>
### G02 — Native, Markdown and portable HTML disagree about notes and time

**Classification:** partial · implemented-path divergence · P0

**Affected task:** Add a review finding, reopen the portable viewer, and copy the same conclusion with the correct source moment.

**Repository basis:** [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) [R006](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/viewer.html#L295-L334) [R018](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294) [R020](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/check-transcript.py#L1-L16)

**Competitor comparison:** [S093](https://help.frame.io/en/articles/9105278-comments-panel-overview) [S005](https://support.atlassian.com/loom/docs/correct-your-transcript/) [S059](https://docs.macwhisper.com/article/57-macwhisper-command-line-tool) (accessed 2026-10-13; documentation unless the linked ledger record labels an observation/report).

**Search/inspection scope:** A06_export plus direct comparison of MarkText.title/markdown, processor.mark_markdown and viewer.titleOf/markdownFor/renderList/sentenceAt.

**Practical impact:** Typed notes and review provenance survive raw JSON and native/processor Markdown, but the portable viewer does not render/copy them. This can remove the most important later interpretation during handoff. HTML sentenceAt can also choose the earlier short sentence at a later sentence start, unlike the native regression-protected rule. These are source-supported divergences, not missing note-taking capability.

**Cost and risk:** Small-to-medium. Three representations must share semantics without introducing an over-general formatting framework. A browser viewer has no ordinary arbitrary-filesystem write permission; read-only parity is the first goal.

**Smallest proposed improvement:** Define a small golden semantic contract: note title/body, source=review label, source time/path and exact sentence-start selection. Bring portable rendering/copying into that contract. Keep native editing and portable reading distinct.

**Proof that can reject it:** One fixture with a 0.05-second sentence, adjacent sentence, silence gap, typed multi-line note and review crop must preserve the same key fields in all outputs. Reject the patch if a note disappears, a review mark implies live DOM, or a clicked sentence highlights a different sentence. Compare semantics, not incidental whitespace.

**Decision:** Fix before adding a new review surface. The HTML viewer is a real product output, not an expendable preview.


<a id="g03"></a>
### G03 — Processing failure can look like silence or endless processing

**Classification:** partial · failure-state / recovery gap · P0

**Affected task:** Stop a narrated recording and know whether transcription succeeded, was skipped, is pending or failed.

**Repository basis:** [R007](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L56-L96) [R008](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L473-L484) [R021](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionLibrary.swift#L102-L122)

**Competitor comparison:** [S047](https://docs.wisprflow.ai/articles/2503460374-retry-failed-transcriptions) [S089](https://github.com/screenpipe/screenpipe/issues/3498) [S021](https://obsproject.com/kb/audio-video-formats-guide) (accessed 2026-10-13; documentation unless the linked ledger record labels an observation/report).

**Search/inspection scope:** A03_speech and direct initial-processing versus Review.reprocess control-flow inspection.

**Practical impact:** Missing recognizer can yield an empty transcript; the UI calls it silent. Initial process termination status is ignored, and an absent session.json displays Processing. Review reprocessing already checks status, so the gap is inconsistent state handling rather than no error handling anywhere. Capture success does not prove transcript availability.

**Cost and risk:** Small-to-medium for explicit stage outcomes and a local retry action. Media salvage after interrupted AVAssetWriter is a separate harder problem. Avoid a background job service.

**Smallest proposed improvement:** Persist or expose a compact processing result with stage/reason and retry action. Distinguish no audio, not requested, unavailable dependency, failed, and ready. Keep raw MP4/JSONL usable when derived transcript/viewer work fails.

**Proof that can reject it:** Run proposed fixtures with no audio, valid cached transcript, missing recognizer, failing subprocess and malformed output. A failed case must never be labeled Silent or Complete, retry must not duplicate marks, and raw inputs must remain intact. Reject an elaborate queue if one local retry path solves the observed failures.

**Decision:** Improve visibility and recoverability first. No claim is made that existing recordings are corrupt.


<a id="g04"></a>
### G04 — Search across notes, transcript and context

**Classification:** absent within inspected scope · retrieval feature gap · P1

**Affected task:** Find the relevant finding in a long narrated review by remembered words, URL or error text.

**Repository basis:** [R017](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SidePanel.swift#L265-L310) [R004](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108) [R009](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168)

**Competitor comparison:** [S060](https://macwhisper.helpscoutdocs.com/article/28-keyboard-shortcuts) [S087](https://github.com/screenpipe/screenpipe) [S093](https://help.frame.io/en/articles/9105278-comments-panel-overview) (accessed 2026-10-13; documentation unless the linked ledger record labels an observation/report).

**Search/inspection scope:** A01_search: all 12 supplied Library Swift files plus viewer.html; zero query-control hits, followed by manual reading of lists/model/library grouping.

**Practical impact:** The app already has transcript seeking, a timeline and mark-type filters. None is an app-level textual query. Search could reduce scrolling and replay, but frequency and benefit on Byron’s sessions remain unmeasured.

**Cost and risk:** Small for in-session lexical filtering with time links; medium for cross-session indexing. Semantic embeddings, vector storage and an always-on index are unnecessary for the first proof.

**Smallest proposed improvement:** Start with a visible local query over note/narration/URL/error text in the open session, showing the matching field and source time. Preserve empty, no-result and clear-filter states. Keep normal chronological review available.

**Proof that can reject it:** Use six paired retrieval tasks over three synthetic sessions, including an unmarked phrase and a repeated URL. Require no accuracy loss and the predeclared time benefit in the proof plan. Reject a cross-session index if in-session search or existing browser Find/manual Markdown already suffices.

**Decision:** The leading additive capability, after output truth is protected; not a commitment to universal search.


<a id="g05"></a>
### G05 — Selected handoff is not selected content

**Classification:** partial · scope / portability gap · P1

**Affected task:** Send only chosen findings, with enough context to act, without silently including the rest of the review.

**Repository basis:** [R015](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) [R018](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294)

**Competitor comparison:** [S093](https://help.frame.io/en/articles/9105278-comments-panel-overview) [S097](https://www.browserstack.com/docs/testing-toolkit/bug-capture/faqs/recording-videos) [S037](https://help.marker.io/en/articles/14430683-why-are-console-logs-network-requests-and-replays-linked-instead-of-attached) (accessed 2026-10-13; documentation unless the linked ledger record labels an observation/report).

**Search/inspection scope:** A06_export; inspect selectedMarks, sessionMarkdown, imageFiles, copied Markdown and viewer media references.

**Practical impact:** Selected mark children can be accompanied by the full session transcript and the full frame behind a crop. Product Grid is local, so this is not evidence of remote transmission. It is a mismatch between potential selection expectations and actual payload scope. Markdown absolute paths also do not travel by themselves.

**Cost and risk:** Small for a truthful payload preview and explicit whole-session option; medium for a self-contained selected bundle. Clip transcoding and redaction raise cost further. Preserve original source evidence rather than destructively shrinking it.

**Smallest proposed improvement:** Show exactly which transcript ranges, images and saved pages will be included. Default a selected derivative to selected findings plus explicitly chosen context; keep a separate deliberate full-session export. Start with copied Markdown plus companion assets before a new integration protocol.

**Proof that can reject it:** Select two of five marks in a canary session. The proposed selected package must list its assets, contain the two conclusions, resolve their source references and exclude unselected content unless visibly opted in. Reject “portable” if moved-directory links fail. Verify PGM re-export still preserves user-owned edits.

**Decision:** Improve the export contract, not an enterprise sharing service.


<a id="g06"></a>
### G06 — Artifact time and temporal association need honest labels

**Classification:** partial · provenance / precision gap · P1

**Affected task:** Understand whether a region image, narrated sentence and DOM snapshot describe the same instant.

**Repository basis:** [R014](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L366-L420) [R013](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L23-L31) [R004](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108)

**Competitor comparison:** [S090](https://docs.replay.io/reference/replay-cli/commands) [S092](https://help.frame.io/en/articles/9105251-commenting-on-your-media) (accessed 2026-10-13; documentation unless the linked ledger record labels an observation/report).

**Search/inspection scope:** A02_capture and A05_canvas_replay; follow mark keypress, selection completion, asynchronous snapshot, decoded review frame and receipt timestamps.

**Practical impact:** A live region shot can be captured after its mark time; page events receive native offsets on arrival; review frame generation drops actual returned time. These are adequate context clues for many tasks but not exact pixel-exposure or semantic-object proof. A timestamp alone does not identify what “this button” refers to.

**Cost and risk:** Small for explicit source/review/approximate labels; medium for actual artifact times and capture IDs. Full clock reconciliation is not justified without a measured mismatch.

**Smallest proposed improvement:** Keep mark intent time separate from image exposure/request time where available. Preserve raw event clocks and tab identity in derived views. Show unknown/approximate rather than inventing precision; require real frame provenance only for clipping or spatial composition.

**Proof that can reject it:** In a later authorized fixture, delay region selection while changing a visible counter. The UI must not imply that delayed pixels were exposed at keypress. For a canvas/clip, verify decoded presentation time and source rectangle. Reject added synchronization machinery if labels and separate times resolve the observed confusion.

**Decision:** Protect truth before demanding frame-exact capture across unrelated APIs.


<a id="g07"></a>
### G07 — Browser connection, session freshness and tab identity

**Classification:** partial · discoverability / context attribution gap · P1

**Affected task:** Know which tab and interval contributed evidence, especially after reconnect or app idle time.

**Repository basis:** [R012](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/BrowserBridge.swift#L26-L50) [R013](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L23-L31) [R010](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L9-L31)

**Competitor comparison:** [S030](https://jam.dev/docs/instant-replay) [S036](https://help.marker.io/en/articles/6673880-session-replay-videos) (accessed 2026-10-13; documentation unless the linked ledger record labels an observation/report).

**Search/inspection scope:** A05_canvas_replay plus background queue/send, native bridge event handler, PageEvent projection and popup status code.

**Practical impact:** Connected is not the same as recording. A reconnect queue can deliver earlier events into a later active session; review recent events are time-filtered rather than fully tab-scoped. The code supports these risk paths, but their observed frequency is unknown. The bridge is loopback-bound; empty-Origin acceptance is a narrower peer-policy issue, not proof of internet exposure.

**Cost and risk:** Small for truthful indicators, freshness tags and queue/session rules; medium if changing wire metadata. Do not add accounts, TLS provisioning or multi-tenant infrastructure.

**Smallest proposed improvement:** Separate connected/active recording/current-tab-supported states. Keep raw tab ID and occurrence time visible when diagnosing context. Drop or explicitly label stale cross-session events instead of silently giving them a new occurrence time. Document and narrowly evaluate the intended local peer policy.

**Proof that can reject it:** A synthetic reconnect trace with two tabs and events before/after session start must never silently present stale data as a new event in the wrong tab. An idle but connected extension must not claim active recording. Reject a complex protocol if a bounded session-start rule and labels suffice.

**Decision:** Improve contextual trust with minimal state; do not convert a personal loopback bridge into a hosted platform.


<a id="g08"></a>
### G08 — Source links need honest framework-specific confidence

**Classification:** partial · grounding boundary, not wholesale absence · P2

**Affected task:** Open the likely Solid/TypeScript source from an observed element without treating a guessed line as exact.

**Repository basis:** [R009](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168) [R010](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L9-L31)

**Competitor comparison:** [S090](https://docs.replay.io/reference/replay-cli/commands) [S007](https://support.atlassian.com/loom/docs/record-for-agent/) [S032](https://jam.dev/integrations/github) (accessed 2026-10-13; documentation unless the linked ledger record labels an observation/report).

**Search/inspection scope:** Inspect sourceFor, source attributes, SourceLocation.isPostTransform and SourceButton; no new framework instrumentation installed.

**Practical impact:** Source-button handoff already exists. Solid requires the documented source attributes; React 19 lines are labeled post-transform; production builds may lack precise locations. DOM context narrows a search but does not prove causality or correctness of an agent-suggested fix.

**Cost and risk:** Small to improve labeling and validate the existing attribute path in one development fixture. Larger framework-wide source-map support is maintenance-heavy and brittle.

**Smallest proposed improvement:** Prove the existing source-attribute route on one representative Solid development build. Distinguish exact supplied location, component file, transformed line and selector-only fallback. Keep copy-path when local opening cannot resolve.

**Proof that can reject it:** Three seeded elements with exact attribute, missing file and transformed source must yield the expected open/copy/qualified label. Reject broader adapters if the existing build attribute route meets the task.

**Decision:** Keep and validate; do not rank “links to code” as an absent feature.


<a id="g09"></a>
### G09 — Display/window selection, system audio and recording pause

**Classification:** partial · capture parity gap · P2 conditional

**Affected task:** Record a walkthrough on another display or include an audible application failure without irrelevant desktop content.

**Repository basis:** [R002](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Recorder.swift#L21-L80) [R024](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionView.swift#L190-L244) [R014](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L366-L420)

**Competitor comparison:** [S020](https://obsproject.com/kb/macos-desktop-audio-capture-guide) [S009](https://screen.studio/) [S013](https://cleanshot.com/screen-recording) [S027](https://support.apple.com/en-us/102618) (accessed 2026-10-13; documentation unless the linked ledger record labels an observation/report).

**Search/inspection scope:** A02_capture: Recorder, main, ControlPanel, HotKeys and RegionSelector. System audio is explicitly false; target is main display; no capture pause/resume/webcam implementation located. Playback pause is excluded.

**Practical impact:** A microphone can narrate a problem but cannot substitute for the application sound. Main-display-only video can require rearranging work. Conversely 15 fps/1920 may be sufficient for deliberate review; there is no measured quality failure justifying blanket 4K/60.

**Cost and risk:** Medium: capture selection changes coordinates, filters and screenshot/page mapping; audio adds permission/routing/clock concerns; recording pause affects event offsets. Webcam and branding add less likely value to a personal diagnostic workflow.

**Smallest proposed improvement:** Use OBS/CleanShot/Screen Studio to validate the missing task first. If it recurs, add one chosen target/audio mode with explicit state and keep current defaults; do not bundle pause, webcam, resolution and effects into one project.

**Proof that can reject it:** A narrated cross-display or application-audio fixture must demonstrate a real failure in the current task and successful completion with the added mode, while marks still align. Reject broader capture work if rearranging the window or a specialist recording is sufficient.

**Decision:** Conditional parity, below the initial local-review cut line.


<a id="g10"></a>
### G10 — Visual arrows and masking are not the existing crop tool

**Classification:** absent within inspected scope · annotation feature gap / reuse candidate · P2 conditional

**Affected task:** Explain one spatial defect clearly or prepare a narrowly shareable image.

**Repository basis:** [R024](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionView.swift#L190-L244) [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) [R018](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294)

**Competitor comparison:** [S062](https://shottr.cc/) [S064](https://shottr.cc/kb/faq) [S012](https://cleanshot.com/) [S070](https://presentifyapp.com/use-cases/cursor-highlight-tool-for-screen-recording) [S066](https://www.techsmith.com/snagit/features/) (accessed 2026-10-13; documentation unless the linked ledger record labels an observation/report).

**Search/inspection scope:** A04_drawing_redaction across native, extension, processor and viewer. SwiftUI drawing/selection dimming is not an annotation document model; no arrow/text/redaction editor path found.

**Practical impact:** Typed notes and crops already support focused findings, but they cannot point to two precise pixels or mask an included full frame. A decorative UI blur must not be counted as image redaction.

**Cost and risk:** Small to reuse an external editor on a copy; medium-to-large for undoable image markup and safe exported derivatives. Live drawing can alter recorded pixels and should be checked against excluded overlays.

**Smallest proposed improvement:** Open a copied crop in a specialist tool and retain both original and labeled derivative. Test Presentify only as a recorder complement. Add a native arrow tool only after manual round-trip cost repeatedly matters.

**Proof that can reject it:** Compare note+crop with one external annotated derivative on a two-location defect. Require better recipient interpretation without losing the original. Reject native editing if external reuse meets the task; never equate a passed crop task with complete redaction.

**Decision:** Reuse before build.


<a id="g11"></a>
### G11 — Transcript correction and general dictation are separate opportunities

**Classification:** absent within inspected scope · speech workflow boundary · P2 conditional

**Affected task:** Correct a misrecognized identifier or dictate a later review note.

**Repository basis:** [R007](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L56-L96) [R023](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionData.swift#L62-L66) [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115)

**Competitor comparison:** [S058](https://www.macwhisper.com/) [S059](https://docs.macwhisper.com/article/57-macwhisper-command-line-tool) [S051](https://superwhisper.com/docs/get-started/quickstart) [S045](https://docs.wisprflow.ai/articles/2772472373-what-is-flow) [S061](https://support.apple.com/guide/mac-help/use-dictation-mh40584/mac) (accessed 2026-10-13; documentation unless the linked ledger record labels an observation/report).

**Search/inspection scope:** A03_speech: native/processor/viewer paths. Existing note editing is not a transcript editor; no arbitrary-app dictation insertion pipeline found.

**Practical impact:** Raw token times are retained, but native sentence projection has no correction model. A bad identifier may hinder search. General dictation solves writing in many apps and should not be inferred from a post-stop recognizer.

**Cost and risk:** Small for using an external dictation tool in NoteEditor; medium for an explicit correction sidecar; large for a robust systemwide dictation product with focus/Accessibility/provider management.

**Smallest proposed improvement:** First use Apple Dictation or a chosen local/cloud specialist in the existing note field. If transcript correction materially affects retrieval, preserve raw recognition and layer explicitly corrected text with original time ranges. Do not change the original video on text correction.

**Proof that can reject it:** Seed a wrong code identifier. Compare a typed/dictated corrective note with a transcript correction overlay. Measure correction burden and retrieval success separately from recognizer accuracy. Reject a native editor if note corrections suffice; decline global dictation implementation.

**Decision:** Reuse dictation; explore narrow transcript correction only after evidence.


<a id="g12"></a>
### G12 — Portable clip and evidence handoff beyond local paths

**Classification:** partial · extraction / recipient access gap · P2 conditional

**Affected task:** Give a recipient the short relevant interval and findings when they cannot open Byron’s original folder.

**Repository basis:** [R018](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294) [R015](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77)

**Competitor comparison:** [S097](https://www.browserstack.com/docs/testing-toolkit/bug-capture/faqs/recording-videos) [S037](https://help.marker.io/en/articles/14430683-why-are-console-logs-network-requests-and-replays-linked-instead-of-attached) [S093](https://help.frame.io/en/articles/9105278-comments-panel-overview) [S085](https://www.descript.com/screen-recording) (accessed 2026-10-13; documentation unless the linked ledger record labels an observation/report).

**Search/inspection scope:** A06_export: Markdown, selected PGM export, processor and HTML. No clip-range/AVAssetExport pipeline found in inspected scope.

**Practical impact:** A complete copied session folder is portable for review; one HTML file or an absolute MP4 path is not. Source context can be present locally yet unusable for a recipient. Video download by itself is also not complete diagnostic portability in competitor products.

**Cost and risk:** Small for a clearly documented folder bundle; medium for clips, copied dependent assets and stable relative references. Cloud share links introduce service cost without proof of need.

**Smallest proposed improvement:** Start with a selected bundle manifest and source interval reference, or a manual clip from an existing tool. Preserve a link back to the original and label edited derivatives. Add a clip exporter only when recipients repeatedly cannot consume the current folder/Markdown.

**Proof that can reject it:** Move a proposed bundle to a different directory on a clean local test account and reopen without a server. Every intended asset and selected finding must resolve. Reject standalone claims if they depend on original absolute paths; prefer a simple folder over a custom package format.

**Decision:** Useful conditional extraction, not a mandate for hosted sharing.


<a id="g13"></a>
### G13 — Spatial storyboard / video-to-canvas

**Classification:** proposed only · exploratory product direction · P3 proof only

**Affected task:** Read and compare a long scrolled walkthrough in space, while retaining the moments that supplied each part.

**Repository basis:** [R019](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/docs/research/video-to-canvas/design.md#L3-L10) [R014](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L366-L420) [R004](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108)

**Competitor comparison:** [S062](https://shottr.cc/) [S074](https://scribe.com/pricing) [S087](https://github.com/screenpipe/screenpipe) (accessed 2026-10-13; documentation unless the linked ledger record labels an observation/report).

**Search/inspection scope:** A05_canvas_replay plus all four prior video-to-canvas documents. No analyzer, source-patch canvas data or implemented reconstruction found. Timeline Canvas is unrelated.

**Practical impact:** The prior direction could support larger-than-frame reading and change comparison. It has no measured product, geometry or performance proof in this baseline. A tall still, a chronological mark list and a stitched multi-time surface make different truth claims.

**Cost and risk:** Medium-to-large with significant false-join and source-loss risk. Automatic geometry, temporal provenance, bounded images and export semantics all need to earn their complexity.

**Smallest proposed improvement:** Keep the full prior vision as an alternative. First compare a useful change-selected board against ordinary review. Only when larger-than-frame geometry provides additional value run the bounded one-viewport scroll/edit/refused-join experiment from prior research.

**Proof that can reject it:** Require no harmful accepted join or lost required change, real patch-to-frame mapping and a predeclared benefit over the stronger simple-board baseline. Reject stitching if the board provides equivalent benefit or uncertain areas are presented as observed pixels.

**Decision:** Explore conditionally; not a required winner and not an approved initiative.


<a id="g14"></a>
### G14 — Continuous DOM or execution replay

**Classification:** absent within inspected scope · desirable omission unless a distinct debugging task appears · Below cut

**Affected task:** Reconstruct a browser failure that cannot be diagnosed from the recorded explanation and context.

**Repository basis:** [R025](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L134-L137) [R010](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L9-L31) [R009](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168)

**Competitor comparison:** [S030](https://jam.dev/docs/instant-replay) [S090](https://docs.replay.io/reference/replay-cli/commands) [S098](https://www.browserstack.com/docs/testing-toolkit/bug-capture/faqs/replays) (accessed 2026-10-13; documentation unless the linked ledger record labels an observation/report).

**Search/inspection scope:** A05_canvas_replay; bounded event summaries and on-demand saved pages only. No rrweb integration or execution recorder in supplied code.

**Practical impact:** MHTML preserves a page snapshot, not all mutations or JavaScript execution. More replay could answer different questions, but adds instrumentation volume, sensitive content and browser-specific support. It does not automatically improve reviewing narrated walkthroughs.

**Cost and risk:** Large relative to this project; permissions/instrumentation/privacy/runtime compatibility and storage may dominate value.

**Smallest proposed improvement:** Escalate a hard browser issue to an existing replay product. Keep relevant raw diagnostic events in Context Recorder. Add a replay dependency only after a specific recurring question cannot be answered otherwise.

**Proof that can reject it:** Use one reproducible failure where current evidence is insufficient and a replay tool supplies the missing fact. Reject embedding replay if it only adds a second way to watch the same viewport.

**Decision:** Decline by default; preserve as a specialist complement.


<a id="g15"></a>
### G15 — Cloud collaboration and autonomous issue/agent workflows

**Classification:** absent within inspected scope · desirable omission / product-boundary choice · Below cut

**Affected task:** Collect feedback from other people or let an agent create tasks without manual review.

**Repository basis:** [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) [R018](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294) [R001](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Package.swift#L1-L20)

**Competitor comparison:** [S007](https://support.atlassian.com/loom/docs/record-for-agent/) [S032](https://jam.dev/integrations/github) [S042](https://bugherd.com/feature/mcp) [S092](https://help.frame.io/en/articles/9105251-commenting-on-your-media) (accessed 2026-10-13; documentation unless the linked ledger record labels an observation/report).

**Search/inspection scope:** A06_export plus native UI/main and supplied manifest; no account/remote collaboration or agent-protocol service implemented. Local Markdown/PGM handoff already exists.

**Practical impact:** Cloud comments and integrations are category strengths, but the brief supplies no team buyer or multi-tenant need. Native copied Markdown is already an agent handoff. Automatic proposals are not verified bugs or approved fixes.

**Cost and risk:** Large for hosted identity, permissions, retention, billing, deployment and integration maintenance. A simple local structured packet costs much less.

**Smallest proposed improvement:** Keep manual reviewed Markdown/JSON handoff and optional PGM. Use Jam/Loom/Frame.io when another person’s workflow makes hosted collaboration valuable. Avoid inventing a new protocol server solely because competitors advertise agents.

**Proof that can reject it:** Demonstrate a repeated task that cannot be completed with current reviewed artifacts or an existing integration. Reject custom infrastructure without that concrete need; generated issue text must remain reviewable and linked to source.

**Decision:** Avoid for the proposed first direction.


<a id="g16"></a>
### G16 — Reliability, performance and test coverage are not established by source

**Classification:** unknown · untested implementation, not feature absence · P1 proof gate

**Affected task:** Trust long-session review, save/retry and export without losing original evidence.

**Repository basis:** [R020](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/check-transcript.py#L1-L16) [R021](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionLibrary.swift#L102-L122) [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) [R008](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L473-L484)

**Competitor comparison:** [S018](https://github.com/CapSoftware/Cap/issues/1696) [S089](https://github.com/screenpipe/screenpipe/issues/3498) [S021](https://obsproject.com/kb/audio-video-formats-guide) (accessed 2026-10-13; documentation unless the linked ledger record labels an observation/report).

**Search/inspection scope:** Static source and harness documentation only; no timing, permissions, media, UI or provider test executed in this research.

**Practical impact:** Caching, queueing, atomic mark writes and export checkpoints deserve credit. They do not prove end-to-end recovery, acceptable latency or usable one-hour sessions. The existing harness depends on named personal sessions, which are not a portable proof corpus.

**Cost and risk:** Small for a few synthetic golden/failure fixtures; medium for later media/UI measurements. A broad benchmark service or large testing rewrite is unjustified.

**Smallest proposed improvement:** Use a synthetic shared corpus and three valuable checks: semantic-output parity, failure/no-raw-loss behavior, and one end-to-end reviewer task. Reuse existing transcript/UI seams without running personal-fixture prepare in this research.

**Proof that can reject it:** Record actual failures and stage timings during later authorized proofs. Reject any claimed performance or reliability benefit without a measured baseline; narrow a failing slice rather than adding a test platform.

**Decision:** Uncertainty gate attached to each proposed change, not an accusation that the app is unreliable.


## Two especially important source corrections

### Input values are not comprehensively excluded

The packet’s README and the brief repeat an input-exclusion claim. Actual `describe()` chooses `target.innerText || target.value || ""`; the change handler and focused/hovered snapshot paths call it. A nonempty value can therefore enter stored structured context. The comment “Never record values” does not change that control flow. This finding corrects the supplied claim using its authorized source, rather than silently accepting or generalizing it. No personal session or actual secret was inspected. [R011](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L194-L215)

### Notes exist, but portable output is not equivalent

Native notes and processor Markdown are implemented. The HTML template still ignores note fields in its title, visible mark detail and copied Markdown. Embedding a note inside hidden JSON is not equivalent to presenting or handing it off. Likewise the existing native transcript regression does not cover HTML’s different sentence selection. Fixing this is semantic parity, not an annotation or transcription feature project. [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) [R006](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/viewer.html#L295-L334) [R020](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/check-transcript.py#L1-L16)

## Desirable omissions and things not worth copying by default

Keep recording sessions bounded unless forgotten all-day context is the actual problem. Keep cloud accounts, multi-tenant permissions, team workspaces, autonomous issue creation and billing out of a personal review tool. Use a ready-made reporter when another person needs to capture feedback. Avoid a full video studio, global dictation engine or mandatory DOM/execution replay dependency. Higher frame rate, webcam, cinematic cursor movement, AI cleanup and a spatial canvas all need task-specific value; a larger feature list is not proof of a better product. [R001](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Package.swift#L1-L20) [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) [R019](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/docs/research/video-to-canvas/design.md#L3-L10) [R023](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionData.swift#L62-L66) [R025](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L134-L137) [S007](https://support.atlassian.com/loom/docs/record-for-agent/) [S032](https://jam.dev/integrations/github) [S088](https://screenpipe.com/privacy) [S083](https://www.descript.com/) [S090](https://docs.replay.io/reference/replay-cli/commands)

## Recorded absence searches

The following searches were executed over the exact packet text in a scratch research directory. They did not operate on a repository checkout. A positive lexical hit can be an unrelated UI term, comment or proposed idea; absence decisions also use manual control-flow/model/UI inspection. No nonempty hit list is interpreted as proof that a capability exists.


### A01_search

Files searched: **13**. Matching source lines: **0**.

Regex used:

```text
searchable|searchText|searchQuery|filterText|localizedCaseInsensitiveContains|type="search"|type=\"search\"
```

Exact files:

- `Sources/ContextRecorder/Library/Components.swift`
- `Sources/ContextRecorder/Library/LibraryView.swift`
- `Sources/ContextRecorder/Library/LibraryWindow.swift`
- `Sources/ContextRecorder/Library/MarkDetail.swift`
- `Sources/ContextRecorder/Library/MarkText.swift`
- `Sources/ContextRecorder/Library/Review.swift`
- `Sources/ContextRecorder/Library/SessionData.swift`
- `Sources/ContextRecorder/Library/SessionLibrary.swift`
- `Sources/ContextRecorder/Library/SessionModel.swift`
- `Sources/ContextRecorder/Library/SessionTimeline.swift`
- `Sources/ContextRecorder/Library/SessionView.swift`
- `Sources/ContextRecorder/Library/SidePanel.swift`
- `scripts/viewer.html`

Interpretation: Zero hits plus inspection of TranscriptList, PageEventsList, filteredMarks and library groups supports the narrow absence of app-level text search. Browser/editor Find is an external alternative.

### A02_capture

Files searched: **5**. Matching source lines: **11**.

Regex used:

```text
pauseCapture|resumeCapture|captureMicrophone|capturesAudio|CGMainDisplayID|sourceRect|webcam|camera|fps|maxWidth
```

Exact files:

- `Sources/ContextRecorder/ControlPanel.swift`
- `Sources/ContextRecorder/HotKeys.swift`
- `Sources/ContextRecorder/Recorder.swift`
- `Sources/ContextRecorder/RegionSelector.swift`
- `Sources/ContextRecorder/main.swift`

Interpretation: Hits confirm configured fps, width, system-audio exclusion and screenshot sourceRect. They do not show a selectable region-video pipeline or recording pause.

Representative positive hits (full scope above; not an exhaustive printed hit dump):

| File / line | Source text |
| --- | --- |
| `Sources/ContextRecorder/Recorder.swift:21` | `static let maxWidth = 1920` |
| `Sources/ContextRecorder/Recorder.swift:22` | `static let fps: Int32 = 15` |
| `Sources/ContextRecorder/Recorder.swift:26` | `let mainID = CGMainDisplayID()` |
| `Sources/ContextRecorder/Recorder.swift:32` | `// Scale to <= maxWidth, keeping aspect, even dimensions for H.264.` |
| `Sources/ContextRecorder/Recorder.swift:33` | `let scale = min(1.0, Double(Self.maxWidth) / Double(display.width))` |
| `Sources/ContextRecorder/Recorder.swift:40` | `config.minimumFrameInterval = CMTime(value: 1, timescale: Self.fps)` |


### A03_speech

Files searched: **27**. Matching source lines: **61**.

Regex used:

```text
dictat|transcrib|transcript|SFSpeech|AVCapture|SpeechAnalyzer|vocab|correctTranscript
```

Exact files:

- `Sources/ContextRecorder/ActivityLog.swift`
- `Sources/ContextRecorder/BrowserBridge.swift`
- `Sources/ContextRecorder/ContextProbe.swift`
- `Sources/ContextRecorder/ControlPanel.swift`
- `Sources/ContextRecorder/Export/ExportSheet.swift`
- `Sources/ContextRecorder/Export/Pgm.swift`
- `Sources/ContextRecorder/Export/PgmExport.swift`
- `Sources/ContextRecorder/HotKeys.swift`
- `Sources/ContextRecorder/JSONValue.swift`
- `Sources/ContextRecorder/Library/Components.swift`
- `Sources/ContextRecorder/Library/LibraryView.swift`
- `Sources/ContextRecorder/Library/LibraryWindow.swift`
- `Sources/ContextRecorder/Library/MarkDetail.swift`
- `Sources/ContextRecorder/Library/MarkText.swift`
- `Sources/ContextRecorder/Library/Review.swift`
- `Sources/ContextRecorder/Library/SessionData.swift`
- `Sources/ContextRecorder/Library/SessionLibrary.swift`
- `Sources/ContextRecorder/Library/SessionModel.swift`
- `Sources/ContextRecorder/Library/SessionTimeline.swift`
- `Sources/ContextRecorder/Library/SessionView.swift`
- `Sources/ContextRecorder/Library/SidePanel.swift`
- `Sources/ContextRecorder/Recorder.swift`
- `Sources/ContextRecorder/RegionSelector.swift`
- `Sources/ContextRecorder/Session.swift`
- `Sources/ContextRecorder/main.swift`
- `scripts/process_session.py`
- `scripts/viewer.html`

Interpretation: Hits show post-stop transcription, sentence/token projection and note editing. No arbitrary-application speech insertion, live caption stream or transcript editor was located.

Representative positive hits (full scope above; not an exhaustive printed hit dump):

| File / line | Source text |
| --- | --- |
| `Sources/ContextRecorder/Export/PgmExport.swift:177` | `if !session.transcript.isEmpty {` |
| `Sources/ContextRecorder/Export/PgmExport.swift:179` | `lines += session.transcript.map { "- \`\(Format.time($0.start))\` \($0.text)" }` |
| `Sources/ContextRecorder/Library/LibraryView.swift:200` | `.help("Narrated: has a transcript")` |
| `Sources/ContextRecorder/Library/SessionData.swift:12` | `var transcript: [Sentence]` |
| `Sources/ContextRecorder/Library/SessionData.swift:14` | `enum CodingKeys: String, CodingKey { case name, folder, duration, marks, activity, browser, transcript }` |
| `Sources/ContextRecorder/Library/SessionData.swift:24` | `transcript = try c.decodeIfPresent([Sentence].self, forKey: .transcript) ?? []` |


### A04_drawing_redaction

Files searched: **34**. Matching source lines: **174**.

Regex used:

```text
redact|pixelate|blur|mask|annotation|arrow|value
```

Exact files:

- `Sources/ContextRecorder/ActivityLog.swift`
- `Sources/ContextRecorder/BrowserBridge.swift`
- `Sources/ContextRecorder/ContextProbe.swift`
- `Sources/ContextRecorder/ControlPanel.swift`
- `Sources/ContextRecorder/Export/ExportSheet.swift`
- `Sources/ContextRecorder/Export/Pgm.swift`
- `Sources/ContextRecorder/Export/PgmExport.swift`
- `Sources/ContextRecorder/HotKeys.swift`
- `Sources/ContextRecorder/JSONValue.swift`
- `Sources/ContextRecorder/Library/Components.swift`
- `Sources/ContextRecorder/Library/LibraryView.swift`
- `Sources/ContextRecorder/Library/LibraryWindow.swift`
- `Sources/ContextRecorder/Library/MarkDetail.swift`
- `Sources/ContextRecorder/Library/MarkText.swift`
- `Sources/ContextRecorder/Library/Review.swift`
- `Sources/ContextRecorder/Library/SessionData.swift`
- `Sources/ContextRecorder/Library/SessionLibrary.swift`
- `Sources/ContextRecorder/Library/SessionModel.swift`
- `Sources/ContextRecorder/Library/SessionTimeline.swift`
- `Sources/ContextRecorder/Library/SessionView.swift`
- `Sources/ContextRecorder/Library/SidePanel.swift`
- `Sources/ContextRecorder/Recorder.swift`
- `Sources/ContextRecorder/RegionSelector.swift`
- `Sources/ContextRecorder/Session.swift`
- `Sources/ContextRecorder/main.swift`
- `extension/background.js`
- `extension/manifest.json`
- `extension/page.js`
- `extension/popup.css`
- `extension/popup.html`
- `extension/popup.js`
- `extension/relay.js`
- `scripts/process_session.py`
- `scripts/viewer.html`

Interpretation: Many hits are UI blur, Canvas drawing, crop masks or generic value variables. These are not a comprehensive artifact redaction pipeline. The describe target.value path is a positive counterexample to blanket input exclusion.

Representative positive hits (full scope above; not an exhaustive printed hit dump):

| File / line | Source text |
| --- | --- |
| `Sources/ContextRecorder/BrowserBridge.swift:16` | `var onEvent: ((JSONValue) -> Void)?          // main queue` |
| `Sources/ContextRecorder/BrowserBridge.swift:24` | `private var pending: [String: (JSONValue?) -> Void] = [:]` |
| `Sources/ContextRecorder/BrowserBridge.swift:31` | `let origin = headers.first { $0.name.lowercased() == "origin" }?.value ?? ""` |
| `Sources/ContextRecorder/BrowserBridge.swift:38` | `params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: Self.port)!)` |
| `Sources/ContextRecorder/BrowserBridge.swift:56` | `completion: @escaping (JSONValue?) -> Void) {` |
| `Sources/ContextRecorder/BrowserBridge.swift:62` | `self.pending[id] = { value in DispatchQueue.main.async { completion(value) } }` |


### A05_canvas_replay

Files searched: **39**. Matching source lines: **6**.

Regex used:

```text
rrweb|analyze_canvas|canvas\.json|scrollX|scrollY|Canvas
```

Exact files:

- `Sources/ContextRecorder/ActivityLog.swift`
- `Sources/ContextRecorder/BrowserBridge.swift`
- `Sources/ContextRecorder/ContextProbe.swift`
- `Sources/ContextRecorder/ControlPanel.swift`
- `Sources/ContextRecorder/Export/ExportSheet.swift`
- `Sources/ContextRecorder/Export/Pgm.swift`
- `Sources/ContextRecorder/Export/PgmExport.swift`
- `Sources/ContextRecorder/HotKeys.swift`
- `Sources/ContextRecorder/JSONValue.swift`
- `Sources/ContextRecorder/Library/Components.swift`
- `Sources/ContextRecorder/Library/LibraryView.swift`
- `Sources/ContextRecorder/Library/LibraryWindow.swift`
- `Sources/ContextRecorder/Library/MarkDetail.swift`
- `Sources/ContextRecorder/Library/MarkText.swift`
- `Sources/ContextRecorder/Library/Review.swift`
- `Sources/ContextRecorder/Library/SessionData.swift`
- `Sources/ContextRecorder/Library/SessionLibrary.swift`
- `Sources/ContextRecorder/Library/SessionModel.swift`
- `Sources/ContextRecorder/Library/SessionTimeline.swift`
- `Sources/ContextRecorder/Library/SessionView.swift`
- `Sources/ContextRecorder/Library/SidePanel.swift`
- `Sources/ContextRecorder/Recorder.swift`
- `Sources/ContextRecorder/RegionSelector.swift`
- `Sources/ContextRecorder/Session.swift`
- `Sources/ContextRecorder/main.swift`
- `extension/background.js`
- `extension/manifest.json`
- `extension/page.js`
- `extension/popup.css`
- `extension/popup.html`
- `extension/popup.js`
- `extension/relay.js`
- `scripts/build-app.sh`
- `scripts/check-transcript.py`
- `scripts/process_session.py`
- `scripts/ui-test/README.md`
- `scripts/ui-test/cua.js`
- `scripts/ui-test/harness.py`
- `scripts/viewer.html`

Interpretation: Hits include sparse viewport scroll metadata and SwiftUI timeline Canvas. Neither supplies continuous DOM replay or reconstructed spatial video.

Representative positive hits (full scope above; not an exhaustive printed hit dump):

| File / line | Source text |
| --- | --- |
| `Sources/ContextRecorder/Library/SessionTimeline.swift:154` | `return Canvas { ctx, size in` |
| `Sources/ContextRecorder/Library/SessionTimeline.swift:217` | `return Canvas { ctx, size in` |
| `Sources/ContextRecorder/Library/SessionTimeline.swift:246` | `return Canvas { ctx, size in` |
| `Sources/ContextRecorder/Library/SessionTimeline.swift:263` | `return Canvas { ctx, size in` |
| `extension/page.js:375` | `viewport: { width: innerWidth, height: innerHeight, dpr: devicePixelRatio, scrollX: Math.round(scrollX), scrollY: Math.round(scrollY) },` |
| `extension/page.js:402` | `const MEANINGFUL = "button, a, input, select, textarea, label, summary, [role], [tabindex], h1, h2, h3, h4, h5, h6, img, svg, canvas, video, table, th, td, li, p, [data-testid], [data-test], [data-cy]";` |


### A06_export

Files searched: **6**. Matching source lines: **68**.

Regex used:

```text
markdown|selectedMarks|note|review|recording\.mp4|--local|AVAssetExport|clip|share
```

Exact files:

- `Sources/ContextRecorder/Export/ExportSheet.swift`
- `Sources/ContextRecorder/Export/Pgm.swift`
- `Sources/ContextRecorder/Export/PgmExport.swift`
- `Sources/ContextRecorder/Library/MarkText.swift`
- `scripts/process_session.py`
- `scripts/viewer.html`

Interpretation: Hits establish local export, selection and multiple Markdown paths. Manual comparison exposes note/provenance divergence and broader session payload; no clip-range exporter was located.

Representative positive hits (full scope above; not an exhaustive printed hit dump):

| File / line | Source text |
| --- | --- |
| `Sources/ContextRecorder/Export/ExportSheet.swift:15` | `var selectedMarks: Set<Int>` |
| `Sources/ContextRecorder/Export/ExportSheet.swift:26` | `selectedMarks = Set(session.marks.map(\.index))` |
| `Sources/ContextRecorder/Export/ExportSheet.swift:39` | `guard selected != nil, !selectedMarks.isEmpty, !loading else { return false }` |
| `Sources/ContextRecorder/Export/ExportSheet.swift:115` | `let marks = session.marks.filter { selectedMarks.contains($0.index) }` |
| `Sources/ContextRecorder/Export/ExportSheet.swift:204` | `Button("Reveal in Finder", systemImage: "folder") { NSWorkspace.shared.activateFileViewerSelecting([t.url]) }` |
| `Sources/ContextRecorder/Export/ExportSheet.swift:281` | `return GroupBlock(title: "Marks", symbol: "flag", trailing: "\(model.selectedMarks.count) of \(all.count)") {` |


## Immutable repository evidence locators

<a id="r001"></a>
### R001 — Stack and platform

Swift package targets macOS 26; the supplied manifest contains Swift, Python and plain JavaScript, but no package.json. The packet is not a full Git tree.

- [`Package.swift:1-20`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Package.swift#L1-L20) — `// swift-tools`.

- [`README.md:124-137`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L124-L137) — `## Layout`.

<a id="r002"></a>
### R002 — Capture configuration

Main display, 1920-pixel width cap, requested 15 fps, visible cursor, optional default microphone; system audio explicitly disabled. Recording stop is distinct from playback pause.

- [`Sources/ContextRecorder/Recorder.swift:21-80`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Recorder.swift#L21-L80) — `static let maxWidth`.

- [`Sources/ContextRecorder/Recorder.swift:81-97`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Recorder.swift#L81-L97) — `func stop()`.

<a id="r003"></a>
### R003 — Controls and keyboard access

Global Carbon hotkeys and floating control panel already exist; keyboard help and review shortcuts are implemented. Registration failure logs do not establish visible conflict recovery.

- [`Sources/ContextRecorder/HotKeys.swift:5-44`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/HotKeys.swift#L5-L44) — `final class HotKeys`.

- [`Sources/ContextRecorder/ControlPanel.swift:153-191`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/ControlPanel.swift#L153-L191) — `func update(`.

- [`Sources/ContextRecorder/Library/LibraryView.swift:303-336`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/LibraryView.swift#L303-L336) — `struct ShortcutsSheet`.

<a id="r004"></a>
### R004 — Review marks already work in source

Add review marks/cropped frames/notes; use recorded activity and prior page events, not a historical DOM snapshot. Only review marks can be deleted.

- [`Sources/ContextRecorder/Library/Review.swift:13-108`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108) — `extension SessionModel`.

- [`Sources/ContextRecorder/Library/Review.swift:108-117`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L108-L117) — `private func recentPageEvents`.

<a id="r005"></a>
### R005 — Native note and provenance output

Native title and Markdown include typed note and review provenance. MarksFile atomically rewrites loose JSON, preserving unmodeled fields; note edits rerun processing.

- [`Sources/ContextRecorder/Library/MarkText.swift:59-115`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) — `static func title`.

- [`Sources/ContextRecorder/Library/Review.swift:64-78`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L64-L78) — `func setNote`.

- [`Sources/ContextRecorder/Library/Review.swift:179-196`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L179-L196) — `enum MarksFile`.

<a id="r006"></a>
### R006 — HTML/native semantic divergence

HTML titleOf, markdownFor and renderList omit typed notes and review provenance. HTML sentenceAt uses first matching sentence with a lead-in; native uses last started sentence.

- [`scripts/viewer.html:295-334`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/viewer.html#L295-L334) — `const titleOf`.

- [`scripts/viewer.html:365-404`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/viewer.html#L365-L404) — `function renderList`.

- [`Sources/ContextRecorder/Library/SessionModel.swift:143-146`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionModel.swift#L143-L146) — `func sentenceAt`.

<a id="r007"></a>
### R007 — Post-capture local transcription

Processor caches transcript.json; extracts 16 kHz mono audio with ffmpeg and runs parakeet-mlx. Missing recognizer returns no transcript. Tokens drive narration windows; native rollup keeps sentence times.

- [`scripts/process_session.py:56-96`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L56-L96) — `def has_audio`.

- [`scripts/process_session.py:98-117`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L98-L117) — `def tokens_of`.

- [`scripts/process_session.py:337-339`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L337-L339) — `"transcript":`.

<a id="r008"></a>
### R008 — Failure and silence states differ by path

Initial processing completion ignores exit status; missing script logs and completes. Native empty transcript is labeled silent. Review reprocessing does check nonzero status and exposes an error.

- [`Sources/ContextRecorder/main.swift:473-484`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L473-L484) — `private func runPostProcessing`.

- [`Sources/ContextRecorder/Library/SessionView.swift:27-48`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionView.swift#L27-L48) — `@ViewBuilder private var content`.

- [`Sources/ContextRecorder/Library/SessionView.swift:359-415`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionView.swift#L359-L415) — `struct NowStrip`.

- [`Sources/ContextRecorder/Library/Review.swift:150-169`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L150-L169) — `func reprocess`.

<a id="r009"></a>
### R009 — Developer source grounding exists, with limits

sourceFor reads framework/build attributes and marks React 19 post-transform lines. SourceButton opens an existing path in VS Code or copies it. Solid needs source attributes; production source fidelity is not assured.

- [`extension/page.js:135-168`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168) — `function sourceFor`.

- [`Sources/ContextRecorder/Library/MarkDetail.swift:400-436`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkDetail.swift#L400-L436) — `struct SourceButton`.

- [`Sources/ContextRecorder/Library/SessionData.swift:97-110`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionData.swift#L97-L110) — `struct SourceLocation`.

<a id="r010"></a>
### R010 — Browser context and bounded diagnostics

Click/navigation/errors plus failed/slow requests are streamed; ring size 60, recent 40; error bodies truncated to 800 characters. Mark snapshot includes DOM descriptions, selection, viewport and source candidates.

- [`extension/page.js:9-31`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L9-L31) — `const RING_SIZE`.

- [`extension/page.js:296-350`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L296-L350) — `function recordRequest`.

- [`extension/page.js:365-384`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L365-L384) — `function snapshot`.

- [`extension/background.js:98-111`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/background.js#L98-L111) — `async function capturePage`.

<a id="r011"></a>
### R011 — Input exclusion claim contradicted

describe() falls back to target.value and is called by change handling and focused/hovered snapshots. No password guard is present in that path. This is reachable sensitive-data collection in source, not an observed leak.

- [`extension/page.js:194-215`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L194-L215) — `function describe`.

- [`extension/page.js:234-237`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L234-L237) — `// Never record values`.

- [`extension/page.js:365-383`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L365-L383) — `function snapshot`.

- [`README.md:96-96`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L96-L96) — `Input values are never`.

<a id="r012"></a>
### R012 — Local connection and indicator boundaries

Bridge binds localhost but accepts empty Origin as well as chrome-extension origins. Popup equates connectivity with capturing. Native event writing is gated on an active session.

- [`Sources/ContextRecorder/BrowserBridge.swift:26-50`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/BrowserBridge.swift#L26-L50) — `func start()`.

- [`extension/popup.js:3-14`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/popup.js#L3-L14) — `const STATES`.

- [`extension/popup.js:49-54`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/popup.js#L49-L54) — `function renderTabState`.

- [`Sources/ContextRecorder/main.swift:167-170`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L167-L170) — `bridge.onEvent`.

<a id="r013"></a>
### R013 — Event time, queue and tab projection

Page has wall-clock event.t; native assigns receipt offset. Extension reconnect queue holds up to 200 messages. Raw events carry tabId; native PageEvent projection and review recent-event selection do not retain/filter all identity fields.

- [`extension/page.js:23-31`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L23-L31) — `function record(event`.

- [`extension/background.js:3-49`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/background.js#L3-L49) — `const MAX_QUEUE`.

- [`extension/background.js:131-139`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/background.js#L131-L139) — `chrome.runtime.onMessage`.

- [`Sources/ContextRecorder/main.swift:167-170`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L167-L170) — `bridge.onEvent`.

- [`Sources/ContextRecorder/Library/SessionData.swift:124-145`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionData.swift#L124-L145) — `struct PageEvent`.

- [`Sources/ContextRecorder/Library/Review.swift:108-116`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L108-L116) — `private func recentPageEvents`.

<a id="r014"></a>
### R014 — Mark time is not all artifact exposure times

Live region mark offset/context are taken before selection, then pixels are captured later. Review saveFrame discards actual returned time; extract_frame stores requested seek, not decoded exposure metadata.

- [`Sources/ContextRecorder/main.swift:366-420`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L366-L420) — `private func addMark`.

- [`Sources/ContextRecorder/main.swift:422-440`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L422-L440) — `private func addRegionMark`.

- [`Sources/ContextRecorder/Library/Review.swift:126-147`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L126-L147) — `private func saveFrame`.

- [`scripts/process_session.py:131-141`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L131-L141) — `def extract_frame`.

<a id="r015"></a>
### R015 — Selected export has broader payload

Export sheet selects mark children, but sessionMarkdown includes full transcript; imageFiles includes full frame alongside a region still. Selection is not a complete content boundary.

- [`Sources/ContextRecorder/Export/ExportSheet.swift:115-121`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) — `let marks = session.marks.filter`.

- [`Sources/ContextRecorder/Export/PgmExport.swift:155-161`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/PgmExport.swift#L155-L161) — `private func imageFiles`.

- [`Sources/ContextRecorder/Export/PgmExport.swift:166-181`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/PgmExport.swift#L166-L181) — `private var sessionMarkdown`.

<a id="r016"></a>
### R016 — Local and partly recoverable Product Grid export

Pgm always appends --local; arguments avoid shell interpolation; queue serializes CLI operations. Re-export updates owned context/images and preserves user title/status/other images. Mapping checkpoints avoid some duplicate work.

- [`Sources/ContextRecorder/Export/Pgm.swift:41-77`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) — `private func runOnce`.

- [`Sources/ContextRecorder/Export/Pgm.swift:206-218`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L206-L218) — `actor PgmQueue`.

- [`Sources/ContextRecorder/Export/PgmExport.swift:98-152`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/PgmExport.swift#L98-L152) — `func run(progress`.

<a id="r017"></a>
### R017 — Navigation is not text retrieval

Native transcript and page lists seek on click. Marks filter by kind, library by date groups; no app-level text query found across all 13 Library/viewer files in scope A01_search.

- [`Sources/ContextRecorder/Library/SidePanel.swift:265-310`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SidePanel.swift#L265-L310) — `struct TranscriptList`.

- [`Sources/ContextRecorder/Library/SessionModel.swift:112-119`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionModel.swift#L112-L119) — `var filteredMarks`.

- [`Sources/ContextRecorder/Library/LibraryView.swift:134-152`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/LibraryView.swift#L134-L152) — `private var groups`.

<a id="r018"></a>
### R018 — Local output and portability boundary

Processor embeds JSON into viewer HTML, but video/images/pages remain relative external files. Native Markdown embeds absolute folder video paths plus text times; a copied link is not a bundled session.

- [`scripts/process_session.py:290-294`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294) — `def write_viewer`.

- [`scripts/viewer.html:191-191`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/viewer.html#L191-L191) — `<div class="player"><video`.

- [`Sources/ContextRecorder/Library/MarkText.swift:78-109`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L78-L109) — `static func markdown(_`.

- [`scripts/process_session.py:330-342`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L330-L342) — `data = {`.

<a id="r019"></a>
### R019 — Spatial canvas is proposal only

Prior design explicitly says not implemented and preserves observed pixel/source semantics. Current timeline Canvas draws lanes, not a reconstructed page. Old research uses another baseline and is not product proof.

- [`docs/research/video-to-canvas/design.md:3-10`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/docs/research/video-to-canvas/design.md#L3-L10) — `Status:`.

- [`docs/research/video-to-canvas/design.md:50-81`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/docs/research/video-to-canvas/design.md#L50-L81) — `## What an image means`.

- [`docs/research/video-to-canvas/proof-plan.md:85-105`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/docs/research/video-to-canvas/proof-plan.md#L85-L105) — `## 5. Decide whether to continue`.

- [`Sources/ContextRecorder/Library/SessionTimeline.swift:148-169`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionTimeline.swift#L148-L169) — `private func ruler`.

<a id="r020"></a>
### R020 — Existing tests and fixture dependency

Transcript regression script exercises native exact sentence starts. UI harness exists with path/process protections but prepare copies specified personal sessions. It was not run; synthetic replacements are needed for a shareable proof.

- [`scripts/check-transcript.py:1-16`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/check-transcript.py#L1-L16) — `#!/usr/bin`.

- [`scripts/ui-test/harness.py:24-28`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/ui-test/harness.py#L24-L28) — `SOURCE =`.

- [`scripts/ui-test/harness.py:95-146`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/ui-test/harness.py#L95-L146) — `def prepare`.

- [`scripts/ui-test/README.md:86-113`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/ui-test/README.md#L86-L113) — `## PR #8`.

<a id="r021"></a>
### R021 — Library and preview implementation, not measured performance

Library rename and recoverable Trash paths exist; preview requests are coalesced and cache capped at 150. These are design choices, not measured responsiveness or crash guarantees.

- [`Sources/ContextRecorder/Library/SessionLibrary.swift:102-122`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionLibrary.swift#L102-L122) — `func rename`.

- [`Sources/ContextRecorder/Library/SessionTimeline.swift:384-422`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionTimeline.swift#L384-L422) — `final class FramePreviews`.

<a id="r022"></a>
### R022 — Permission/onboarding paths

README describes Screen Recording, microphone and Chrome Automation; main requests screen permission outside library-only mode. Extension injection/retry and restricted-page errors exist; no runtime permission success was tested.

- [`README.md:65-74`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L65-L74) — `First run asks`.

- [`Sources/ContextRecorder/main.swift:188-195`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L188-L195) — `if devLibraryFolder == nil {`.

- [`extension/background.js:60-93`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/background.js#L60-L93) — `async function handle`.

- [`Sources/ContextRecorder/main.swift:198-200`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L198-L200) — `// Ask for screen-recording permission`.

<a id="r023"></a>
### R023 — Native transcript model is not a dictation/editor

Sentence only stores start/end/text; NoteEditor edits a mark note, not the recognized transcript. No arbitrary-app speech insertion path found in A03_speech.

- [`Sources/ContextRecorder/Library/SessionData.swift:62-66`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionData.swift#L62-L66) — `struct Sentence`.

- [`Sources/ContextRecorder/Library/MarkDetail.swift:440-478`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkDetail.swift#L440-L478) — `struct NoteEditor`.

- [`scripts/process_session.py:77-96`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L77-L96) — `def transcribe`.

<a id="r024"></a>
### R024 — Crop and visual markup boundaries

Review and capture both have rectangle selection. RegionPicker dims an overlay for selection; saved output is a crop, not an irreversible privacy mask or an annotation editor.

- [`Sources/ContextRecorder/Library/SessionView.swift:190-244`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionView.swift#L190-L244) — `struct RegionPicker`.

- [`Sources/ContextRecorder/Recorder.swift:126-140`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Recorder.swift#L126-L140) — `func screenshot`.

- [`Sources/ContextRecorder/Library/Review.swift:126-147`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L126-L147) — `private func saveFrame`.

<a id="r025"></a>
### R025 — Snapshots do not supply replay

README lists rrweb as future work. Extension streams event summaries and captures MHTML on demand; it does not implement continuous DOM mutation replay or browser execution replay in A05_canvas_replay.

- [`README.md:134-137`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L134-L137) — `## Next`.

- [`extension/page.js:21-30`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L21-L30) — `const STREAM`.

- [`extension/background.js:98-111`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/background.js#L98-L111) — `async function capturePage`.

## Checks and limits

Executed: packet section/count/byte/hash checks; three Python AST parses; processor `--help` on an extracted scratch script; five external JavaScript syntax checks and one embedded-viewer syntax check; the six scoped source searches above; final CSV/JSON/ID/reference/count/hash/archive checks recorded in the manifest. These are research-package/static checks.

Not run: `swift build`, `scripts/check-transcript.py` execution, native UI harness, any recording/capture/permission request, ffmpeg media decode, speech provider inference, PGM export or usability/performance/crash experiment. The old canvas research’s historical build is not this run’s result. Existing harness `prepare` would read specified personal sessions; it was intentionally not used. [R020](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/check-transcript.py#L1-L16)

## Unresolved human choices — exactly three


**H1: Which primary outcome should govern the next proof: personal bug/product review, polished communication, or general dictation?** Personal local review is provisional, not a discovered preference. Review selects O3/RT-05; communication selects O5 specialist reuse; dictation selects O2/RT-07. Do not approve a broad implementation before this choice.

**H2: What data may leave the private session folder, and who must consume it?** Local private originals; explicit selected, previewed derivatives; no automatic upload. Determines export scope and whether a hosted specialist is acceptable. A raw full-session handoff requires a deliberate broader choice.

**H3: How much measured benefit must a new local-review surface deliver to justify its maintenance cost?** Keep the simpler workflow unless it clears a predeclared provisional 20% full-task time gain with no accuracy loss. Set the acceptance budget before evaluation, for lexical retrieval or a separately justified spatial-reading alternative. Do not move the threshold afterward or expand scope merely because a prototype exists.

All other uncertainties above are explicit proof conditions or below-cut omissions, not additional open-ended research projects. Codex owns intent recovery, alternative reconciliation, initiative validation and any later review PR. These files do not claim that work has happened.
