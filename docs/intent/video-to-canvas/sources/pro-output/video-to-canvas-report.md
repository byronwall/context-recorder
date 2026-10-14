# Video to canvas: an observed spatial storyboard

**Decision: CONDITIONAL GO for a small offline proof. Not yet GO for a general reconstruction feature.**

Research date: **October 13, 2026**, America/Indiana/Indianapolis. Repository: `byronwall/context-recorder`. Baseline: `016684895df51872aeea1be5e93e28419fd63a7f`. The supplied local `docs/research/video-to-canvas/intent-brief.md` is part of the decision basis, not a file assumed to exist at that commit.

## Executive decision

The distinctive idea deserves a direct test: reconstruct the **observed portion of one scrolling viewport** into useful page geometry, then recover its source moments through interaction. Translation registration and existing scroll-capture implementations make this technically plausible. They do not establish that this repository's compressed recordings support sufficiently accurate, readable and truthful results. [E01](https://raw.githubusercontent.com/opencv/opencv/4.14.0/modules/imgproc/include/opencv2/imgproc.hpp) [E08](https://github.com/Brkgng/ScrollSnap) [E09](https://raw.githubusercontent.com/Brkgng/ScrollSnap/main/ScrollSnap/Managers/StitchingManager.swift)

The first proof should produce one tall, source-linked surface from a short narrated product walkthrough, put one edited state to its right, and refuse a deliberately ambiguous transition. Compare it with raw video and a change-selected keyframe storyboard. Do not start with a full editor, generic video reconstruction, browser replay, native canvas infrastructure or automatic semantic transcript grounding. **VC-01, VC-02, VC-09.**

The main risk is not merely a visible seam. A plausible-looking join can merge repeated text, overwrite a changed value, or suggest that pixels seen at different moments coexisted. A video cannot reveal changes that happened entirely offscreen. Therefore the artifact must say **“observed across these times”**, not “the page at this time.” That limit is intrinsic to the input, not something a higher confidence score repairs.

**GO now:** research/design and the bounded proof plan. **GO later:** a narrow local feature only after gates G1–G4 pass on actual recordings. **NO-GO now:** claims of general reconstruction accuracy, a shipped dependency choice validated on this Mac, or measured user benefit. All image-reconstruction, playback, corpus and usability experiments are **unrun**.

## Evidence and access

Labels used throughout: **R** = repository fact; **E** = external primary-source evidence; **I** = inference; **P** = proposal; **U** = unrun experiment. Numeric thresholds and performance estimates below are proposals or arithmetic, never measured reconstruction results. Bracketed R/E references resolve to direct sources at the end; the sources artifact records access limits.

