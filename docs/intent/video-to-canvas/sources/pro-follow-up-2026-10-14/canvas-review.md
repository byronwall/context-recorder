# Canvas implementation review: recover the page, not just the next card

**Repository:** `byronwall/context-recorder`  
**Reviewed main:** `76afc4faa24887408c275360132f0dd03384c94b`  
**Review date:** October 14, 2026, America/Indiana/Indianapolis  
**Decision:** Keep the native architecture. Improve region discovery, continuity, and change modeling before broadening the visual effects.

## Executive assessment

The reported experience fits the implementation: a little scrolling joins, a difficult frame arrives, and the system starts another item. This is not primarily a shortage of sampled frames. `CanvasAnalyzer.build` consumes every frame returned by `FrameSource.next`; the decoded frames go through a half-resolution change gate, a predominantly global integer-y motion estimate, a strict overlap check, and a segmenter that immediately ends the current run on a rejection. [R1–R5]

The deepest design problem is that **a registration failure, a content change, and a new place on the canvas are too tightly coupled**. They should be different decisions. A region can remain the same page even when its geometry is temporarily uncertain. A page can scroll successfully while one price, tooltip, or animation changes. Conversely, a visually plausible displacement does not establish that two page states are identical.

The existing foundation is worth keeping: offline analysis, source frame references, row ownership, cropped source pixels, reusable `CanvasKit`, a command-line fixture harness, and native review integration. No stack rewrite, cloud model, OCR pipeline, or generative reconstruction is warranted by this review. Python/OpenCV in this package are diagnostic tools, not a proposed replacement application stack. [R1, R6–R9]

This review uses the current implementation, not the old research baseline `0166848…`, which did not contain the canvas. Unpushed local changes and the exact recording behind the user's report were not available. No private recordings were fetched.

## What actually runs now

```text
FrameSource.next(): decode each source frame
    ↓
Segmenter.feed(): half-size changed-pixel gate
    ↓
RowProfileEstimator: one integer vertical displacement
    ↓
Joiner: detect fixed bands; possibly narrow columns
    • narrowing only starts after a nonzero full-width estimate
    • verify overlap, ambiguity, and detail
    ↓
same / shift / change / noOverlap / ambiguous
    ↓
anything other than same or shift ends the current Run
    ↓
Run becomes one card or column; CanvasStrip puts every item to the right
```

`CanvasStage` is not independently deciding to create more cards. It renders the analyzer's `CanvasDocument.items`. Its non-lazy horizontal arrangement then makes fragmentation particularly prominent. [R2–R5, R7]

## Executed evidence

Four upstream Swift files were copied from connected GitHub responses and checked against their Git blob hashes: `ShiftEstimator.swift`, `Join.swift`, `Segmenter.swift`, and `Storyboard.swift`. All four match exactly. For execution on Linux, preparation removes unavailable imports and excludes the Vision implementation; `DecodedFrame` and image operations are replaced by raw-array/metadata stubs. The row-profile estimator, join verifier, change gate, run patch planning, and segmentation logic themselves run from the verified source. [Local: `results/source-verification.json`, `experiments/prepare_swift.py`]

**Executed:** 34 synthetic frame-pair cases; 10 synthetic sequences containing 380 frames, including two FFmpeg H.264 encode/decode round trips; one 20-frame geometry-anchor ablation; tile phase-correlation and sparse optical-flow candidate probes. The scenes use generated text and deliberately difficult fixed regions. Three seeds test repeatability of selected mechanisms, not a representative accuracy distribution.

