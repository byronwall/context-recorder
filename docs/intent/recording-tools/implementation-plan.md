---
title: "Recording tools — proof-first proposal"
slug: recording-tools
phase: plan
status: current
last_updated: "2026-10-14"
---

# Recording tools — proof-first proposal

## Plan at a glance

This is a proposed sequence, not authorization to change the application. All product proofs below remain unrun.
First protect the meaning of an existing reviewed finding. Then separate processing failure from a silent recording.
These repairs produce useful intermediate states without selecting a new product architecture.
The next milestone is a focused decision spike. It compares the current workflow with a bounded retrieval candidate.

Do not proceed to a detailed search/export implementation until Byron selects the primary job and output policy.
If he selects communication or dictation, evaluate the matching specialist workflow instead.
The shape gate remains active: a current document describes the current proposal, not an approved application plan.

Keep the test corpus synthetic and small. Do not use the existing harness's personal-session preparation unchanged.
One fixture can expose the note, timing, output-scope, and source-preservation risks.
A few controlled failures can expose processing-state errors. A later real Mac check confirms integration that fixtures cannot establish.

The main implementation challenge is consistent meaning across Swift, Python, and browser output.
Use a small shared answer key, not a cross-language rendering framework.
Search value and export policy are separate questions. Neither follows automatically from repairing the current viewer.

## Implementation strategy

- **First proof:** A note and its source meaning survive reopen and copy across current output paths.
- **Primary seam:** Existing mark serialization and output functions; then the existing processor subprocess result.
- **Fast local loop:** Proposed `python3 scripts/check-review-contract.py --case parity`; this script does not exist yet.
- **Local dependencies:** Tiny synthetic JSON/JSONL, placeholder images, and cached transcript. No network or personal recording.
- **Provider/live confirmation:** A later authorized Mac check uses a synthetic session in an isolated library. Test capture separately if needed.
- **Rollout and rollback:** Keep native editing and chronological review. Revert each small repair independently; leave raw session files unchanged.

### Material dependency proof strategy

The first metadata proof substitutes cached speech and fixed context for recognition and capture.
It does not prove microphone permissions, Chrome attachment, frame timing, or recognizer quality.
Processing tests use a temporary executable path with controlled success, missing-tool, and nonzero-exit results.
Use the existing launch path; introduce no provider abstraction solely for the test.

When live behavior matters, use the real local command and explicit synthetic media on the intended Mac.
No emulator, cloud sandbox, or deployment is needed for these repairs.
PGM is absent from the first proof. A later local PGM smoke is needed only if its payload changes.
That smoke must preserve user-owned title, status, and images during re-export.

## Milestone 1: A reviewed finding survives portable handoff

This is the smallest visible repair. It leaves the current capture and review flow in place.

- **Change — Align existing output semantics**
  - Inspect `Sources/ContextRecorder/Library/MarkText.swift`, `scripts/process_session.py`, and `scripts/viewer.html`.
  - Preserve note-first title/body, review origin, source time, and path meaning in visible and copied output.
  - Match the native exact-start rule in `Library/SessionModel.swift`; retain explicit gaps between sentences.
- **Change — Add one meaningful synthetic contract check**
  - Reuse the intent of `scripts/check-transcript.py`. Create a small answer key for a note, crop, review mark, and adjacent short sentences.
  - Check semantics rather than whitespace. Include a benign source clue and an unknown captured field that must survive note edits.
  - Use `Library/Review.swift` and `MarksFile` for the permitted note rewrite. Hash raw media, context, and transcript before and after.

### Desired end state

- The same reviewed conclusion appears in native Markdown, processor Markdown, and portable HTML read/copy.
- Exact sentence starts select the expected sentence. Review marks do not imply live DOM evidence.
- The fixture passes, raw evidence is unchanged, and an isolated browser check confirms visible output.

Rollback: revert the viewer/formatting repair. Continue using native Markdown while the defect remains documented.

