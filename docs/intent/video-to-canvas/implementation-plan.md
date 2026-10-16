---
title: "Video to canvas — implementation plan"
slug: "video-to-canvas"
phase: plan
status: current
last_updated: "2026-10-15"
---

# Video to canvas — implementation plan

## Plan at a glance

Build in two stages. **Stage 1 (Milestones 6–7)** delivers automatic whole-screen reconstruction with local change markers inside the existing card/column layout. Byron then uses it on real recordings. **Stage 2 (Milestones 8–9)** adds stable pages, the visit ribbon, and visit-aware source access, and is gated on that use plus a short ribbon/layout design pass. The existing native canvas remains usable after each step.

First, make a full-screen web page with a sidebar and header reconstruct automatically. Add positive coverage checks with that behavior. A result containing only cards must fail. Second, keep the page continuous through slow scrolling and temporary overlays while preserving small edits. Show local events and before/after changes in the existing canvas during this step.

After Stage 1 use, third, give pages stable positions and add the compact visit ribbon. Separate the frame that supplied pixels from later frames that show them. Selecting content uses the active visit and still switches to full video. Fourth, verify the complete flow on a representative personal recording and check native interaction, persistence, and resource cost.

Do not rebuild the storyboard, repeat the engine selection, or implement all ten research recommendations. Keep the row-profile estimator initially. Add more motion handling only when a failing fixture or recording requires it. Manual crops remain diagnostic tools; they cannot satisfy the whole-screen acceptance gate.

## Implementation strategy

**Baseline:** `5710dd5` on `main`; canvas code is unchanged since `76afc4f`, the revision Pro reviewed. `CanvasKit`, `canvas-tool`, native canvas display, PNG export, and source-frame marks already exist. Implementation continues on the current working branch.

**Primary seam:** Extend the existing `CanvasDocument` stored in `canvas.json`, with images under `canvas/`. Keep geometry, pixel contributors, visits, and local events distinct within this document. Do not add a database or a parallel analysis pipeline.

**Fast local loop:** Run from the repository root:

```sh
swift run -c release canvas-tool check --fixtures tmp/canvas-next
```

This existing command generates missing synthetic clips and runs the native analyzer. Extend its fixture set and checks in place. Use `--only` with actual fixture names for focused work. Use `--regen` after changing fixture generation. No network, cloud, or new package is required.

`Check.run` currently supplies `truth.box` to the analyzer. Change automatic fixtures to pass `nil`; retain a separate expected moving rectangle in their truth. Otherwise the test supplies the region the algorithm must discover. Keep the frame barcode outside the expected document region and test against it only for source seeking.

**Dependency proof:** Known pixels and motion → real AVFoundation decode and Core Graphics composition through `canvas-tool` → native AVPlayer/SwiftUI interaction → personal recording. Generated clips test geometry but cannot prove real app operation. `AVAssetImageGenerator` checks do not prove AVPlayer seeks. Use both. No new platform API or alternative engine is required for the first step.

**Transition:** Change analyzer, decoder, and reader together when the document shape changes. Increment `CanvasDocument.currentVersion` and offer Rebuild for old derived files. Do not support two schema versions. Keep recording.mp4 and session notes unchanged. Use disposable session copies for analysis and marks. Keep full-video review available throughout.

**Real canary:** From Milestone 6 on, also analyze a disposable copy of `~/Movies/ContextRecorder/2026-10-13_00-57-10` (97 s, 1512×982, maximized Chrome on explorEDA docs: menu bar, tab and bookmarks bars, Dock, left nav, right “On this page” rail, sticky header, slow scrolls, returns to `/docs`). Copy it under `tmp/canary/` and run `canvas-tool analyze` with no `--box`. Inspect the column images by eye each milestone. Reduce any failure it exposes into a fixture. It lacks a deliberate overlay and small edit; record a short disposable clip for those before closing Milestone 7.

**Output convention:** Save fixture logs and UI screenshots under `tmp/`. Do not commit generated evidence. Do not use `scripts/build-app.sh` for proof: it installs and launches the normal app.

## Stage 1 — reconstruction in the existing layout

## Milestone 6: A whole-screen page reconstructs automatically

The first visible result is one readable scrolling page despite a detailed stationary sidebar and header.

