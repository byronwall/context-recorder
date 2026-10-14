---
title: "Session editing: shape brief"
slug: "session-editing"
phase: shape
status: draft
last_updated: "2026-10-13"
---

# Session editing: what we are adding

**Outcome:** You can cut a session down, join sessions together and draw on the video. The edited session keeps working the way sessions do now: marks, narration, transcript, page events, Markdown and Product Grid export all line up with what you see, and the original recording is never touched.

**Primary flow:** Open a session → select a range → Delete → (repeat) → draw a box or a note over a frame → Copy as Markdown or export, with everything in edited time.

## Feature scope

```text
Session editing
├── PLANNED ADDITIONS
│   ├── Cut any range
│   │   ├── Select a range: drag on the ruler, or press I and O at the playhead
│   │   ├── Delete removes it; any number of cuts, anywhere
│   │   ├── Timeline closes the gap; "Show cuts" reveals removed ranges, hatched
│   │   └── Undo/redo per cut; restore a single cut; "Restore original"
│   ├── Join sessions
│   │   ├── Select two or more sessions in the sidebar → Join
│   │   ├── Creates a new session that refers to the originals, in the order picked
│   │   └── Boundaries between sources shown on the timeline; trim with normal cuts
│   ├── Annotation layer (RegionShot's tools, rebuilt in SwiftUI)
│   │   ├── Draw mode: select, rectangle, arrow, text, highlight, freehand
│   │   ├── Move, resize, recolor, delete; undo/redo shared with cuts
│   │   └── Each shows for ~3 s by default; a timeline lane bar you drag to adjust
│   └── Context stays true after edits
│       ├── Marks, transcript, activity and page events in removed ranges drop out
│       ├── Later items shift; narration windows only quote what's still there
│       └── Markdown and Product Grid export use edited times and keep a source reference
├── EVALUATE BEFORE COMMITTING
│   ├── Suggested cuts: long silence, no activity, dead start/end, keep marks ± N s
│   ├── Annotations drawn into mark frames and screenshots used in exports
│   ├── Blur rectangle as a seventh annotation tool
│   └── Mark notes shown as captions over the video
└── LATER POSSIBILITIES
    ├── MP4 export with annotations burned in
    ├── Clips from several sessions in any order; reordering ranges
    └── Speed-up of idle time, auto-zoom, transcript-driven editing
```

## Behavior

| Situation | Expected result |
| --- | --- |
| A cut covers a mark | The mark is hidden from the list, timeline and exports, not deleted. Restoring the cut brings it back. |
| A cut splits a sentence | The sentence is kept if most of it survives, with its time clamped. Otherwise it drops out. |
| A review mark or shot is added on an edited session | It is saved at the matching moment of the original recording, so later cuts and restores keep it in place. |
| An annotation spans a cut | It shows on both sides of the cut and is hidden only during the removed part. |
| A joined session's source is moved or deleted | The session opens with a clear "source missing" message instead of a broken video. |
| Draw mode is on (E) | Single keys switch tools (S, R, T, D, A, H). Esc leaves draw mode. Outside draw mode, existing keys (M, S, J, K) work as now. |
| `viewer.html` for an edited session | Plays the original video and skips removed ranges. For joined sessions it shows a notice instead. |

## Decisions and boundaries

**Appetite:** A focused editing layer for one person's own sessions. That means one data model for cuts and joins, one annotation layer and the existing export paths. It is not a video editor.

**Key decision:** Cuts and joins are the same thing. An edited session is an ordered list of *segments*, each a range of some source recording. A raw session is one segment of itself. A cut splits a segment and a join puts segments from several sessions in a row. The segment list lives in `edits.json` beside the untouched raw files. `process_session.py` is the one place that converts original times to edited times, so `session.json`, Markdown and export all come out in edited time with no change to the code that reads them. The player builds an AVFoundation composition from the same segment list, so the playhead is in edited time too. Raw `.jsonl` files and annotations always stay in original time, which is what makes every cut reversible.

**Collision:** Markdown and export currently say `recording.mp4 @ t`. After an edit, that reference should name the source recording and its original time, so it still points at real footage.

**Boundary:** Nothing writes to `recording.mp4` or the raw `.jsonl` files. Deleting `edits.json` returns the session to exactly how it is today. Annotations stay in the app (`annotations.json`) and are not rendered into video.

**First proof:** **Try:** Hand-write an `edits.json` for a real session, with one cut at the start, one in the middle and one at the end. Run `process_session.py` and open the session. **Observe:** Playback skips the three ranges. Every mark's frame matches the video at its new time, and its narration quotes only kept speech. Adding a review mark after the middle cut saves the correct original time to `marks.jsonl`. **Decide:** If all three hold, build the range-selection interface and joins on this model. If the composition can't seek precisely or the frames don't match, move frame extraction and time conversion into Swift before building the interface.

**Open choices:** None blocking. Which of the evaluate-before-committing items to take is best decided after using cuts on real sessions.

[Intent](intent-brief.md) · [Brainstorm](brainstorm.md)
