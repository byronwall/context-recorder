# Codex handoff: improve reconstruction before adding more cards

Baseline reviewed: `76afc4faa24887408c275360132f0dd03384c94b`. Reconcile later local changes before applying these recommendations. This package is analysis and diagnostics, not a patch to the repository.

## First scoped change: expose and repair continuity

Start with VCI-10 diagnostics and regression fixtures; implement VCI-01 region hypotheses and VCI-02 bounded recovery. Protect VCI-06 small persistent edits while tuning. Do not combine all ten recommendations into one large rewrite.

| File / symbol | Intended scope |
|---|---|
| `Sources/CanvasKit/Join.swift` / `Joiner.join` | Try independent region hypotheses even when the global winner is zero. Emit structured alignment/rejection diagnostics. Keep a verified moving-region result distinct from unaligned grouping. |
| `Sources/CanvasKit/ShiftEstimator.swift` | Preserve a candidate bank, including zero and alternative translations. Fix `VisionEstimator` column cropping before any renewed bakeoff. Do not interpret a single response as certainty. |
| `Sources/CanvasKit/Segmenter.swift` / `feed` | Add a bounded uncertain interval and reliable-anchor retry. Separate settling clock from geometry anchor. Keep transient observations even when geometry is recovered. |
| `Sources/CanvasKit/Join.swift` / `inPlace` and `Storyboard.swift` | Replace area-only ignore behavior with component persistence. Keep the existing pointer controls as explicit negative tests. |
| `Sources/CanvasTool/Fixtures.swift`, `Check.swift`, `Geometry.swift` | Add positive reconstruction coverage, fragmentation, and lost-edit checks; distinguish intentional `--storyboard` from unexpected all-card output. |

A minimal native result contract could contain `candidateTransform`, `verifiedRegion`, `residualComponents`, and `rejectionReason`. Keep dimensions and units explicit. This is a proposed contract, not source that compiles as supplied.

### Acceptance gates for the first change

These are proposed gates, not measured product results:

1. Clean continuous integer scrolling must reconstruct a column, not merely avoid a false stitch. Target at least 90% of ground-truth novel document area in correctly registered output on the directed corpus, with no more than one unexplained break per continuous short scroll. Exclude unobserved gaps from the denominator; count observed-but-lost content as failure.
2. On accepted geometry, target 95th-percentile displacement error at most 2 source pixels and no placement error over 4 pixels on these controlled fixtures. Preserve repeated-row/no-overlap refusals; fewer cards never compensates for a false join.
3. A visible persistent one-digit/checkbox/20×20 edit must remain discoverable. An overlay that is not stitched must remain available as an event or source observation. Cursor-only controls must not explode into cards.
4. Every owned patch and every visit must map to the correct source region/time. Native source seeks and selected composite export need their own checks; Linux metadata probes do not certify them.

Use the existing clean, reversal, header, jump, repeated, blank, cursor, and edit fixtures plus only a few new cases: detailed stationary sidebar, narrow nested pane, changed header badge, 0.5-pixel motion, 2-pixel x drift, and one transient overlay. Add three consented disposable real recordings before claiming everyday improvement: product page, nested application pane, and code/slide walkthrough. Those recordings are not part of this package.

## Second scoped change: improve geometry and preserve state

VCI-03/04/05/07: floating-point poses or stable geometry anchors, temporal fixed/dynamic masks, separate aligned content changes, and 2-D candidate verification. Keep source observations at every inspected frame even when geometry anchors are less frequent. Integer raster output must not be confused with integer accumulated motion. Preserve old pixels and state transitions; do not update an already-owned region silently.

Test both fractional raster phase and true content changes. Probe crop-size sensitivity and small x motion. Do not jump to arbitrary homographies, machine-learning scene segmentation, or OCR to compensate for the current region/continuity bugs.

## Third scoped change: make the canvas an atlas, not a run log

VCI-09: add a compact observation/pose log plus stable surface and state identities. `Run` can remain a temporary analysis object. `CanvasDocument` should retain source ownership separately from visits.

`CanvasStage` should default to a stable document view with a moving recorded-viewport rectangle, an inline source preview, and a chronological visit ribbon. `showSource` can keep its explicit full-video command, but ordinary exploration should not require leaving the canvas. Use state branches for meaningful changes, not every low-confidence frame. Show unaligned continuations with visible gaps.

Keep two selection actions: the existing single-source-frame mark and a new observed-canvas-composite export with source provenance. Do not silently change what a review mark means.

## Optional future capture aid

VCI-08 geometry telemetry should follow a demonstrated browser-only benefit. It needs nested-container identity, document epoch, fractional CSS offsets, viewport calibration, clock uncertainty, and resize/zoom handling. It must not make existing video-only recordings unusable.

## Reproduction run sheet

The first block runs this package's Linux diagnostics using already installed tools. It overwrites only generated experiment files/results inside this package. No dependency installation is performed. Fixture pixels depend on the recorded font/environment; the exact inputs used here are included for direct inspection.

```bash
# From the extracted canvas-review package. Requires Swift, Python, NumPy, Pillow,
# OpenCV, and FFmpeg already installed. The recorded environment is in results/.
cd /path/to/canvas-review/experiments
./run.sh
```

The following is a separate macOS run sheet using actual repository CLI options. These native commands were not executed in this review. The fixture command writes disposable files, and analyze replaces derived canvas output in the specified session copy. Do not point it at the only copy of a valuable session.

```bash
# Run from the repository on macOS 26 with the supported toolchain.
# Use a new disposable fixture directory; do not run build-app.sh for this review.
FIXTURES="$(mktemp -d "${TMPDIR:-/tmp}/canvas-review-fixtures.XXXXXX")"
swift run canvas-tool check --fixtures "$FIXTURES" --regen
swift run canvas-tool bakeoff --fixtures "$FIXTURES"

# Optional cards-only comparison. Copy first because each check writes canvas output.
STORYBOARD="${FIXTURES}-storyboard"
cp -R "$FIXTURES" "$STORYBOARD"
swift run canvas-tool check --fixtures "$STORYBOARD" --storyboard

# Optional diagnostic analysis of an already-disposable session copy.
# Replace the path and region with actual selected video-pixel bounds.
SESSION_COPY="/absolute/path/to/disposable-session-copy"
CANVAS_DEBUG=1 swift run canvas-tool analyze "$SESSION_COPY" --box 100,80,1000,600
```

## Explicitly unrun

Full macOS build; AVFoundation decoding; Vision estimates; Core Graphics composition; AVPlayer source seeks; SwiftUI interactions; user recordings; production performance; automatic temporal masks; automatic recovery; telemetry; observation/state schema; native composite export. No commit, push, or PR was created.
