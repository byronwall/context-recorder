Hi, **the canvas concept is sound, but the current implementation couples “could not align this frame” too closely to “start a new place on the canvas.”** Several concrete failures in the code reproduce the fragmentation you described.

The most useful next step is **not increasing frame sampling or replacing the whole matcher**. The analyzer already processes every decoded frame. The biggest improvements are finding the correct scrolling region, recovering across temporary failures, and separating geometric motion from content changes.  

**canvas-review\.zip[Download the complete review, experiments, results, and interaction concept — ZIP, 6.2 MB](sandbox:/mnt/data/canvas-review.zip)**

## What was reviewed and tested

This review targets current `main` at **`76afc4faa24887408c275360132f0dd03384c94b`**, not the earlier research baseline. The current implementation includes native `CanvasKit`, a `canvas-tool` command-line harness, and SwiftUI canvas integration.  

Four algorithm source files were copied exactly and verified against their Git blob hashes. Their **actual Swift matching, verification, and segmentation logic** ran using Linux-compatible raw-image and image-metadata substitutes—not a Python rewrite of the algorithm.

The experiments covered **34 synthetic frame pairs, 10 sequences totaling 380 frames, and a separate 20-frame anchor experiment**. Two sequences also went through FFmpeg H.264 encoding and decoding.

| Synthetic case | Current implementation | Tested intervention |
|---|---|---|
| Clean scrolling, 45 frames | **1 column** | Positive control; compressed version also produced one column. |
| Detailed stationary sidebar, 45 frames | **2 cards, no columns** | Cropping to the known moving pane produced **1 column**. |
| One transient overlay during scrolling | **2 columns** | Skipping the known transient and verifying the bridge produced **1 column**. The fragmentation also occurred after H.264 encoding. |
| Slow scrolling at 0.5 pixel per frame | **12 columns and 1 card** | Using every second frame as a geometry anchor produced **1 column**. |
| Persistent 20×20-pixel edit | Classified as **“same”**; the held sequence retained only the original card | Lowering the ignore threshold detected the edit, but cursor false positives under that setting remain untested. |
| Small edit while scrolling | Accepted as an ordinary scroll | Demonstrates that successful alignment does not establish unchanged content. |
| Two pixels of horizontal movement alongside scrolling | Join rejected in all three tested seeds | Local two-dimensional motion probes recovered the intended displacement. |

These are **controlled reproductions, not a real-recording accuracy benchmark**. Known crops and the known-transient skip are diagnostic interventions, not finished automatic fixes. The macOS app, Apple decoder, Vision estimator, Core Graphics compositor, AVPlayer seeks, and SwiftUI interactions remain unrun.

The reproduction-checks.json[machine-readable reproduction results](sandbox:/mnt/data/canvas-review/results/reproduction-checks.json) explicitly distinguish those limits.

## Why it finds a little stitching, then falls apart

The pipeline currently does approximately this:

```text
Decode every frame
    → detect enough changed pixels
    → estimate one integer vertical shift
    → verify overlap
    → same / shift / change / noOverlap / ambiguous
    → anything except same or shift ends the current run
    → display the resulting runs side by side
```

That last transition is the central problem. A briefly obscured page, a difficult subpixel position, or a changing header can end a valid scrolling surface. The viewer then faithfully displays the resulting fragments; it is not independently inventing those cards.  

The existing foundation is worth keeping: source-frame references, pixel ownership, offline analysis, native integration, and the CLI harness. The recommendations below improve that foundation rather than replacing the stack.

## Ten ranked improvements

### 1. Find the scrolling pane before letting the stationary background win — VCI-01

**This is the most direct scrolling-detection defect.**

In `Joiner.join`, the first estimate uses the full width unless a scrolling region is already known. Sidebar detection is then gated on that estimate being nonzero:

```swift
if known == nil, est.shift != 0 {
    let moving = scrollingColumns(...)
    // Re-estimate inside the moving region.
}
```

A detailed stationary sidebar can make zero the winning global estimate. Consequently, the code never attempts the region discovery that would have rescued the scroll. There is also a one-third-width requirement during that discovery path, which excludes some narrow panes. 

**Change:** Evaluate a small set of independent region hypotheses: the existing tracked pane, central content, plausible left/right panes, and the user-selected crop. Keep stationary and moving hypotheses simultaneously. A moving pane should not have to win a whole-screen majority vote.

