---
title: "Session editing: implementation plan"
slug: "session-editing"
phase: plan
status: draft
last_updated: "2026-10-13"
---

# Session editing: implementation plan

## Plan at a glance

The riskiest part of this work is time, not drawing or interface. Every lane in a session is stored as seconds from the start of `recording.mp4`. Cuts and joins change what "seconds from the start" means. So the first milestone proves the segment model end to end, with no editing interface. A hand-written `edits.json` has to produce edited-time context from `process_session.py` and edited-time playback from an AVFoundation composition. Review marks added on the edited session also have to land back at the right original time.

After that, each milestone adds one user-visible capability on the same model:

1. Cutting from the timeline.
2. Joining sessions, which only adds more sources to the same segment list.
3. The annotation layer.
4. The rest of RegionShot's tool set.

Joining comes before annotations because it is the second user of the time model. If a multi-source join needs the model to change, it's cheaper to find out before annotations depend on it.

**The pushback.** Don't let Swift and Python each own their own version of the time conversion. Python is the only place that converts *context* (marks, transcript, activity, page events, narration). It writes the resolved segment table into `session.json`. Swift does only two narrow things with that table: it builds the player's composition, and it converts an edited playhead back to `(source, original time)` when you add something. A shared fixture of conversion cases keeps the two in agreement.

Every milestone leaves the app shippable. A session without `edits.json` behaves exactly as it does today, and deleting `edits.json` always undoes everything.

## Implementation strategy

- **First proof:**
  1. Copy a real session into `tmp/` and hand-write an `edits.json` with cuts at the start, in the middle and at the end.
  2. Reprocess the copy.
  3. Open it with `swift run ContextRecorder --library tmp/`.
  4. Confirm that playback skips the cuts, frames and narration match, and a new review mark keeps the right original time.
- **Primary seam:** the segment table. `edits.json` holds the input: ordered segments of `{source, start, end}`, where `source` is `"."` for the session's own recording or a path relative to the sessions root for joins. `session.json.segments` holds the resolved output, the same segments plus `editedStart` and the source video path. Nothing else crosses between Python and Swift.
- **Fast local loop:**
  1. `python3 -m unittest scripts/test_process_session.py`: pure conversion and filtering, no ffmpeg needed.
  2. `python3 scripts/process_session.py tmp/<copy>`.
  3. `python3 scripts/ui-test/harness.py run --session <fixture>` (the fixture harness merged from main) to look at the result. Screenshots come from `screencapture -l <window id>`.
- **Local dependencies:** the harness's fixture copies in `tmp/ui-test/fixtures` (`harness.py prepare`), and a JSON fixture of conversion cases at `scripts/fixtures/edit-cases.json` shared by the Python tests and a Swift `--self-test edits` launch flag. No network.
- **Live confirmation:** the installed app (`./scripts/build-app.sh`) on a fresh recording, once per milestone.
- **Rollout and rollback:** this is purely additive. Without `edits.json` and `annotations.json` the code paths match today's. Raw files are never written by editing. Deleting either file returns the session to its pre-edit state.

### Material dependency proof strategy

The only difficult dependency is **AVFoundation composition playback** (`AVMutableComposition` + `AVPlayerItem`). It runs locally, so the ladder is short:

```text
pure conversion in process_session.py + shared fixture (unit tests)
    → composition from one source with three cuts, inspected in the debug app (M1)
    → composition across two sources of different size and audio (M3 spike)
    → installed app on a fresh recording
```

Frame extraction stays on ffmpeg at *original* time from the *source* recording. That's why the existing frame cache (`frames/NNN.jpg`, cached by index) stays valid through any cut.

## Milestone 1: A hand-written cut list plays and lines up

This proves the time model with no new interface. It deliberately leaves out range selection, joins and annotations.

- **Change: segment conversion in `process_session.py`**
  - Read `edits.json`, defaulting to one segment covering the whole recording. Validate it: segments are in order, they don't overlap within a source, and each falls within that source's duration.
  - Add pure functions: `resolve(segments)` gives `editedStart` values and the edited duration, and `to_edited(source, t)` gives an edited time, or nothing if `t` falls inside a cut.
  - Apply the conversion when building `session.json`, which then carries `segments` and an edited `duration`:
    - Marks keep `sourceOffsetSeconds` and gain an edited `offsetSeconds`. Marks inside cuts move to `hiddenMarks` rather than disappearing.
    - Activity and page events are converted and filtered. An activity entry that started before a cut carries over to the start of the next kept range, so the "Apps" lane stays continuous.
    - Transcript sentences are kept when more than half survives, with times clamped. Tokens are filtered the same way, so narration windows quote only kept speech.
  - Frames are extracted at `sourceOffsetSeconds` from the source recording, so the cache still works.
  - The Markdown video line becomes `` `<source>/recording.mp4` @ <original>s ``, keeping the reference to real footage.
  - The timeline's hover previews (`FramePreviews`, new on main) read from the same composition, so they show edited time.
  - Verify with `scripts/test_process_session.py` against `scripts/fixtures/edit-cases.json`, covering:
    - a cut at the start, the middle and the end;
    - back-to-back cuts;
    - a mark exactly on a boundary;
    - a sentence split by a cut;
    - an empty or missing `edits.json` matching today's output byte for byte, except for the added `segments`.
