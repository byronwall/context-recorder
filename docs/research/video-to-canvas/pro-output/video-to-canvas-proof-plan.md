# Video-to-canvas proof plan

**Status: proposed; all media, reconstruction, application and user-task experiments are UNRUN.**

Decision supported now: **CONDITIONAL GO to a bounded proof**, not feature approval. Research date: October 13, 2026, America/Indiana/Indianapolis. Repository `byronwall/context-recorder`, exact baseline `016684895df51872aeea1be5e93e28419fd63a7f`, plus the supplied local intent brief. No recording or runnable checkout was supplied. The companion report answers the five ranked research questions; this document is a standalone execution contract for the later local proof.

## 1. Hypothesis, scope and decision order

**Hypothesis:** In a narrated product walkthrough with one fixed-scale scrolling viewport, source-linked spatial reconstruction helps Byron locate, compare and capture content more effectively than raw video or a change-selected storyboard, without creating misleading joins or losing changes.

**Initial supported scope proposal:** upright, square-pixel screen video; one selected rectangular viewport; predominantly vertical translation; sufficient overlap; unchanged layout within a state. Browser metadata and audio are optional. One viewport selection per clip is permitted and timed. Per-frame alignment corrections are not permitted in automatic scoring.

**Explicitly outside the first automatic-stitch scope:** unknown scale changes, full-window nested motion, virtualized/reordered content without reliable identity, unobserved jumps and arbitrary camera video. Such inputs still require useful timestamped cards and source playback, not an exception or a guessed reconstruction. Lecture slides/code remain part of the corpus and broader storyboard path.

Recommendations: **VC-01** evidence contract; **VC-02** guarded translation; **VC-03** offline cache; **VC-04** HTML/shared clock; **VC-05** changes/motion/returns; **VC-06** time/pixel/transcript mapping; **VC-07** bounded tiles/export; **VC-08** optional browser hints; **VC-09** decisive gates.

Evaluate truth first, geometry second, personal value third, resources/regression fourth. Do not compensate for a harmful join with higher coverage or lower runtime. Allow at most one targeted method revision before an explicit decision to narrow or stop; the point is not to build a benchmark platform.

## 2. What has actually been checked

| Check | Status and result |
|---|---|
| Connected GitHub `Package.swift` at exact ref | **EXECUTED — PASS.** One macOS 26 Swift executable target. |
| Exact-ref recursive Git tree | **EXECUTED — PASS.** `truncated:false`; required paths present; no package.json/test suite/sample recording found. |
| Packet manifest validation | **EXECUTED — PASS.** All 23 extracted entries match declared byte sizes and SHA-256. |
| Separate prompt versus packet prompt | **EXECUTED — PASS.** Byte-for-byte identical. |
| Required source reading | **EXECUTED.** All 21 selected baseline files plus the local brief and prompt; not an audit of every other source file. |
| Python AST parse of `scripts/process_session.py` | **EXECUTED — PASS.** Parsing only; no processor execution. |
| Node syntax checks | **EXECUTED — PASS.** `extension/page.js`, `background.js`, `relay.js` and the one embedded script in `scripts/viewer.html`. |
| Extension manifest JSON parse | **EXECUTED — PASS.** |
| `bash -n` on `scripts/build-app.sh` | **EXECUTED — PASS.** Syntax only. No build, signing or installation. |
| External primary-source research | **EXECUTED.** API/source/project/license review; retrieval limits recorded in sources document. |
| `swift build`, app launch, processor `--help`/processing | **UNRUN.** Linux research runtime is not the required macOS application environment. |
| Dependency resolution/import, ffprobe/ffmpeg on recordings | **UNRUN.** No dependency installation or media execution performed. |
| Synthetic registration, corpus evaluation, performance, usability, export | **UNRUN.** No source video or generated video experiment exists in this assignment. |

Artifact structure/hash validation is separate from product validation. JSON parsing or a mathematically consistent example does not prove the proposed pipeline works.

## 3. Small corpus, with ground truth defined before scoring

