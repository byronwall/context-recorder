# Recording tools — conditional proof-first plan

**Status:** proposed and unrun. No implementation, capture test, repository mutation or approval occurred.  
**Repository / baseline:** `byronwall/context-recorder@6c74158ca96abd36819d2a58f75bacdc44107bb0`  
**Research date:** 2026-10-13, America/Indiana/Indianapolis

## 1. Intent and proposed first direction

The provisional task is: **review a deliberate narrated product walkthrough, locate a meaningful problem, explain it in a later note, and hand off selected evidence while retaining its source.** The next proof should compare this task in the current app against the smallest proposed local-review improvement—not against a deliberately weak video-only player.

Recommend O3, a focused local evidence workbench. O1 is the valid no-build result. O2/O5 win when general dictation or polished communication is the actual goal. O6 preserves the earlier spatial-reading idea as an alternative, not an approved requirement. The current app already has native review marks, notes, source links, a timeline and local PGM export. Reuse those seams. [R004](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108) [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) [R009](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168) [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) [R017](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SidePanel.swift#L265-L310)

The first changes worth considering protect evidence truth: RT-02 collection/export scope, RT-03 portable semantic parity and RT-04 processing states. RT-05 is the first additive product-value experiment. Do not implement all ten recommendations as one project.

## 2. Preconditions and safety boundary

Codex must first recover the existing intent and inspect the integration branch against the immutable baseline, preserving dirty files and prior research. This package does not verify the state of `/Users/byronwall/Projects/context-recorder` and did not access that path. No new worktree, install script, package installation or capture permission is needed to assess the research.

For a later authorized proof, use disposable **synthetic** sessions and an explicit fixture root. Do not run the existing harness `prepare` unchanged: it copies named personal recordings. Its safe-path/process checks and `--library` hooks are reusable, but the fixture source must be deliberately replaced or provided without reading personal sessions. No real recording, provider request or screenshot is an implicit prerequisite to the first data-only proof. [R020](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/check-transcript.py#L1-L16) [R022](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L65-L74)

Keep an allowlist of intended writes. Raw `recording.mp4`, activity/browser logs, saved pages and cached raw transcript should remain byte-identical during review/export. `marks.jsonl` is already mutable by design: allow intentional note edits and added/deleted review marks while checking that captured-mark evidence fields and unknown fields survive. Do not require a new schema or sidecar solely to imitate immutability; enforce the actual invariant. PGM mappings and exported derivatives have their own explicit write boundary. [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77)

## 3. Small realistic fixture set

Fixtures below are specifications, **not assets generated or tests executed in this research**. Reuse a single small fixture factory or hand-authored JSON rather than a testing service.

### F1 — Deliberate local product review

A synthetic three-minute walkthrough of a toy settings page and a small native window. Include five findings: a save failure, a wrong label, an animation/state transition, a repeated URL in a different context and a later reviewer correction. Give marks stable indices and times. Include one live mark with a supplied source attribute, one region still with its full frame, one later review mark, and one unmarked phrase that must be found through the transcript.

Include a cached transcript with an identifier deliberately misrecognized and a reviewer note correcting it. Use exact sentence-start fixtures at 1.00–1.05 seconds, 1.10–2.00 seconds and 4.00–5.00 seconds. These reuse the intent of the existing regression check while adding portable-view parity. A synthetic MP4 can be prepared during a separately authorized local proof; initial output/selection checks can work from metadata and placeholder assets without decoding media. [R020](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/check-transcript.py#L1-L16) [R006](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/viewer.html#L295-L334)

Ground truth is an explicit small JSON answer key: finding ID, note text, original time, source kind, expected source file/line confidence and allowed exported assets. The answer key must not be visible to the reviewer while timing tasks. It is not a model-generated answer evaluated against itself.

### F2 — Boundary and failure variants

Use F1’s structure with variants, not a separate large corpus. Add a two-tab reconnect trace containing events before and after session start; a late page-capture result; a missing MHTML page; a malformed derived session; no-audio, recognizer-unavailable and nonzero processor results. Include a captured mark with an unknown JSON field that must survive a note rewrite.

Put distinct synthetic canaries in input/password text, selected text, shallow props, a URL query, an error body, a full frame outside the selected crop and a saved page. Canaries are test strings, not credentials. Their allowed/disallowed status is defined by H2. A passed structured-input exclusion test does **not** certify pixels or MHTML. [R011](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L194-L215) [R012](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/BrowserBridge.swift#L26-L50) [R013](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L23-L31) [R015](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121)

### F3 — Matched retrieval variants

Make two additional independent three-minute sessions with equivalent task difficulty but different labels, errors and ordering. Each has five findings and one unmarked transcript clue. This yields three session variants for six matched tasks. Do not simply repeat the same clip, which would confound retrieval with memory.

The optional O6 spatial proof uses a separate short viewport fixture only when H1/H3 select spatial reading. It must compare against the stronger simple review/board baseline; it does not require lexical search to win first. The optional capture proof uses a separate synthetic display/audio fixture only when that task is a demonstrated blocker. Neither expands the initial corpus automatically.

## 4. First proof: no-build baseline, then a narrow candidate

### Stage A — Establish the current task baseline (PF-01 / PF-05)

Use the current native Sessions view, transcript seeking, mark navigation, typed notes and existing Markdown/PGM handoff. Also allow a realistic no-build alternative: search generated Markdown in an existing editor. Choose the stronger comparison, not whichever makes the candidate look better. Do not use a plain video player as the only baseline when the repository already offers more. [R004](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108) [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) [R017](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SidePanel.swift#L265-L310)

For each of six tasks, start when the task prompt is revealed and stop only when the selected evidence has been reopened and its source checked. Include search, playback, interpretation, note correction, export selection and packaging time. Record success/error, elapsed time, number of incorrect source selections and manual corrections. Product value is not just the time to the first search result.

Two matched tasks on each of three session variants are enough for a personal decision seed. Rotate which view is used first and use different but matched findings to reduce learning effects. Record order and all failures. This is not a statistical user study or a general market claim.

### Stage B — Prove semantic truth and failure visibility first (PF-02 / PF-03 / PF-04)

Before new search UI, compare native Markdown, processor Markdown and HTML rendering/copying against the same answer key. Require note-first title/body, review provenance and source time. At exact adjacent sentence starts, the expected sentence must be selected in native and HTML rules. Hidden JSON retention alone is not a pass. [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) [R006](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/viewer.html#L295-L334)

Exercise selected-two-of-five export. Inventory transcript ranges, crop/full-frame images and pages before writing. A whole-session option may deliberately include more, but it must be labeled. Current local PGM export is not a data-exfiltration finding; this proof tests scope and future recipient expectations. If a sanitized derivative is proposed, examine **every included surface** for its prohibited canaries. [R015](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77)

Show distinct no-audio, unavailable, pending, failed and ready states. A missing executable or failed subprocess may not produce a Silent label. A failed derived step must retain raw capture and expose a useful retry/log action; no autonomous background recovery service is required. [R007](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L56-L96) [R008](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L473-L484)

### Stage C — Add only the proposed retrieval-to-handoff slice (PF-05)

Prototype a local, in-session lexical query across note/narration/URL/error text. Each result shows why it matched and retains its time/source action. Use the existing player, mark selection and note model. Include clear-query, no-result, duplicate-match and unmarked-transcript cases. Do not add embeddings, a new server, all-day capture or a global library index.

The candidate may start as a narrow static/HTML or native experiment, whichever uses the existing seam with fewer changes. The acceptance task is the same across both. No new app stack is authorized. A portable read-only viewer is a valid intermediate state; arbitrary filesystem editing from a file:// page is not assumed.

Finish by exporting/copying the selected findings, opening the result from a moved disposable directory and following the source interval. A selected bundle need not invent a new package format: Markdown, relative assets and a small manifest can be enough. Keep the full private session unchanged.

## 5. Predeclared acceptance and rejection rules

These numerical gates are **proposals**, not measurements or approved product budgets. H3 may change them before evaluation. Record the chosen values before seeing results; do not tune them to conceal a failed proof.

| Dimension | Proposed acceptance | Reject / narrow when |
| --- | --- | --- |
| Semantic fidelity | All six task answers and all required note/provenance fields match the fixture key; no false historical DOM or exact-source assertion. | Any conclusion disappears, is attributed to the wrong time/source, or requires a hidden manual repair. |
| Personal task value | No accuracy loss; at least 20% lower median full-task time than the stronger O1/no-build baseline; at least four of six pairs faster. | Benefit is below target, limited to one rehearsed example, or consumed by correction/packaging time. Keep O1/O2. |
| Selected scope | Two selected findings appear with every intended dependent asset; prohibited canaries are absent from the claimed derivative. | Selection silently includes broader transcript/images/pages or a sanitize claim exceeds the tested surfaces. |
| Source preservation | Raw media/context/transcript hashes unchanged; captured-mark fields survive allowed note/review edits; owned/unowned export assets remain distinguishable. | A derivative replaces an original, unknown fields disappear, or re-export overwrites user-owned edits. |
| Processing state | Each fixture outcome is correctly labeled; one retry completes a recoverable derived step without duplicate marks. | Failure looks silent/complete, raw capture becomes inaccessible, or retries require recapture. |
| Portability | Moved-directory read/copy resolves intended video/image/page references without the original absolute path or local server. | Only the original machine/path can open the supposedly portable evidence. |
| Interaction budget | On a documented test Mac, proposed in-session filtering completes within 200 ms for a 5,000-sentence/500-mark synthetic metadata fixture; no playback interruption. | The modest lexical path blocks review; fix one measured bottleneck or reduce scope before adding indexing. |


The 5,000-sentence/500-mark metadata case is a stress fixture, not a claim that typical sessions contain that much data. Measure the app operation directly, not a standalone string-search microbenchmark. Record hardware, OS/app/CLI versions and whether the run is cold or warm. Do not infer responsiveness from source-level caches.

A minimal rejection is useful: current native marks plus editor search may already be good enough. Accepting that outcome is not a failed research project. Make one focused revision for an identified cause, then narrow or stop rather than expanding the proof indefinitely.

## 6. Keep five validation questions separate

**Product value:** Does the complete reviewer task improve? Use cached correct transcripts initially so recognition quality does not conceal UI value.

**Provider accuracy:** Later, on explicitly authorized synthetic speech, compare the existing local recognizer with one chosen alternative only when recognition errors are the bottleneck. Measure code-identifier preservation, correction effort and wrong-meaning substitutions. Do not convert a vendor claim or one successful transcript into an accuracy ranking. Keep raw recognition and corrected interpretation separate. [S059](https://docs.macwhisper.com/article/57-macwhisper-command-line-tool) [S053](https://superwhisper.com/docs/common-issues/troubleshooting) [S046](https://docs.wisprflow.ai/articles/4048537120-what-to-expect-from-flow-accuracy-and-known-limitations)

**Permissions and focus:** On the intended Mac, record existing Screen Recording/Microphone/Automation grants and actual capture results separately. Dictation insertion may need Accessibility. A preflight result is not a successful recording, and a successful recognizer is not proof of correct insertion focus. Stop rather than silently requesting broader permissions. [R022](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L65-L74) [R020](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/check-transcript.py#L1-L16) [S051](https://superwhisper.com/docs/get-started/quickstart)

**Performance and recovery:** Measure capture, processing, indexing and review independently. A saved audio file with a stale transcript is a different failure from missing microphone input; a durable container is not a completed index. The cited user reports motivate failure classes, not a reliability score. [S018](https://github.com/CapSoftware/Cap/issues/1696) [S089](https://github.com/screenpipe/screenpipe/issues/3498) [S021](https://obsproject.com/kb/audio-video-formats-guide)

**Feasibility and provenance:** Validate actual decoded presentation time only when a clip/canvas requires exact media mapping. A requested seek value, mark time or late event receipt is not a substitute. Source attributes qualify a location; they do not prove the bug’s cause. [R009](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168) [R013](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L23-L31) [R014](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L366-L420)

## 7. Existing seams and bounded dependencies

| Existing seam | Proposed role | Boundary |
| --- | --- | --- |
| SessionData / SessionModel / SidePanel | Small query result projection, existing seek/select and visible stage outcomes. | Keep one AVPlayer; do not add a parallel session store. |
| MarkText / processor.mark_markdown / viewer.markdownFor | Agree on a few semantic fields and sentence-boundary behavior. | A golden contract is sufficient; no general cross-language rendering framework. |
| Review / MarksFile | Preserve note/review edits and unmodeled captured fields. | Retain atomic rewrite; do not rerun unrelated expensive analysis on each note. |
| process_session.py | Expose stage outcome and use cached transcript; write derivative output. | No new provider abstraction until one replacement is actually required. |
| ExportSheet / PgmExporter / Pgm | Explicit selection scope and payload preview; preserve local update behavior. | Keep --local and mapping checkpoints; no automatic remote issue writes. |
| BrowserBridge / extension | Truthful connection/recording/freshness indicators; bounded identity metadata when needed. | Do not add accounts or a hosted message service. |
| Transcript script / UI-test hooks | Reuse useful exact-start and isolated-library checks with synthetic fixtures. | Do not invoke personal-fixture prepare or infer runtime results from syntax checks. |


Dependency risks are concrete: command-line discovery in a GUI login-shell environment, missing ffmpeg/parakeet/pgm, macOS capture/Automation grants, Chrome restricted pages or multiple profiles, model download/offline choice, and source-attribute availability in the target development build. The first proof should make these states visible rather than introducing compatibility layers for every hypothetical setup. [R007](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L56-L96) [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) [R022](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L65-L74) [R009](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168)

## 8. Three valuable checks, not a testing platform

1. **Semantic golden check:** one synthetic session covers note/provenance output, short-sentence selection, source fallback and selected payload inventory across Swift/Python/HTML.
2. **Failure/no-loss check:** one parameterized set covers unavailable processing, malformed derived output, stale browser trace, canary boundaries and preservation of captured/unknown fields.
3. **Observed end-to-end check:** the matched reviewer tasks confirm actual reopen/copy/source access and user value; one later authorized capture fixture confirms the capture leg when necessary.

These can reuse existing scripts/harness seams. They are not three mandates to create new frameworks or three separate CI services. Parser/syntax checks from this research do not satisfy them.

## 9. Valid intermediate states and ordered outcomes

**Outcome 0 — Evidence collected.** This package is complete as research; product proof is unrun. Codex may reconcile sources and reject recommendations without implementing anything.

**Outcome 1 — Contract made truthful.** Existing capture/review still works. Privacy wording reflects actual scope, notes survive handoff, and processing failure is explicit. No new search UI is necessary to reach this useful state.

**Outcome 2 — One-session retrieval tested.** A small optional query/view can fail or be absent without preventing chronological review. Keep it only when the full-task gate passes.

**Outcome 3 — Selected local handoff validated.** The chosen derivative has an inventory and relative references. Full-session export remains deliberate and separate. PGM update semantics stay intact.

**Outcome 4 — Goal-specific branch considered.** O2/O5 specialist reuse can be the final answer. O6 spatial geometry or RT-09 capture breadth gets a separate task-level proof only after the reason is explicit.

No outcome authorizes a merge, deploy, remote upload, repository-wide refactor or automatic issue creation. A documentation review PR is Codex’s later work, not a claim made by these artifacts.

## 10. Optional proofs below the initial cut line

### PF-06 — temporal/context qualification

Use a counter that visibly changes between mark keypress and region completion, plus a two-tab reconnect trace. Require distinct or qualified times, correct tab labeling and exact/transformed/missing source fallbacks. Add the smallest metadata that resolves an observed ambiguity. Reject a generalized clock synchronization system if explicit labels suffice. [R012](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/BrowserBridge.swift#L26-L50) [R013](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L23-L31) [R014](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L366-L420) [R009](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168)

### PF-07 — specialist reuse

Compare dictating into NoteEditor, annotating a copied crop, or editing a polished demonstration using one specialist suited to H1/H2. Count correction, focus errors and returning the derivative to the finding. Reject a native integration when the task is infrequent or manual reuse succeeds. [S061](https://support.apple.com/guide/mac-help/use-dictation-mh40584/mac) [S049](https://superwhisper.com/) [S062](https://shottr.cc/) [S009](https://screen.studio/)

### PF-08 — preserve the canvas vision without forcing it

The earlier intent remains a source-linked spatial exploration of observed content across time, including changed states, motion, revisits, narration and larger-than-frame capture. Do not reduce it to a contact sheet and claim the original vision was proved. The contact sheet/board is a **comparison**. [R019](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/docs/research/video-to-canvas/design.md#L3-L10)

Only if spatial reading matters, use the prior 60–90-second one-viewport proof: scroll across three viewport heights, change visible content, then jump without overlap. Require a tall observed view, a separate changed state, a refused-join card and source playback. Every visible patch maps to an actual frame/time/crop; unknown regions stay unknown. No harmful accepted join or missed required visible change is acceptable in the scored set. Compare the whole task against the stronger simple board, including setup/correction time. Proposed prior geometric/resource thresholds remain unapproved calibration targets, not results. Do not add mandatory DOM replay, cloud analysis or another frontend stack. [R019](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/docs/research/video-to-canvas/design.md#L3-L10) [R014](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L366-L420)

### PF-09 / PF-10 — blocked capture and broader product boundaries

A new display/audio mode needs one recurring task that current capture demonstrably cannot complete, with a specialist counterfactual and a mark-alignment check. A hosted/always-on/editor/replay expansion needs a different, explicit intent decision; a competitor checkbox is insufficient. Keep the smaller app when external reuse is enough. [R002](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Recorder.swift#L21-L80) [R025](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L134-L137) [S020](https://obsproject.com/kb/macos-desktop-audio-capture-guide) [S013](https://cleanshot.com/screen-recording) [S088](https://screenpipe.com/privacy) [S090](https://docs.replay.io/reference/replay-cli/commands)

## 11. Cut line

Below the first cut: cross-session semantic/vector search; live captions; a global dictation engine; transcript-to-video cutting; a mature image editor; default high-resolution/high-frame-rate capture; webcam effects; continuous desktop memory; mandatory DOM/execution replay; hosted collaboration; billing/enterprise permissions; autonomous bug/issue creation; spatial reconstruction before source/value proof. A future proof can reopen one boundary, not all of them together.

## 12. Unresolved human choices — exactly three

### H1

**Which primary outcome should govern the next proof: personal bug/product review, polished communication, or general dictation?**

Default proposal: Personal local review is provisional, not a discovered preference.

Effect: Review selects O3/RT-05; communication selects O5 specialist reuse; dictation selects O2/RT-07. Do not approve a broad implementation before this choice.

### H2

**What data may leave the private session folder, and who must consume it?**

Default proposal: Local private originals; explicit selected, previewed derivatives; no automatic upload.

Effect: Determines export scope and whether a hosted specialist is acceptable. A raw full-session handoff requires a deliberate broader choice.

### H3

**How much measured benefit must a new local-review surface deliver to justify its maintenance cost?**

Default proposal: Keep the simpler workflow unless it clears a predeclared provisional 20% full-task time gain with no accuracy loss.

Effect: Set the acceptance budget before evaluation, for lexical retrieval or a separately justified spatial-reading alternative. Do not move the threshold afterward or expand scope merely because a prototype exists.

## 13. Codex collection and Sleuth handoff

The seven companions and ZIP are research inputs. Stable source/recommendation IDs let Codex recover intent, compare alternatives, shape a narrower proposal, develop a proof-first plan and validate initiative state. The recommended direction is not approved, and the current branch/dirty state remains to be inspected by Codex.

Preserve the originals before reconciliation. The expected repository destinations in the brief are future Codex actions; no files were saved there by this research. Use the manifest to verify archive/standalone identity and the immutable baseline. Do not reinterpret an artifact-integrity pass as a product-test pass.

## 14. Executed versus proposed

Executed in this research: 48-section packet integrity check, three Python AST parses, processor help, six JavaScript syntax checks including the embedded viewer, six scoped static searches, and final research-package parsing/ID/reference/count/hash/ZIP checks. All fixture, capture, provider, UI, recovery, source-map and task-value proofs above are **unrun**. No repository files, commits or PRs were created.
