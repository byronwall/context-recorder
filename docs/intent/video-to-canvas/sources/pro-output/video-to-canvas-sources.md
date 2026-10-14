# Video-to-canvas source ledger

**Research access date:** 2026-10-13 (America/Indiana/Indianapolis).
**Repository baseline:** `016684895df51872aeea1be5e93e28419fd63a7f`. **Decision:** conditional GO to a bounded proof; no reconstruction experiment has run.

## 1. Evidence rules and access status

Repository facts come from the authorized selected source packet plus connected GitHub reads at the exact baseline. External facts below come from primary documentation, specifications, author publications or implementation repositories. Product rules, thresholds, memory budgets and runtime ranges are proposals/inferences. No primary source is treated as validation on Context Recorder recordings. No benchmark numbers from another project are reported as results of this assignment.

Connected access succeeded for `Package.swift` and the complete recursive tree. The tree returned `truncated:false`; no `package.json`, test suite or sample recording was found. All 23 packet entries passed byte-size/SHA-256 checks, and the separately supplied prompt matched its packet copy exactly. This establishes packet integrity and exact-ref access, not independent remote content verification for every selected file. No writable checkout is required or claimed.

- Exact package: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Package.swift
- Exact tree: https://api.github.com/repos/byronwall/context-recorder/git/trees/016684895df51872aeea1be5e93e28419fd63a7f?recursive=1

## 2. Repository reading inventory

All 21 baseline files below were read from the packet. Native source line numbers are used in symbol links; packet line numbers are separately identified where useful. The two research documents are local additions and must not be assumed to exist at the baseline URL.

### R01 — `README.md`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/README.md
- Supports: Product behavior, output layout, portable viewer and rrweb as future work.
- Packet integrity: 9,908 bytes; SHA-256 `a8974d327a25101f15bdb2ffb4aff1ec201438858fe0032471b8a71b0d89167b`.

### R02 — `Package.swift`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Package.swift
- Supports: One Swift executable; macOS 26; no test target or package dependencies.
- Packet integrity: 564 bytes; SHA-256 `ee4be4430ba641a33aa6f99829bc486aee4b7e9acbf775828d4ea9c5b6125174`.

### R03 — `Sources/ContextRecorder/Recorder.swift`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Recorder.swift
- Supports: Capture settings, clock, writer and separate still capture.
- Packet integrity: 7,431 bytes; SHA-256 `397eb46ba9f77593661168106ea2c255dbf883b3e1a9b28f35c7d86e2f918c6d`.

### R04 — `Sources/ContextRecorder/Session.swift`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Session.swift
- Supports: Marks and browser events persisted as JSONL.
- Packet integrity: 2,853 bytes; SHA-256 `b5f1ad2b06bdc3a4829f0f0bb50e8721a91ffee47304f6d935a1c8bdcb2da761`.

### R05 — `Sources/ContextRecorder/ActivityLog.swift`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/ActivityLog.swift
- Supports: Two-second sampling plus application activation; writes only when app/title/URL key changes.
- Packet integrity: 2,144 bytes; SHA-256 `3529ca90d021a6859d77e0c5439797d3512a2956b12d714c39c7e7bb5a641fe3`.

### R06 — `Sources/ContextRecorder/ContextProbe.swift`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/ContextProbe.swift
- Supports: App/window/browser context and mixed display-coordinate metadata.
- Packet integrity: 2,778 bytes; SHA-256 `751beb96e2c0234f9c7ebf3dae4967473fdc676eccef6c0fca5383b9ee879a1d`.

### R07 — `Sources/ContextRecorder/main.swift`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/main.swift
- Supports: Capture/mark/bridge orchestration, coordinate conversion and post-processing launch.
- Packet integrity: 22,047 bytes; SHA-256 `9413e44b721980102e60fc27931f650246873ba46781a1a67bb84dd3d7fb4510`.

### R08 — `extension/page.js`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/extension/page.js
- Supports: Selected streamed events; on-demand snapshot and viewportOrigin conversion.
- Packet integrity: 22,435 bytes; SHA-256 `19045817d88bf4b8d4e7bda277f4a5a434bb1ef61442fc3a8eb6be8791114fae`.