- In `Sources/CanvasTool/Fixtures.swift`, add a full-screen case modeled on the canary: macOS menu bar, browser chrome, Dock, a detailed left sidebar, and a right rail around the scrolling document. Add a narrow-document variant. Keep existing clean, repeated, blank, jump, and cursor controls. Record expected moving bounds and observed document extent separately from analyzer input.
- In `Geometry.swift` and `Check.swift`, require a reconstructed column and positive registered coverage on scroll fixtures. Compute coverage as correctly placed unique document area divided by observed document area. Count observed but omitted content as loss. Exclude screen chrome and genuinely unobserved gaps. Explicit `--storyboard` skips reconstruction requirements only; refusal and change-preservation checks must still run where applicable.
- In `Join.swift`, test a bounded set of region candidates independently of the global zero-shift winner. Include the tracked region and plausible moving bands. Use distributed image support to reject repeated or blank candidates. A candidate must pass verification before it sets the tracked bounds.
- Return selected bounds and rejection reasons in a small diagnostic record. Emit through the existing CLI/debug path; do not build a diagnostics dashboard.
- Check `Run.cols`, `CanvasAnalyzer.compose`, `CanvasItem.sourceX`, and source-region mapping together. A detected pane must produce the correct image and source coordinates.
- In `CanvasModel.swift`, `SessionView.swift`, and the empty state in `CanvasStage.swift`, make ordinary Build and Rebuild analyze the whole frame without opening the picker. Keep explicit crop commands secondary. Rebuild must not silently reuse an earlier crop.

**Proof:** Run the CLI suite. The automatic sidebar/header and narrow-document cases each produce one readable column. Use at least 90% correctly registered observed document area as an initial engineering gate. Preserve the existing 2 px p95 and 4 px maximum placement limits. Require zero false joins and correct source-region mapping. Do not weaken thresholds to hide a failure. The canary builds without a crop and its scrolled docs pages read as columns between both sidebars.

### Desired end state

Build Canvas needs no crop gesture. Full-screen fixtures prove automatic region discovery through native composition. Existing cards and source playback still work. If detection only succeeds with supplied bounds, this milestone remains incomplete.

## Milestone 7: Slow scrolling and interruptions preserve content

The page remains continuous without losing edits or temporary UI. Changes appear locally before the layout changes.

- Extend `Fixtures.FrameSpec` and rendering to express fractional scroll, a changing header badge, a brief overlay, and a persistent small edit. Existing integer `scrollY` truth is insufficient for half-pixel tests. Add fractional truth and rasterize deliberately. Include an edit during scrolling and cursor/caret negative controls.
- In `Segmenter.feed`, keep a reliable geometry anchor and a bounded uncertain interval. Retry against that anchor before closing a run. Size the bound in elapsed video time; calibrate on the directed cases. Do not bridge navigation, unsupported overlap, or persistent incompatible content.
- Separate event inspection from geometry anchors. Inspect intervening frames for changes even when insufficient motion has accumulated for a reliable integer estimate. Start with this smaller intervention before floating-point image composition.
- In `Join.swift`, return alignment support and localized residual changes separately. In `Storyboard.swift` and segmentation, use component persistence to distinguish settled edits from brief cursor noise. Merely reducing `ignorePixels` is insufficient.
- Extend `CanvasDocument` and `CanvasAnalyzer` with local event records: kind, source frame/time, relevant page rectangle, and before/after references for persistent edits. Retain temporary uncertain observations without forcing new page images. Preserve existing pixel ownership instead of silently overwriting earlier states.
- In `CanvasStage.swift`, show small overlay markers and local before/after controls. Markers open source video through `showSource`; ordinary content clicks retain current behavior.
- Update old edit fixtures to require retained before/after states. Their current `mustStartAt` and cross-page restrictions assume every edit requires another item. Replace only those assumptions; retain checks that incompatible state pixels never merge silently.

**Proof:** Slow scroll and a recovered overlay remain one geometric surface. Overlay playback and the persistent edit remain discoverable. Before/after regions match known fixture pixels and source times. Cursor/caret controls do not create persistent edit events. True jumps and periodic ambiguity still refuse alignment. Run source seek and coverage checks after recovery, not only pair estimates.

### Desired end state

The existing canvas shows continuous scrolling with local changes and overlay markers. Native output preserves observations that geometry estimation excluded. A lower card count with lost edits fails.

### Stage 1 gate

Rebuild the canary and the overlay/edit clip in the native app and hand them to Byron. His use of Stage 1 on real recordings, plus a short design pass for the ribbon and page layout, decides whether and how Stage 2 starts. Record the decision in the initiative map.

## Stage 2 — stable pages and visits (gated)

## Milestone 8: Stable pages and a visit ribbon recover the right moment

Replace the chronological run layout with pages that stay in place while visits carry time.