**Test evidence:** All three sidebar cases and all three narrow-pane cases recovered the correct shift when supplied the known moving region.

**Immediate practical relief:** Add an “exclude sidebar/header” adjustment with a short analysis preview. Automatic pane discovery can follow; the user should not need to rebuild an entire recording to discover that the selected box is unsuitable.

### 2. Recover across temporary failures instead of immediately ending the surface — VCI-02

`Segmenter.feed` closes the current run after a single rejected join. Tentative runs suppress some noise, but they cannot reconnect a column that has already ended. 

**Change:** Introduce a bounded tracking state:

```text
Tracking → Uncertain → Reacquired
                    → Confirmed break
```

Keep the last reliable geometry anchor and a small buffer of suspect observations. After a failure, attempt the next few frames against that anchor before committing a split.

A starting recovery budget of approximately **3–5 frames** is a proposal to calibrate, not an established threshold. Actual navigation, persistent incompatible content, or exhausted overlap should still break the surface.

**Test evidence:** One transient overlay split a clean scroll into two columns. The existing joiner could correctly verify the bridge across it.

**Important:** Preserve the overlay as an event or source observation. “Do not split the background page” must not become “discard what appeared.”

### 3. Handle fractional scrolling and small horizontal displacement explicitly — VCI-03

The motion estimate and accumulated run position are integers. Moreover, zero-shift verification and nonzero-shift verification use different tolerance behavior. This creates a fragile boundary when scaled screen content moves between raster rows. Horizontal motion is not represented.  

**Change:** Separate the **frame inspected for events** from the **frame used as a geometry anchor**.

Eventually, track floating-point `(dx, dy)` poses and accumulate them without rounding every step. A smaller initial intervention is to advance geometry anchors only when sufficient movement has accumulated, while still inspecting intervening frames for edits and overlays.

**Test evidence:** Forty half-pixel steps produced 12 columns and one card. Integer-spaced anchors produced one column. Two-pixel horizontal drift also defeated the existing vertical-only verifier.

This does **not** justify dropping every other frame globally. It justifies separating event sampling from geometric anchoring.

### 4. Learn fixed and dynamic regions over time — VCI-04

`fixedBands` scans inward from the top and bottom until it reaches a differing row. A small changing badge touching the top edge can therefore invalidate a mostly fixed header. The current column logic also trims edges rather than representing arbitrary interior overlays. 

**Change:** Maintain a coarse temporal map of regions that are:

- Stationary relative to the viewport.
- Moving with the document.
- Changing independently.

Compare regions under both zero motion and the proposed document motion. Allow small dynamic islands inside a fixed header. Do not treat blank space as strong evidence of either motion model.

**Test evidence:** The changing-header cases failed to join in all three seeds. Excluding the known header restored every join. Automatic temporal masking remains untested.

Masking something out of geometric estimation should not remove it from review. Keep fixed chrome and transient overlays available through source observations or separate context layers.

### 5. Separate “aligned” from “unchanged” — VCI-05

The current result type forces an important distinction into `shift` versus `change`. Above a residual threshold, a scroll may become a new item. Below it, a real edit can be accepted as ordinary scrolling. `Run.append` then only adds newly exposed rows, leaving changes inside existing overlap unrepresented.  

**Change:** Return geometry and changes separately:

```text
Alignment
  transform
  supported region
  confidence / rejection reasons
  residual change regions
```

Then decide whether to extend the surface, create a changed state, attach a motion event, or preserve an unregistered observation.

**Test evidence:** A small edit while scrolling was accepted as a pure shift. The affected overlap would not become a new owned patch under the current append logic.

This is why simply relaxing the residual threshold is not a complete fix: it can reduce fragmentation while increasing lost changes.

### 6. Stop treating small changed area as proof of a pointer — VCI-06

`ignorePixels = 600` does not know whether those pixels represent a cursor, checkbox, changed number, error badge, or edited word. The separate half-resolution gate introduces another absolute-area threshold.  

**Change:** Track localized change components and their persistence. A small region that remains changed after settling deserves an event or state update. Suppress pointer-like motion only when that classification has supporting evidence.

**Test evidence:** A persistent 400-pixel change was ignored. Reducing the threshold to 80 detected it.

