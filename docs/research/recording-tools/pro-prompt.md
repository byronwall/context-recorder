# Recording, dictation, and annotation product research

https://github.com/byronwall/context-recorder

## Mission

Research the current range of screen recording, dictation, and annotation products. Then assess the meaningful gaps in Context Recorder.

Answer this decision question: which unmet workflows should this personal macOS project address, and which competitor features should it avoid copying?

Use October 13, 2026, America/Indiana/Indianapolis, as the research date. State access dates and product versions when available. Verify current claims through web research. Do not rely on model memory for product status, prices, or capabilities.

Work as a candid product researcher with knowledge of macOS capture, speech workflows, developer tools, and visual review. Seek breadth first, then depth. Do not assume that a larger feature list makes a better product.

## Source and access preflight

- Repository: `byronwall/context-recorder`.
- Immutable source baseline: `6c74158ca96abd36819d2a58f75bacdc44107bb0` on `main` when inspected.
- Codex integration branch: `codex/recording-tools-research`, created from that baseline in the existing checkout.
- Local checkout: `/Users/byronwall/Projects/context-recorder`. This path is context, not remote access.
- Attached fallback: `recording-tools-source-packet.txt`, a selected text source snapshot with a file manifest and SHA-256 hashes.
- The packet contains baseline code, relevant prior research, repository rules, and this new prompt. It contains no recordings or credentials.
- Connected GitHub access to the baseline README was verified by Codex. Your access may differ.

First confirm the repository identity, baseline, and available evidence. Prefer connected GitHub when it exposes this ref. Use the attached packet when indexing, permissions, or local additions prevent access. State the packet's coverage limits. It is not a runnable checkout.

GO when the baseline source and required documents are readable and live web research is available. Read-only analysis and downloadable artifacts are sufficient. You do not need repository write access.

NO-GO for a complete gap analysis if the repository identity differs, required source is absent, or browsing is unavailable. Preserve useful partial research, identify the failed gate, and give the smallest recovery action. Do not infer missing source from the README alone.

If one vendor is inaccessible, record the limit and continue. If a product decision depends on Byron's preference, present alternatives. Do not invent his preference or stop all research for it.

## Verified repository context

These facts come from the baseline README and source. Check them against the packet before using them.

- Swift and SwiftUI app for macOS 26, with a Python processor and a plain JavaScript Chrome extension. `Package.swift` is the manifest. There is no tracked `package.json`.
- `Recorder.start` captures the main display, up to 1920 pixels wide, at 15 fps, with an optional default microphone. System audio is explicitly disabled. The cursor is visible in video.
- Capture uses ScreenCaptureKit and AVAssetWriter. Hotkeys start or stop capture, mark a time, or take a region screenshot.
- Marks have timestamps, context, still images, and narration. Review supports new marks, cropped frame images, and typed notes.
- The native Sessions window has playback, a timeline, transcript navigation, app/page activity, session names, and a session library.
- `process_session.py:transcribe` runs local `parakeet-mlx` after capture. It extracts audio with ffmpeg and caches `transcript.json`. This is post-recording transcription; it is not verified live dictation into arbitrary applications.
- Raw transcription includes token times; the native session model stores sentence times. Do not equate transcript seeking with transcript editing.
- The Chrome extension captures clicks, navigation, errors, and selected failed or slow network events. Marks can include DOM element context, development source locations, and saved MHTML pages.
- Input values are excluded, but page content, selected text, props, URLs, and error bodies can still contain sensitive content. Local storage is not proof of comprehensive redaction.
- Review marks reuse recorded context. They do not obtain a new historical DOM snapshot.
- Output is local: MP4, JSON/JSONL, Markdown, images, saved pages, and a portable HTML viewer. Product Grid export uses `pgm --local`.
- The earlier spatial video canvas research is a proposal. No canvas implementation or measured proof exists in this baseline.
- There is a transcript regression script and a native UI test harness. Do not repeat the earlier research's stale statement that no checks exist.

The desired audience is provisionally Byron, a personal developer reviewing narrated product walkthroughs. Code describes current capability, not a decision to exclude other useful workflows. Do not assume a commercial team product, multi-tenant service, or enterprise buyer.

## Required reading route

Read at minimum these files and relevant connected code. Cite file paths and symbols, preferably line ranges at the immutable baseline.

1. Packet repository rules, `README.md`, and `Package.swift`.
2. `Sources/ContextRecorder/main.swift`, `ControlPanel.swift`, `HotKeys.swift`, `Recorder.swift`, `RegionSelector.swift`, and `Session.swift`.
3. `Sources/ContextRecorder/ContextProbe.swift`, `ActivityLog.swift`, `BrowserBridge.swift`, and `extension/{manifest.json,background.js,page.js,relay.js,popup.js}`.
4. `Sources/ContextRecorder/Library/{SessionData.swift,SessionModel.swift,Review.swift,SessionTimeline.swift,SessionView.swift,SidePanel.swift,MarkDetail.swift,MarkText.swift,SessionLibrary.swift,LibraryView.swift}`.
5. `Sources/ContextRecorder/Export/{PgmExport.swift,Pgm.swift,ExportSheet.swift}`.
6. `scripts/process_session.py`, `scripts/viewer.html`, `scripts/check-transcript.py`, `scripts/ui-test/README.md`, and `scripts/ui-test/harness.py`.
7. `docs/research/video-to-canvas/{intent-brief.md,design.md,proof-plan.md,research-review.md}`. Treat this prior direction as context, not proof or a required winner.

