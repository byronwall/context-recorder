# Comparison plan: narrated review through accepted changes

**Proposal only. No trial, installation, account connection, purchase, recording upload, code change, commit, or deployment is authorized by this document.** The research establishes useful comparison targets, not measured product outcomes. Start with a short public-evidence check of Jam, Clipy, and Vidmatic; select two challengers; then compare Context Recorder, those two, and screenshots plus written instructions. Decide on total human effort through five accepted changes. Permit one additional batch only if the first result is tied or materially confounded.

## 1. Freeze one application and one experiment

Use **Context Recorder's portable/cloud browser viewer**, starting from repository commit **`1d9f29d4b38c8c964b948b9ba244289947476b9e`**. The mutable research branch is not the starting point. Keep the same synthetic session fixtures, browser version, operating system, viewport, local server behavior, and starting app state in all arms. The viewer is a suitable real target: the inspected source exposes specific discrepancies between native review, processing, portable Markdown, and cloud MCP. All five tasks address this viewer; several share rendering/Markdown code and R3 depends on R2. They are five accepted requests, not five independent experiments. This personal workflow comparison cannot rank rich telemetry, production replay or cross-framework debugging; those strengths are outside this task set. [S1], [S2], [S3], [S4], [S5], [S6]

Before a later authorized trial, prepare a fixture bundle containing six marks (two screenshots), typed notes including one multiline note and harmless HTML-like text, one `source: "review"` mark, narration, page events, and both ordinary and flattened cloud representations. Include an audio-containing recording with no available transcript, and a separately verified no-audio example. Use only synthetic/public content. Freeze the fixture files and hashes. Fixture creation and acceptance preparation are shared costs; record them once, separately from each arm. Do not patch product behavior during preparation.

Complete this registration sheet **before the first arm**. A model family such as “best Claude” or “latest GPT” is insufficient; retain the literal model identifier, client version, and exported configuration. No model identifier is fabricated here because the later authorized environment has not been inspected.

| Frozen setting | Registration value required before execution |
|---|---|
| Repository base | `1d9f29d4b38c8c964b948b9ba244289947476b9e` |
| Fixture bundle | Exact file list and SHA-256 manifest |
| Coding client | One installed client and exact version; prefer a client documented for both selected challengers |
| Coding model | One exact model/snapshot ID, provider, reasoning setting, and context limit |
| Sampling and budget | Literal settings; record “not exposed” where appropriate; same limits and compaction policy |
| Agent instructions | Hash of common prompt and repository instructions; fresh conversation and memory for every arm |
| Tool access | Same shell, repository, current-app browser driver, and acceptance tools; only evidence connector differs |
| Execution | One implementing agent; same optional review role/model in every arm; vendor-generated summaries remain allowed |
| App environment | OS/browser/runtime versions, viewport, port mapping, dependency lockfile hash, feature flags |
| Run isolation | Four separate clean worktrees at the base; separate artifact folders, browser profiles and agent histories |
| Order | Draw and record the four-arm order before recording; no answer transfer between arms |

Inspect repository rules and installed prerequisites when execution is later authorized. Do not silently install missing dependencies. Record a blocked condition rather than changing environments halfway through. Cloud checks use the repository's TypeScript/pnpm setup; its existing scripts expose `test` and `typecheck`. This document does not assert that either ran. [S7]

## 2. Stage 1: select two challengers without accounts

Time-box this stage to **45 active minutes**. Recheck public documentation, pricing/limits, current compatibility, public samples, and source where already accessible. Do not create accounts or upload a test just to resolve a documentation gap. Choose the two candidates with the strongest documented fit and achievable prerequisites; preserve the rejected candidate and reason.

| Candidate | Decisive public-evidence check |
|---|---|
| Jam | Narrated video and timed transcript/frame retrieval, diagnostic scope, exact plan duration, and supported coding client. Use ordinary narrated video, not Instant Replay: current MCP documents different media-tool availability. [V1] |
| Clipy | Agent context/AREC, timed transcript and visual moments, real-screen versus headless capture, transcript revision behavior, privacy defaults, and exact connected-client scope. Check AREC 1.3 stable and current MCP docs rather than older “read-only” descriptions; distinguish driver-attested proof from independent acceptance. [V2], [V8], [V9], [V10] |
| Vidmatic | Timed speech/mark images, one-recording/many-ask-row skill, supported client, queue/demo prerequisites, sharing defaults, and access readiness. Confirm that it fits the chosen client without promising untested interoperability. [V3], [V4], [V5], [V6] |