- **Change: edited-time playback in `SessionModel`**
  - Decode `segments` in `SessionData`. When there is more than one segment or a non-trivial one, build an `AVMutableComposition` by inserting each segment's time range from its source asset in order. Otherwise keep `AVPlayer(url:)` exactly as now.
  - Rebuild the player item on `reload()` when the segment table changes. Keep the playhead at the same edited time, clamped.
  - Add `EditMap.toSource(editedTime) -> (source, t)`, a pure Swift struct. A debug flag, `--self-test edits`, runs it against the shared fixture and exits with a non-zero code on any mismatch.
- **Change: review marks and shots write original time (`Review.swift`)**
  - Convert the playhead with `EditMap.toSource` before writing `offsetSeconds` to `marks.jsonl`.
  - `saveFrame` reads the source asset at the original time.
  - `recentPageEvents` filters `browser.jsonl` by original time.
  - `wallTime` uses the source folder's timestamp.

- **Spike: seek precision and scrubbing on a many-segment composition**
  - Decision required: is a composition good enough for exact seeking and drag-scrubbing at 15 fps, with 20 or more segments?
  - Evidence to gather: in the debug app, drag the timeline across a dozen cuts and step through marks with J/K. Compare the frame shown with `frames/NNN.jpg`.
  - Fallback: keep `AVPlayer(url:)` on the source and skip removed ranges with a boundary time observer, converting the playhead in `SessionModel.currentTime`. This is only enough for one-source cuts. Joins would then need the composition anyway, so look at that again in M3.

### Desired end state

- A copied session with a hand-written `edits.json` plays without the three removed ranges, and the timeline's duration and lanes are in edited time.
- Every visible mark's frame matches the video at its new time. Narration quotes only kept speech. Hidden marks don't appear.
- A review mark added after the middle cut writes the correct original `offsetSeconds`. Removing `edits.json` and reprocessing puts it back at the same moment.
- The unit tests and `--self-test edits` pass. Sessions without `edits.json` are unchanged.

## Milestone 2: Cut ranges from the timeline

This turns M1's file format into a gesture. It leaves out joins and annotations.