### R09 — `extension/background.js`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/extension/background.js
- Supports: Queued WebSocket delivery, active-tab snapshot and asynchronous MHTML capture.
- Packet integrity: 5,332 bytes; SHA-256 `99f630918360f8b63ac32f03bcde1037c6e730a116bc4416156c0163912f7d33`.

### R10 — `extension/relay.js`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/extension/relay.js
- Supports: Page/extension relay and request timeout.
- Packet integrity: 1,316 bytes; SHA-256 `0da9b076a4810adeeeff2dd138042e1c5beb6f4671e1851f563cf29444b419fc`.

### R11 — `extension/manifest.json`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/extension/manifest.json
- Supports: MV3 permissions and MAIN/isolated content-script configuration.
- Packet integrity: 1,061 bytes; SHA-256 `58a83f30532ebd23a7a12e9c6606f7d01504627a3de14197c768374dd9436a85`.

### R12 — `Sources/ContextRecorder/BrowserBridge.swift`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/BrowserBridge.swift
- Supports: Loopback bridge, request timeout and event dispatch.
- Packet integrity: 6,569 bytes; SHA-256 `a74f395005f81a2eb524e108ecb8655ad870ce7fa4cdbae518f6c8c77dee1b3b`.

### R13 — `scripts/process_session.py`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/process_session.py
- Supports: Standard-library processor, mark frames, transcript rollup and inline-JSON viewer.
- Packet integrity: 13,850 bytes; SHA-256 `5ea7c4db660728bdc900eb8c21885a8724ec837fdb0c1a1a0e0cb6eb6728b819`.

### R14 — `Sources/ContextRecorder/Library/SessionData.swift`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/SessionData.swift
- Supports: Native decoded projection; PageSnapshot excludes viewport/DPR/scroll fields.
- Packet integrity: 8,627 bytes; SHA-256 `381db50d44e524ae04194f5b16282cf759791a59b1f0e488d5841b963fcfca67`.

### R15 — `Sources/ContextRecorder/Library/SessionModel.swift`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/SessionModel.swift
- Supports: AVPlayer, shared playhead, seek and session.json reload.
- Packet integrity: 8,179 bytes; SHA-256 `499dee6ea290fba23f68faa5b805e40043f699bd334dcf26ce35f6c4cedd1dc4`.

### R16 — `Sources/ContextRecorder/Library/SessionView.swift`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/SessionView.swift
- Supports: Stage, native RegionPicker, browser-open action and existing timeline composition.
- Packet integrity: 17,426 bytes; SHA-256 `747b1630bde793562985fafc099a2ab9b139ad055c52de21cec257eaaecda500`.

### R17 — `Sources/ContextRecorder/Library/SessionTimeline.swift`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/SessionTimeline.swift
- Supports: Shared time-axis interaction and lanes.
- Packet integrity: 16,884 bytes; SHA-256 `9e88d8ab32dca23493f276497b028a8b4cfc9fdeac66814082ffd2e8b1d82f73`.

### R18 — `Sources/ContextRecorder/Library/Review.swift`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/Review.swift
- Supports: Review marks, frame crops, note edits and reprocessing.
- Packet integrity: 9,721 bytes; SHA-256 `887465c6b0ffa62284f3b7f5cdd4b5989d47027bcdc3e682e0b9854d00dfd40e`.

### R19 — `scripts/viewer.html`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/viewer.html
- Supports: Inline session data, video.currentTime, renderNow and single-image lightbox.
- Packet integrity: 39,722 bytes; SHA-256 `a8f2d60a616d65f3c9bb09fd159806b7fcf1bb7525b1f427b6e470e4b016c8d9`.

### R20 — `Sources/ContextRecorder/Export/PgmExport.swift`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Export/PgmExport.swift
- Supports: Existing per-mark Product Grid export and durable export mapping.
- Packet integrity: 9,061 bytes; SHA-256 `63cc34b04201ce5dfed5cdcb78f502b461d1d1c1cb5809ced5a4f551234e4908`.

### R21 — `scripts/build-app.sh`
- Source: https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/build-app.sh
- Supports: Explicit resource copying, release build, signing and optional installation.
- Packet integrity: 1,706 bytes; SHA-256 `c04036f6685fc4c212f83d7aac5223edd623f67632df3d94a6f05c45e49e62a9`.

### Local additions and supplied attachment identity