| Diagnostic case | Current Swift result | Tested counterfactual or alternative |
|---|---|---|
| Clean integer scrolling, 45 frames | 1 column | Positive control; H.264 version also produced 1 column. |
| Detailed fixed sidebar, 45 frames | 0 columns, 2 cards | Cropping to the known moving pane produced 1 column. |
| Sidebar pairs, three seeds | Global estimate 0; classified `change` in all three | Supplying the known scrolling columns recovered the correct 8-pixel join in all three. |
| Changing badge in a fixed header | No accepted scroll join in all three seeds | Excluding the known 56-pixel header recovered 8-pixel joins in all three. |
| Narrow central scrolling pane | Global estimate 0 in all three seeds | Known-pane crops/column ranges recovered 8-pixel joins; local candidate probes also detected the moving minority. |
| One transient overlay during 45-frame scroll | 2 columns | A known-transient skip produced 1 column; the original joiner verified the 16-pixel bridge across that frame. The same fragmentation appeared after H.264 encoding. |
| 40 frames moving 0.5 pixel per frame | 12 columns and 1 card | Using every second frame as a geometry anchor, preserving their original timestamps, produced 1 column. This is not permission to discard intervening events. |
| Persistent 20×20-pixel edit | `same`; held-edit sequence kept only the original card | Reducing `ignorePixels` from 600 to 80 detected the pair as `change`. Pointer false positives under that setting were not evaluated. |
| Small edit while scrolling | Accepted as a pure 8-pixel shift | Demonstrates why geometric success cannot mean “no content changed.” |
| 2-pixel horizontal drift plus 8-pixel vertical scroll | No accepted join in all three seeds | Local 2-D candidates recovered approximately `(dx=2, scrollY=8)`. These are candidates, not end-to-end safe stitches. |
| Return over already-seen rows | One column; patch contributors were frames 0, 1, 2, although the run reached frame 4 | Later observations need a separate visit/pose record; pixel-contributor provenance is not visit history. |

Raw values, settings ablations, candidate lists, and sequence patch plans are in `results/`. All 23 reproduction assertions passed. **That means the documented failures and counterfactuals were reproduced, not that the product passed an acceptance benchmark.**

Important negative evidence: the tile candidate probe confidently proposed a shift on exactly periodic rows. Sparse flow proposed spurious motion across unrelated generated pages. The native ambiguity guard correctly refused the periodic pair. Neither phase correlation nor optical flow should replace validation with a single confidence number. [Local: `results/prototype-results.json`, `results/reproduction-checks.json`]

### Not executed

The full macOS package build, AVFoundation decoder, Apple Vision estimator, Core Graphics color compositor, AVPlayer seeks, SwiftUI behavior, real recording evaluation, production performance, and an integrated replacement pipeline remain unrun. The H.264 tests used FFmpeg at 640×360, 15 fps, requested 4 Mbps; they are not equivalent to a complete ScreenCaptureKit-to-AVPlayer evaluation. The HTML concept is not the native application; its interactive behavior is not a user-tested result.

## Ten ranked improvements

### VCI-01 — Discover the moving region before letting the background vote “no scroll”

**Problem.** `Joiner.join` first estimates over `known ?? full`. It calls `scrollingColumns` only when `est.shift != 0`. A detailed stationary sidebar can make zero the best full-width hypothesis; the code then never attempts to find the scrolling content. The discovery pass also requires the candidate to occupy at least one third of the width. [R3, lines 45–73]

**Change.** Evaluate a small set of region hypotheses independently: current tracked region, central pane, left/right content candidates, and the user's selected crop. Keep stationary and moving hypotheses simultaneously. Select a moving region only when its own image evidence is good; do not require scrolling to win over the whole frame. Start with one moving pane rather than an unrestricted multi-layer scene model.

The fastest practical relief is an explicit “exclude sidebar/header” correction and a short preview before rebuilding the whole session. The existing crop mechanism can seed the initial region. Do not count an oracle crop as automatic detection.

**Evidence.** Three sidebar and three nested-pane pairs failed globally and joined correctly with known columns. A 45-frame sidebar sequence went from two cards to one column after cropping. The local candidate probe found both zero-motion background and moving central content.

**Cost/confidence.** Small-to-medium native change; high confidence in the defect, medium confidence in automatic region selection. Validate thin panes, two independently scrolling panes, and a changing sidebar before claiming broad coverage.