Create eight short directed clips, typically 30–90 seconds each, using a local controlled page/slide/code setup. These are proposed fixtures, **not included recordings**. Use a capture configuration that approximates `Recorder.start`: requested 15 fps, width capped at 1920, H.264 target 4 Mbps and cursor visible. Record actual dimensions, timestamps and codec settings rather than assuming they were achieved. Include a lossless/reference rendering only as ground truth, not as the evaluation input. [R03](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Recorder.swift)

| Clip | Required actions and visual content | Ground truth and expected outcome |
|---|---|---|
| **C01 clean + reversal** | Static page with distinctive section labels; slow/medium scroll down three viewport heights, pause, reverse upward. | Known rendered section coordinates and decoded-frame landmarks. Accept supported joins; preserve return traversal without duplicating content geometry. |
| **C02 sticky + transient UI** | Fixed header, a sticky subheading entering/leaving its threshold, tooltip, moving cursor, caret and selected text. | Overlay/pane masks and exact source intervals. Do not repeat headers down the page; preserve transient evidence; split ambiguous sticky transitions. |
| **C03 multiple geometry** | Independent nested pane scroll, then whole-window move, resize and browser zoom. | Pane bounds, selected scope and scale-change times. Full-window stitching must refuse; independently scoped pane can be tested separately without relabeling the original failure. |
| **C04 edits + unstable content** | One-digit edit, inserted paragraph, lazy-loaded image, then a virtualized list with recycled/reordered rows. | Named old/new values and last-old/first-new witness frames; layout/row-identity annotations. New states/charts or refusal, never overwritten evidence. |
| **C05 jumps + ambiguity** | Fast scroll with some recoverable intermediate frames, a true no-overlap jump, blank area and repeated rows with a misleading offset. | Known displacement where observed; no claimed displacement across true gaps. This is an adversarial wrong-join test, not a coverage target. |
| **C06 return identity** | A→B→A, same URL with changed content, a visually similar different page and a repeat of a slide. | Distinct visit IDs and scoped identity/change annotations. At least ten positive and ten negative candidate pairs across variations for a later return test; report the finite count. |
| **C07 motion + brief change** | Spinner, expanding control, animated chart/embedded clip, changes visible for 0.25/0.5/1 second. | Exact visible frame ranges and semantic edits. Required ≥0.5-second changes survive in a state/card or explicit motion interval. Report 0.25-second failures separately. |
| **C08 slides + code** | Slide build, code scroll, code edit, repeated slide and speaker/video region; no browser log supplied to analysis. | Slide/build IDs, code landmarks, visit and motion intervals. Preserve temporal cards; stitch only eligible code scrolling. |

Use variants of C01, C02 and C04 for **development/calibration**. Freeze thresholds and the eligible-scope declaration before held-out variants and C03/C05–C08. Do not label difficult regions “ineligible” after inspecting failures. Record eligibility time/area, all attempted joins, accepted joins, rejected joins and reasons.

Add **two actual narrated product walkthroughs, R01 and R02**, each roughly 3–5 minutes and using different content/actions. They can be newly recorded on controlled local products; no private browsing history is needed. Require both before feature GO. Add **one authorized supplied lecture file R03** for lecture-specific acceptance; without it, lecture robustness stays explicitly unresolved. Do not fetch YouTube or private recordings as part of this plan.

Ten-/sixty-minute resource workloads may be assembled from many distinct controlled variants. Looped identical content can make deduplication unrealistically easy, so include enough unique surfaces/states to reach the declared image budget. These workloads measure scaling only, not real-recording generalization.

### Ground-truth procedure

Assign stable visible landmark IDs to section edges, labels and code lines in the controlled setup. Record renderer/container coordinates and event times, then verify them against decoded recorded pixels. Ground truth uses only content that actually appeared in the encoded video. Offscreen DOM size does not count as observed coverage.

For each clip, manually annotate a small set of source-frame landmark correspondences, content-change witness pairs, motion spans, visit identities, occlusions and unsupported transitions. Inspect at native source resolution. Use decoded frame PTS as the final time reference, not browser event receipt time. For an edit seen only after returning, ground truth is an interval between witnesses, not the unobserved edit instant.