- `docs/research/video-to-canvas/intent-brief.md` — 3,588 bytes; SHA-256 `88f2b0f0d991131c13d9358ed8c13e3e67e0b6b163dcfaf0df567aaad7775027`. Supplied local addition, not a baseline file.
- `docs/research/video-to-canvas/pro-prompt.md` — 16,040 bytes; SHA-256 `4cb6485421398cbf5b41d66449729352b001a0dff271b51e38bc35998363f3cc`. Supplied local addition, not a baseline file.

The intent brief is at packet lines 4665–4730. Its eight preserved experiences are scroll reconstruction, rightward changed states, compact frequent changes, playable motion, return visits, narration association, lecture storyboards and larger-than-frame capture. The prompt is the authority for this read-only assignment; Codex, not this run, owns repository integration and the PR.

## 3. Consequential source details and integration anchors

- **`Sources/ContextRecorder/Recorder.swift` · `Recorder.start(outputURL:recordMicrophone:)` · lines 24–72:** Main-display capture, width cap, requested frame rate, cursor and encoding/microphone settings. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Recorder.swift#L24-L72).
- **`Sources/ContextRecorder/Recorder.swift` · `Recorder.currentOffset()` · lines 100–105:** Host-clock minus first video PTS; nominal frame rate is not an exact per-frame clock. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Recorder.swift#L100-L105).
- **`Sources/ContextRecorder/Recorder.swift` · `Recorder.screenshot(to:rect:)` · lines 108–122:** Separate still capture uses display points and pointPixelScale; not a decoded video frame. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Recorder.swift#L108-L122).
- **`Sources/ContextRecorder/ActivityLog.swift` · `ActivityLog.start()` · lines 24–33:** Two-second timer and app-activation callback. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/ActivityLog.swift#L24-L33).
- **`Sources/ContextRecorder/ActivityLog.swift` · `ActivityLog.sample()` · lines 42–50:** Only app/title/URL key changes are written; window movement alone is not continuous geometry. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/ActivityLog.swift#L42-L50).
- **`Sources/ContextRecorder/main.swift` · `bridge.onEvent` · lines 97–100:** App records bridge receipt offset, not synchronized page-event occurrence. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/main.swift#L97-L100).
- **`Sources/ContextRecorder/main.swift` · `AppDelegate.addMark(screenshot:)` · lines 293–309:** Keypress offset precedes asynchronous browser snapshot and possible region selection. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/main.swift#L293-L309).
- **`Sources/ContextRecorder/main.swift` · `AppDelegate.addRegionMark` · lines 349–364:** Still capture happens later while stored mark offset remains the earlier captured value. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/main.swift#L349-L364).
- **`Sources/ContextRecorder/main.swift` · `AppDelegate.pointerPayload` · lines 381–388:** Backing scale and coordinate-origin conversion. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/main.swift#L381-L388).
- **`extension/page.js` · `snapshot(req)` · lines 365–383:** On-demand viewport, DPR and rounded scroll coordinates. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/extension/page.js#L365-L383).
- **`extension/page.js` · `viewportOrigin(req)` · lines 391–400:** Pointer-based mapping with zoom estimate; window-geometry fallback. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/extension/page.js#L391-L400).
- **`extension/background.js` · `send(msg)` · lines 39–50:** Disconnected queue makes arrival-time interpretation unsafe. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/extension/background.js#L39-L50).
- **`extension/background.js` · `capturePage(tabId,id)` · lines 98–110:** Asynchronous MHTML API call/retry, not continuous recording. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/extension/background.js#L98-L110).
- **`scripts/process_session.py` · `extract_frame` · lines 131–140:** Mark-frame cache lacks returned decoded PTS. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/process_session.py#L131-L140).
- **`scripts/process_session.py` · `tokens_of` · lines 98–102:** Raw recognition data retains tokens. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/process_session.py#L98-L102).
- **`scripts/process_session.py` · `write_viewer` · lines 282–287:** Inline JSON template injection; no local-file JSON fetch needed. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/process_session.py#L282-L287).
- **`scripts/process_session.py` · `session rollup in main` · lines 329–332:** Rollup stores sentence start/end/text, not token arrays. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/process_session.py#L329-L332).
- **`Sources/ContextRecorder/Library/SessionData.swift` · `PageSnapshot` · lines 69–80:** Native projection excludes viewport/window/DPR/scroll fields. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/SessionData.swift#L69-L80).
- **`Sources/ContextRecorder/Library/SessionModel.swift` · `SessionModel.seek(_:play:)` · lines 169–174:** Existing AVPlayer/shared-playhead seeking integration. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/SessionModel.swift#L169-L174).
- **`Sources/ContextRecorder/Library/Review.swift` · `saveFrame(at:crop:to:)` · lines 126–137:** AVAssetImageGenerator result actual time is discarded. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/Review.swift#L126-L137).
- **`Sources/ContextRecorder/Library/Review.swift` · `SessionModel.reprocess()` · lines 150–170:** Review edits rerun processing; do not couple this to full video reconstruction. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/Review.swift#L150-L170).
- **`scripts/viewer.html` · `renderNow` · lines 407–419:** Existing HTML source of current playback time. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/viewer.html#L407-L419).
- **`scripts/viewer.html` · `lightbox` · lines 484–492:** Single-image pan/zoom, not a tiled infinite canvas. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/viewer.html#L484-L492).
- **`Sources/ContextRecorder/Export/PgmExport.swift` · `PgmExporter.imageFiles(for:)` · lines 155–160:** Existing export accepts mark images/frame, not arbitrary composite provenance. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Export/PgmExport.swift#L155-L160).
- **`scripts/build-app.sh` · `resource copy` · lines 21–23:** New helper would require explicit bundling; signing script not executed. [Exact source](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/build-app.sh#L21-L23).

## 4. External primary sources

Each entry was accessed on **2026-10-13**. Mutable documentation/main branches are not pinned source dependencies. A later reuse/install decision must record the actual release or commit and resolved package artifacts.

### E01 — OpenCV phase correlation API and 4.14.0 declarations
- Primary URL: https://raw.githubusercontent.com/opencv/opencv/4.14.0/modules/imgproc/include/opencv2/imgproc.hpp
- Accessed: 2026-10-13.
- Supports: Tagged source, phaseCorrelate and createHanningWindow declarations and documentation. Translation estimation, floating-point inputs, optional window, response semantics.
- Coverage/limit: Full relevant declaration/comment block inspected. API presence is not an installation or accuracy test.

### E02 — OpenCV motion-analysis documentation
- Primary URL: https://docs.opencv.org/4.13.0/d7/df3/group__imgproc__motion.html
- Accessed: 2026-10-13.
- Supports: Fourier phase-correlation procedure and response; Python call shape.
- Coverage/limit: Documentation retrieved through the 4.x route identified itself as 4.13.0. E01 separately verifies selected 4.14.0 API presence.

### E03 — OpenCV tracking and ECC registration
- Primary URL: https://docs.opencv.org/4.13.0/dc/d6b/group__video__track.html
- Accessed: 2026-10-13.
- Supports: Lucas–Kanade, Farneback, findTransformECC, translation motion mode and initialization/convergence caveats.
- Coverage/limit: Used to compare methods, not to recommend a multi-engine implementation.

### E04 — OpenCV robust fitting
- Primary URL: https://docs.opencv.org/4.13.0/d9/d0c/group__calib3d.html
- Accessed: 2026-10-13.
- Supports: estimateAffinePartial2D supports robust estimation but estimates translation, rotation and uniform scale; it is not a translation-only model.
- Coverage/limit: Relevant API documentation inspected. No feature-matching experiment performed.

### E05 — OpenCV Python headless 4.14.0.94 package record
- Primary URL: https://pypi.org/project/opencv-python-headless/4.14.0.94/
- Accessed: 2026-10-13.
- Supports: Release dated July 28, 2026; macOS ARM64 wheel 46.5 MB, uploaded July 29, and x86-64 wheel 33.1 MB. Headless package choice, one cv2 package per environment, bundled binaries and licensing.
- Coverage/limit: Candidate pin, not a claim of tested compatibility. PyPI ranks 5.0.0.93 above this 4.x version; newest version number and latest upload date differ.

### E06 — NumPy license
- Primary URL: https://numpy.org/doc/stable/license.html
- Accessed: 2026-10-13.
- Supports: BSD three-clause redistribution terms for NumPy.
- Coverage/limit: License inspected. Exact NumPy version and wheel resolution remain a local proof setup check.

### E07 — Apple Vision translation registration
- Primary URL: https://developer.apple.com/documentation/vision/vntranslationalimageregistrationrequest
- Accessed: 2026-10-13.
- Supports: Official identity of native translation-registration API.
- Coverage/limit: Apple page exposed a JavaScript-dependent shell here. Concrete call usage is corroborated by E09; no SDK compilation or performance validation.

### E08 — ScrollSnap macOS project
- Primary URL: https://github.com/Brkgng/ScrollSnap
- Accessed: 2026-10-13.
- Supports: A native scrolling-screenshot application exists; repository identifies MIT licensing and a Swift/macOS implementation.
- Coverage/limit: Prior art, not a benchmark on Context Recorder recordings and not a selected dependency.

### E09 — ScrollSnap native stitching implementation
- Primary URL: https://raw.githubusercontent.com/Brkgng/ScrollSnap/main/ScrollSnap/Managers/StitchingManager.swift
- Accessed: 2026-10-13.
- Supports: VisionOffsetEstimator compares regional translations; findTranslation uses VNTranslationalImageRegistrationRequest and its alignment result. StitchingManager retains a growing image.
- Coverage/limit: Relevant implementation inspected on mutable main. Do not transfer its thresholds or claim its total memory is constant. Record a commit before any reuse.

### E10 — scrollsnap traceable reconstruction project
- Primary URL: https://github.com/Haruhiyuki/scrollsnap
- Accessed: 2026-10-13.
- Supports: Closely related scroll-recording reconstruction with page coordinates, boundaries, mosaics/tiles and crop traceability. Author-maintained benchmark reports exist.
- Coverage/limit: README and metadata inspected; reported evaluations were not independently reproduced. This run did not audit its entire algorithm or validate its outputs.

### E11 — scrollsnap package metadata
- Primary URL: https://raw.githubusercontent.com/Haruhiyuki/scrollsnap/main/pyproject.toml
- Accessed: 2026-10-13.
- Supports: Metadata declares scrollsnap-core 0.1.0, Alpha, Python >=3.10, Apache-2.0, NumPy/OpenCV/Pillow dependencies and optional integrations.
- Coverage/limit: Project URLs use a different repository path from the inspected repository. Resolve canonical distribution/source identity before adopting; not evidence of wrongdoing.

### E12 — scrollsnap changelog
- Primary URL: https://raw.githubusercontent.com/Haruhiyuki/scrollsnap/main/CHANGELOG.md
- Accessed: 2026-10-13.
- Supports: Initial 0.1.0 release entry dated May 7, 2026.
- Coverage/limit: Evidence of published project history, not a maintenance guarantee.

### E13 — Efficient representations of video sequences and their applications — Irani et al.
- Primary URL: https://www.wisdom.weizmann.ac.il/~irani/abstracts/mosaics.html
- Accessed: 2026-10-13.
- Supports: Author abstract describes video mosaics, alignment/integration and residual analysis.
- Coverage/limit: Abstract-level prior art only; no quantitative result imported.

### E14 — Swipe Mosaics from Video — Reynolds, Haines and Brostow
- Primary URL: https://arxiv.org/abs/1609.08080
- Accessed: 2026-10-13.
- Supports: Author paper abstract describes navigable two-dimensional collections of video frames and uncertain pairwise translation.
- Coverage/limit: Abstract and metadata inspected. PDF retrieval failed; no claim of full-paper or figure analysis.

### E15 — Video Tapestries with Continuous Temporal Zoom — Barnes et al.
- Primary URL: https://research.adobe.com/publication/video-tapestries-with-continuous-temporal-zoom/
- Accessed: 2026-10-13.
- Supports: Author-organization publication record for multi-scale visual video summaries and temporal zoom.
- Coverage/limit: Publication/project descriptions, not an independently reproduced user study or reusable maintained package.

### E16 — Video Tapestries author project
- Primary URL: https://pixl.cs.princeton.edu/gfx/pubs/Barnes_2010_VTW/index.php
- Accessed: 2026-10-13.
- Supports: Author-hosted project description supports temporal-zoom/tapestry prior art.
- Coverage/limit: Primary search result available; direct page retrieval was inconsistent. No detailed quantitative claim rests on this source.

### E17 — Video Digests author publication listing
- Primary URL: https://www.amypavel.com/
- Accessed: 2026-10-13.
- Supports: Author lists Video Digests with paper/project/code links and digest thumbnails/text.
- Coverage/limit: Used for attribution and the text-plus-visual navigation precedent, not inferred semantic-grounding accuracy.

### E18 — Video Digests author-linked implementation
- Primary URL: https://github.com/ucbvislab/vdigests
- Accessed: 2026-10-13.
- Supports: README describes creating/distributing video digests and lists a web server, MongoDB, Node and other dependencies.
- Coverage/limit: Inspected README; substantial application stack, sparse setup documentation. No current maintenance or redistribution license established, so not a dependency recommendation.

### E19 — Dynamosaics: Dynamic Mosaics with Non-Chronological Time
- Primary URL: https://www.microsoft.com/en-us/research/video/dynamosaics-dynamic-mosaics-with-non-chronological-time/
- Accessed: 2026-10-13.
- Supports: Research presentation demonstrates dynamic mosaic navigation with non-chronological local time.
- Coverage/limit: Useful contrast for motion inspection; this report rejects loss of chronology for evidence review.

### E20 — Chrome pageCapture API
- Primary URL: https://developer.chrome.com/docs/extensions/reference/api/pageCapture
- Accessed: 2026-10-13.
- Supports: saveAsMHTML and pageCapture permission; saved page archive API.
- Coverage/limit: Does not establish frame-exact capture, continuous DOM history or visibility of archived offscreen content.

### E21 — rrweb official repository
- Primary URL: https://github.com/rrweb-io/rrweb
- Accessed: 2026-10-13.
- Supports: DOM snapshots, incremental recording/replay components and MIT license.
- Coverage/limit: Possible future instrumentation, not already present in the repository baseline. Replay is not original video-pixel evidence.

### E22 — CSSOM View specification
- Primary URL: https://drafts.csswg.org/cssom-view/#dom-window-devicepixelratio
- Accessed: 2026-10-13.
- Supports: CSS viewport coordinates, devicePixelRatio and page zoom semantics.
- Coverage/limit: A browser/display/video calibration is still required; CSS pixels are not recording pixels.

### E23 — HTML media currentTime
- Primary URL: https://html.spec.whatwg.org/multipage/media.html#dom-media-currenttime
- Accessed: 2026-10-13.
- Supports: Media timeline seeking through currentTime and asynchronous playback/seek behavior.
- Coverage/limit: Does not certify frame-exact local-file seeking in the proposed viewer. That requires the proof checks.

### E24 — HTML canvas security
- Primary URL: https://html.spec.whatwg.org/multipage/canvas.html#security-with-canvas-elements
- Accessed: 2026-10-13.
- Supports: Origin-clean restrictions apply to pixel reads and image export.
- Coverage/limit: Displaying a local image does not by itself prove export/readback works. Browser/local-file tests remain unrun.

### E25 — FFprobe documentation
- Primary URL: https://ffmpeg.org/ffprobe.html
- Accessed: 2026-10-13.
- Supports: Structured stream/frame metadata inspection.
- Coverage/limit: Use actual frame presentation timestamps and decoded dimensions; no media was probed in this run.

### E26 — FFmpeg CLI documentation
- Primary URL: https://ffmpeg.org/ffmpeg.html
- Accessed: 2026-10-13.
- Supports: Timestamp handling and fps_mode passthrough versus frame duplication/drop behavior.
- Coverage/limit: Muxing/filter choices can still alter timestamps. Proposed extraction must validate its own mapping.

### E27 — FFmpeg showinfo filter
- Primary URL: https://ffmpeg.org/ffmpeg-filters.html#showinfo
- Accessed: 2026-10-13.
- Supports: Per-output-frame ordinal, PTS, pts_time and size information.
- Coverage/limit: A proposed sequential extraction audit trail, not a decoder run executed here.

## 5. Dependency and prior-art disposition

| Item | Disposition | What remains unverified |
|---|---|---|
| FFmpeg/FFprobe | Existing external command dependencies; retain for decoding/metadata. | Actual local build, timestamp behavior and performance on supplied media. |
| OpenCV headless 4.14.0.94 + NumPy | Proposed isolated analysis environment; no install executed. | Resolver/ABI compatibility, installed footprint, runtime, accuracy and exact NumPy pin on the Mac. |
| Apple Vision | Native translation alternative, not simultaneous second engine. | SDK compilation, score calibration and throughput. Apple documentation shell limited retrieval. |
| Brkgng/ScrollSnap | Native scroll-capture precedent; relevant code inspected. | No Context Recorder evaluation. Growing-composite memory must not be called constant. |
| Haruhiyuki/scrollsnap / scrollsnap-core | Very relevant reuse lead; alpha metadata and README reviewed. | Canonical package/source URL identity, pinned algorithm/output audit and independent reproduction. |
| rrweb | Future optional structural instrumentation; not shipped here. | Incremental benefit, privacy scope and capture overhead. |
| Video Digests / Tapestries / Swipe Mosaics / classical mosaics | Research/design precedent, not maintained application dependencies selected for this project. | Full reproduction and, for some papers, full-text access. No imported user-study or accuracy claims. |

The OpenCV package record states different licensing for wrapper/build scripts, OpenCV and bundled third-party binaries, including FFmpeg. Do not label the entire wheel MIT-only. NumPy terms were checked from its own documentation. No new dependency is included in the delivered ZIP.

## 6. Material evidence gaps and effect on the decision

1. **No recordings or media experiments.** Reconstruction accuracy, harmful-join rate, readable coverage, lost changes, revisit detection, transcript timing and personal task value are unknown. Effect: conditional GO to experiments, not feature feasibility established. Required resolution: P0–P4 and actual narrated walkthroughs.
2. **No macOS runtime validation.** App build, screen permissions, decoder timestamp normalization, optional CV dependency setup, native Vision API execution and browser local-file behavior remain unrun. Effect: no installation or playback claim. Required resolution: P0 and P4 on the chosen Mac.
3. **Packet is selected source, not a checkout.** Other app files were not audited merely because their paths appeared in the tree. Effect: proposed integration points are grounded, but a later implementation review must inspect directly affected additional files only when needed.
4. **Browser metadata is sparse and clocks differ.** There is no continuous scroll/DOM track; queued or background-tab events cannot establish exact visible content/time. Effect: browser-assisted trajectories are a future proposal, not a capability available from this baseline.
5. **Unobservable history cannot be reconstructed.** Offscreen changes, occluded content and skipped frames cannot be recovered as recorded pixels. Effect: atlas labels, scoped identity and explicit gaps are mandatory; no future experiment can justify inventing unseen evidence.
6. **Prior-art access/reproduction limits.** Swipe Mosaics PDF retrieval failed; Tapestries project retrieval was inconsistent; several Apple documentation pages required JavaScript. Abstracts, primary project records and corroborating source code support only the modest claims stated. No full-paper quantitative result or unseen figure is used.
7. **Closest reusable package not adoption-ready on current evidence.** scrollsnap source/package identity and complete algorithm/output audit were not resolved; no evaluation was executed. Effect: do not add it blindly, but inspect a pinned component before duplicating substantial work.
8. **Resource ranges are assumptions.** Compression bytes/pixel, decode throughput, matching cost and browser caches were not measured. Arithmetic is reproducible, but a 60-minute feature budget remains a proposed gate.
9. **Transcript region semantics are unresolved.** Existing sentence/token timing supports temporal association, not proof that narration refers to a specific object or pixel. Effect: label spoken-during associations and keep ambiguous regions null.
10. **Lecture generalization remains separate.** Directed slides/code clips are not a substitute for an authorized real lecture file. Effect: retain the storyboard path, but do not promise general lecture reconstruction without its own acceptance sample.

## 7. Research actions and boundaries

Executed: exact-ref connector reads; all required packet reading; 23-entry size/hash verification; prompt identity; Python/JavaScript/Bash syntax checks; JSON parsing; external primary-source review; artifact creation and structural/integrity validation. No dependencies, external media or executable programs are packaged. No OCR, video registration, generated synthetic performance experiment, transcription, application build/run, signing, installation, publishing or repository mutation occurred.

The supplied intent brief uses a review-PR framing for the overall workflow. The controlling prompt assigns this run research/artifact production only. Codex will preserve/reconcile the outputs and owns the repository design/proof-plan PR. These artifacts were created under the conversation download directory, not under any claimed repository path.
