---
title: "Video to canvas — implementation plan"
slug: "video-to-canvas"
phase: plan
status: current
last_updated: "2026-10-13"
---

# Video to canvas — implementation plan

## Plan at a glance

Canvas mode becomes usable early, and stitching accuracy is proven against exact answers before it reaches real footage.

Milestone 1 adds a Canvas mode to the Sessions stage with a source-mapped storyboard. Build canvas asks for a content box through the existing `RegionPicker`. The analysis uses FFmpeg, which the project already depends on, to record exact frame times and pick change cards. Clicking a card switches back to the video at that frame. Nothing new is installed.

Milestone 2 is the riskiest step and happens away from the UI. Fake scroll videos are cut from tall screenshots, so every offset is known. Python + OpenCV and Apple Vision are compared on them, the better one is kept, and joining is hardened against fixed headers, cursors, repeated text, and jumps. Milestone 3 places the resulting columns in Canvas mode and tries them on scripted recordings. Milestone 4 adds the two extras, column PNG export and marking from the canvas, both on existing paths. Milestone 5 is your own use and a go/no-go decision.

Each milestone leaves the app working. Without canvas data, the Sessions window behaves exactly as it does today.

## Implementation strategy

- **First proof:** On a real session, Canvas mode shows change cards. Clicking one switches the stage to the video at that card's exact frame.
- **Primary seam:** `canvas.json` plus `canvas/` images in the session folder. The file is versioned and records the video's SHA-256 and the content box. The analyzer writes it; `SessionModel` reads it. The engine choice stays behind this file.
- **Fast local loop:** `python3 scripts/canvas/test_canvas.py` generates fixtures, runs the analyzer, and checks offsets, refusals, and frame mapping. It needs no app build, recording, or network. Run `swift build` only when UI changes.
- **Local dependencies:** FFmpeg/ffprobe (existing). Milestone 2 adds either OpenCV-headless + NumPy in a pinned optional virtualenv or no Python dependency at all (Vision).
- **Live confirmation:** Two or three scripted recordings under five minutes, then your own sessions.
- **Rollout and rollback:** Build canvas runs only on request. A missing or mismatched `canvas.json` disables the toggle or offers Rebuild. Rollback means deleting `canvas.json` and `canvas/`.

### Material dependency proof strategy

The stitching engine is the only new material dependency. Neither candidate's result can be trusted alone: OpenCV's phase-correlation response is not a correctness probability, and Vision's registration confidence is not either. Every join therefore needs an independent pixel check at source resolution. Both engines run the same fixture contract. Frame timing is the quieter risk: asking the player for a time does not prove which frame appeared, so Milestone 1 checks it with a burned-in counter.

```text
engine + fake scroll clips with known offsets (deterministic)
    → scripted real recordings, checked by eye
    → your own sessions
```

## Milestone 1: Storyboard in Canvas mode

- **Change — Frame index and change cards in `scripts/analyze_canvas.py`**
  - Decode with FFmpeg `showinfo` to get frame number, PTS, time base, size, and SHA-256. Compare downscaled frames inside the content box to find changes, and save one image per card under `canvas/`.
  - Test: a fake clip with a burned-in frame counter and three known changes yields three cards with correct frame numbers. A blinking cursor yields none.
- **Change — Build canvas action**
  - Add a toolbar or menu action. It opens `RegionPicker` on the current frame for the content box, then runs the analyzer the same way `Review.reprocess` runs `process_session.py`. It shows progress and errors.
  - It never runs during capture or `reprocess`.
- **Change — Canvas stage mode**
  - Add a toggle on `Stage` that swaps `PlayerSurface` for a horizontally scrolling card strip. Clicking a card calls `SessionModel.seek` and returns to video. Hovering sets a preview time that drives `NowStrip` and the inspector transcript.
  - Test: after a click, the visible frame counter on the fake clip matches the card's frame.

### Desired end state

- A real session has a usable storyboard in Canvas mode.
- Sessions without canvas data are unchanged.
- Editing a note does not rebuild the canvas.

## Milestone 2: Engine choice and joining on fake clips

- **Change — Fixture generator `scripts/canvas/make_fixtures.py`**
  - Crop a moving window over tall PNG fixtures with FFmpeg. Cover smooth scroll, reversal, fast jump, fixed header, cursor overlay, repeated rows, blank gap, and a mid-scroll edit. Write the true offsets beside each clip.
- **Spike — Engine bake-off**
  - Decision required: Python + OpenCV, possibly with scrollsnap, or a small Swift/Vision analyzer.
  - Evidence to gather: Run both on the fixtures. Compare p95 offset error, false joins, refusals, runtime, and install cost. Check scrollsnap's license and source-URL mismatch before reuse.
  - Fallback: OpenCV phase correlation plus our own verification. Keep only one engine either way.
- **Change — Join, verify, refuse**
  - Join within the content box and verify the overlap at source resolution. Require unique support, and refuse with a reason otherwise. Choose seams that avoid text rows. Each patch keeps its frame, source rectangle, and offset in `canvas.json`.
  - Test: `test_canvas.py` requires p95 ≤ 2 px, zero false joins, and a refusal on every jump or edit fixture.

### Desired end state

- One engine is chosen and recorded in the initiative map.
- The fixture suite passes locally in seconds.
- Thresholds are frozen before real footage.

## Milestone 3: Tall columns in Canvas mode

- **Change — Column layout**
  - Lay columns out left to right with cards between them. Rejected joins fall back to Milestone 1 cards. Clicking any point resolves to its patch's frame and seeks there. Recordings are under five minutes, so whole columns may load as images, with a simple size guard.
- **Change — Scripted recordings**
  - Record two or three walkthroughs at fixed zoom. Each scrolls several viewport heights, makes one edit, and makes one jump.
  - Test: check five clicks per column against the visible frame. Inspect seams for cut or doubled glyphs.

### Desired end state

- Each scripted clip shows readable columns, a card for the edit, and a refusal card for the jump.
- Every visible patch returns to its true source frame.

## Milestone 4: Export a column and mark from the canvas

- **Change — Copy or export column PNG**
  - Add **Copy Image** and **Export PNG…** to the column context menu. Name the file with the session and time range. The image may combine several moments.
- **Change — Mark from canvas**
  - Drag a rectangle on a column. Use the patch under it to get the source time and rectangle, seek there, and call the existing `addReviewShot(region:)`. The mark then flows through reprocessing, Markdown, and export like any review mark.
  - Test: the new mark's time and crop match the selected content. Reprocessing keeps it.

### Desired end state

- A column can be copied or exported.
- A canvas selection produces a normal review mark.

## Milestone 5: Decide from real use

- **Change — Personal use**
  - Use Canvas mode on several of your own sessions. Note where it beat scrubbing and where it failed.

### Desired end state

- The initiative map records a decision to continue, narrow to the storyboard, or stop.

## Open decisions and spikes

- **Engine:** Python + OpenCV vs Apple Vision, decided by the Milestone 2 bake-off.

## Below the cut line

- Changed states beside earlier states, return arrows, motion posters, and card stacks
- Automatic content-area detection
- Tiling and long-session memory work for recordings over five minutes
- Lecture mode
- Product Grid canvas export
- HTML viewer canvas
- Browser scroll instrumentation
- Token-level transcript alignment