### VCI-02 — Replace immediate run termination with bounded recovery

**Problem.** One `change`, `noOverlap`, or `ambiguous` result ends the run in `Segmenter.feed`. There is no opportunity for a clean frame immediately afterward to rejoin the existing page. Tentative runs reduce some card noise but cannot reconnect a finished column. [R4, lines 95–152]

**Change.** Introduce `tracking → uncertain → reacquired/confirmed-break`. Keep a short ring of trusted geometry anchors and suspect observations. After a rejection, try the next few frames against the last reliable anchor. A provisional starting budget is 3–5 frames or roughly 0.2–0.35 seconds at 15 fps; calibrate it rather than hard-code it as truth. Real navigation, persistent incompatible content, or exhausted overlap should still commit a break.

Retain suspect frames as event evidence. A recoverable tooltip must not disappear just because it should not split the background page. Uncertain intervals may be visually grouped without being geometrically stitched.

**Evidence.** One transient frame split a clean run into two columns, before and after H.264 encoding. The existing joiner successfully verified the bridge across the known transient. The skip experiment used an oracle and is not an implemented general recovery detector.

**Cost/confidence.** Medium. Add explicit `tentativeSince`, `lastReliable`, and observation times. Do not blindly update `current.last` on every still frame: the present settling clock relies on its age. Test true cuts adjacent to tooltips and long occlusions.

### VCI-03 — Track fractional motion and tolerate small x displacement explicitly

**Problem.** `ShiftEstimate.shift` and `Run.y` are integers. Zero-shift verification takes a different path from nonzero-shift verification: `inPlace` does not get the neighbor-row interpolation allowance. Small raster-phase changes can alternate between a tolerated one-row shift and a content change. Horizontal displacement is not represented. [R2–R4]

**Change.** Separate the frame inspected for events from the geometry anchor. Estimate translation in floating-point `(dx, dy)`, accumulate poses in floating point, and quantize only at a defined rendering boundary. For an initial smaller fix, advance geometry anchors only when enough motion has accumulated for a stable alignment, while continuing to inspect every decoded frame for meaningful changes.

Allow a small bounded x translation as a distinct model; do not silently stretch, rotate, or apply a homography to UI text. Prefer a sharp, near-native raster-phase observation for each owned patch. Reset or recalibrate on zoom/window geometry changes.

**Evidence.** Half-pixel scrolling fragmented into 12 columns plus one card; integer-spaced geometry anchors produced one column. Sparse flow estimated approximately 0.5 pixel on the clean test pairs. Tiled phase correlation gave roughly 0.70–0.80 pixel on those same pairs: “subpixel capable” does not make every estimator equally accurate. Three 2-pixel-x examples failed the native verifier but yielded correct 2-D motion candidates.

**Cost/confidence.** Medium-to-large because transforms and source mapping must agree. High confidence in the reproduced weakness; source-resolution seams and native rendering remain untested.

### VCI-04 — Model fixed and dynamic UI over time, not as exact bands from one pair

**Problem.** `fixedBands` scans inward from the image edges until the first row that differs. A badge, pointer, loading indicator, or changed header row can invalidate a mostly fixed header. Blank document margins can also look stationary in one pair. `scrollingColumns` only trims edge strips and cannot express an interior overlay or arbitrary nested rectangle. [R3, lines 83–107 and `scrollingColumns`]

**Change.** Keep a coarse, time-smoothed map of stationary, scrolling, and independently changing regions. Compare each region under both zero motion and the candidate document motion. Require detail before declaring stationary structure; blank space is not evidence. Allow small dynamic islands inside a fixed header without throwing out the entire mask.

Use masks for matching, but preserve the actual header, tooltip, or sidebar in a context layer and source observations. Excluding something from geometric voting is not permission to erase it from the review.

**Evidence.** A small badge touching the top edge prevented joining in all three header stress cases. Manually excluding the known header restored all three. Automatic temporal masking itself has not been implemented or tested here.