Connected GitHub successfully returned `Package.swift` at the exact commit. A recursive Git tree at that commit returned `truncated:false`. It confirms the selected paths and shows no `package.json`, test suite, test target directory or sample recording. The package itself declares one macOS 26 executable target. No later default-branch content was used. [R02](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Package.swift) [RTREE](https://api.github.com/repos/byronwall/context-recorder/git/trees/016684895df51872aeea1be5e93e28419fd63a7f?recursive=1)

The authorized packet was the full-content reading route: **21 baseline files plus the local intent brief and prompt, 23 entries total**. All manifest byte sizes and SHA-256 hashes passed verification. The separately uploaded prompt exactly matches the packet copy. This verifies packet integrity, not an independently downloaded copy of every repository blob. Only `Package.swift` content and the tree were fetched through the connector. The packet is not a runnable checkout.

Source inspection and safe syntax checks ran in Linux. Python AST parsing, four JavaScript syntax checks, extension-manifest JSON parsing and `bash -n` passed. The build script was **parsed, not executed**. No dependency was installed. No video was supplied, decoded, stitched, transcribed or reviewed. No repository file was edited and no commit, push or PR was created.

## 1. Can time become useful, truthful space?

### 1.1 Three approaches and what each establishes

| Approach | Useful evidence and strengths | Limits and decision |
|---|---|---|
| Video-only visual registration | Original recorded pixels; applies to web products, code and supplied lectures without browser access. Overlapping stable content can establish relative displacement. | Ambiguity from repetition, occlusion, compression, multiple motion fields and unseen changes. **Selected for the first proof**, with refusal. |
| Browser-assisted reconstruction | Measured viewport/container offsets, document identity and geometry can constrain motion and distinguish navigation. DOM recording can supply a separate structural account. [E20](https://developer.chrome.com/docs/extensions/reference/api/pageCapture) [E21](https://github.com/rrweb-io/rrweb) [E22](https://drafts.csswg.org/cssom-view/#dom-window-devicepixelratio) | Current snapshots are only on demand. DOM/layout is not proof of recorded visibility. Replay can differ from the original pixels. **Optional later hints, not the evidence image.** |
| Change-selected keyframes | Easy source-time mapping, no fabricated page geometry, works across content types. | Repeats overlapping content and makes long-page comparison/capture awkward. **Required comparator and fallback**, not a substitute for testing stitching. |

A hybrid earns its cost when browser measurements reduce a demonstrated ambiguity while visual verification still guards the join. Current browser events can cheaply label candidate visits; they cannot supply continuous scroll trajectories. `extension/page.js` has a selected `STREAM` set and `snapshot(req)` includes viewport/DPR/scroll values only when requested. `background.js` captures MHTML after that request. [R08](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/extension/page.js) [R09](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/extension/background.js) **VC-08.**

### 1.2 User-visible rules

**Extend a surface.** Join only observations supported by a single translation, sufficient overlap and no detected conflicting content in that overlap. Append newly observed pixels in their relative page positions. Moving upward can expose content above the initial origin; negative surface coordinates are valid. The origin means “first accepted observation,” not “document top.” Retain observation times even when an upward reversal adds no new pixels. **VC-01, VC-02.**

**Create a state.** A persistent content edit or layout change starts a rightward state. Geometry can share a surface chart only where correspondences still support it. A reflow, zoom or width change normally starts a new chart. Do not populate an edited state's unobserved top with pixels from an earlier state. Old content may be shown separately as a clearly labeled comparison, never silently carried forward. State identity means compatible observations, not proof that an entire page stayed unchanged.

**Preserve motion.** Keep a poster and a source-video interval at the relevant canvas location. Playback temporarily replaces the poster or opens the one shared player. Rapid change becomes an expandable stack with timestamps, not a temporal average. Transient overlays and selections can be excluded from registration while remaining accessible as temporal evidence. A mask is not permission to erase history. **VC-05.**

**Link a return.** Always retain a new chronological visit. A confirmed link requires later/earlier visual witnesses in an identified region; a URL or thumbnail resemblance only proposes a candidate. A later visit to an edited page can link to the same surface as “returned, changed” without being declared the same state. Repeated lecture slides receive distinct visit times and narration. **VC-05.**

**Refuse clearly.** The fallback is a timestamped viewport card, a source interval and a reason such as `insufficient-overlap`, `ambiguous-repeat`, `multiple-motion`, `scale-change` or `content-conflict`. Chronological adjacency does not imply a spatially known gap. Observed white background remains white; unknown space is hatched or transparent with an explicit label.

### 1.3 Distinguish the causes of movement

| Observation | Interpretation and proposed action |
|---|---|
| Desktop/window and browser chrome move together | Global screen/window movement, not document scroll. Split the initial proof run; later estimate viewport position separately. |
| Content moves inside a stable viewport; chrome stays fixed | Candidate top-level scroll. Register the content region, not the entire screen. |
| One pane moves while another content pane remains still | Nested scrolling. First proof refuses a full-window join. A deliberately selected single pane can be a separate surface. |
| Font size, line breaks, columns or width change | Scale/layout change. Start a new chart or state rather than distort text to fit. |
| Geometry agrees but a label/value/image changes | Content change. Retain both states even when the changed area is small. |
| Cursor, caret, tooltip or animation moves locally | Separate transient/motion evidence; do not let it dictate global translation or disappear without a temporal link. |

This classification is a proposal, not a claim that the initial detector can reliably identify every cause. When several explanations fit the same pixels, abstention is correct.

### 1.4 Provenance, not a single timestamp

Each displayed evidence patch has a source recording digest, actual presentation timestamp (PTS), source-pixel rectangle, translation into a surface, and an ownership region. A patch contains pixels from **one frame**; the composite contains several patches. Overlap selection determines which frame owns each output pixel. Do not blend two times into a text edge. Store independent layout placement so moving a card does not change its source geometry. **VC-01, VC-06.**

A click resolves the visible patch owner, then its frame and source pixel. The inspector shows the contributor time and visit. Alternative observations of that location appear in a visit/time chooser. The later visit's card must seek to its own witness, not silently to an earlier frame reused for visual storage. A “jump to earlier visit” is a separate explicit action.

Narration starts with **“spoken during this visit”** interval association. A sentence spanning two visits may link to both. It is not evidence that every word describes a particular pixel. Raw token times support later splitting at visual boundaries, but token alignment is still recognition output and needs inspection. Do not infer a visual referent from temporal overlap alone. [R13: `tokens_of`, `main`](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/process_session.py) [R14: `Sentence`](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/SessionData.swift)

### 1.5 Three worked layouts — hypothetical, not executed

**A. Scroll, then edit.** At 0:02, 0:04 and 0:06, overlapping viewports reveal successive parts of a product settings page. At 0:10 a visible quota changes from 10 to 20. Only the region actually revisited after the edit belongs to the new state.

```text
chronological order →              (horizontal distance is not elapsed seconds)

Visit 1 · state A · observed 0:02–0:06     Visit 2 · state B · observed 0:10–0:12
┌──────────────────────────────┐         ┌──────────────────────────────┐
│ page top  [owner 0:02]        │         │ unknown in this state ////// │
│ general settings             │         │ //////////////////////////// │
├ · optional provenance seam · ┤  edit → ├──────────────────────────────┤
│ quota: 10 [owner 0:04]        │         │ quota: 20 [owner 0:10]       │
│ lower settings [owner 0:06]  │         │ observed lower settings      │
└──────────────────────────────┘         └──────────────────────────────┘
Narration 0:03–0:05 → visit 1             Narration 0:10–0:12 → visit 2
```

The tall image is an atlas of compatible observations, not a screenshot taken at 0:06. A seam click reports its contributor, not the visit start. If the change happened offscreen, the system cannot establish its exact time; record the interval between last old and first new observation instead of inventing a transition instant.

**B. Return to an earlier page.** A dashboard appears, another page intervenes, then the dashboard returns. A changed badge prevents a whole-page identity claim.

```text
[1 · Dashboard A · 0:05] → [2 · Detail · 0:20] → [3 · Dashboard A′ · 0:42]
        ↑                                             │
        └──── explicit return link: same chart, ───────┘
              badge changed; keep later visit

Click visit 3 pixels → 0:42 witness
Activate “earlier visit” → visit 1 at 0:05; navigation can return to visit 3
```

If only a chart region matches, scope the return to that region. If identity is ambiguous, show “possible return” without a confirmed arrow or automatic collapse. URL equality is not sufficient.

**C. Slide/code lecture, supplied as a local video.** A slide, progressive slide build, code scroll, animation and repeated slide form a storyboard without browser metadata.

```text
[Slide 1 · 0:00] → [Slide 1 build · 0:18] → [Code · 0:35–1:10] → [Demo ▶ 1:10–1:25]
                                                    │                         │
                                            ┌───────┴────────┐                ↓
                                            │ code line 1    │       [Slide 1 again · 1:26]
                                            │ ...            │                │
                                            │ code line 80   │                │
                                            └────────────────┘                │
[Slide 1 · 0:00] ◀───────── return to matching slide; preserve 1:26 visit ───────┘

Transcript rail: sentence intervals linked to visits; ambiguous references stay unassigned.
```

Only stable code scrolling is a stitch candidate. Code edits start a state; slide builds are separate observations, not blended slides. Speaker video is a motion region, not a page surface. This gathers observed assets and words; it does not recover original slide files or unreadable code.

## 2. Which reconstruction method can one developer build?

### 2.1 Compare methods, then select one

| Method | What it earns | Cost/failure and disposition |
|---|---|---|
| Phase correlation plus translation verification | Small API; translation is appropriate for unchanged UI at fixed scale. [E01](https://raw.githubusercontent.com/opencv/opencv/4.14.0/modules/imgproc/include/opencv2/imgproc.hpp) [E02](https://docs.opencv.org/4.13.0/d7/df3/group__imgproc__motion.html) | Repetition, weak texture, mixed motion and circular-shift ambiguity. **Selected candidate.** |
| Feature correspondences plus robust translation fit | Can use sparse distinctive landmarks despite local occlusion. | Repeated glyphs and similar controls can match incorrectly; feature count is not identity. `estimateAffinePartial2D` permits more than translation. [E04](https://docs.opencv.org/4.13.0/d9/d0c/group__calib3d.html) **One possible follow-up, not a second default engine.** |
| ECC with translation model | Direct intensity registration can refine an initialized estimate. [E03](https://docs.opencv.org/4.13.0/dc/d6b/group__video__track.html) | Initialization and convergence matter. **Do not add initially** when local integer verification suffices. |
| Sparse/dense optical flow | Potentially distinguishes local motion from a dominant field. [E03](https://docs.opencv.org/4.13.0/dc/d6b/group__video__track.html) | More parameters and field interpretation; dense warping can deform letters. **Later motion diagnostic, not output geometry.** |
| Apple Vision translation registration | Native API; concrete Swift use exists in ScrollSnap. [E07](https://developer.apple.com/documentation/vision/vntranslationalimageregistrationrequest) [E09](https://raw.githubusercontent.com/Brkgng/ScrollSnap/main/ScrollSnap/Managers/StitchingManager.swift) | Native helper/measurement integration and score calibration still needed. **Alternative if Python deployment is the blocker**, not a parallel implementation. |
| Browser offsets | Direct geometric hint for a known scroll container. [E22](https://drafts.csswg.org/cssom-view/#dom-window-devicepixelratio) | Must align clocks, viewport origin, zoom and container identity; does not detect all content changes. **Only after a demonstrated need.** |

**Selected P pipeline, VC-02:** optional Python, existing FFmpeg/FFprobe and one OpenCV/NumPy environment. No learned model, OCR, image embeddings, vector database, optical-flow network, panorama library, cloud service or web stack conversion.

### 2.2 Small processing pipeline

1. **Establish input and scope.** Hash the video; inspect stream time base, PTS, dimensions, rotation and sample aspect ratio. Initial proof accepts upright square-pixel video and one user-selected rectangular content viewport per clip. Selection excludes browser chrome, not inconvenient failures within that viewport. Do not require per-frame alignment or edits. Unhandled orientation/geometry receives an explicit unsupported result. [E25](https://ffmpeg.org/ffprobe.html)
2. **Scan without accumulating frames.** Decode sequentially. Use a small low-resolution native-cadence change/motion sentinel and nominal 2 Hz candidates; retain a short bounded buffer. Monitor the viewport boundary and an adjacent chrome/frame guard region separately from the content crop. A moving boundary or unsupported guard invalidates the fixed-viewport assumption; do not mistake a moved window for document scrolling. Where no reliable guard exists, limit the claim to scoped content displacement, not recovered browser scroll. Marks, navigation hints and major changes propose additional candidates. Retry nearby original frames up to native cadence when motion threatens overlap. No decoder-created duplicate frame counts as new evidence. [E26](https://ffmpeg.org/ffmpeg.html) [E27](https://ffmpeg.org/ffmpeg-filters.html#showinfo)
3. **Propose translation.** Compare grayscale floating-point crops at roughly 640 pixels wide, using a Hann window. Compare the whole content crop and informative full-height strips so a fixed header cannot win solely by area. Store response and disagreement separately. The OpenCV response is not a calibrated probability of correctness. [E01](https://raw.githubusercontent.com/opencv/opencv/4.14.0/modules/imgproc/include/opencv2/imgproc.hpp) [E02](https://docs.opencv.org/4.13.0/d7/df3/group__imgproc__motion.html)
4. **Verify at source resolution.** Refine around the scaled estimate with integer translations and independently check multiple text/edge regions and photometric residuals. Check alternative displacement minima where repeated rows make a runner-up plausible. Revalidate against an earlier overlapping anchor to limit drift. No scale, shear or perspective transform is admitted into the evidence composite.
5. **Check changes separately.** Evaluate aligned residuals, including small coherent components, rather than only global average error. Mask known transient regions only for alignment, not for change-history accounting. Audit full-resolution candidates at a fixed maximum temporal gap even when the low-resolution sentinel says “unchanged.” Stable, materially different content creates a state; uncertain local change becomes a temporal card. Tiny/brief changes can still escape sampling and are an explicit test boundary.
6. **Commit or refuse.** Accept only after overlap, spatial support, uniqueness, residual and state tests pass. Add new observed regions with single-frame ownership; keep overlap alternatives as metadata. Otherwise emit a card and reason. Do not fabricate a bridge over a no-overlap jump.
7. **Materialize a bounded view.** Save contributor crops/tiles and small overview images. Save actual frame PTS, transforms, intervals and decisions in a sidecar. Preserve the original video for motion and exact contextual review. Scored automatic output precedes any human correction.

A fixed 1/5/10-second grid is useful as an experimental sampling ablation, not a product requirement. At 2 Hz, sufficiently fast scrolling still needs denser observations. Even dense sampling cannot recover content skipped between recorded frames. Avoid a “successful” low-cost scan that quietly loses one-digit edits.

### 2.3 Initial confidence policy — all values provisional

The following are calibration starting points, not learned probabilities or acceptance results. Report the component vector and rejection reason rather than one authoritative-looking score.

| Signal | Proposed starting rule | Calibration or refusal |
|---|---|---|
| Overlap | At least 60% of the scoped viewport; vertical displacement at most 40% of its height between accepted candidates | Retry nearer frames; otherwise card. This also limits circular-shift ambiguity. |
| Phase response | Start at 0.6; compare 0.3/0.6/0.8 on development clips | Response alone never accepts a join. |
| Spatial support | At least three informative regions distributed across the content, not all one repeated row/header | Blank or localized evidence means abstain. Initial edge-density threshold is calibrated, not hard-coded from another application. |
| Translation agreement | Refined regional offsets within 2 source pixels; proposed horizontal drift at most 2 pixels for vertical-scroll scope | Conflicting motion suggests nested panes, movement or layout change. |
| Residual | Starting median absolute grayscale error at most 6/255 in eligible overlap; inspect coherent differences above 12/255 | Sweep on H.264 fixtures. Small meaningful changes override a good global median. |
| Uniqueness | Reject when a materially different displacement yields nearly equivalent verification error; start runner-up gap at 20% | Repeated rows require an independent distinctive anchor, not just a taller peak. |
| Drift | Recheck an overlapping earlier anchor whenever available and at least every ten accepted candidates | If no anchor remains, record accumulated uncertainty and cap run length until measured drift is acceptable. |

A high score cannot prove absent offscreen edits. The strongest enforceable contract is **accurate patch provenance plus conservative, visibly scoped reconstruction**.

### 2.4 Seams and difficult cases

**Text legibility:** keep integer-aligned source pixels. Within verified overlap, select a low-edge-energy horizontal cut away from glyphs; assign each side to one frame. A hard seam with inspectable provenance is preferable to ghosted text. If a seam would cut or duplicate a line and no safe cut exists, retain overlapping cards. Lossless PNG avoids additional lossy recompression; it does not undo H.264 damage. Thumbnails are disposable presentation assets, not evidence replacements. **VC-02, VC-07.**

| Failure family | Required behavior |
|---|---|
| Fixed headers, sticky rows, sidebars | Exclude identified stationary bands from motion fitting; retain them in frame/context evidence. Sticky transitions can force a split. Never repeatedly paste a header down the document. |
| Tooltips, cursor, caret, selections | Use limited transient masks for registration. Preserve the event/poster or source interval. Do not fill an occluded region unless a credited observation actually shows it. |
| Animation and embedded video | Use a motion card/interval. Do not smear animation into a static surface or autoplay many independent moments. |
| Compression and antialiased text | Calibrate residual thresholds on the recorder's actual encoding; inspect source-resolution readability. Pixel-level identity is not expected between compressed frames. |
| Blank areas and repeated text | Low information or competing offsets means refusal. A uniform white region is observed, but does not establish displacement. |
| Scroll reversal | Extend above/below only with verified overlap. Keep the temporal traversal even when geometry is already known. |
| Fast jump | Try intervening recorded frames. Without evidence, split and label unknown spatial relation; do not guess skipped height. |
| Zoom, window move, resize, reflow | End the initial run. A later viewport-tracking feature must distinguish screen placement from document coordinates. No warp to make incompatible text fit. |
| Nested panes | Reject a full-window single transform. A separately scoped pane can form its own surface; do not imply the surrounding panes scrolled with it. |
| Virtualized list | DOM or scroll offset alone does not establish persistent row identity. Recycling/reordering can invalidate a page chart. Require visual witnesses or cards. |
| Lazy-loaded content | New pixels extend an atlas only while supported geometry stays stable; inserted content/reflow creates a state/chart boundary. |
| Same URL changed, similar pages, repeated slides | Use URL/title/thumbnail only for candidate retrieval. Verify a distinctive region, scope the identity claim and keep the later visit. |

### 2.5 Prior art versus implementation dependencies

Classical mosaic work explicitly couples registration/integration with residual analysis. That is the useful precedent: a good alignment does not mean all content is unchanged. Swipe Mosaics provides a spatial-navigation precedent without requiring one perfectly fused image. Video Tapestries motivates temporal zoom, while borderless blending is a poor default for evidence-sensitive UI text. Video Digests motivates combining visual summaries with text. Dynamosaics is useful for motion inspection, but its non-chronological premise must not erase this application's chronology. [E13](https://www.wisdom.weizmann.ac.il/~irani/abstracts/mosaics.html) [E14](https://arxiv.org/abs/1609.08080) [E15](https://research.adobe.com/publication/video-tapestries-with-continuous-temporal-zoom/) [E16](https://pixl.cs.princeton.edu/gfx/pubs/Barnes_2010_VTW/index.php) [E17](https://www.amypavel.com/) [E19](https://www.microsoft.com/en-us/research/video/dynamosaics-dynamic-mosaics-with-non-chronological-time/)

Two closely related implementation leads matter. **Brkgng/ScrollSnap** demonstrates a native translation approach and regional agreement; its source still holds a growing composite, so it is not evidence of bounded total image memory. **Haruhiyuki/scrollsnap** is unusually close to the requested reconstruction/provenance problem and deserves a bounded reuse review before code is duplicated. Its inspected package is alpha, adds dependencies and exposes inconsistent repository URLs in metadata. Its author-reported benchmarks are not this project's validation. **Neither is selected as a dependency in this research.** [E08](https://github.com/Brkgng/ScrollSnap) [E09](https://raw.githubusercontent.com/Brkgng/ScrollSnap/main/ScrollSnap/Managers/StitchingManager.swift) [E10](https://github.com/Haruhiyuki/scrollsnap) [E11](https://raw.githubusercontent.com/Haruhiyuki/scrollsnap/main/pyproject.toml) [E12](https://raw.githubusercontent.com/Haruhiyuki/scrollsnap/main/CHANGELOG.md)

For the later proof, first inspect a pinned scrollsnap source/output sample against this report's patch/time contract. Reuse a small compatible component only if that removes work without importing its agent/server integrations or weakening G1. Do not implement both it and the proposed engine as permanent parallel paths. Video Digests' full web application is not an appropriate dependency here. [E18](https://github.com/ucbvislab/vdigests) **VC-02.**

## 3. How should people navigate and inspect it?

### 3.1 Layout decision

| Layout | Benefit | Decision/tradeoff |
|---|---|---|
| Rightward chronological visits, vertical page geometry | Matches the intent; edits sit beside prior content while page structure stays readable. | **Default proposal.** Column widths are layout, not elapsed time. Explicit numbered visits and a timeline recover chronology. |
| Page/surface-grouped lanes | Compact for many returns; useful comparison index. | Secondary overview. Grouping alone hides the later occurrence and its narration. |
| Chronological filmstrip/cards | Familiar, robust across unsupported content. | Baseline and fallback. Does not reveal the distinctive long-page structure. |

A full session need not remain expanded horizontally. Use chapters or collapsible time ranges in an overview, while preserving a linear chronological list as a navigation backbone. The graph of return links is an overlay, not the only route through the session. **VC-04, VC-05.**

### 3.2 Zoom, selection and playback

At **overview zoom**, show visit labels, durations, state-change/motion badges and small previews. At **reading zoom**, show the visible tile range with neighboring context and an optional provenance seam overlay. At **source-pixel zoom**, provide a clearly defined image scale and source crop for inspection; browser CSS scaling and display DPR still affect physical screen pixels. Temporal zoom is separate: expand a stack into more recorded moments without changing page geometry.

Selecting a patch opens its time, source crop, state and visit. Seek to its exact contributor frame time. For repeated observations, default to the currently displayed visit's witness; show an observation chooser rather than guessing from URL or global proximity. Clicking blank unknown space cannot manufacture a seek target. A whole-visit button seeks to its first representative frame, clearly labeled as such. **VC-06.**

Keep one shared player. Motion playback starts at the selected interval, highlights the current viewport/visit, and stops or loops at the interval end only when that mode is selected. Do not imply frame-accurate stepping until actual decoded timestamps are used. Playback in the original full frame remains available for occlusions and surrounding context. Transcript text sits in a side rail, not over page pixels; selecting a sentence seeks to its source start and highlights all temporally associated visits.

### 3.3 Accessibility and minimal correction

Use actual DOM buttons/links and a chronological reading order, not an inaccessible bitmap with pointer-only hit targets. Provide visible focus, text labels, time spans, keyboard pan/zoom, Enter to activate and Escape to exit selection. Keep existing J/K mark navigation intact; proposed `[`/`]` visit navigation must be scoped and documented. Arrow keys pan only while the canvas is focused, leaving player/timeline shortcuts intact. Offer a list view for long sessions and screen readers. **VC-04.**

Minimum corrections are **split this run**, **reject this join/restore cards**, **adjust the one scoped viewport or exclusion rectangle**, and **accept/reject a return**. A source-observation chooser resolves an unwanted seam contributor. Keep undoable overrides in a small durable `canvas-edits.json`; reject stale overrides when the source digest changes. These are recovery controls, not a freeform layout/warp editor. Score automatic performance before applying them. First-slice alignment must not depend on manual offsets. **VC-01, VC-04, VC-09.**

### 3.4 Composite region capture

A drag selection is in surface coordinates. Clip it against ownership regions, map each portion back to its source rectangle, and export those portions with an explicit multi-time label and a provenance sidecar. Holes remain holes. A selection across states is a labeled montage, not a screenshot of one page. Export at source resolution, not the current zoom's screenshot resolution. **VC-07.**

The current `RegionPicker` and `addReviewShot(region:)` capture a single video frame; they do not already support this operation. Likewise, `PgmExporter.imageFiles(for:)` exports mark images/frames, not arbitrary spatial provenance. Keep the new artifact separate until a deliberate export integration is specified. [R16](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/SessionView.swift) [R18](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/Review.swift) [R20](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Export/PgmExport.swift)

## 4. Where does it fit in this repository?

### 4.1 Verified baseline and its consequential limits

The executable records the main display through ScreenCaptureKit and AVAssetWriter. `Recorder.start` requests 15 fps, at most 1920 pixels wide, H.264 average bitrate 4 Mbps, cursor inclusion and optional microphone audio. Width is capped; height follows display aspect ratio. Actual frame times must be inspected rather than reconstructed from the requested frame rate. [R03](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Recorder.swift)

`Session` appends marks and browser events as JSONL. `ActivityLog.start/sample` samples every two seconds and after activation, but writes only when app, window title or browser URL changes. Window movement alone is not a continuous geometry track. `ContextProbe.capture` returns context, not a synchronized per-frame viewport. [R04](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Session.swift) [R05](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/ActivityLog.swift) [R06](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/ContextProbe.swift)

Several details affect provenance:

- `AppDelegate.bridge.onEvent` stamps **receipt time** using `Recorder.currentOffset()`. The extension can queue events and forwards events from tabs that need not be the visible one. `event.t = Date.now()` is a different clock. Do not assume browser.jsonl is an exact screen-event timeline. [R07](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/main.swift) [R08](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/extension/page.js) [R09](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/extension/background.js) [R12](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/BrowserBridge.swift)
- `AppDelegate.addMark` saves the keypress offset, but `addRegionMark` takes the still after region selection. On-demand snapshot/MHTML operations are asynchronous too. A mark time is not verified exposure time for those assets. [R07](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/main.swift) [R03](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Recorder.swift)
- `extract_frame` caches a mark JPEG and does not persist the actual decoded frame PTS. `Review.saveFrame` requests a frame but discards the returned actual time. These are not sufficient for a new exact patch-to-frame contract. [R13](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/process_session.py) [R18](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/Review.swift)
- `SessionData.PageSnapshot` does not decode viewport/DPR/scroll/window fields. They remain in raw JSON but are absent from this native projection. The processor's session transcript retains sentences, whereas raw `transcript.json` has tokens. Read raw evidence where those fields are needed. [R14](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/SessionData.swift) [R13](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/process_session.py)

These are scoped integration findings, not an assertion that the existing review behavior is broken for its current purpose. **VC-06.**

### 4.2 Offline first; portable HTML first

| Choice | Why selected or deferred |
|---|---|
| Offline reconstruction | Repeatable on disposable inputs; no competition with capture, no new recording failure mode. Longer post-stop latency is acceptable for the proof. |
| During capture | Could supply immediate previews and better synchronized metadata. Defer until benefit and capture overhead are measured. |
| Portable HTML proof | `write_viewer` already embeds JSON and `viewer.html` already uses local video and a common time. DOM image placement needs no package project. |
| SwiftUI proof | `SessionModel` already owns AVPlayer and precise seek requests. Native integration is attractive later, but adds canvas rendering/interaction work before validating the idea. |

**Proposed short call path, VC-03/VC-04:** explicitly run a new `scripts/analyze_canvas.py` on a disposable session; it writes `canvas.json` and `canvas/`. A small optional read in `process_session.py` includes a validated, source-matching sidecar in `DATA.canvas` during `write_viewer`. Add a Canvas mode to the existing viewer; retain its original video, timeline and fallback views. Do not fetch JSON through `file://` or create a server dependency.

Geometry caching uses the video digest, analysis method/version, viewport and parameters. Transcript associations can be rebuilt cheaply when recognition data changes. Note/mark edits must not trigger video reconstruction: `Review.reprocess()` currently reruns `process_session.py`. Missing, stale or malformed canvas output must leave ordinary session review usable. Write new output atomically; never replace the only good sidecar with a partial run. [R13: `main`, `write_viewer`](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/process_session.py) [R18: `reprocess`](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/Review.swift)

Later native integration can add a small canvas data type and a view alongside `Stage`, using `SessionModel.seek(_:play:)`, `currentTime` and the existing `SessionTimeline`. Do not add a second independently advancing player. The `lightbox` in HTML supplies useful zoom math, but is a single-image viewer, not an existing infinite-canvas component. [R15](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/SessionModel.swift) [R16](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/SessionView.swift) [R17](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/SessionTimeline.swift) [R19](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/viewer.html)

`build-app.sh` explicitly copies only the existing processor and HTML template. A helper is not automatically bundled; packaging must be an explicit later change. The script builds and signs even with `INSTALL_DIR=`. It was not run. [R21](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/build-app.sh)

### 4.3 A small data model

**P:** One `canvas.json`, not a database. Surface = coordinate chart; state = compatible visual observations; visit = chronological occurrence. Frames retain PTS. Patches own displayed pixels and reference bounded images. Links and temporal transcript associations complete the model. All rectangles use half-open `[x, y, width, height]` coordinates.

The following is a **hypothetical structural example, not a fixture or measured output**. Its source digest is deliberately `null`; real output must supply the actual digest. `span` denotes visit bounds, not a guarantee that every surface pixel stayed visible throughout. Images in this example are all smaller than 1024 pixels on either axis; larger regions split into equivalent bounded records.

```json
{
  "schemaVersion": 1,
  "illustrative": true,
  "source": {
    "video": "recording.mp4",
    "sha256": null,
    "width": 1920,
    "height": 1080,
    "timeBase": [
      1,
      15000
    ],
    "mediaZeroPts": 0,
    "pixelSpace": "oriented-video-top-left",
    "sampleAspectRatio": [
      1,
      1
    ]
  },
  "analysis": {
    "method": "translation-proof-proposal",
    "coverageClaim": "observed-pixels-only"
  },
  "surfaces": [
    {
      "id": "page-a",
      "origin": "first accepted viewport",
      "units": "source-video-pixels"
    }
  ],
  "states": [
    {
      "id": "a0",
      "surface": "page-a",
      "label": "No detected change in these observations"
    },
    {
      "id": "a1",
      "surface": "page-a",
      "label": "Edited state; unobserved areas remain unknown"
    }
  ],
  "visits": [
    {
      "id": "v1",
      "state": "a0",
      "span": [
        1,
        3
      ],
      "canvasOrigin": [
        0,
        0
      ],
      "patches": [
        "p1",
        "p2"
      ]
    },
    {
      "id": "v2",
      "state": "a1",
      "span": [
        10,
        12
      ],
      "canvasOrigin": [
        1000,
        0
      ],
      "patches": [
        "p3"
      ]
    },
    {
      "id": "v3",
      "state": "a0",
      "span": [
        20,
        22
      ],
      "canvasOrigin": [
        2000,
        0
      ],
      "patches": [
        "p4"
      ],
      "identityScope": "visible 800x640 region only"
    }
  ],
  "frames": [
    {
      "id": "f1",
      "pts": 15000,
      "time": 1
    },
    {
      "id": "f2",
      "pts": 30000,
      "time": 2
    },
    {
      "id": "f3",
      "pts": 150000,
      "time": 10
    },
    {
      "id": "f4",
      "pts": 300000,
      "time": 20
    }
  ],
  "images": [
    {
      "id": "i1",
      "path": "canvas/patches/p1.png",
      "size": [
        800,
        640
      ]
    },
    {
      "id": "i2",
      "path": "canvas/patches/p2.png",
      "size": [
        800,
        256
      ]
    },
    {
      "id": "i3",
      "path": "canvas/patches/p3.png",
      "size": [
        800,
        640
      ]
    },
    {
      "id": "i4",
      "path": "canvas/patches/p4.png",
      "size": [
        800,
        640
      ]
    }
  ],
  "patches": [
    {
      "id": "p1",
      "visit": "v1",
      "image": "i1",
      "frame": "f1",
      "sourceRect": [
        100,
        160,
        800,
        640
      ],
      "videoToSurface": [
        -100,
        -160
      ],
      "ownedSurfaceRect": [
        0,
        0,
        800,
        640
      ]
    },
    {
      "id": "p2",
      "visit": "v1",
      "image": "i2",
      "frame": "f2",
      "sourceRect": [
        100,
        544,
        800,
        256
      ],
      "videoToSurface": [
        -100,
        96
      ],
      "ownedSurfaceRect": [
        0,
        640,
        800,
        256
      ]
    },
    {
      "id": "p3",
      "visit": "v2",
      "image": "i3",
      "frame": "f3",
      "sourceRect": [
        100,
        160,
        800,
        640
      ],
      "videoToSurface": [
        -100,
        96
      ],
      "ownedSurfaceRect": [
        0,
        256,
        800,
        640
      ]
    },
    {
      "id": "p4",
      "visit": "v3",
      "image": "i4",
      "frame": "f4",
      "sourceRect": [
        100,
        160,
        800,
        640
      ],
      "videoToSurface": [
        -100,
        -160
      ],
      "ownedSurfaceRect": [
        0,
        0,
        800,
        640
      ]
    }
  ],
  "links": [
    {
      "kind": "next",
      "from": "v1",
      "to": "v2"
    },
    {
      "kind": "next",
      "from": "v2",
      "to": "v3"
    },
    {
      "kind": "return",
      "from": "v3",
      "to": "v1",
      "scope": "visible region only",
      "witnessFrames": [
        "f4",
        "f1"
      ]
    }
  ],
  "transcript": [
    {
      "sourceFile": "session.json",
      "sourcePointer": "/transcript/0",
      "span": [
        1.1,
        2.2
      ],
      "text": "Example narration, not an evaluated transcript.",
      "visits": [
        "v1"
      ],
      "relation": "spoken-during-visit",
      "region": null
    }
  ]
}
```

`videoToSurface = [tx, ty]` means `surface = videoPixel + translation`. Image-local coordinates first add the `sourceRect` origin. In `p2`, video y=544 maps to surface y=640. Combined with `p1`, the observed surface is 800×896, larger than its 800×640 viewport. The second observation's original full viewport corresponds to surface y=256…896; only its new tail owns pixels in this compact example.

The edited visit has no observation for surface y=0…256. The return visit has no later observation below y=640, so it must not borrow the earlier lower tail as later evidence. Its return link is scoped to visible content. Storage deduplication may share identical image bytes, but frame/time references remain visit-specific. A larger implementation may add observation records for non-owning overlaps and bounded masks; no per-pixel database is needed.

### 4.4 Coordinate and clock boundaries

**Video time.** `Recorder.currentOffset()` subtracts first video PTS from host-clock time; writer session start uses that first PTS. For analysis, retain each decoded PTS and stream time base and explicitly map to the media timeline. Validate media-zero normalization rather than blindly subtracting an arbitrary container start. FFprobe frame data and FFmpeg `showinfo` provide inspection routes. Never substitute `frameIndex / 15`. Seeking is asynchronous; verify the presented witness after seeking. [R03](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Recorder.swift) [E23](https://html.spec.whatwg.org/multipage/media.html#dom-media-currenttime) [E25](https://ffmpeg.org/ffprobe.html) [E26](https://ffmpeg.org/ffmpeg.html) [E27](https://ffmpeg.org/ffmpeg-filters.html#showinfo)

**Video pixels.** Use oriented, top-left recording pixels as the canonical space. For the first proof, reject unsupported rotation/non-square sample aspect ratio rather than silently mis-map it. A later normalization step must record its transform. Full-resolution recording-time stills may have a different scale and exposure; do not substitute them for video contributors without explicit calibration.

**Display points.** AppKit mouse positions are global bottom-left coordinates. `pointerPayload` and `displayRect(fromScreen:)` convert to main-display top-left points. Backing scale maps points to display pixels; the recording has a further downscale. Derive effective x/y factors from actual capture geometry, allowing even-dimension rounding. Do not assume video width equals display pixel width. [R06](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/ContextProbe.swift) [R07](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/main.swift) [R03](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Recorder.swift)

**CSS pixels and zoom.** The extension's viewport geometry is CSS-based. `viewportOrigin(req)` estimates page zoom as DPR divided by screen backing scale and uses paired pointer positions or a window-geometry fallback. That fallback is not a precise viewport calibration for every browser arrangement. CSSOM defines DPR with page zoom; visual-viewport/pinch behavior needs separate handling. Document coordinates require scroll offsets for the correct container at the correct time. None of those measurements is continuously available now. [R08](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/extension/page.js) [E22](https://drafts.csswg.org/cssom-view/#dom-window-devicepixelratio)

**Optional browser instrumentation, VC-08.** Only after a measured failure, add document/navigation identity, active tab/window visibility, viewport bounds, page zoom, visual-viewport scale/offset, top-level scroll and identified nested-container offsets. Sample/throttle locally and record browser monotonic time plus a host-clock handshake with uncertainty. Handle reconnects/queued events and stale geometry. Those records constrain alignment; recorded pixels still decide whether content changed. DOM-derived text/layout, if offered, belongs in a separately labeled layer with its own provenance and no automatic blending into observed evidence. rrweb is a possible later instrument, not a prerequisite. [E20](https://developer.chrome.com/docs/extensions/reference/api/pageCapture) [E21](https://github.com/rrweb-io/rrweb)

### 4.5 Evidence, caches and memory

Retain original `recording.mp4`, recorded marks/context/browser logs, original screenshots and MHTML as source materials. Retain `transcript.json` as recognition evidence, not authoritative word truth. Preserve user notes, correction overrides and `exports/pgm.json`. Generated frame JPEGs, `session.json`, viewer HTML, canvas tiles and layout can be regenerated from retained inputs, subject to recognition/version reproducibility. Do not delete a directory merely because it contains some derived assets. [R04](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Session.swift) [R13](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/process_session.py) [R18](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/Review.swift) [R20](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Export/PgmExport.swift)

**P memory strategy, VC-07:** lossless evidence patches or tiles at most 1024×1024; overview pyramid thumbnails; viewport culling; an explicit 12-tile decoded LRU budget (48 MiB RGBA) plus a bounded frame work buffer. Remove offscreen image references rather than assuming `loading="lazy"` guarantees eviction. Metadata grows with observations; images, decoder buffers and GPU/browser copies must all be measured. Never allocate the entire session as one canvas bitmap.

For composite export, cap a single selection at **32 million source pixels** initially (128 MB for one RGBA buffer), use a worker/offline path, and split larger selections into numbered pieces with one provenance index. Browser pixel export is not assumed safe just because local images display: canvas has origin-clean restrictions. Keep the local-file proof independent of browser readback. [E24](https://html.spec.whatwg.org/multipage/canvas.html#security-with-canvas-elements)

### 4.6 Disk, memory and processing estimates — not measurements

Assume 1920×1080, requested 15 fps, video target 4 Mbps, optional microphone 96 kbps. Actual aspect ratio, bitrate, hardware, encoder behavior and content vary. Decimal MB/GB are used for disk; MiB for decoded-memory budgets. Existing screenshots/MHTML, model weights and transcription runtime are excluded because no representative count/size/model execution was supplied. [R03](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Recorder.swift)

For derived storage, assume **six novel viewport-equivalents per minute**, 0.5–2 encoded bytes per evidence pixel, and one-third extra for overview levels. This is a budgeting scenario, not a compression prediction. It counts novel/state-specific content, not every analysis frame.

| Quantity | 10 minutes | 60 minutes |
|---|---:|---:|
| Nominal source frames | 9,000 | 54,000 |
| Video at target bitrate | 300 MB | 1,800 MB |
| Optional microphone at target bitrate | 7.2 MB | 43.2 MB |
| Existing 16 kHz mono 16-bit WAV cache assumption | 19.2 MB | 115.2 MB |
| Nominal 2 Hz analysis candidates | 1,200 | 7,200 |
| Novel source-resolution evidence | 124.4 megapixels | 746.5 megapixels |
| Evidence images plus overview estimate | 83–332 MB | 498–1,991 MB |
| Conservative 512-byte frame/decision metadata allowance | 4.6 MB | 27.6 MB |
| Recording + mic + estimated canvas images/metadata | 395–644 MB | 2,369–3,862 MB |

The final row excludes the WAV cache and other pre-existing session assets. Frequent whole-screen state changes can greatly exceed the image estimate. Proposed operational ceilings are 350 MB of canvas images for ten minutes and 2.1 GB for an hour; upon reaching a ceiling, keep temporal interval records and downshift future output to bounded posters/cards. Report the downshift and reduced spatial coverage, rather than silently dropping history.

One 1920×1080 RGBA frame is 7.91 MiB. Retaining all nominal frames would take about 74.6 GB or 447.9 GB in decimal units. A streaming worker target of 512 MiB and incremental viewer target of 256 MiB therefore require explicit eviction, not just tiles. These are acceptance budgets, not measured peak RSS.

For runtime arithmetic, assume two sequential decode passes at an **unmeasured 100–250 frames/second**, 5–20 ms per nominal candidate for matching/verification, and 10–60 seconds of image writing per ten minutes. This yields roughly **88–264 seconds for ten minutes** and **528–1,584 seconds for an hour**. Those are conditional budget calculations, not expected Mac performance. Native-cadence matching can increase candidate work up to 7.5×; hard content, PNG cost and a slower decoder can exceed the range. Measure on Byron's actual Mac and keep transcription separate.

### 4.7 Dependency decision and installation cost

Candidate: **`opencv-python-headless==4.14.0.94` plus its compatible NumPy dependency**, in one local Python environment for the explicit proof. The tagged OpenCV source retains the selected phase-correlation API. PyPI lists macOS ARM64 and Intel wheels; no source build is intended. The candidate is a deliberate 4.x pin, not the highest version number on PyPI. No dependency was installed or imported for image experiments here. [E01](https://raw.githubusercontent.com/opencv/opencv/4.14.0/modules/imgproc/include/opencv2/imgproc.hpp) [E05](https://pypi.org/project/opencv-python-headless/4.14.0.94/)

The inspected wheel downloads are 46.5 MB ARM64 and 33.1 MB Intel, before NumPy and installed expansion. Exact total install footprint and resolver compatibility remain unrun. The wrapper/build scripts, OpenCV library and bundled third-party binaries have different licenses; do not describe the complete wheel as MIT-only. NumPy uses BSD three-clause terms. Preserve the package's notices if bundling later. Existing external FFmpeg/FFprobe commands remain the decoding route; their actual installed build is a local check. [E05](https://pypi.org/project/opencv-python-headless/4.14.0.94/) [E06](https://numpy.org/doc/stable/license.html)

Apple Vision removes the Python CV wheel from distribution but would move proof analysis into a native helper or Swift path. That is a valid fallback if packaging dominates. Do not maintain both engines merely for optionality. Neither rrweb, a canvas library nor a package.json-based frontend earns a place in the initial slice. **VC-02, VC-03, VC-08.**

## 5. What proof decides GO or NO-GO?

The companion proof plan defines the full procedures. Every stage below is **unrun** except research/source integrity and syntax checks. **VC-09.**

**P0 — establish the measurement contract.** On a disposable real session, validate frame PTS, pixel transforms, source hashes and current review behavior. The source packet cannot substitute for this environment check.

**P1 — prove the distinctive geometry.** Use a clean controlled scroll with at least three overlapping viewport positions. Require automatic translation, a composite taller than one viewport, and patch clicks that reveal the correct frame/pixel. Inject a wrong-match and no-overlap case; both must refuse.

**P2 — stress only likely failure modes.** Eight short directed clips cover clean/reverse scrolling, sticky/transient UI, nested panes/window/zoom changes, edits/lazy load/virtualization, jumps/repeated text, revisits, animation and slides/code. Develop thresholds on designated variants; freeze them before held-out cases. Include actual narrated product recordings separately. Synthetic success alone is insufficient.

**P3 — compare personal value.** In the HTML proof, compare raw video, change-selected keyframes and canvas on counterbalanced content-finding, change-comparison, source-time and long-region capture tasks. Include accuracy, time and correction effort. No population-level conclusion follows from a small personal test.

**P4 — test scaling and non-regression.** Measure ten- and sixty-minute workloads, metadata/image growth, peak memory, time-to-first-use and total processing. Synthetic concatenation may test resource bounds but is not evidence of reconstruction generalization. Verify ordinary video/marks/transcript still work when canvas output is unavailable.

**P5 — gated follow-ons.** Add richer motion inspection, verified return detection, token-level temporal association and provenance-bearing composite export only after their respective checks. Native UI and browser instrumentation are subsequent choices, not first-slice commitments.

### Four decisive gates — provisional acceptance criteria

| Gate | Required evidence | Failure outcome |
|---|---|---|
| **G1: truth and provenance** | Zero harmful accepted joins or lost required changes in the finite test set; registration error p95 ≤2 source pixels and max ≤4; every owned pixel resolves to a real frame/crop; source seek within one actual neighboring frame interval; zero false confirmed returns where enabled. | Block stitched output. Fix once in a targeted way, otherwise retain cards. Never waive this for visual appeal or speed. |
| **G2: useful spatial coverage** | At least 90% of distinct, observed, eligible clean-scroll content represented legibly in valid geometry; at least one automatic result spans ≥2 viewport heights; report eligibility and abstention. | Narrow scope only with an explicit retained user benefit. If clean scrolling still needs manual alignment, reject the stitcher. |
| **G3: personal task value** | On the small matched-task comparison, no accuracy loss, at least 20% lower median task time than the stronger baseline, and a useful larger-than-frame capture result. Count corrections in task time. | Favor the simpler storyboard if geometry adds no practical benefit. Treat the exact 20% threshold as a product proposal, not a statistical discovery. |
| **G4: local cost and regression** | Worker peak RSS ≤512 MiB, incremental viewer peak ≤256 MiB, processing ≤recording duration on the recorded test Mac; controlled image budgets; no canonical mutation and ordinary review remains usable. | Optimize one bottleneck or narrow output. Stop if the local workflow remains expensive or fragile relative to its benefit. |

A “lost required change” is a ground-truth semantic edit visible for at least 500 ms that is neither represented as a distinct state/card nor covered by an explicitly marked motion interval. Merely leaving the original video somewhere in the session does not count as preserving the change in the storyboard. Report shorter events separately; no guarantee is made for arbitrary sub-frame or invisible changes.

Revisit precision is meaningful only with accepted links and denominators. Report recall and abstention too; zero proposed links cannot be called a successful return detector. A no-false-links result in a small corpus is an acceptance check, not a population error-rate bound.

### Smallest end-to-end slice

One **60–90 second narrated product recording**, one fixed viewport selection, a static scroll spanning three viewport heights, one visible edit and one deliberate unstitched jump. Output: the observed tall surface, a rightward edited-state card, a refusal card, exact contributor click-to-video, a sentence rail and the two baselines. No automatic revisits, dense motion segmentation, token-to-pixel grounding, arbitrary export editor or native canvas is required for this slice. It proves spatial reconstruction, not merely frame selection.

Before declaring feature GO, add at least two actual narrated walkthrough recordings with different content and the directed holdouts. The fuller G3 gate includes a bounded composite export/capture capability after the initial interaction slice; do not claim the first slice alone passes all gates.

## Rejected ideas and remaining choices

Reject a seamless panorama with a single timestamp; general homography/flow warping of UI text; generative filling; treating MHTML as observed pixels; mandatory rrweb; all-frame PNG dumps; a graph database or cloud service; a new frontend framework; and a full editor built before automatic performance is measured. These either weaken the evidence contract or add cost before proving the central benefit. **VC-01–VC-09.**

Open product choices do not block the research conclusion: whether a one-time viewport crop is acceptable in a personal tool; whether the proposed 20% task-time gain and memory budgets match Byron's priorities; whether confirmed returns default to compact cards or expanded duplicates; and whether native integration earns its cost after the HTML proof. Actual CV accuracy, false-join rates, dependency resolution, text readability and browser playback/export behavior remain empirical questions, not settled product choices.

**Conclusion:** proceed to the scoped design/proof-plan PR and then the small proof, with a strong refusal path. Preserve the complete vision in the data and interaction rules. Do not promise that all of it ships, or that any reconstruction experiment has already succeeded.

## Source references

All external references were accessed for this research on 2026-10-13. Details and limits are in `video-to-canvas-sources.md`. Repository references below use the exact baseline; the intent brief is a supplied local addition.

- [R01](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/README.md) — `README.md`.
- [R02](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Package.swift) — `Package.swift`.
- [R03](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Recorder.swift) — `Sources/ContextRecorder/Recorder.swift`.
- [R04](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Session.swift) — `Sources/ContextRecorder/Session.swift`.
- [R05](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/ActivityLog.swift) — `Sources/ContextRecorder/ActivityLog.swift`.
- [R06](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/ContextProbe.swift) — `Sources/ContextRecorder/ContextProbe.swift`.
- [R07](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/main.swift) — `Sources/ContextRecorder/main.swift`.
- [R08](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/extension/page.js) — `extension/page.js`.
- [R09](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/extension/background.js) — `extension/background.js`.
- [R10](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/extension/relay.js) — `extension/relay.js`.
- [R11](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/extension/manifest.json) — `extension/manifest.json`.
- [R12](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/BrowserBridge.swift) — `Sources/ContextRecorder/BrowserBridge.swift`.
- [R13](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/process_session.py) — `scripts/process_session.py`.
- [R14](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/SessionData.swift) — `Sources/ContextRecorder/Library/SessionData.swift`.
- [R15](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/SessionModel.swift) — `Sources/ContextRecorder/Library/SessionModel.swift`.
- [R16](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/SessionView.swift) — `Sources/ContextRecorder/Library/SessionView.swift`.
- [R17](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/SessionTimeline.swift) — `Sources/ContextRecorder/Library/SessionTimeline.swift`.
- [R18](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/Review.swift) — `Sources/ContextRecorder/Library/Review.swift`.
- [R19](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/viewer.html) — `scripts/viewer.html`.
- [R20](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Export/PgmExport.swift) — `Sources/ContextRecorder/Export/PgmExport.swift`.
- [R21](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/build-app.sh) — `scripts/build-app.sh`.
- [RTREE](https://api.github.com/repos/byronwall/context-recorder/git/trees/016684895df51872aeea1be5e93e28419fd63a7f?recursive=1) — exact-ref recursive tree; `truncated:false`.

- [E01](https://raw.githubusercontent.com/opencv/opencv/4.14.0/modules/imgproc/include/opencv2/imgproc.hpp) — OpenCV phase correlation API and 4.14.0 declarations.
- [E02](https://docs.opencv.org/4.13.0/d7/df3/group__imgproc__motion.html) — OpenCV motion-analysis documentation.
- [E03](https://docs.opencv.org/4.13.0/dc/d6b/group__video__track.html) — OpenCV tracking and ECC registration.
- [E04](https://docs.opencv.org/4.13.0/d9/d0c/group__calib3d.html) — OpenCV robust fitting.
- [E05](https://pypi.org/project/opencv-python-headless/4.14.0.94/) — OpenCV Python headless 4.14.0.94 package record.
- [E06](https://numpy.org/doc/stable/license.html) — NumPy license.
- [E07](https://developer.apple.com/documentation/vision/vntranslationalimageregistrationrequest) — Apple Vision translation registration.
- [E08](https://github.com/Brkgng/ScrollSnap) — ScrollSnap macOS project.
- [E09](https://raw.githubusercontent.com/Brkgng/ScrollSnap/main/ScrollSnap/Managers/StitchingManager.swift) — ScrollSnap native stitching implementation.
- [E10](https://github.com/Haruhiyuki/scrollsnap) — scrollsnap traceable reconstruction project.
- [E11](https://raw.githubusercontent.com/Haruhiyuki/scrollsnap/main/pyproject.toml) — scrollsnap package metadata.
- [E12](https://raw.githubusercontent.com/Haruhiyuki/scrollsnap/main/CHANGELOG.md) — scrollsnap changelog.
- [E13](https://www.wisdom.weizmann.ac.il/~irani/abstracts/mosaics.html) — Efficient representations of video sequences and their applications — Irani et al..
- [E14](https://arxiv.org/abs/1609.08080) — Swipe Mosaics from Video — Reynolds, Haines and Brostow.
- [E15](https://research.adobe.com/publication/video-tapestries-with-continuous-temporal-zoom/) — Video Tapestries with Continuous Temporal Zoom — Barnes et al..
- [E16](https://pixl.cs.princeton.edu/gfx/pubs/Barnes_2010_VTW/index.php) — Video Tapestries author project.
- [E17](https://www.amypavel.com/) — Video Digests author publication listing.
- [E18](https://github.com/ucbvislab/vdigests) — Video Digests author-linked implementation.
- [E19](https://www.microsoft.com/en-us/research/video/dynamosaics-dynamic-mosaics-with-non-chronological-time/) — Dynamosaics: Dynamic Mosaics with Non-Chronological Time.
- [E20](https://developer.chrome.com/docs/extensions/reference/api/pageCapture) — Chrome pageCapture API.
- [E21](https://github.com/rrweb-io/rrweb) — rrweb official repository.
- [E22](https://drafts.csswg.org/cssom-view/#dom-window-devicepixelratio) — CSSOM View specification.
- [E23](https://html.spec.whatwg.org/multipage/media.html#dom-media-currenttime) — HTML media currentTime.
- [E24](https://html.spec.whatwg.org/multipage/canvas.html#security-with-canvas-elements) — HTML canvas security.
- [E25](https://ffmpeg.org/ffprobe.html) — FFprobe documentation.
- [E26](https://ffmpeg.org/ffmpeg.html) — FFmpeg CLI documentation.
- [E27](https://ffmpeg.org/ffmpeg-filters.html#showinfo) — FFmpeg showinfo filter.