Store annotations in one compact JSON per clip. Record annotator, source digest and uncertainties. A second pass audits disputed joins/changes; no large annotation framework is required. For real recordings, mark 15–30 distributed landmarks and all task-relevant changes manually. Do not use the stitcher's own matches as ground truth.

## 4. Staged experiments

### P0 — local baseline and provenance contract [UNRUN]

**Input:** disposable copy of one real Context Recorder session and C01's controlled reference. **Purpose:** confirm source identity, environment and temporal/pixel mapping before evaluating reconstruction.

Read source video digest, stream dimensions, time base, rotation, sample aspect ratio and decoded frame PTS. Establish the mapping to the player's media timeline. Check first frame, final frame, pauses, irregular frame gaps and any stream start offset. Keep an output-ordinal/PTS correspondence when extracting images; verify equal counts and ordering. A small FFmpeg `showinfo` audit can support this, but no chosen command is accepted until its timestamps are checked against FFprobe. [E25](https://ffmpeg.org/ffprobe.html) [E26](https://ffmpeg.org/ffmpeg.html) [E27](https://ffmpeg.org/ffmpeg-filters.html#showinfo)

Verify translation sign using a known downward scroll: content moves upward in the next viewport, while its placement in page coordinates increases. Test top-left origin conversion, crop bounds, negative surface coordinates and inverse mapping. Source-space round trips should be exact for integer translations.

Open ordinary video, marks, transcript and a review shot in the baseline. Note that current mark JPEG extraction does not store actual decoded time, and `Review.saveFrame` ignores the returned actual time; the new evidence path must not reuse these assumptions. [R13: `extract_frame`](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/process_session.py) [R18: `saveFrame`](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/Sources/ContextRecorder/Library/Review.swift)

**Reject outcome:** unresolved PTS/media mapping, unsupported rotation/SAR, incorrect source dimensions or mutation of canonical input blocks further claims. Fix the measurement path first. This stage does not test stitching accuracy.

### P1 — one distinctive spatial reconstruction [UNRUN]

**Input:** C01 development variant, followed by a frozen holdout and the first actual narrated walkthrough. **Ground truth:** visible landmark positions and source-frame witnesses.