**Cost/confidence.** Medium. Begin with the selected pane and a bounded header mask; avoid a full segmentation framework.

### VCI-05 — Return geometry and content differences separately

**Problem.** `JoinResult` forces a frame pair into `shift` or `change`. Residual above 0.8% can turn scrolling into a new card; residual below it can cause a real edit to be treated as unchanged. `Run.append` only adds newly exposed rows. An edit inside already-owned overlap can therefore be omitted from the composite. [R3, R4]

**Change.** Return an alignment observation containing the transform, supported region, residual components, and confidence reasons. Then make separate decisions:

- Newly exposed content extends the surface.
- Persistent changes inside observed coordinates create a successor state or localized version patch.
- Transient motion becomes a playable event associated with that region.
- Unverified geometry keeps an observation without asserting a stitch.

Do not overwrite the old pixels and call the result a single historical screenshot. A composite is an atlas of observations; changed versions and their time spans must remain selectable.

**Evidence.** The small edit during scrolling was accepted as an ordinary shift, while the stationary version of a small edit was ignored entirely. Raising a global residual threshold cannot distinguish edits from noise and cannot fix the zero-shift region-discovery failure.

**Cost/confidence.** Medium. A small `alignment + changes[]` result is enough initially; a general-purpose image editor is not required.

### VCI-06 — Stop using total changed area as a pointer detector

**Problem.** `ignorePixels = 600` treats all small in-place changes as unimportant. The half-resolution 60-pixel gate supplies another absolute-area cutoff. These are not equivalent thresholds, and neither knows whether the pixels belong to a cursor, a checkbox, a changed word, or an error badge. [R3, R5]

**Change.** Detect localized residual components and observe their persistence. A small region that remains changed after the settling interval deserves a state event. A moving pointer-shaped component can be masked when that classification is actually supported. Keep change sensitivity relative to the chosen region and record important small components rather than simply normalizing everything by frame area.

A lower pointer budget is a useful ablation, not the finished fix. Without a persistence/component model it can replace lost edits with a flood of cursor cards.

**Evidence.** A persistent 20×20 black patch replaced a white patch. The half-resolution gate saw enough change to invoke joining, yet `inPlace` returned `same`; a held sequence retained only the old card. `ignorePixels=80` changed the pair result to `change`.

**Cost/confidence.** Small-to-medium. Validate a one-digit edit, checkbox toggle, caret, moving pointer, selection highlight, compression noise, and a changed error badge at several crop sizes.

### VCI-07 — Keep multiple hypotheses and strengthen ambiguity verification

**Problem.** Sixteen row-band averages deliberately discard horizontal structure. The winner and runner-up are chosen from a limited refinement shortlist. Repeated text, blank areas, and a large dynamic patch can make the selected displacement wrong or ambiguous. The synthetic profile-collision example has unique 2-D pixels but identical row-bin means. [R2]

**Change.** Retain the row profile as a cheap proposal mechanism, then verify several candidates using 2-D structure, spatially distributed support, bidirectional agreement, and a temporal motion prior. Preserve alternative peaks instead of turning a correlation response into a probability of correctness. Use an anchor spanning more than one adjacent pair to detect drift and aliases.

Apple's translation APIs, phase correlation, and sparse flow are candidate generators. No new production dependency is required to first improve the existing native candidate bank. Apple Vision also needs a correctness fix before a fair comparison: `VisionEstimator.estimate(...cols:)` never uses `cols`; its helper crops rows only. It also discards x translation. That bug is source-verified, not executed on macOS. [R2; E1–E3]

**Evidence.** Local probes recovered the row-profile collision and the moving minority pane, but they also proposed motion on periodic content. Sparse flow produced plausible-looking outliers across unrelated pages. Keep refusal behavior when evidence is intrinsically ambiguous.

**Cost/confidence.** Medium. Test this behind an estimator interface and retain negative controls. Do not ship “always choose the strongest nonzero peak.”