Useful local commands, when an appropriate checkout exists:

```sh
git status --short
git show 6c74158ca96abd36819d2a58f75bacdc44107bb0:Package.swift
rg -n 'captureMicrophone|capturesAudio|maxWidth|fps' Sources/ContextRecorder/Recorder.swift
rg -n 'transcribe|parakeet|transcript|tokens' scripts/process_session.py
rg -n 'search|note|addReview|deleteReview|export' Sources/ContextRecorder/Library Sources/ContextRecorder/Export
python3 scripts/process_session.py --help
swift build
python3 scripts/check-transcript.py
```

Do not run `scripts/build-app.sh` by default; it installs the app. Do not open personal recordings, request capture permissions, or claim runtime tests from static inspection. Report checks as executed, proposed, unavailable, or not run.

## Ranked research questions

### 1. What does the product landscape look like, and where is real workflow overlap?

Map at least 25 distinct, currently verified products across six groups. Explain why each belongs. Separate direct competitors from adjacent tools and possible complements.

Cover these groups:

1. Screen recorders and narrated async video: for example Loom, Screen Studio, CleanShot X, Cap, OBS, ScreenFlow, Camtasia, and native macOS capture.
2. Developer bug capture and contextual feedback: for example Jam, Bird Eats Bug, Marker.io, and other strong current options.
3. Speech input and local transcription: for example Wispr Flow, Superwhisper, FluidVoice, VoiceInk, MacWhisper, and Apple Dictation.
4. Screenshot and on-screen annotation: for example Shottr, CleanShot X, Snagit, and drawing/presentation tools.
5. Step capture, tutorials, and interactive demos: for example Scribe, Tango, Guidde, and current alternatives.
6. Transcript-led video editing, review, or screen memory: select relevant current products, such as Descript, Screenpipe, or replay/review tools.

These are discovery seeds, not verified claims or a required vendor list. Check renames, acquisitions, shutdowns, feature removals, and platform changes. Replace weak matches. Count each product once even when it spans categories. Include open-source and local-first choices. Avoid turning the survey into a general meeting-bot catalog.

Select at least 12 products for deeper analysis. Cover all six groups and prioritize workflow overlap. Explain the selection. Compare complete tasks, not just landing-page lists: capture → speak → mark/annotate → review → extract → hand off.

### 2. Which capabilities are common, and how well do products actually serve these tasks?

Define a feature taxonomy before counting prevalence. Distinguish:

- microphone narration, system audio, webcam, display/window/region selection, recording pause, quality and frame rate;
- speech-to-text after capture, live captions, live dictation into another app, transcript correction, language/model choices, vocabulary, and cleanup;
- live drawing, post-capture arrows/text, screenshots/crops, timed notes, blur/redaction, cursor emphasis, zoom, and comments;
- transcript search, transcript seeking, text-based editing, clip extraction, chapters, summaries, and action items;
- DOM/source context, browser errors, network evidence, replay, and links from evidence to code;
- local files, offline use, cloud processing, portable export, share links, collaboration, integrations, and data ownership;
- onboarding, permission friction, keyboard access, discoverability, reliability, performance, and recovery where evidence exists.

Use explicit values: native, partial, integration-only, absent with evidence, or unknown. Do not equate a crop with a redaction, a timestamp with semantic grounding, a share link with portable export, or narration with dictation.

Report what is common within each category. Give denominators and disclose unknowns; a convenience sample is not market share. Identify table stakes, category-specific strengths, distinctive combinations, and low-value parity features.

For each deep profile, explain what it does well, what it does poorly, who benefits, and the tradeoff. Ground strengths and limitations in evidence. Separate documented limits, independent observations, user reports, vendor claims, and your inference. Never invent hands-on use, benchmarks, transcription accuracy, or reliability results.

Use current official docs, pricing, release notes, and public source code first. Use independent reviews and dated user reports to assess lived friction. Do not turn a single complaint or competitor-authored comparison into a product-wide verdict. State when a negative claim cannot be substantiated.

### 3. Which gaps exist in this repository, and which ones matter?

Produce a gap matrix mapped to actual repository files and symbols. Classify each capability as implemented, partial, absent within inspected scope, proposed only, or unknown. Record search scope for absence claims.

For each meaningful gap, include the affected task, competitor evidence, repository evidence, practical impact, cost/risk, simplest improvement, and a proof that could reject it. Separate a missing feature from a discoverability problem or an untested implementation.

Give explicit credit to the repo's existing context capture, time links, local artifacts, and review marks. Check whether those combinations are still distinctive; do not claim uniqueness without evidence.

Separate parity gaps from desirable omissions. Rank gaps for a single personal developer. Account for maintenance cost, macOS permissions, local processing, and the risk of losing useful source evidence. Avoid security or collaboration infrastructure without a concrete need.