## Milestone 2: Processing failure has a useful result

This repair addresses current ambiguity. It does not require search or a job service.

- **Change — Report the actual processing outcome**
  - Connect `main.swift:runPostProcessing` to exit status and derived-output availability.
  - Reuse `Library/Review.swift:reprocess` and `process.log` for one bounded retry.
  - Update `scripts/process_session.py` and `Library/SessionView.swift` to distinguish silent, unavailable, pending, failed, and ready.
- **Change — Prove failure without risking real recordings**
  - Inject no-audio, cached transcript, missing recognizer, nonzero exit, and malformed derived-output cases.
  - Require useful feedback, accessible raw files, and no duplicate marks after retry.
  - Confirm one real local processor run later with synthetic media. Record executable versions and stage times.

### Desired end state

- A missing recognizer does not produce a Silent label.
- A failed processor does not leave an unexplained permanent Processing state.
- One recoverable derived step can be retried without recapture or raw-file mutation.

Rollback: retain the raw session and documented manual processor command. Revert the result presentation independently.

## Milestone 3: Decide whether local retrieval earns expansion

This is a decision spike. It does not prescribe a new export architecture while human choices remain open.

- **Spike — Select the job and output contract**
  - Decision required: primary task, recipient, permitted assets, and acceptable maintenance benefit.
  - Evidence: current task steps and the research's no-build and specialist alternatives.
  - Fallback: retain local private originals and current native/Markdown review. Do not implement selected sharing without a contract.
- **Spike — Compare a narrow candidate after that choice**
  - For personal review, use `Library/SidePanel.swift`, `SessionModel.swift`, and existing note/seek actions as the likely query seam.
  - Compare six paired tasks across three small matched sessions. Allow editor Find in the baseline.
  - Count errors and total time through reopened handoff, including corrections and packaging. Rotate task order.
  - Proposed gate: no accuracy loss, 20% lower median time, and four of six pairs faster. Confirm before measurement.
  - Inspect `Export/ExportSheet.swift` and `PgmExport.swift` for actual outgoing transcript, crop/full-frame, and page scope.
  - Inspect `extension/page.js:describe` for value-derived input text. Use distinct canaries per included surface.
  - Test moved-directory asset resolution only for a proposed portable derivative. A scope label must match all included files.

### Desired end state

- A written decision selects a small next proposal or keeps the current workflow.
- The chosen output contract identifies included content and preserves original evidence.
- A failed value test ends or narrows the candidate. It does not trigger a broader search platform or automatic redaction project.

Rollback: discard the experiment and its disposable files. Keep current review and manual handoff.

## Cross-cutting verification

No personal recordings are needed. The existing `scripts/ui-test/harness.py` references named personal sessions; do not run its preparation unchanged.
Use its isolated-library conventions only with an explicit synthetic source.
Run `python3 scripts/check-transcript.py` when sentence behavior changes, then the focused new contract check.
Inspect native and browser outputs separately. Build Swift only when native code changes.
Do not claim runtime, performance, provider accuracy, or data exclusion from syntax checks or research-package validation.

## Open decisions and spikes

1. Primary job selects local review, specialist communication, or dictation reuse. Keep the current workflow if unresolved.
2. Recipient and data scope determine selected output. Keep private local originals if unresolved.
3. Benefit threshold determines whether retrieval survives. Set it before observing results; do not move it to rescue a prototype.

## Below the cut line

- Cross-session or vector search, continuous capture, cloud teams, and autonomous issue creation.
- A new dictation engine, full image/video editor, and broad capture rewrite.
- Automatic comprehensive redaction, universal source adapters, or a clock synchronization service.
- Spatial reconstruction before comparison with a useful board and proof of real patch-to-frame mapping.

These may return only after a distinct task justifies them. See the [shape](shape-brief.md) and [research dispositions](../../research/recording-tools/research-review.md).
