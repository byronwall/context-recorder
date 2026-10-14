https://github.com/byronwall/context-recorder

# Research a video that unfolds into an infinite canvas

## Mission and decision

Research a practical way to turn a narrated screen recording into an interactive spatial storyboard.
Determine whether the distinctive idea is feasible, then propose the smallest convincing proof in this repository.
Preserve the broader vision and explain the path from that proof to it.
Do not reduce the result to a conventional grid of keyframes without testing the spatial reconstruction idea.
Do not assume the full idea works. A justified NO-GO or narrower proposal is a useful result.

Act as a computer vision researcher and a product designer who builds small local tools.
Compare methods candidly. Explain their cost, limits, and failure behavior.
Use current primary sources for algorithm, library, platform, and prior-art claims.
Codex will review your output, integrate the findings, and open a review PR.
Your assignment is research and artifact production. Do not change repository files, commit, push, or create a PR.

Repository: `byronwall/context-recorder`.
Baseline: `016684895df51872aeea1be5e93e28419fd63a7f`, fetched from `origin/main` on October 13, 2026, America/Indiana/Indianapolis.
Codex integration branch: `codex/video-to-canvas-research` in the existing checkout.
The branch and new brief may be unpushed. Use the exact baseline plus the supplied local brief.
Do not assume later default-branch changes belong to this baseline.

## User intent

Byron wants to convert time into space, then recover time through interaction.

Imagine a product walkthrough. The user scrolls down a web page while speaking.
Align overlapping frames so the canvas shows the observed page from top to bottom.
When content changes, move the new state to the right.
For constant change, show compact overlapping cards or another readable sequence.
One, five, and ten second intervals were examples. Sampling may instead depend on meaningful changes.
Animations should remain inspectable or playable from the canvas.
If the recording returns to earlier content, show an arrow and a jump to that content.
Retain the later visit and its place in time.
Associate transcript chunks with the relevant visual content and source times.
For a professor speaking over slides and code, gather the assets and words into one spatial storyboard.
Allow region captures of the compiled result, including composites larger than a single recorded frame.

The main case is narration over web products with scrolling static content.
Slides and code walkthroughs are a second case. A local copy of a generic lecture video may have no browser data.
No video or personal recording accompanies this research packet.
Do not claim to have evaluated real recordings. Propose a small corpus and mark its checks as unrun.

## Access gate

First try connected GitHub access to the exact baseline.
Codex verified connected access to `Package.swift` at that ref before submission.
That does not establish your access or a writable checkout.

GO when the repository identity, baseline, and required source are available through GitHub or the supplied packet.
The source packet is an authorized selected snapshot, not a runnable checkout.
Its manifest names the baseline, included files, hashes, and local additions.
Use that packet if GitHub cannot expose the ref. State the coverage limit.
Read the new `docs/research/video-to-canvas/intent-brief.md` from the attachment.

NO-GO for a repository-specific conclusion if neither route supplies the required evidence.
Stop and name the missing files if a material source gap prevents the decision.
Do not substitute another repository or infer source from the repository name.
If external browsing is unavailable, label the external research incomplete.
You may return useful partial analysis, but do not label it a completed research result.
If file creation is unavailable, return every artifact's complete content in the response.
Do not require a writable repository for this read-only assignment.

## Repository facts to verify

- `Package.swift` defines a Swift executable for macOS 26. There is no `package.json` at this baseline.
- `Recorder` uses ScreenCaptureKit and AVAssetWriter. It records the main display at 15 fps and up to 1920 pixels wide.
- Its H.264 settings request 4 Mbps and include the cursor. Microphone recording is optional.
- `Recorder.currentOffset()` relates marks to the first video presentation timestamp using the host clock.
- `Session` writes marks and browser events as JSONL. `ActivityLog` samples context every two seconds and on app activation.
- The extension streams selected page events. On-demand snapshots include viewport size, DPR, and scroll coordinates.
- MHTML is captured at marks. These snapshots are not a continuous DOM or scroll recording.
- `scripts/process_session.py` uses Python's standard library plus external ffmpeg, ffprobe, and parakeet-mlx commands.
- It extracts a frame for each mark. Raw transcript data includes tokens; `session.json` reduces narration to sentences.
- `Library/SessionModel.swift` owns an AVPlayer and the shared playhead.
- `Library/Review.swift` creates marks and region shots during review, then reprocesses the session.
- `Library/SessionView.swift` and `SessionTimeline.swift` show the native session view and timeline.
- `scripts/viewer.html` is a portable template with session JSON embedded for direct local-file use.
- Product Grid export already exists under `Sources/ContextRecorder/Export/`.
- The README lists rrweb recording as a possible next step, not a shipped feature.
- No tracked test target, test suite, or sample recording was found in this baseline.