Use one scoped viewport, a native-cadence low-resolution sentinel and nominal 2 Hz candidates. Check the viewport boundary/adjacent chrome guard for window movement before treating content displacement as scroll. Fit phase-correlation translation; verify at source resolution with integer offsets, independent spatial support and local residual checks. Reject insufficient overlap and competing repeated-row displacements. Retry with nearer recorded frames rather than lowering the truth gate. No feature matcher, optical-flow warping or browser offset oracle is added in this first comparison. [E01](https://raw.githubusercontent.com/opencv/opencv/4.14.0/modules/imgproc/include/opencv2/imgproc.hpp) [E02](https://docs.opencv.org/4.13.0/d7/df3/group__imgproc__motion.html)

Materialize a surface spanning at least two viewport heights. Show source seams and click several patches to retrieve their contributor frames. Force a no-overlap transition and an incorrect repeated-text candidate; neither may be stitched. Add one visible edit: it must create a new state/card without inheriting unobserved old pixels.

Run two non-stitching comparators on the same frames: **B0 raw video** with existing timeline/transcript, and **B1 change-selected keyframes** with the same decode/candidate budget and access to marks/transcript, but using unregistered viewport differences rather than a spatial reconstruction. Select start/end anchors and meaningful changes, suppress near-duplicates, impose a maximum temporal gap, and retain source intervals/playback. Freeze its difference threshold on the development clips. B1 must be competent, not a deliberately sparse five-second grid. Also compare fixed 1/5/10-second sampling once on C01/C07 to expose the sampling tradeoff; this is an ablation, not three additional permanent systems.

**Reject outcome:** no valid ≥2-viewport result, excessive drift, lost edit, false join or source-time error. First adjust one diagnosed cause. If otherwise eligible clean scrolling still requires manual offsets, stop stitching work and retain B1.

### P2 — refusal, state changes and identity stress [UNRUN]

**Input:** frozen held-out C02–C08 variants and both actual walkthroughs. **Procedure:** evaluate every attempted transition and all named semantic edits; separate geometry acceptance from content-change preservation.

Evaluate all confidence components, not only a final scalar. Proposed calibration seeds: ≥60% overlap; phase response 0.6; three informative distributed regions; regional agreement within 2 source pixels; aligned grayscale residual median ≤6/255 with coherent-change inspection above 12/255; materially different runner-up displacement at least 20% worse in verification error. Sweep these on development data only. Report the selected parameters and disagreements.

A full-window nested pane should refuse. Re-running with a single scoped pane is a separate scope experiment, not retroactive success. Fixed-header masks cannot hide the tooltip/selection from history. A same-URL changed page is not the same visual state. For return detection, shortlist with metadata/visual summaries, then verify a distinct region at both visits. If return detection is not implemented, mark that metric unrun; do not claim zero false positives by omitting the feature.

**Optional single escalation:** if clean/eligible failures are dominated by local occlusion or phase ambiguity, compare one translation-constrained feature method **or** a pinned reusable scrollsnap component on the same heldout set. Native Vision is an alternative when packaging is the blocker. Do not build a permanent ensemble. A browser-hint ablation belongs later only if viewport/scroll identity specifically blocks value. [E04](https://docs.opencv.org/4.13.0/d9/d0c/group__calib3d.html) [E07](https://developer.apple.com/documentation/vision/vntranslationalimageregistrationrequest) [E09](https://raw.githubusercontent.com/Brkgng/ScrollSnap/main/ScrollSnap/Managers/StitchingManager.swift) [E10](https://github.com/Haruhiyuki/scrollsnap) [E11](https://raw.githubusercontent.com/Haruhiyuki/scrollsnap/main/pyproject.toml)

**Reject outcome:** any harmful accepted join blocks that mode. Predominant abstention on the primary case narrows or rejects stitching. Safe refusal on declared unsupported cases is correct but must not inflate the useful-coverage metric.

### P3 — smallest HTML slice and personal-value comparison [UNRUN]

**Input:** a 60–90 second narrated clip with three viewport heights, one edit and one deliberate jump. **Output:** stitched observed surface, rightward edited-state card, refusal card, exact patch click-to-video, sentence rail and B0/B1 views. One viewport selection is allowed; no manual alignments. Automatic revisits and composite export are not required to establish this initial interaction slice.

Use existing local `viewer.html` as the proof surface. Share its video element and timeline rather than creating a player per tile. Inline validated canvas data through `write_viewer`; avoid `fetch()` of sidecar JSON in local-file mode. Test click/seek and keyboard behavior in the installed Chrome and Safari versions, recording those versions. Rendering/seek completion must be observed; setting `currentTime` alone is not proof of the displayed frame. [R13](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/process_session.py) [R19](https://github.com/byronwall/context-recorder/blob/016684895df51872aeea1be5e93e28419fd63a7f/scripts/viewer.html) [E23](https://html.spec.whatwg.org/multipage/media.html#dom-media-currenttime)

For the later full G3 comparison, add bounded composite selection/export, then use **six matched task triplets (18 timed trials)**: two field-finding triplets, two changed-value/explanation triplets and two later-visit/narration triplets. Each triplet uses three comparable content instances, assigned once each to B0, B1 and canvas. Rotate condition order and assignment to reduce learning effects. Add **one capture triplet (three trials)** for a meaningful region larger than one viewport. The total is 21 small trials, not a large benchmark. Report each matched result, not only one average; compare relative times within triplets before aggregating.

Record task accuracy, completion time, wrong-time selections, viewport-selection time and correction time. Count failures and timeouts consistently. A baseline that cannot produce the requested composite has a capture-task failure; do not include an invented completion time in the median speed comparison. Analyze capture success separately. Byron's preference and workload value matter; this is a personal decision study, not statistically generalizable evidence.

### P4 — resources, cache and non-regression [UNRUN]

**Input:** 10-/60-minute workloads with declared unique-content counts; a copied real session with review marks/notes. **Procedure:** measure worker process and child-process peak memory, wall time, output bytes, candidate counts, tile counts and viewer incremental memory above the same video-only page. Record Mac model, RAM, OS, Python/NumPy/OpenCV/FFmpeg/browser versions, thermal/power state and whether caches were cold.

Use 1024×1024 maximum evidence tiles and an explicit 12-tile decoded LRU target. Inspect long sessions at overview and native scale, then pan through enough content to expose retained-image growth. Measure browser/GPU behavior where tooling permits and disclose gaps; JavaScript heap alone is not total memory. Test budget exhaustion and partial failures: they must produce labeled fallback output, not corrupted geometry.

Change only a note, reprocess the session, and verify geometry analysis is not rerun. Change the video digest or viewport parameters and verify stale canvas/override data is rejected. Remove/malform the sidecar and confirm ordinary video/marks/transcript remain usable. The original input session must retain all hashes. On the disposable copy, permit only the intended marks.jsonl note edit and the normal regenerated outputs; video, capture logs and original still/archive evidence must remain unchanged. Do not rerun model transcription merely to exercise canvas code.

### P5 — milestones after the initial slice [UNRUN]

| Milestone | Minimal addition | Separate acceptance condition |
|---|---|---|
| Motion inspection | Poster + source interval, one-player loop and explicit stack expansion | Named C07 motion/required-change intervals are reachable and never flattened into a false static state. |
| Verified returns | Distinct later visit, scoped witness match, explicit earlier-visit jump/back | Finite positive/negative candidate test reports precision, recall and abstention; zero false confirmed links. |
| Transcript refinement | Raw token-source references and splits at visual boundaries where timing supports them | Source token/sentence pointers remain valid; no invented times or automatic claim of pixel-level semantic grounding. |
| Composite capture | Surface selection, bounded lossless PNG/parts plus provenance JSON | Every output patch reverses to its own source pixels/time; multi-time and unknown areas labeled. |
| Native integration | Canvas beside Stage, existing AVPlayer/shared playhead | Existing review/marks/exports behavior preserved; no second time source. |
| Browser assistance | Measured viewport/container geometry and calibrated clock, only for a diagnosed failure | Paired video-only/hinted clips reduce abstention without adding wrong joins or unseen DOM pixels. |

These are options gated by evidence, not a promise that every milestone ships.

## 5. Metrics and decisive gates

### Metric definitions

**Useful content coverage:** unique, task-relevant *observed* content area represented legibly in valid spatial geometry divided by the corresponding observed eligible area. For controlled pages, use the union of annotated visible surface rectangles per state, excluding genuine occlusions and counting changes separately. Report a second end-to-end storyboard coverage measure including cards, but do not let cards satisfy the spatial coverage gate. Report declared ineligible/unknown area separately.

**Registration error:** Euclidean source-pixel displacement error at independently annotated overlap landmarks, after the proposed transform. Report median, p95, maximum and accumulated drift at re-observed anchors. Algorithm residual/confidence is not ground truth.

**Bad stitches:** accepted joins that misplace, duplicate, truncate or semantically mix content. Report numerator and attempted/accepted-join denominators, with worst-case crops. Any wrong state merge or invented observed region is harmful even if average geometric error is low. With zero accepted joins, error is “not established,” not zero.

**Lost changes:** required ground-truth semantic edits visible for at least 500 ms that lack a distinct state/card or an explicit motion interval covering the change. A generic link to the entire raw video is insufficient. Report 250 ms and other shorter changes separately. Include one-digit changes, not just large scene cuts.

**Revisit precision/recall:** true scoped matches divided by confirmed links; correctly linked eligible returns divided by annotated returns. Count false links between similar pages and changed states; report withheld candidates. No links means precision unavailable and recall zero, not a passing detector.

**Source-time/pixel mapping:** percentage of displayed/exported ownership regions with valid source digest, frame PTS, in-bounds rectangle and invertible transform. Sample at least 30 patch points across first/last frames, seams, negative coordinates, states and visits. Compare the presented player frame with the stored witness; error is measured relative to the actual local frame interval, not nominal fps alone.

**Readability:** transcribe a fixed small set of task-relevant labels/numbers/code lines from source frames and reconstructed views at matched scale. Report exact-match errors and cut/ghosted/duplicated glyphs. Use human reading; no OCR dependency is required. Count information already illegible in the recording separately rather than claiming reconstruction recovers it.

**Resource cost:** decode/analysis/materialization time separately; output bytes by asset class; peak worker plus children; incremental viewer memory; cold first-open time; frame/candidate/abstention counts. Corrective work and viewport selection are user costs.

### G1–G4: thresholds are proposals, not measurements

| Gate | Proposed pass rule | Decision on failure |
|---|---|---|
| **G1 truth/provenance** | Zero harmful joins and zero lost required changes in scored finite corpus; p95 registration ≤2 source pixels, max ≤4; 100% patch provenance valid; click/seek within one actual adjacent-frame interval; no reconstruction-added readability errors on the selected labels; zero false confirmed returns when enabled. | Block affected stitched/return mode. A targeted fix may be tested once; otherwise retain cards. |
| **G2 spatial usefulness** | ≥90% clean-scroll observed eligible coverage in valid geometry, and ≥2 viewport heights reconstructed automatically. Report harder-case coverage and all abstention. | Narrow only if the remaining scope still serves real tasks; stop if clean scrolling needs manual alignment. |
| **G3 personal value** | No accuracy loss; median completion time on comparable tasks ≥20% lower than the stronger B0/B1 baseline; useful larger-than-frame capture succeeds with provenance. Include correction/setup cost. | Prefer a simpler storyboard if the extra geometry fails to earn its cost. Do not claim statistical significance. |
| **G4 local cost/regression** | Worker+child peak RSS ≤512 MiB; incremental viewer peak ≤256 MiB; total analysis ≤recording duration on the declared Mac; canvas images ≤350 MB/10 min and ≤2.1 GB/hour with labeled fallback; no canonical mutation or loss of ordinary review. | Diagnose/optimize one bottleneck or narrow; stop if the workflow remains expensive or fragile. |

G1 is mandatory. G2 must be met on actual primary-case content as well as the clean fixture before feature GO. G3 requires the small user-task trial; G4 requires measured workloads. Passing only synthetic C01 is **not** a completed feasibility result. Zero errors in this finite corpus is not a guarantee of zero errors in future recordings.

## 6. Concrete repository integration plan

All names below describe **future changes**, not files created in this repository during research.

| Proposed seam | Baseline source and exact symbols | Scope |
|---|---|---|
| Optional offline analyzer | New `scripts/analyze_canvas.py`; `scripts/process_session.py` functions `main`, `write_viewer` | Explicit analysis command first. Processor may embed a valid sidecar, not implicitly analyze on every run. |
| Canvas and playback | `scripts/viewer.html`: `DATA`, `video`, `renderNow`, `select`, `lightbox` | New DOM tile/patch surface; same video clock. Existing lightbox is only a single-image reference. |
| Native follow-on | `Library/SessionModel.swift`: `seek(_:play:)`, `currentTime`, `reload`; `SessionView.swift`: `SessionView`, `Stage`; `SessionTimeline.swift`: `SessionTimeline` | One small optional canvas type/view after HTML value is proven. Preserve shared playhead. |
| Review/cache boundary | `Library/Review.swift`: `setNote`, `addReviewShot`, `saveFrame`, `reprocess` | No expensive reconstruction for note changes. Composite selection is not a current-frame region shot. |
| Raw evidence access | `Session.swift`: `addBrowserEvent`, `appendLine`; `page.js`: `snapshot`, `viewportOrigin`; `SessionData.swift`: `PageSnapshot` | Read raw JSON for geometry/clock fields excluded by native projection. Current snapshots are not continuous scroll measurements. |
| Optional instrumentation | `main.swift`: `bridge.onEvent`, `pointerPayload`; `background.js`: `send`, `handle`; `BrowserBridge.swift`: `request`, `handle` | Only after a demonstrated need. Handle queues, active-tab identity and clock uncertainty. |
| Export follow-on | `Export/PgmExport.swift`: `PgmExporter.run`, `imageFiles(for:)`, `ExportRecord` | Existing mark export remains unchanged. Add composite image/provenance semantics deliberately. |
| Packaging follow-on | `scripts/build-app.sh`: explicit processor/template `cp`; `AppDelegate.processScriptURL()` | A new helper must be explicitly bundled. Do not run signing/install script in research. |

The full baseline paths and direct links are listed below. No change to `Recorder` is required for the initial proof. Canonical sources and durable user/export state must remain separate from disposable `canvas.json`, `canvas/` tiles and rendered HTML. Proposed durable corrections live in `canvas-edits.json`, scoped by source digest.

### Small proposed JSON example

This deliberately uses no fabricated source hash or measured scores. It is illustrative, not a supplied fixture. Real output requires a SHA-256, validated stream mapping and actual contributor frames. `span` is a visit's time range, not continuous visibility of every displayed patch. Translation acts on full source-video pixels, before independent canvas layout placement.

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

For example, `p2` source y=544 plus translation y=96 equals surface y=640. The earlier patch owns y=0…640; the new patch owns y=640…896. A click on `p2` seeks to f2 at 2 seconds. A click on the later matching `p4` seeks to f4 at 20 seconds, despite sharing state identity. The edited state does not include unobserved y=0…256. Non-owning overlap witnesses may be retained as additional observation records, but a first-slice rectangular ownership partition is sufficient.

## 7. Later local command run sheet — not executed here

These commands are for a suitable macOS checkout. They do not install dependencies or create the proposed analyzer. Use an existing disposable fixture or explicitly copy a chosen session; no fixture is bundled with this research. The processor rewrites generated session output. Do not point it at an irreplaceable original.

```sh
# Run from the intended repository checkout after Codex has reviewed the design.
# These existing commands were source-verified, not executed in this research.
swift build
python3 scripts/process_session.py --help

# Supply a real local input. This placeholder is NOT an included recording.
SOURCE_SESSION='/absolute/path/to/chosen/session'
test -f "$SOURCE_SESSION/recording.mp4" || exit 1
WORK="$(mktemp -d "${TMPDIR:-/tmp}/video-to-canvas-proof.XXXXXX")"
cp -R "$SOURCE_SESSION" "$WORK/session"

# Process and review only the disposable copy.
python3 scripts/process_session.py "$WORK/session" --before 30 --after 5
swift run ContextRecorder --library "$WORK/session"

# The repository also documents this development-library entry point:
# swift run ContextRecorder --library tmp/

# Proposed analyzer command: NOT AVAILABLE at this baseline; do not run yet.
# python3 scripts/analyze_canvas.py "$WORK/session" --viewport x,y,width,height

# Packaging is not needed for this research/proof. This still builds and signs:
# INSTALL_DIR= ./scripts/build-app.sh
# Leave it unrun until a separate packaging decision.
```

Pin the selected OpenCV/NumPy environment and record its resolved wheel versions/digests during later authorized setup. The candidate OpenCV API is documented and wheels exist; an install/ABI check on the actual Mac remains required. Do not infer that an available wheel has already been tested. [E01](https://raw.githubusercontent.com/opencv/opencv/4.14.0/modules/imgproc/include/opencv2/imgproc.hpp) [E05](https://pypi.org/project/opencv-python-headless/4.14.0.94/) [E06](https://numpy.org/doc/stable/license.html)

## 8. Result record and stop rules

For each stage record `status`, source/corpus digests, analysis parameters, environment, raw metric counts, rejected joins/reasons, representative failure crops, interpretation and gate decision. Distinguish automatic output from corrected output. Keep one compact result table and a few counterexamples; no dashboard service is necessary.

**Feature GO:** G1–G4 pass in the declared primary-case scope, including actual recordings. **Narrow GO:** only a clearly useful supported subset passes; unsupported cases remain labeled cards and claims explicitly name the limits. **NO-GO for stitching:** clean eligible content cannot be reconstructed without harmful joins/manual alignment, source provenance remains unreliable, or the spatial result fails to beat a simpler storyboard after one targeted revision. **Stop broader work:** local cost/regression remains unacceptable or the core benefit is absent. Motion/revisit/lecture failures can stop those milestones independently without inventing support.

## Direct source references

Accessed October 13, 2026. The source ledger contains full coverage and limits. R references use the exact baseline; local intent remains attachment-derived.

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