- **Change: range selection in `SessionTimeline`**
  - Shift-drag on any lane selects a range. A plain drag still seeks, and the ruler keeps its mark pins (main moved the marks onto the ruler, so the ruler can't own selection).
  - I and O set the start and end of the selection at the playhead. Esc clears it.
  - The selection shows as a band across every lane, with its length.
  - Verify in the debug app by selecting with I/O and a new `--select <a,b>` launch flag on a harness fixture.
- **Change: edit commands on `SessionModel` (`Edits.swift`, alongside `Review.swift`)**
  - Delete removes the selection. Edited times are converted to original ranges, so the new segment list is computed from original ranges, not from times on screen.
  - Each change writes `edits.json` and rebuilds the composition straight away. Context lanes refresh when the reprocess finishes, with "Updating…" shown in `reviewStatus`.
  - Undo and redo (⌘Z, ⇧⌘Z) keep a stack of earlier segment lists in memory. "Restore Original" is in the Session menu.
- **Change: "Show Cuts" view**
  - A toggle switches the timeline to original time.
  - Removed ranges are hatched and greyed. Hidden marks show faded.
  - Clicking a hatched range offers "Restore this cut".
- **Change: portable `viewer.html`**
  - When `segments` has more than one entry, the `<video>` skips removed ranges on `timeupdate`.
  - Positions are converted to edited time through the embedded segment table.

- **Spike: reprocess latency per cut**
  - Decision required: is running the whole script after each cut fast enough, given that the transcript and frames are cached?
  - Evidence to gather: time `process_session.py` on a 30-minute session with 20 marks after a cut.
  - Fallback: add `--edits-only`, which skips frames, Markdown and the viewer and rewrites only `session.json`. Write the rest after edits have settled.

### Desired end state

- A session can be trimmed at the start, in the middle and at the end from the timeline, and each cut can be undone, redone or restored on its own.
- Show Cuts shows exactly what was removed. Restore Original deletes `edits.json`.
- Copy as Markdown and the Product Grid export give edited times and references to the original footage.
- `viewer.html` for a cut session plays only the kept ranges.

## Milestone 3: Join sessions end to end

This is the second user of the segment model. It leaves out picking ranges across sources and reordering.

- **Change: "Join Sessions" command (`LibraryView`)**
  - The sidebar already supports multiple selection (merged from main). With two or more sessions selected, the selection summary and the context menu offer **Join**, ordered by recording time.
  - Join creates `<root>/<timestamp>-joined/`. Its `edits.json` holds one full-length segment for each picked source, in order, plus a `sources` list. It has no `recording.mp4`.
  - The new session opens as soon as processing finishes.
- **Change: multi-source processing in `process_session.py`**
  - For each source, load raw marks, activity, page events and transcript, converting each source's own times to the joined edited time.
  - Number marks in edited order and record each mark's `sourceSession`.
  - Reference images from source folders through relative paths (`../<source>/frames/003.jpg`) instead of copying them.
  - Every source must already be processed. Missing sources are reported in `session.json.errors`.
- **Change: joined playback and authoring in Swift**
  - Build the composition across several assets.
  - The timeline gets a thin source-boundary lane.
  - Review marks on a joined session are saved in the joined folder's `marks.jsonl` with `sourceSession` and original time.
  - A missing source shows a "Source missing: <name>" banner instead of a broken player.
  - `SessionLibrary` summaries read the joined `session.json` like any other session.
  - `viewer.html` shows a "joined session; open in the app" notice.

- **Spike: sources that differ in size or audio**
  - Decision required: how should segments with different pixel sizes, or with no microphone track, play in one composition?
  - Evidence to gather: join a 1920-wide recording with a smaller one, and a silent session with a narrated one.
  - Fallback: an `AVMutableVideoComposition` with one fit-to-frame transform per segment, and an empty audio range for silent sources. If that's unreliable, refuse joins of mixed sizes with a clear message for now.

### Desired end state

- Two or three sessions join into one that plays straight through, with one timeline, marks numbered in order and context lanes that line up.
- Cutting the joined session works exactly as in M2.
- Deleting the joined folder leaves every source untouched. Moving a source shows a clear message.

## Milestone 4: Annotation layer with rectangles and timing

This proves the annotation model (original time, coordinates as fractions of the video frame, a time span on the timeline) with one tool before building the rest.

- **Change: `annotations.json` and `Annotations.swift`**
  - Each entry is `{id, kind, sourceSession?, start, end, rect (0–1 of video), color, text?, points?}`, in original time.
  - Entries are converted to edited time for display through `EditMap`. Spans that cross a cut are hidden only while the cut lasts.
  - Edits go through the same undo stack as cuts.
- **Change: overlay on the stage (`SessionView`)**
  - A SwiftUI `Canvas` above the player shows annotations active at `currentTime`, scaled to the video's on-screen size.
  - Draw mode turns on and off with a toolbar button and the E key. It pauses playback.
  - Inside draw mode, R draws a rectangle and S selects (RegionShot's keys). Outside it, today's M, S, J and K are untouched.
- **Change: annotation lane on the timeline**
  - Each annotation is a bar covering its span, about 3 s from the drawing time by default.
  - Drag the ends to change the span, drag the body to move it, and press Delete to remove it.

### Desired end state

- A rectangle drawn on a paused frame appears for 3 s of playback. Dragging its bar changes when it shows.
- It stays put on the frame through window resizes and survives cuts and restores.
- Removing `annotations.json` clears the layer and nothing else.

## Milestone 5: The rest of RegionShot's tools

This fills in the tool set on the proven model. It deliberately follows RegionShot's handling, not its code.

- **Change: tools and editing**
  - Arrow (A), Text (T, with inline editing: Return commits, Shift-Return adds a line break, Esc cancels), Highlight (H, translucent, with its own remembered colour) and Freehand (D, lightly smoothed).
  - Selecting shows handles for move and resize. Arrows have handles at both ends.
  - One shared colour, and changing it recolours the selected annotation.
  - Hover cursors match what the next click will do, and a click without a drag deselects.
- **Change: annotation colour and size defaults**
  - Line width and text size are fractions of the video's height, so they look the same at any window size.

### Desired end state

- RegionShot's six tools work over the video, with its keys and direct manipulation.
- Annotations survive cuts, restores, joins and relaunch.

## Cross-cutting verification

- After each milestone:
  - Run the unit tests and `--self-test edits`.
  - Take a debug-app screenshot of the edited `tmp/` session in light and dark mode.
  - Check that an unedited session from `~/Movies/ContextRecorder` opens, exports and copies Markdown with no change from before.
- Before calling the work done, run one pass in the installed app on a fresh recording.

## Open decisions and spikes

1. **Composition seeking (M1).** Is the composition good enough to scrub across many segments? If not, skip ranges on the source player for single-source cuts.
2. **Reprocess latency (M2).** Is a full reprocess fast enough after each cut? If not, add `--edits-only`.
3. **Mixed sources in a join (M3).** Can one composition fit sources of different size, and with or without audio? If not, refuse joins of mixed sizes for now.

## Below the cut line

- Suggested cuts from silence, idle time, dead start and end, or "keep marks ± N s". Do this first after M5, since it needs only the transcript and activity already in `session.json`.
- Drawing annotations into mark frames and screenshots for exports.
- A blur rectangle tool, and mark notes shown as captions.
- MP4 export with annotations burned in. Joined sessions in `viewer.html`.
- Picking ranges across sources, reordering ranges, speeding up idle stretches, auto-zoom and editing by transcript.
- Pasting images as annotations, cropping the frame, and per-annotation opacity.