For each, mark **eligible**, **conditional**, or **blocked**, with a URL and unresolved condition. Prefer a complete twelve-minute capture, but allow a documented limit to require multiple clips; count the interruptions and handoff cost. Never credit a paid feature as available merely because its marketing page exists. Jam, Clipy and Vidmatic each have a credible adoption case. Default to Jam and Clipy. Substitute Vidmatic for either when the frozen coding client, access prerequisites or chosen issue/workstream preference makes it a better fit. Select the two that best combine complete evidence, compatibility, control and setup burden; record that decision before implementation rather than treating any as a token reserve. If two candidates cannot be responsibly qualified, stop before execution and report the missing prerequisites; do not manufacture a four-arm result.

## 3. The five real requested changes

The reviewer holds the following acceptance sheet. The agent receives the walkthrough or baseline handoff, not this polished answer key. These are proposed changes to the pinned app; nothing in this research implements them.

### R1 — Preserve typed notes across web review and handoff

Show a nonempty note on the web mark, use its first nonblank line as the title consistently, and retain the note in per-mark/all-mark copy and cloud MCP `get_mark`/`get_session` output. Preserve useful narration and evidence links. Test multiline text, whitespace-only notes and harmless `<tag>` content without interpreting it as markup. This closes a concrete gap: native `MarkText.title/markdown` and Python `note_title/mark_markdown` account for notes, while inspected web/cloud formatters do not. **Accepted when the same fixture conveys the same note and intended title through all four handoff surfaces**, with appropriate local/cloud URLs; compare semantic content rather than byte-identical links or whitespace. [S1], [S2], [S3], [S4]

### R2 — Add Find to the web viewer

Provide case-insensitive text Find across marks, transcript and page events, with match counts, useful highlighting, an empty state, and Escape-to-clear behavior. Include note text, narration and visible context in mark search; preserve screenshot/mark type filtering. Keyboard focus and narrow layouts must remain usable. The native app already documents Find; do not propose rebuilding native search. The inspected web `renderList` filters mark kind and otherwise lists transcript/events without a query. **Accepted when known terms find the expected items in each tab and clearing restores the original lists.** [S1], [S5]

### R3 — Add “Copy visible marks,” preserving “Copy all”

Add a separate, clearly named control that copies exactly the marks matching the current mark-kind filter and Find query, in visible order. Keep “Copy all as Markdown” meaning every mark regardless of filters. Handle zero results without accidentally copying the full session, state the exported count, and disable or hide the new control outside the Marks tab. Preserve each mark's identity and links. Current `copyAll` explicitly maps the entire marks array; changing that behavior would implement the canceled instruction below. **Accepted when a two-mark result copies two, Copy all still copies six, and an empty result cannot silently expand scope.** [S1]

### R4 — Show review-mark provenance

Give marks with `source: "review"` a visible “Added during review” badge and concise explanation that no live page snapshot was captured for that mark. Carry that distinction into web copy and cloud MCP. Do not imply that all historical context is absent: review marks can inherit app/URL/narration and prior recorded page events. Native review creates this flag, and native/Python Markdown already explains it. **Accepted when the flag survives ordinary/cloud fixtures and agent handoff, while live marks and historical events remain accurately described.** [S2], [S3], [S4], [S6]

### R5 — Stop labeling an unavailable transcript “Silent”

Replace empty-transcript “Silent” assertions with the neutral **“No transcript available”** in the header, transcript tab and current-narration panel. The processing path can return no transcript because audio is absent **or** because Parakeet is unavailable; the viewer currently maps both to silence. Keep the existing data model: no new processing-state schema, audio detector or transcription service is requested. **Accepted when empty-transcript fixtures consistently use the neutral label and transcript-present rendering still works.** [S1], [S3]

## 4. Record one deliberate twelve-minute batch per arm

Use the same outline, fixture tour and final intent for each recording, allowing normal product-specific marking. Allocate roughly two minutes to each change and two minutes to navigation/review. Include these realistic intent events, rather than five independent tickets:

- **Correction:** initially ask Find to search marks, then explicitly broaden the final request to marks, transcript and page events.
- **Cancellation:** initially suggest changing Copy all to follow filters, then withdraw that and request a separate Copy visible control. The final result still contains five requests.
- **Ambiguity:** refer once to “this Copy control” while both the toolbar and a per-mark control are visible. The reviewer keeps a fixed clarification: the new filtered action belongs in the toolbar. Record whether the agent asks, declares an interpretation for review, or silently guesses.
- **Rerender:** switch filters/tabs so `renderList` rebuilds the mark DOM, then return to the target. Current-app verification must identify it again using current content/state, not assume an earlier element handle is valid.