### VCI-08 — Add optional browser geometry telemetry for future recordings

**Problem.** The current extension streams click/nav/console/error/request events, not a continuous scroll track. The analyzer does not consume a continuous browser geometry channel. The old mark snapshots must not be reinterpreted as one. [R1, R13]

**Change.** While recording, collect throttled document and nested-element scroll positions, viewport rectangles, document epoch, container identity, browser zoom/device scale, resize information, and a sequence number. A 10–15 Hz geometry channel plus end-of-scroll updates is a proposal to evaluate, not a measured requirement. Do not capture form values for this purpose.

Calibrate browser time to recording time and carry timing uncertainty; receipt time alone can be distorted by queued delivery. Map CSS pixels to the selected video viewport using a measured scale and origin. Do not multiply by DPR twice. Geometry should propose bounds and displacement; video pixels should still verify the visible content. Browser standards distinguish viewport, element, and visual-viewport scrolling. [E4]

**Benefit.** This can replace a difficult inference with a constrained measurement for product walkthroughs, especially nested panes. It cannot retroactively repair old recordings or establish identical content at the same URL.

**Cost/confidence.** Medium across extension and Swift capture. Entirely unrun here. Keep video-only operation for existing recordings, other apps, and lectures.

### VCI-09 — Separate surfaces, states, visits, and pixel ownership

**Problem.** A run is both an analysis segment and a display item. Patches record only contributing pixels, not every later time those pixels were visible. During a scroll reversal inside known bounds, `Run.last` advances without necessarily adding any patch. `frame(atImageY:)` then correctly returns the contributor but cannot answer “when was this discussed on the later visit?” [R4, R6]

**Change.** Keep pixel ownership as it is conceptually, and add a compact observation/pose log. Give related runs a stable surface identity, distinguish changed states, and derive visits from contiguous observations. Layout consumes that model rather than equating every temporary tracking break with a new full-size card.

A small next schema could add `surfaceId`, `stateId`, and observations with `frame`, `viewportTransform`, `visibleRegion`, and registration status. Derived cards, joins, and links remain rebuildable. Do not introduce a database or graph service.

**Evidence.** In the five-frame return sequence, frame 4 was the last view, but only frames 0, 1, and 2 contributed image patches. Both histories are valid and useful, but they are not interchangeable.

**Cost/confidence.** Medium. It unlocks the time lens, return navigation, state comparison, and accurate narration placement described below.

### VCI-10 — Make failures diagnosable and make all-card scrolling fail the proof

**Problem.** The native fixture harness has useful source-time and geometry checks, but `Geometry.check` returns early when no columns exist, adding only “storyboard only; joining not checked.” Fixtures such as clean scrolling primarily set an upper bound on the number of columns. A zero-column result can therefore avoid the geometry failure that should matter for that fixture. This is a static source finding; the native harness was not executed here. [R10–R12]

**Change.** Record a small diagnostic event per attempted join: frame pair, candidate region, best and alternate transforms, detail support, residual components, mask fractions, and the actual rejection reason. Add a reviewer overlay showing the chosen motion, crop, seam, and source frame. Keep “not verified” distinct from a demonstrated absence of overlap.

Extend the existing fixture harness rather than creating a benchmark platform. Require positive joined-content coverage for scroll fixtures, bounded fragmentation, low placement error, preservation of visible edits, and correct return/source mapping. A giant incorrect column must fail even when it reduces card count; an all-card result must fail clean-scroll reconstruction even when every card is truthful.

Provide only a few correction controls: change the tracked region, split here, declare a related but unaligned continuation, and retry the local interval. Never make a manual grouping action silently certify geometry.

**Cost/confidence.** Small-to-medium and a prerequisite for safely tuning the other changes. The corpus and probes in this package are ready for Codex to adapt into that harness.

## A different canvas: document atlas with a time lens

### 1. Make the document stable; move the recorded viewport over it