That threshold reduction is only an experiment. Shipping it alone could replace missing edits with excessive cursor cards. The regression set needs both meaningful small edits and cursor/caret negative controls.

### 7. Keep several motion hypotheses and verify them in two dimensions — VCI-07

The row-profile estimator reduces each row to 16 band averages. That is inexpensive, but it discards horizontal structure. The winner and runner-up are also chosen from a limited refinement shortlist. 

**Change:** Keep row profiles as a proposal mechanism, then verify several candidates using two-dimensional structure, spatially distributed support, temporal consistency, and alternate-peak checks.

Phase correlation and pyramidal Lucas–Kanade flow provide useful candidate-generation APIs; neither should be treated as a complete truthful-stitching decision. [OpenCV Documentation](https://docs.opencv.org/4.x/d7/df3/group__imgproc__motion.html)

**Test evidence:** Local probes recovered moving panes and a constructed case that row averages could not distinguish. But they also exposed false-confidence risks: periodic rows produced confident-looking candidates, and sparse flow produced spurious motion across unrelated pages.

**Additional implementation bug:** `VisionEstimator.estimate(...cols:)` accepts `cols` but does not use it when cropping the inputs. It also discards horizontal translation. Fix that before treating a Vision comparison as a fair regional-estimator comparison. This finding is source-verified; Vision itself was not executed. 

### 8. Add optional browser geometry telemetry for future recordings — VCI-08

The current extension’s streamed event set does not include continuous scrolling. The analyzer cannot obtain a reliable scroll trajectory from the existing sparse mark snapshots.  

**Change:** For future browser recordings, capture throttled geometry events containing document identity, nested-container identity, fractional scroll position, viewport bounds, resize/zoom changes, and timing information.

Document scrolling, element scrolling, and visual-viewport changes are distinct coordinate cases; the instrumentation needs to preserve that distinction. [W3C](https://www.w3.org/TR/cssom-view/)

Use those measurements to constrain the visual problem, then verify the pixels. Do not infer content identity merely from a matching URL or scroll offset.

**Status:** Proposed, not tested here. This is a valuable acceleration path for product walkthroughs, but not a prerequisite for improving existing video-only recordings.

### 9. Separate surfaces, states, visits, and pixel contributors — VCI-09

The current model conflates an analysis run with a display item. Patches identify which frames supplied pixels, but not every later occasion those pixels were visible. When scrolling back over known content, `Run.last` advances without necessarily adding patches.  

**Change:** Retain pixel ownership, and add a compact observation/pose log:

| Concept | Meaning |
|---|---|
| Surface | The page or pane being explored. |
| State | A particular observed version of its content. |
| Visit | A contiguous occasion when that surface/state was shown. |
| Contributor | The source frame supplying a displayed pixel region. |

**Test evidence:** In the return sequence, the run reached frame 4, but image patches came only from frames 0, 1, and 2.

That is not incorrect provenance. It is insufficient history for “show what was being said when this appeared again.” This distinction unlocks the better canvas interactions below without requiring a database or a graph service.

### 10. Make useful reconstruction a test requirement, and expose rejection reasons — VCI-10

The current fixture harness checks several valuable properties, but `Geometry.check` returns early when no columns exist. Clean-scroll fixtures that primarily specify a maximum column count can therefore avoid the geometry failure that an all-card result should trigger. This is a source-level finding; the native suite was not executed here.  

**Change:** Require positive reconstruction coverage, not just absence of bad stitches. Measure fragmentation and lost edits alongside placement error.

Also record a small diagnostic entry for every attempted join: selected region, candidate shifts, alternate scores, mask coverage, residual components, and rejection reason.

The UI should distinguish **“alignment not verified”** from **“demonstrably no overlap.”**

Provide a few correction controls: adjust the tracked region, split here, group a related but unaligned continuation, and retry a local interval. A grouping correction must not silently certify geometry.

## A better way to show the canvas

The most promising default is **a stable document atlas with a moving recorded-viewport lens**, rather than a horizontal log of whatever runs the segmenter happened to emit.

The canvas-concepts.html[interactive concept](sandbox:/mnt/data/canvas-review/canvas-concepts.html) demonstrates the atlas/time relationship, a local-change view, and a failed-pair inspector using synthetic evidence. It is a self-contained HTML file, not an implemented native feature or a completed browser usability test.

### Keep the page stable; move time through it

Show the reconstructed page in document coordinates. As time changes, move a viewport rectangle over the page to indicate what was visible. Keep the corresponding source frame or video preview alongside it.

Today, clicking canvas content switches the stage back to video. That interrupts spatial exploration. An inline source preview would let the user inspect evidence without abandoning the canvas; an explicit command can still open full video.  

### Give different kinds of change different presentations

| Presentation | When it earns its space |
|---|---|
| **Tall document surface** | Verified scrolling through substantially stable content. |
| **Local change marker and before/after view** | A price, field, checkbox, paragraph, or code region changes. |
| **Rightward state branch** | A substantial new page state deserves comparison with the previous one. |
| **Motion portal** | An animation, menu interaction, or video needs playback rather than another static card. |
| **Grouped fragments with an explicit gap** | Content is related, but the geometry between observations is unverified. |

This preserves the spatial idea even when reconstruction is imperfect. Related fragments can belong together visually without pretending their coordinates are known.

### Add a chronological journey ribbon

Use a compact ribbon for “what happened next,” while the atlas answers “where was it?”

Returning to an earlier page should create another visit in the ribbon, not necessarily another page image. Selecting that visit should change narration and playback context. Show return arrows for the active path rather than drawing every connection simultaneously.

This avoids asking one horizontal layout to represent chronology, document identity, content versions, and geometric uncertainty all at once.

### Use semantic zoom and explicit folding

At overview scale, show surfaces, visit counts, and important changes. At reading scale, show page content. At inspection scale, expose seams, source ownership, and alignment diagnostics.

Long documents can fold sections with an explicit “collapsed content” indicator. Do not silently distort document geometry to make everything fit. A viewport-aware tile cache would also be preferable to treating every long image as equally active; production memory behavior still needs profiling.

### Make source-frame capture and composite capture separate actions

The current canvas region-mark command intentionally clips to one source frame. Full-item PNG export exists, but selecting an arbitrary multi-frame composite region is a different capability.  

Keep both meanings explicit:

**Capture source frame** preserves one recorded moment. **Capture observed composite** exports the selected atlas region with a provenance sidecar identifying contributing frames and times.

That distinction makes large composite capture useful without misrepresenting it as a single historical screenshot.

## Recommended implementation order

**First:** diagnostics and positive-coverage tests, independent region hypotheses, and bounded recovery. Protect small persistent edits while making those changes.

**Second:** fractional geometry, temporal masks, and separate content-change handling.

**Third:** the observation/visit model and atlas time lens. Browser telemetry remains optional.

The next convincing demonstration should be one narrated page that **stays one navigable surface through a sidebar, slow scrolling, and a transient overlay—while retaining a small edit and refusing a genuine no-overlap jump**. That is a better target than simply reducing card count.

## Downloadable findings

| Artifact | Contents |
|---|---|
| canvas-review\.md[Full implementation review](sandbox:/mnt/data/canvas-review/canvas-review.md) | Detailed diagnosis, ten recommendations, experiment interpretation, and presentation proposals. |
| canvas-improvements.json[Structured recommendations](sandbox:/mnt/data/canvas-review/canvas-improvements.json) | VCI-01–VCI-10 with source evidence, alternatives, costs, confidence, and validation status. |
| codex-next-steps.md[Codex implementation handoff](sandbox:/mnt/data/canvas-review/codex-next-steps.md) | File-level scope, proposed acceptance gates, and verified native CLI run sheets. |
| canvas-concepts.html[Interactive canvas concept](sandbox:/mnt/data/canvas-review/canvas-concepts.html) | Synthetic atlas/time lens, local changes, and failure inspection. |
| sources.md[Sources and evidence boundaries](sandbox:/mnt/data/canvas-review/sources.md) | Pinned repository inventory, primary documentation, and unresolved limits. |
| swift-core-results.json[Raw Swift experiment results](sandbox:/mnt/data/canvas-review/results/swift-core-results.json) | Pair decisions, ablations, sequence segmentation, and patch plans. |
| manifest.json[Package manifest](sandbox:/mnt/data/canvas-review/manifest.json) | File sizes and SHA-256 hashes. |

The ZIP includes the reproduction scripts, exact synthetic inputs, logs, and source-verified algorithm copies. No repository files were changed, and no commit or PR was created.

**The key shift is to make the canvas represent documents and their history—not the matcher’s sequence of successes and failures.**