## Required reading route

1. Packet instructions, `README.md`, `Package.swift`, and the supplied intent brief.
2. `Sources/ContextRecorder/Recorder.swift`, `Session.swift`, `ActivityLog.swift`, `ContextProbe.swift`, and `main.swift`.
3. `extension/page.js`, `background.js`, `relay.js`, `manifest.json`, and `Sources/ContextRecorder/BrowserBridge.swift`.
4. `scripts/process_session.py`, `Sources/ContextRecorder/Library/SessionData.swift`, and `SessionModel.swift`.
5. `Sources/ContextRecorder/Library/SessionView.swift`, `SessionTimeline.swift`, `Review.swift`, and `scripts/viewer.html`.
6. `Sources/ContextRecorder/Export/PgmExport.swift` and `scripts/build-app.sh`.

These paths are relative to the repository root.
The supplied packet includes these files, the intent brief, and this prompt.
Check further source through GitHub only when it affects a recommendation.

Verified repository commands for a later local proof:

```sh
swift build
swift run ContextRecorder --library tmp/
python3 scripts/process_session.py --help
python3 scripts/process_session.py path/to/session --before 30 --after 5
INSTALL_DIR= ./scripts/build-app.sh
```

The session path is an input chosen for the proof, not an included fixture.
The processing command mutates session output. Use disposable fixtures for later tests.
The build script signs a bundle and normally installs it; `INSTALL_DIR=` prevents installation.
Do not run that script as part of this research.
Commands require the proper macOS environment. State any checks you could not run.

## Priority questions

### 1. Can time become useful, truthful space?

This is the primary question.
Define the user-visible rules for extending a scroll surface, creating a new state, preserving motion, and linking a return.
Compare at least three viable approaches: visual registration, browser-assisted reconstruction, and a simple keyframe baseline.
Consider a hybrid only when each component earns its cost.
Distinguish global screen motion, viewport scrolling, nested scrolling, layout changes, and content changes.
Explain how the output avoids inventing unseen content or implying that different moments existed at one time.
Define provenance from each image region and transcript chunk back to source time and pixels.
Show three worked examples: page scrolling then changing, a repeated page visit, and a slide/code lecture.
Include a small conceptual canvas layout for each. Use diagrams where they explain the spatial and temporal rules.

### 2. Which reconstruction method can a personal developer build?

Compare translation or phase-correlation methods, feature matching with robust fitting, optical flow, and useful platform APIs.
Do not recommend every method. Select one small initial pipeline and state when it should refuse to stitch.
Research prior work on video mosaics, scroll stitching, video summarization, and spatial video navigation.
Separate useful prior art from a maintained implementation dependency.
Address fixed headers, sticky elements, tooltips, pointer motion, text selections, animated areas, compression, blank areas, and repeated text.
Address scroll reversals, fast jumps with little overlap, zoom, window movement, nested panes, virtualized lists, and lazy-loaded content.
Explain seam handling and text legibility. Avoid geometric warps that corrupt UI text without a clear reason.
Discuss revisits to the same URL with changed content, visually similar pages, and repeated lecture slides.
Specify confidence signals, thresholds to calibrate, and a clear non-stitched result when evidence is weak.
Propose how observed pixels remain separate from DOM-derived or inferred content, if the latter is useful.

### 3. How should people navigate and inspect it?

Compare the proposed left-to-right flow and stacked cards with one or two alternatives.
Keep page geometry useful while making chronology and repeat visits clear.
Define zoom levels, selection, transcript placement, playback, animation inspection, return arrows, and composite region capture.
Make a click on canvas content seek to a defined source moment. Explain ambiguous mappings with several visits.
Consider keyboard access and a readable overview for long sessions.
Define the minimum correction controls needed when automatic grouping or alignment is wrong.
Do not build a full editor to avoid proving the automatic pipeline.

### 4. Where does it fit in this repository?