The default view should show one stable document surface, with a rectangle indicating what the user could see at the selected time. Scrubbing moves that rectangle and highlights associated narration. Clicking content should open an in-place source preview; a separate command can switch to the full video. Today `showSource` immediately changes the stage back to video, which interrupts spatial exploration. [R7, R8]

The time lens should distinguish “these pixels were contributed here” from “this region was visible again here.” Hover may show the contributor time, while an active-visit selector determines narration and playback. Expose both when they differ.

### 2. Branch states to the right, but show local changes first

Keep y as document geometry. Use rightward branches for changed states of the same surface, not every failed pair. A small edit initially appears as a margin callout with before/after crops at the same document coordinate. Expand it into a full state column only when useful. Selection highlights and ephemeral menus can be collapsed events rather than page-sized replacements.

Uncertain fragments can live inside the same labeled episode with a visible separation and “alignment unresolved.” This groups related material without pretending the fragments share an established coordinate system.

### 3. Keep chronology in a compact journey ribbon

A bottom ribbon gives every episode and visit a position in time, independent of page geometry. Return visits point back to the existing surface with numbered visit markers; only the active path needs a prominent arrow. This avoids a tangle of permanent return arrows across a long canvas.

Offer a chronological storyboard as a second view over the same evidence model. It is a useful fallback and comparison, not the only visualization forced by weak tracking.

### 4. Let motion be a small playable region, not a stack of entire screens

Attach a motion portal to the changing area: poster frame, source span, and play control. The surrounding page stays stable. Reuse one preview player rather than instantiate a player for every object. A loader, tooltip, chart animation, or video-in-page can remain inspectable without becoming ten full-page cards.

This depends on separating residual events from background registration. It is a proposal, not something the candidate probes implement.

### 5. Add semantic zoom, folded long sections, and bounded loading

At overview scale, show page silhouettes, episode labels, and change/visit counts. At reading scale, show text and the selected narration rail. At inspection scale, expose seams, residual masks, and source pixels. Allow long uninteresting sections to fold, but mark the fold explicitly rather than changing document coordinates invisibly.

The current view creates an `NSImage` entry for every item and uses a regular `HStack`; composition allocates one full-height bitmap. Actual decode residency and performance were not profiled. For longer sessions, use visible-range loading and bounded tiles/cache rather than assuming the 16,000-row run limit is a complete memory strategy. A 1920×16000×4-byte bitmap is about 117 MiB before temporary copies; this is arithmetic, not a measured app footprint. [R1, R7]

### 6. Make source capture and composite capture separate commands

The current canvas region mark intentionally clips to the one frame supplying the selection's middle. Full-item PNG export exists, but a selected multi-frame region is not preserved by that mark operation. [R6–R8]

Offer **Capture source frame** and **Capture canvas composite** separately. Composite capture exports the selected visible state/regions with a sidecar of contributing frame times and source rectangles. Label multi-time composites, keep unknown areas marked, and do not silently crop a tall selection to one viewport. This directly serves the original larger-than-one-frame intent.

## Suggested implementation order

First, add the small regression fixtures and reason logging from VCI-10. Then address region discovery and a bounded recovery buffer (VCI-01/02), with the persistent-edit regression protected from the beginning (VCI-06). Next tackle fractional geometry and temporal masking (VCI-03/04) and separate residual state events (VCI-05/07). Introduce the observation/visit model and time-lens view once the geometric output is stable enough to inspect (VCI-09). Browser telemetry is an optional acceleration path, not a prerequisite for repairing video-only behavior (VCI-08).

The next convincing demonstration is not “more cards.” It is one narrated page that stays one navigable surface through a sidebar, a slow scroll, and a transient overlay, while a small edit is explicitly retained. A real no-overlap jump must still remain unstitched.

See `codex-next-steps.md` for file-level scope and checks, `canvas-improvements.json` for structured recommendations, and `sources.md` for the source ledger. `canvas-concepts.html` illustrates the spatial/time interaction using synthetic evidence; it is not an implemented native feature.
