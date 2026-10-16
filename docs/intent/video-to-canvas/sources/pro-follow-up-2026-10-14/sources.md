# Source ledger and evidence boundaries

Access/review date: **October 14, 2026, America/Indiana/Indianapolis**.

Connected GitHub resolved main to **`76afc4faa24887408c275360132f0dd03384c94b`**. All implementation reads were pinned to that commit. The older source packet at `016684895df51872aeea1be5e93e28419fd63a7f` was used only as historical context, not as evidence of the shipped canvas.

## Repository reading inventory

Thirteen complete source files and three targeted/partial reads are listed below. Branch, tree, Library, and Tests listings were also read. This is a focused canvas review, not a claim to have read every file in the repository. No unpushed working tree was available.

### R1 — `Sources/CanvasKit/CanvasAnalyzer.swift`
- Source: [Sources/CanvasKit/CanvasAnalyzer.swift](https://github.com/byronwall/context-recorder/blob/76afc4faa24887408c275360132f0dd03384c94b/Sources/CanvasKit/CanvasAnalyzer.swift)
- Coverage: full.
- Supports: CanvasAnalyzer.Options/build/compose; every decoded frame; default estimator; item emission and images.

### R2 — `Sources/CanvasKit/ShiftEstimator.swift`
- Source: [Sources/CanvasKit/ShiftEstimator.swift](https://github.com/byronwall/context-recorder/blob/76afc4faa24887408c275360132f0dd03384c94b/Sources/CanvasKit/ShiftEstimator.swift)
- Coverage: full.
- Supports: RowProfileEstimator.estimate/profiles/cost; integer shift, 16 bins, shortlist; VisionEstimator ignores cols and discards x.

### R3 — `Sources/CanvasKit/Join.swift`
- Source: [Sources/CanvasKit/Join.swift](https://github.com/byronwall/context-recorder/blob/76afc4faa24887408c275360132f0dd03384c94b/Sources/CanvasKit/Join.swift)
- Coverage: full.
- Supports: JoinSettings; Joiner.join, inPlace, fixedBands, residualShare, scrollingColumns, detailRows.

### R4 — `Sources/CanvasKit/Segmenter.swift`
- Source: [Sources/CanvasKit/Segmenter.swift](https://github.com/byronwall/context-recorder/blob/76afc4faa24887408c275360132f0dd03384c94b/Sources/CanvasKit/Segmenter.swift)
- Coverage: full.
- Supports: Segmenter.feed/finish; Run.append; immediate run termination, settling, novel-row ownership, return history.

### R5 — `Sources/CanvasKit/Storyboard.swift`
- Source: [Sources/CanvasKit/Storyboard.swift](https://github.com/byronwall/context-recorder/blob/76afc4faa24887408c275360132f0dd03384c94b/Sources/CanvasKit/Storyboard.swift)
- Coverage: full.
- Supports: StoryboardSettings and Diff.changedCount; half-resolution gate and settling/motion thresholds.

### R6 — `Sources/CanvasKit/CanvasDocument.swift`
- Source: [Sources/CanvasKit/CanvasDocument.swift](https://github.com/byronwall/context-recorder/blob/76afc4faa24887408c275360132f0dd03384c94b/Sources/CanvasKit/CanvasDocument.swift)
- Coverage: full.
- Supports: CanvasDocument, CanvasItem, Patch, FrameRef; flat items, row-to-source ownership, sourceRegion selection clipping.

### R7 — `Sources/ContextRecorder/Library/CanvasStage.swift`
- Source: [Sources/ContextRecorder/Library/CanvasStage.swift](https://github.com/byronwall/context-recorder/blob/76afc4faa24887408c275360132f0dd03384c94b/Sources/ContextRecorder/Library/CanvasStage.swift)
- Coverage: full.
- Supports: CanvasStage, CanvasStrip, CanvasImages; horizontal layout, hover, click, image cache, export, selection.

### R8 — `Sources/ContextRecorder/Library/CanvasModel.swift`
- Source: [Sources/ContextRecorder/Library/CanvasModel.swift](https://github.com/byronwall/context-recorder/blob/76afc4faa24887408c275360132f0dd03384c94b/Sources/ContextRecorder/Library/CanvasModel.swift)
- Coverage: full.
- Supports: SessionModel canvas extension; crop/rebuild, showSource changes stage, source-frame-only region marks.

### R9 — `Sources/CanvasKit/FrameSource.swift`
- Source: [Sources/CanvasKit/FrameSource.swift](https://github.com/byronwall/context-recorder/blob/76afc4faa24887408c275360132f0dd03384c94b/Sources/CanvasKit/FrameSource.swift)
- Coverage: full.
- Supports: FrameSource.next; all decoded presentation timestamps, raw image conversion, GrayImage.halved.

### R10 — `Sources/CanvasTool/Check.swift`
- Source: [Sources/CanvasTool/Check.swift](https://github.com/byronwall/context-recorder/blob/76afc4faa24887408c275360132f0dd03384c94b/Sources/CanvasTool/Check.swift)
- Coverage: full.
- Supports: Check.run/checkStoryboard/checkSeeks; existing native fixture and source-time checks.

### R11 — `Sources/CanvasTool/Geometry.swift`
- Source: [Sources/CanvasTool/Geometry.swift](https://github.com/byronwall/context-recorder/blob/76afc4faa24887408c275360132f0dd03384c94b/Sources/CanvasTool/Geometry.swift)
- Coverage: full.
- Supports: Geometry.check: no-column early return, accepted-patch error, mapping checks, maxColumns upper bound.

### R12 — `Sources/CanvasTool/Fixtures.swift`
- Source: [Sources/CanvasTool/Fixtures.swift](https://github.com/byronwall/context-recorder/blob/76afc4faa24887408c275360132f0dd03384c94b/Sources/CanvasTool/Fixtures.swift)
- Coverage: lines 1–250.
- Supports: Fixture cases, truth model, integer scroll positions, fixed selected region, synthetic encoding; rest of renderer not read.

### R13 — `extension/page.js`
- Source: [extension/page.js](https://github.com/byronwall/context-recorder/blob/76afc4faa24887408c275360132f0dd03384c94b/extension/page.js)
- Coverage: lines 1–40.
- Supports: STREAM includes click/nav/console/error/request, not scroll. Blob matches the previous packet copy.

### R14 — `Sources/CanvasTool/main.swift`
- Source: [Sources/CanvasTool/main.swift](https://github.com/byronwall/context-recorder/blob/76afc4faa24887408c275360132f0dd03384c94b/Sources/CanvasTool/main.swift)
- Coverage: full.
- Supports: Existing CLI commands and argument names for disposable native checks.

### R15 — `Package.swift`
- Source: [Package.swift](https://github.com/byronwall/context-recorder/blob/76afc4faa24887408c275360132f0dd03384c94b/Package.swift)
- Coverage: full.
- Supports: macOS 26, native CanvasKit/CanvasTool, optimization flags; test target is AnnotationTests.

### R16 — `README.md`
- Source: [README.md](https://github.com/byronwall/context-recorder/blob/76afc4faa24887408c275360132f0dd03384c94b/README.md)
- Coverage: partial response; Canvas section read.
- Supports: Documented current canvas actions and behavior; not an independent performance measurement.

## Primary external sources

The OpenCV 4.x documentation routes resolved to 4.13.0 in this run. Installed diagnostic APIs were also 4.13.0. This is not a claim that 4.13.0 is the newest release on every channel.

### E1 — Apple — VNTranslationalImageRegistrationRequest
- Source: [Apple — VNTranslationalImageRegistrationRequest](https://developer.apple.com/documentation/vision/vntranslationalimageregistrationrequest)
- Accessed: October 14, 2026, America/Indiana/Indianapolis.
- Supports: Translation-registration API exists. No evidence here that it solves nested scrolling or UI state identity. The repository wrapper defect is established by R2, not Apple documentation.

### E2 — OpenCV — motion analysis / phaseCorrelate
- Source: [OpenCV — motion analysis / phaseCorrelate](https://docs.opencv.org/4.13.0/d7/df3/group__imgproc__motion.html)
- Accessed: October 14, 2026, America/Indiana/Indianapolis.
- Supports: phaseCorrelate accepts optional windowing and returns a subpixel translation and response. The response is a correlation statistic, not a product-level probability of a truthful stitch.

### E3 — OpenCV — object tracking / calcOpticalFlowPyrLK
- Source: [OpenCV — object tracking / calcOpticalFlowPyrLK](https://docs.opencv.org/4.13.0/dc/d6b/group__video__track.html)
- Accessed: October 14, 2026, America/Indiana/Indianapolis.
- Supports: Sparse pyramidal Lucas–Kanade optical-flow API used in the diagnostic probe; ECC translation model is another API option, not a tested recommendation.

### E4 — W3C — CSSOM View Module
- Source: [W3C — CSSOM View Module](https://www.w3.org/TR/cssom-view/)
- Accessed: October 14, 2026, America/Indiana/Indianapolis.
- Supports: Document/element/visual viewport coordinates and scrolling are distinct. Used to frame optional future browser geometry telemetry, not to claim current extension support.

## Local experimental evidence

`results/source-verification.json` records Git blob hashes and SHA-256 values for the four verbatim upstream files used in the probe. `experiments/prepare_swift.py` rechecks the blob hashes before execution.

`results/swift-core-results.json` records actual executions of the row-profile estimator, join checks, half-size gate, Segmenter, and Run patch planning under Linux metadata stubs. It is not a reimplementation of those algorithms in Python. The unavailable Vision implementation is excluded, and decoding/image rendering are stubbed.

`results/prototype-results.json` records diagnostic OpenCV motion proposals. These are not accepted stitches or an integrated alternative segmenter. `results/anchor-ablation.json` records the separate geometry-anchor ablation. `results/reproduction-checks.json` contains the 23 reproduced behavioral assertions and environment versions.

Synthetic fixtures deliberately isolate failure mechanisms. Known crops and a skipped known transient are oracle interventions. They establish that recoverable geometry exists, not that automatic region discovery or transient classification is solved. All generated content is synthetic; no user recording or browsing history was fetched.

## Material gaps

The macOS app build, AVFoundation decoder, Apple Vision, Core Graphics compositor, AVPlayer seek behavior, SwiftUI interactions, real-recording coverage, and integrated replacement pipeline remain unrun. FFmpeg H.264 round trips are not an Apple end-to-end capture test. No claim is made about the frequency of these failures in real use, or about production speed/memory.

The HTML concept uses synthetic probe images and the clean run’s patch plan, rendered by Python for demonstration. Its source-coordinate checks and JavaScript syntax are checked separately; browser interaction and native integration are not validated by those checks.

Recommendations VCI-01 through VCI-10 and UI layouts are proposals unless an explicitly named experiment is reported. Numerical acceptance thresholds are provisional. No repository files were changed, committed, pushed, or published.