Do not repeat until a product gets a cleaner take. Retakes, mark repair, transcript corrections, chunking and navigation errors are measured human work. For the baseline, produce the screenshots and written instructions a competent developer would actually send, conveying the same final five asks and canceled behavior. The writer may resolve ambiguity in prose; count that thinking, selection, annotation and writing time. Do not deliberately degrade the baseline or gift it an uncharged prepared specification.

## 5. Four arms and common execution

Use **A: Context Recorder; B/C: the selected challengers; D: screenshots plus writing**. For Context Recorder, preselect one supported handoff route—portable artifacts or cloud MCP—and retain it for the run. Do not quietly switch to a handwritten perfect request list when extraction is difficult. Record any rescue or manual transfer as part of that arm.

Every arm gets the same common instruction: identify the final requests; cite the evidence for each; reconcile corrections/cancellations; ask about material ambiguity; inspect the current code/app; propose a short plan; implement the approved scope; and return changes with verification evidence. The reviewer checks the extracted plan once, records any omissions/wrong targets, and supplies only necessary clarification. Changes remain local/reviewable during the comparison; no merge, deployment, public issue, vendor notification or purchase is needed.

Allow each product's documented strengths: Jam's diagnostic/frame reads and supported proof workflow; Clipy's native context/capture/proof facilities if selected; Vidmatic's ask rows and workstream/demo skills. Do not deny competitors native features while allowing custom Context Recorder prompts. Conversely, an external browser driver and ordinary test runner are available to all arms. Count extra setup and transfers. Vidmatic's single issue with many rows is an acceptable decomposition; separate ticket or PR counts are not the objective. Treat dashboards and agent reports as claims until acceptance checks establish behavior. [V1], [V2], [V3], [V4], [V5], [V6]

After implementation, use the same fixed checks for all arms: fixture behavior in portable and cloud modes; copied Markdown contents; MCP note/provenance parity; keyboard/narrow-layout review; the existing relevant cloud tests and type check; and a diff review for unintended changes. Add only targeted checks that resolve the five concrete risks. Native Swift tests are appropriate only if the agent changes native code. Record command, exit status, tested head commit and observed result; a screenshot alone cannot establish every functional condition. [S7], [S8]

## 6. Empty scoring sheets

Record active minutes contemporaneously. Waiting is elapsed time unless the person is actively monitoring or troubleshooting. Report cold-start cost and repeat-use cost separately; do not make adoption win by hiding setup, or make it lose by charging reusable preparation repeatedly.

| Measure | CR | Challenger 1 | Challenger 2 | Written baseline |
|---|---|---|---|---|
| Exact versions/plan/model/config hash | — | — | — | — |
| Setup and learning minutes | — | — | — | — |
| Capture, screenshot selection or writing | — | — | — | — |
| Retakes, edits and transcript correction | — | — | — | — |
| Handoff/connector/manual-transfer work | — | — | — | — |
| Request reconciliation and clarification | — | — | — | — |
| Code review and wrong-target repair | — | — | — | — |
| Verification, failed checks and rechecks | — | — | — | — |
| Cleanup and integration into working branch | — | — | — | — |
| **Total active human minutes** | — | — | — | — |
| Elapsed minutes / processing wait | — | — | — | — |
| Recurring spend and observed usage cost | — | — | — | — |
| Correct final asks on first plan / 5 | — | — | — | — |
| Missed/duplicate/invented asks | — | — | — | — |
| Canceled behavior implemented? | — | — | — | — |
| Wrong targets / clarification turns | — | — | — | — |
| First-pass acceptance failures | — | — | — | — |
| Requests finally accepted / 5 | — | — | — | — |
| Overall status and blocking reason | — | — | — | — |

Use a second sheet with one row per R1–R5 per arm: original evidence location; agent's final interpretation; clarification; changed files/head commit; acceptance observation/proof link; reviewer decision; repair minutes. Record **accepted, partial, failed, blocked, or not run** explicitly. A blocked connector is not a zero-effort success. Overall acceptance requires all five final requests, preserved cancellation, no unresolved material regression, and reviewer-approved evidence. Keep extraction quality visible even when later human repairs make the final code correct. Classify problems as capture, retrieval, intent, target, implementation or verification; a coding error is not automatically a recorder defect.