### 4. What should Byron keep, improve, explore, reuse, or decline?

Present 6–7 meaningfully different product directions. Include a minimal/no-build path, reuse of existing tools, a focused local review path, and a broader end state. Distinguish them by user task and product boundary, not cosmetic variants.

Recommend a narrow first direction with reasons, plus a stronger alternative where it could win. Show what changes if the primary goal is personal bug review, polished communication, or general dictation. Keep uncertain goals as proposals.

Produce a short ordered set of recommendations with stable IDs. For each, record: problem, user/task, evidence, proposed change, benefit, cost, simpler alternative, confidence, dependencies, proof, failure rule, and suggested priority. Include keep and avoid decisions, not only additions.

### 5. What is the smallest useful proof and path forward?

Propose observable end-to-end proofs, realistic fixtures, measurable acceptance/rejection rules, and valid intermediate states. Distinguish product value from provider accuracy, permissions, performance, and implementation feasibility.

Use existing Swift/Python/browser seams where practical. Do not replace the app stack. Prefer a fast local loop and few tests that protect likely failures. Use at most three unresolved human choices or research spikes. State what remains below the cut line.

Codex will apply the full software-design-sleuth process after collection: recover intent, compare alternatives, shape the proposal, build a proof-first plan, and validate initiative state. Supply evidence and useful proposals for those phases. Do not claim that your proposed plan is approved or implemented.

## Evidence and stopping rules

- Every decisive external claim needs a direct URL and access date. Every gap needs repository evidence.
- Use stable source IDs and recommendation IDs. Make all references resolvable in the output package.
- Label fact, inference, proposal, uncertainty, and unrun checks clearly.
- Distinguish vendor documentation from measured experience. Record plan/platform restrictions and billing cadence when prices matter.
- Verify decisive claims against current primary sources. Preserve conflicting reports rather than hiding them.
- Stop expanding the vendor set after category coverage and deeper workflow comparisons cease to change the recommendation.
- Do not declare success if the 25-product breadth, 12-profile depth, category coverage, citation rules, or repository gap evidence is missing. Explain any justified shortfall as partial completion.
- Stop short of an implementation commitment when an essential human judgment remains. Still deliver the research, alternatives, and conditional plan.

## Scope and repository rules

Research, analysis, and proposed planning only. Do not edit this repository, commit, push, open issues, make purchases, sign up for products, contact vendors, merge, deploy, or run capture tests. Codex owns local integration and the review PR.

Do not overwrite prior research. Do not treat an uncommitted checkout as disposable. Preserve personal project scale: simple control flow, small scope, no default enterprise patterns, no speculative compatibility layers, and few valuable tests. Use pnpm for any JavaScript package work if later authorized; no package installation is needed here.

Write clear technical prose with short active sentences. A documented feature gap is not authorization to implement it.

## Deliverables

Return these downloadable files, plus one ZIP containing identical copies and a manifest:

1. `recording-tools-report.md`: standalone research report; landscape, taxonomy, common features, at least 12 deep profiles, strengths/weaknesses, workflow comparisons, ranked gaps, options, and recommendation.
2. `recording-tools-matrix.csv`: one row per product; stable product ID, category, URL, platform, feature cells, restrictions, source IDs, and date. Include a data dictionary in the report. Count unique products consistently.
3. `recording-tools-gap-analysis.md`: detailed repository matrix, evidence, scope of absence checks, ranked gaps, desirable omissions, and uncertainties.
4. `recording-tools-sources.md`: stable IDs, title, publisher, direct URL, publication/update date when known, access date, evidence type, and supported claims.
5. `recording-tools-recommendations.json`: a JSON object with a `recommendations` array. Each item has a unique `id`, `title`, `category`, `problem`, `user_task`, `repo_evidence`, `external_source_ids`, `proposal`, `benefit`, `cost`, `alternative`, `confidence`, `dependencies`, `proof`, `failure_rule`, and `priority`. Use `category` values `keep`, `improve`, `explore`, `reuse`, or `avoid`.
6. `recording-tools-proof-plan.md`: conditional proposal, first proof, acceptance and rejection rules, dependency risks, ordered outcomes, cut line, and at most three human decisions.
7. `recording-tools-manifest.json`: baseline, research date, inspected files, checks actually run, file names, byte sizes, SHA-256 hashes, counts, omissions, and unresolved limits. The manifest need not hash itself or the ZIP.
8. `recording-tools-research.zip`: those seven companion files.

Codex will preserve originals under `docs/research/recording-tools/pro-output/`. It will write the reconciled review beside them and concise Sleuth artifacts under `docs/intent/recording-tools/`. Do not claim to have saved repository files at these paths.

If file generation is unavailable, return every artifact's full content in clearly labeled sections. Do not substitute a short summary for missing files. State that no repository files or commits were created.

Validate CSV and JSON parsing, file integrity, unique IDs, reference resolution, product/profile counts, and answer coverage before delivery. These checks validate the research package, not the product.

End with direct links to every output, a concise recommendation, access status, counts, files inspected, executed checks, unanswered questions, and material limitations.
