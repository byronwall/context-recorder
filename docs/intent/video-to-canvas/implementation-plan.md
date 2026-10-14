---
title: "Video to canvas — implementation plan"
slug: "video-to-canvas"
phase: plan
status: current
last_updated: "2026-10-13"
---

# Video to canvas — implementation plan

## Plan at a glance

Prove the cheapest useful thing first, then add geometry only where it can be checked against known answers.

Milestone 1 builds the source-mapped storyboard: decoded frame times, change-selected cards, and click-to-seek in the existing `viewer.html`. It needs only FFmpeg, which the project already uses. The result is useful by itself, forms the comparison baseline, and becomes the fallback for every join the stitcher refuses.

Milestone 2 introduces the one new dependency, OpenCV/NumPy, and develops scroll joining against synthetic clips. Those clips are cut from tall screenshots with FFmpeg, so every true offset is known. The primary loop is therefore local, fast, and deterministic. Failure cases such as fixed headers, cursors, repeated text, and fast jumps are generated rather than waited for.

Milestone 3 runs the same pipeline on a real 60–90 second walkthrough and puts tall columns and changed states in the viewer. Milestone 4 compares the canvas with the storyboard and ordinary video on real tasks, then decides whether to continue.

The material pushback against the research proof plan is ordering. It begins with stitching on a real recording and treats the storyboard only as a comparison. Here the storyboard ships first and synthetic ground truth comes before real footage. That replaces hand-labeled landmarks with exact answers and leaves a working viewer after every milestone.

## Implementation strategy

- **First proof:** A real session's `viewer.html` shows a change-selected storyboard in which each card seeks the shared player to its exact source frame.
- **Primary seam:** `canvas.json`, a versioned file that `scripts/analyze_canvas.py` writes beside the session and `process_session.py` embeds inline when present and valid. The viewer reads only this file.
- **Fast local loop:** `python3 scripts/canvas/test_canvas.py` regenerates synthetic clips from fixture images, runs the analyzer, and checks offsets, refusals, and source mapping. It needs no recording, network, or app build.
- **Local dependencies:** FFmpeg/ffprobe, already required, plus OpenCV-headless and NumPy in an optional, pinned virtualenv used only by the analyzer.
- **Live confirmation:** One or two real narrated walkthroughs copied into a disposable folder.
- **Rollout and rollback:** The analyzer is never called automatically. Without `canvas.json`, or with a version or video-hash mismatch, the viewer behaves exactly as it does today. Rollback means deleting `canvas/` and `canvas.json`.

### Material dependency proof strategy

OpenCV is the only new library. Its phase correlation returns an estimate, not a calibrated correctness probability. Every join therefore passes an independent pixel-difference check at source resolution, and both steps are tested against synthetic ground truth before real footage. FFmpeg frame timing is a quieter risk: requested seek time is not proof of the displayed frame, so Milestone 1 checks it directly.

```text
analyzer core + synthetic clips with known offsets (deterministic)
    → real disposable recording, human-checked
    → small task comparison vs storyboard and video
```

## Milestone 1: Source-mapped storyboard in the viewer

This proves the source-mapping foundation and gives the canvas a fallback before any stitching exists.

- **Change — Frame index in `scripts/analyze_canvas.py`**
  - Decode with FFmpeg `showinfo`; record frame number, PTS, time base, size, and video SHA-256.
  - Test: a synthetic clip with a burned-in frame counter decodes to the expected numbers and times, including the first and last frames.
- **Change — Change-selected cards**
  - Use a cheap downscaled difference at the recorded cadence. Each card keeps its frame, interval, and reason.
  - Test: a synthetic clip with three known changes yields three cards. A blinking cursor yields none.
- **Change — `canvas.json` and viewer embedding**
  - `process_session.py` inlines valid canvas data next to `DATA`. `viewer.html` renders a card strip and a transcript rail grouped by card interval. Clicking a card seeks the existing video.
  - Test: after a seek, the displayed frame number, read from the burned-in counter, equals the card's frame.

### Desired end state

- Running the analyzer on a session produces a working storyboard in `viewer.html`.
- A session without canvas data looks unchanged.
- Editing a note and reprocessing does not rerun analysis.

## Milestone 2: Scroll joining proven on synthetic clips

This adds OpenCV in isolation, with exact answers, before real footage.

- **Change — Fixture generator `scripts/canvas/make_fixtures.py`**
  - Crop a moving window over tall PNG fixtures with FFmpeg: smooth scroll, reversal, fast jump, fixed header, cursor overlay, repeated rows, blank gap, and mid-scroll edit.
  - Write the true offsets beside each clip.
- **Spike — scrollsnap reuse**
  - Decision required: adopt a pinned component or write about 200 lines on OpenCV directly.
  - Evidence to gather: Run its stitcher on the fixtures and compare error, refusals, and license or provenance. Its metadata points to a different source URL.
  - Fallback: Use our own phase correlation plus a verification pass.
- **Change — Join, verify, refuse**
  - Estimate translation within the selected viewport. Verify the overlap at source resolution, require unique support, and refuse with a reason. Choose seams that avoid glyph rows. Every output patch keeps its frame, source rectangle, and translation.
  - Test: `test_canvas.py` asserts p95 error ≤ 2 px, zero false joins, and a refusal for every jump or edit fixture.

### Desired end state

- The fixture suite passes locally in seconds.
- The analyzer emits tall columns and changed states in `canvas.json`. Refused joins fall back to Milestone 1 cards.
- Thresholds are frozen before Milestone 3.

## Milestone 3: Real walkthrough on the canvas

- **Change — Record and run the target clip**
  - Use 60–90 seconds at fixed zoom: three viewport heights of scrolling, one edit, and one jump. Copy it to a disposable folder.
  - Select one viewport manually. No manual offsets are allowed.
- **Change — Canvas layout in `viewer.html`**
  - Place tall columns left to right and changed states to the right of their predecessors. Show refused joins as cards. Clicking any point resolves to its patch's frame.
  - Test: check five random clicks per column against the burned-in or visible frame. Inspect seams for cut or doubled glyphs.

### Desired end state

- The real clip produces one readable tall view, one separate changed state, and one refusal card.
- Every visible patch seeks to its true source frame.

## Milestone 4: Decide whether the canvas earns its cost

- **Change — Small task comparison**
  - Use ordinary video, the Milestone 1 storyboard, and the canvas on a second real walkthrough. Rotate order across tasks: find content, compare the edit, find the narration, and return to source.
  - Record time, errors, selection or correction time, analysis time, and peak memory. Include your own judgment.

### Desired end state

- A written go/no-go decision is recorded in the initiative map.
- If the canvas does not clearly beat the storyboard, keep the storyboard and stop.

## Open decisions and spikes

- **Viewport selection:** Manual selection keeps the proof small. Automatic detection is a later spike only if selection proves annoying.
- **Test clips:** Purpose-made clips give clean ground truth. If only existing sessions are allowed, Milestone 3 uses the closest existing session and the plan notes the weaker evidence.

## Below the cut line

- Motion posters, frame stacks, and in-place playback
- Return detection and arrows
- Larger-than-frame capture and Product Grid composite export
- Lecture and slide mode
- Native SwiftUI canvas
- Browser scroll instrumentation
- Tiling and long-session memory work beyond a basic guard
- Raw token-level transcript alignment