`H_total = setup + capture/writing + correction + handoff + reconciliation + clarification + review + repair + verification + cleanup`.

## 7. Decision rules and bounded stop

Precommit these proposed thresholds before execution; they are decision preferences, not statistical claims. Compare only arms that reach acceptance at the common quality bar.

**Adopt:** an existing workflow reaches all five accepted changes and reduces active human effort by at least **25% and ten minutes** versus Context Recorder, without violating the chosen local/privacy/cost constraints. Also require the product to beat the best acceptable written baseline, or record the specific control/privacy benefit that justifies higher effort/cost. If the written baseline wins, use it for this workload; recording need not be justified universally. Pause overlapping capture/editor development for four weeks of ordinary use, then reconsider only observed friction.

**Integrate:** capture and agent retrieval are effective, but a narrow transfer, evidence/provenance or request-reconciliation step dominates cleanup. First try a small prompt/sidecar using existing tools. Continue only if that removes a measured bottleneck; do not start a second tracker or orchestration platform to match a vendor feature list.

**Keep building selectively:** Context Recorder is materially better, or the alternatives are unacceptable on the recorded constraints, and a specific bounded change is likely to reduce the measured failure. Distinguish personal utility from market differentiation. An untested feature wishlist is not enough.

Cap shared setup at **45 active minutes**, each arm at **60 active minutes or three elapsed hours**, and first-round synthesis at **30 active minutes**, in addition to the 45-minute evidence check. A cap reached without acceptance is recorded as partial/failed/blocked; never omit its sunk effort. That bounds the first round at six active hours. Only a difference below the threshold, a material order effect, or a documented infrastructure interruption justifies a second, different three-to-five-change batch between the **two decision-relevant arms**. Cap it at two additional active hours total. Do not add new products or keep rerunning stochastic agents until a preferred tool wins. At eight active hours, decide provisionally from accepted outcomes and open constraints, or retain the current workflow and defer a paid adoption decision.

## 8. Conditional milestones after the decision

These are independent planning bets, not a sequential roadmap or approval to build. Existing paths below were inspected; paths labeled **proposed** do not exist merely because they are named here. Keep new cloud implementation in TypeScript with pnpm, one personal user and one current client/server version.

### M1 — Handoff parity that is useful regardless of adoption

**Condition:** retain or export Context Recorder sessions. Align `scripts/viewer.html` and `cloud/src/markdown.ts` with the useful note/provenance behavior in `Library/MarkText.swift` and `scripts/process_session.py`; protect it in `cloud/test/mcp.test.ts`. Add a small shared fixture, not a renderer framework. **Proof:** one fixture carries notes, review origin and honest transcript availability through native-produced data, portable copy and cloud MCP without inventing context. **Risk:** title/timing and local-versus-cloud URL conventions drift. **Design-mode question:** “What is the smallest mark-text contract that keeps these handoff surfaces equivalent?” [S1], [S2], [S3], [S4], [S8]

### M2 — A plain request register, only if the trial shows need

**Condition:** missed, superseded or ambiguous asks cause repeated reconciliation work. Start with a session-side `requests.json` plus readable Markdown maintained by the agent: ID, final wording, original quotes/times/mark references, active/canceled/superseded state, clarification, source target, change link and separately reported/verified outcome. Integrate with existing `cloud/src/markdown.ts`/`mcp/server.ts` only if useful; **proposed** `cloud/src/request-register.ts` would validate the small record, not implement a task engine. **Proof:** the correction/cancellation fixture produces five final asks, preserves withdrawn intent without executing it, and links every accepted ask to evidence. **Risk:** the register becomes extra manual work or falsely authoritative. **Design-mode question:** “Can a sidecar and one review step solve the observed loss before product UI is needed?” Vidmatic supplies ask rows/workstreams and Clipy supplies structured AREC requests/plans; reuse those where they suffice. [V2], [V3], [V4], [V5]

### M3 — Explicit source and runtime provenance

**Condition:** target mapping or stale code materially causes failure. First record repository URL/local identity, commit, dirty state, app URL, deployment/build identity, runtime/dependency versions and capture time in a small sidecar. Optional integration touches `cloud/src/manifest.ts` and `Cloud/CloudBundle.swift`; **proposed** `cloud/src/provenance.ts` would validate/display fields. Existing `inputHash` detects changed bundle inputs; it is not proof of the app's Git revision. **Proof:** a deliberate checkout mismatch is surfaced before editing, and unknown build-to-commit relations remain unknown. **Risk:** a supplied commit incorrectly appears to authenticate the running app. **Design-mode question:** “Which few provenance fields prevent our observed wrong-base work, and which can remain explicit user declarations?” [S9], [S11]