Compare offline post-processing with processing during capture.
Compare the existing SwiftUI view with the portable HTML viewer as the first proof surface.
Use actual file paths and symbols for integration points.
Describe one small data model with a concrete JSON example: surfaces, states or visits, transforms, images, time spans, and links as needed.
Separate canonical source evidence from disposable derived assets.
Explain timestamps, video pixel coordinates, display points, CSS pixels, browser zoom, and device scale where they cross boundaries.
Do not assume the existing mark snapshots provide continuous scroll offsets.
Explain what optional future instrumentation would improve and what video-only input can still do.
Use bounded image tiles or another concrete memory strategy if full composites become large.
Estimate disk, memory, and processing cost for a 10-minute and a 60-minute recording. Label estimates and assumptions.
Choose dependencies sparingly. Verify current APIs, licensing, maintenance, and installation costs from primary sources.

### 5. What proof decides GO or NO-GO?

Define a small sequence of experiments before committing to a broad implementation.
Compare against raw video review and a simple change-selected keyframe storyboard.
Specify inputs, ground truth, procedure, metrics, provisional thresholds, and failure outcomes.
Include clean vertical scrolling, sticky UI, nested panes, content edits, fast jumps, repeated visits, animation, and slides.
Measure useful content coverage, registration error, bad stitches, lost changes, revisit precision, source-time mapping, readability, and resource cost.
Choose a few decisive acceptance gates; do not turn this into a large benchmark platform.
Define the smallest end-to-end slice that proves value to Byron.
Give later milestones for motion, revisits, transcript mapping, and composite export without promising they all ship in the first slice.
State what evidence would reject stitching, favor a simpler layout, or stop the work.

## Constraints and non-goals

This is a personal project. Assume one developer and local use.
Prefer short call paths and a small data model. No distributed service, cloud ingestion, vector database, or agent framework by default.
Preserve the current Swift, Python, and HTML structure. Do not propose a stack conversion merely for convenience.
If a new package-based web project becomes justified, Byron's default is TypeScript, TSX, SolidJS, and pnpm.
No application implementation, dependency installation, public publishing, deployment, or merge is part of this assignment.
Do not fetch private recordings or browsing history. The selected source packet is the only local attachment scope.
No YouTube download service, downloader, DRM workaround, or account integration is required. Treat lectures as supplied video files.
Do not propose generative image filling as evidence reconstruction.
Do not promise video-resolution text can recover detail that was never recorded.
Do not treat a synthetic example as proof of performance on real recordings.
Keep tests few and directed at important behavior and likely failures.
Do not add compatibility layers or version coexistence without a concrete need.

## Evidence and recommendation rules

Separate repository facts, external facts, inferences, proposals, and unrun experiments.
Cite exact repository paths and symbols for each consequential integration claim.
Cite direct primary-source URLs for external claims. Record access dates and which claims each source supports.
Explain uncertainty and limits. Mark numerical thresholds as proposals unless you measured them.
For each substantive recommendation, use a stable ID such as VC-01.
Include the user problem, proposal, evidence, alternatives, benefit, cost, confidence, and validation method.
Keep the recommendation list to the decisions that affect this project.
Use clear, short sentences. Prefer tables only for useful comparisons.

## Deliverable contract

Produce these downloadable files, plus a ZIP containing them:

1. `video-to-canvas-report.md`: standalone report answering the five ranked questions, with access status, source baseline, comparison tables, worked layouts, rejected ideas, open choices, and a clear GO / conditional GO / NO-GO decision.
2. `video-to-canvas-recommendations.json`: an array of recommendations with `id`, `title`, `proposal`, `repositoryEvidence`, `externalSources`, `alternatives`, `benefit`, `cost`, `confidence`, and `validation` fields.
3. `video-to-canvas-proof-plan.md`: the staged proof, corpus design, decisive gates, concrete integration points, a small proposed data example, and checks clearly marked executed or unrun.
4. `video-to-canvas-sources.md`: primary source links, supported claims, access dates, and material evidence gaps.
5. `manifest.json`: file names, byte sizes, and SHA-256 hashes for the four substantive artifacts.
6. `video-to-canvas-research.zip`: those five files, with no code dependencies or executable programs.

Codex will preserve originals under `docs/research/video-to-canvas/pro-output/`.
Codex will reconcile findings into `docs/research/video-to-canvas/design.md`, `proof-plan.md`, and `research-review.md`.
Do not claim you saved files at these local repository paths.
If downloadable file creation is unavailable, provide the complete contents with exact file names in your response.

Link every output in the final response, including the ZIP and standalone files.
Summarize the decision, the smallest proof, the main risk, access status, files read, checks run, and open questions.
Do not claim success until each priority question has an evidence-backed answer or a clear unresolved limit.
Missing repository evidence, unsupported decisive claims, or incomplete artifacts require a focused follow-up.
Product choices that can remain clear proposals do not require another research round.