- Extend `CanvasDocument` with page/state identity, visits, and a compact frame/pose observation log. Keep patch contributors as the source of exported pixels. Record observed bounds and source frames even when no new pixels were added.
- In `Segmenter` and `CanvasAnalyzer`, treat runs as temporary analysis objects. Reuse a page on a return only after image-supported identity and alignment. Group uncertain continuations with explicit gaps; grouping must not assign invented coordinates. Keep incompatible states separate.
- Start return matching with a bounded comparison against existing page content. Do not use URL equality as proof. Local edits use their before/after marker; substantial incompatible content becomes another state or fragment.
- In `CanvasStage.swift`, replace `CanvasStrip` chronology with stable page positions and a compact chronological visit ribbon. Selecting a visit changes active context and highlights its page. It must not rearrange pages. Show the recorded viewport outline where its pose is verified.
- In `SessionModel.swift` and `CanvasModel.swift`, own active visit selection. Resolve hover, narration, content clicks, M, and source-frame region marks through that visit. Use a frame in that visit that actually shows the selected point. If the active visit never shows it, offer another recorded visit explicitly; do not silently use a contributor time.
- Preserve PNG copy/export as an observed composite. Preserve region marks as single-source-frame captures. A visit-aware mark must use the selected frame and its actual rectangle. Do not add arbitrary composite selection.
- Route `canvasItem(at:)` and timeline selection through visits. Add a single shared resolver for point/visit → frame/rectangle so mouse, accessibility actions, and marks agree.

**Proof:** Add A → B → A, down/up reversal, local edit/return, and similar-but-unrelated-page cases. The first A retains its position, both A visits remain selectable, and narration differs correctly. Test a point visible in both visits and one absent from the active visit. Verify actual source frames, pixel-state consistency, and explicit uncertain gaps after document reload.

### Desired end state

Stable pages and the visit ribbon work together. Content clicks switch to full video in the active visit. Exported pixel contributors remain distinct from visit history. Keyboard and accessibility actions use the same source resolver as mouse input.

## Milestone 9: The stable-page flow works on a personal recording

Prove the target experience through the native app, beyond synthetic geometry.

- Use generated sessions for repeatable UI checks. Two existing personal sessions are available as read-only inputs at `~/Movies/ContextRecorder/2026-10-13_00-57-10` and `2026-10-13_20-48-53`. Their suitability for this scenario is unverified. Inspect disposable copies, not the originals.
- Use `scripts/ui-test/harness.py prepare` and `launch` as documented in `scripts/ui-test/README.md`. Extend the isolated harness only as needed to open generated canvas fixtures. It must not launch against the real library.
- Complete one whole-screen narrated web walkthrough under five minutes: sidebar/header, slow scroll, overlay, small edit, return visit, and genuine jump. If existing footage lacks this sequence, record a disposable target clip before declaring completion. Synthetic clips alone do not close this milestone.
- Verify Build without crop, progress/cancel, stable positions, visit switching, narration, local comparison, overlay playback, source clicks, mark/crop, PNG export, reload, and stale-data Rebuild. Check the existing cut-session time mapping for visit seeks; do not bypass `SessionModel.seek` or add a second clock.
- Use real pointer input and keyboard/accessibility interaction. Save screenshots of the stable layout, changes, and uncertainty gap. Check at the harness’s supported 980-point width and at a normal desktop width.
- Record analysis duration, peak memory, image size, and interaction responsiveness on the target clip. Compare with the previous analyzer on the same disposable input. Investigate an obvious resource regression before adding tiling or new caches.

**Proof:** The complete scenario passes without manual crop correction, false joins, lost edits, or wrong-visit seeks. Record native observations separately from automated results. Byron’s review decides whether the experience earns continued use. If the real recording fails, reduce it to a failing fixture and repair the relevant earlier milestone; do not declare success from synthetic results.

### Desired end state

A representative personal recording meets the combined shape. Logs, screenshots, fixture results, and remaining limits are recorded in the initiative map. No production install or deployment is needed to prove completion.

## Open decisions and spikes

1. **Region discovery:** Decide whether bounded region candidates handle the changing-header fixture and the canary’s two-sided layout. Add a coarse temporal mask only if residuals show it is needed. A supplied crop remains a diagnostic comparison.
2. **Fractional motion:** Decide whether accumulated-motion anchors satisfy slow scrolling. If not, add floating-point poses and bounded two-dimensional verification in the existing engine. Correct `VisionEstimator` column cropping before any renewed comparison; no engine replacement without measured benefit.
3. **Return identity:** Calibrate visual support on A → B → A and similar-page negatives. If uncertain, retain related fragments with a gap. Do not certify a return to satisfy the ribbon.

## Below the cut line

- Composite region capture, inline video, and embedded motion playback.
- Browser telemetry, OCR, general video reconstruction, and a second maintained engine.
- Several independently scrolling panes reconstructed at once, and nested scrolling panes inside web apps.
- Windowed browsers that move or resize mid-recording, and non-browser apps.
- Long-session tiling, elaborate zoom modes, cloud services, and database storage.
- Compatibility with old derived canvas schemas; offer Rebuild instead.