### M4 — Selective export and concrete sanitization

**Condition:** useful sessions cannot be safely shared through the selected workflow. Start with an export inclusion manifest and preview for video/audio, images, transcript, notes, browser events, MHTML and component props. Existing seams are `Cloud/CloudBundle.swift`, `Export/PgmExport.swift` and cloud manifest/file delivery; **proposed** `cloud/src/export-policy.ts` can validate declared included artifacts. Apply exclusions before publishing artifacts and preserve original ownership separately. **Proof:** synthetic canaries are absent from every selected exported channel and its derived text, while allowed evidence still resolves. **Risk:** blurred pixels coexist with raw frames, audio, page values or metadata. `extension/page.js:describe` reads `innerText || value`, so input values cannot be categorically excluded. **Design-mode question:** “Which channels should this export omit, and what exact canary audit can establish that omission?” This is not a promise of universal secret detection. [S9], [S10], [S13]

### M5 — Reuse live inspection and verification integrations

**Condition:** correct intent still yields stale targets or weak completion proof. Reuse the chosen browser driver/test tools and existing MCP `get_mark/get_frame/get_frames`; attach current base/head commit, request IDs, checked actions, test exit status and before/after evidence. A **proposed** `cloud/src/verification.ts` could validate references if a plain artifact is insufficient. Do not build another browser automation stack. **Proof:** a rerendered target is reacquired and a deliberately failing acceptance check remains failed despite a persuasive video or agent report. **Risk:** proof is produced against the wrong browser/build, or a reported success is treated as independent verification. **Design-mode question:** “What small receipt connects a final request to the exact app/build that passed its check?” Jam, Vidmatic and Clipy already document proof-oriented workflows. [S8], [S12], [V4], [V6], [V7], [V9]

### M6 — Optional Solid source instrumentation

**Condition:** an actual Solid application repeatedly lacks useful source anchors and that gap costs time. First try development-only source attributes in that application's existing build tooling. `extension/page.js:sourceFor` already reads locator/code-inspector-style attributes; the pinned README explicitly identifies this route for Solid. No new framework adapter is justified until that seam fails. A **proposed** `cloud/src/source-hints.ts` would only normalize labeled hints if cloud presentation needs it. **Proof:** a nested/rerendered control maps to the correct source file/line in the actual dev app; production without attributes stays honest about missing hints. **Risk:** transformed line numbers, stale paths or dev metadata exposure. **Design-mode question:** “Can existing dev-only attributes remove the observed source-search cost without changing capture?” [S5], [S10]

## Sources and access limits

Code facts are static inspection at the pinned commit, not successful live tests. Native Find is documented in the pinned README; this plan inspected web search behavior, not the missing native Find implementation file. No comparative results exist. External documentation access date: **2026-10-24 America/Indianapolis**. Clipy AREC and MCP HTML documentation was retrieved; the text extractor could not read its separate `text/markdown` agent endpoint, and the proof page relied on the main research's direct primary retrieval. These access differences do not establish product unavailability.

[S1]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/scripts/viewer.html
[S2]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Library/MarkText.swift
[S3]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/scripts/process_session.py
[S4]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/cloud/src/markdown.ts
[S5]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/README.md
[S6]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Library/Review.swift
[S7]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/cloud/package.json
[S8]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/cloud/test/mcp.test.ts
[S9]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Cloud/CloudBundle.swift
[S10]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/extension/page.js
[V1]: https://jam.dev/docs/jam-mcp
[V2]: https://clipy.online/docs/arec
[V3]: https://www.vidmatic.ai/docs/recording-to-issue
[V4]: https://www.vidmatic.ai/docs/agent-workstreams
[V5]: https://www.vidmatic.ai/docs/mcp
[V6]: https://www.vidmatic.ai/docs/demos
[V7]: https://jam.dev/docs/cli-proof-video

[S11]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/cloud/src/manifest.ts
[S12]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/cloud/src/mcp/server.ts
[S13]: https://github.com/byronwall/context-recorder/blob/1d9f29d4b38c8c964b948b9ba244289947476b9e/Sources/ContextRecorder/Export/PgmExport.swift
[V8]: https://clipy.online/docs/mcp
[V9]: https://clipy.online/docs/proof
[V10]: https://clipy.online/spec
