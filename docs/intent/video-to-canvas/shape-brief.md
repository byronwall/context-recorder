---
title: "Video to canvas — shape brief"
slug: "video-to-canvas"
phase: shape
status: current
last_updated: "2026-10-13"
---

# Video to canvas — what we are adding

**Outcome:** A recorded walkthrough can be reviewed as a spatial canvas in which every visible piece links back to the frame and narration that produced it.

**Primary flow:** Finish a session → run canvas analysis on request → open `viewer.html` → scan the canvas → select content → the shared player jumps to its source moment.

## Feature scope

```text
Canvas review (portable HTML viewer)
├── PLANNED ADDITIONS
│   ├── Source-linked storyboard
│   │   ├── Change-selected frame cards in time order
│   │   ├── Click any card → shared player seeks to its source frame
│   │   └── Transcript rail grouped by card interval
│   ├── Tall scroll views
│   │   ├── Overlapping frames joined into one column per scroll run
│   │   ├── Click any point → the frame that supplied that patch
│   │   └── Unverifiable joins stay as cards with a short reason
│   ├── Changed states placed to the right of the earlier state
│   └── Offline analyzer, run on request, writing canvas data beside the session
├── EVALUATE BEFORE COMMITTING
│   ├── Reusing scrollsnap's stitching instead of writing our own
│   └── Automatic content-area detection instead of one viewport selection
└── LATER POSSIBILITIES
    ├── Motion posters with in-place playback
    ├── Verified return arrows between visits
    ├── Larger-than-frame region capture and export
    ├── Lecture mode (slides plus code scrolls)
    └── Native canvas in the Sessions window
```

## Behavior

| Situation | Expected result |
| --- | --- |
| Smooth scroll over static content | One tall column; seams avoid cutting glyphs |
| Visible edit mid-page | New state to the right; unseen areas stay blank, not borrowed |
| Jump with too little overlap | Separate card labeled "not joined: no overlap" |
| Fixed header, cursor, repeated text | No false join; header appears once |
| Canvas data missing or stale | Viewer shows the existing session review unchanged |
| Note edited and session reprocessed | Canvas is reused, not recomputed |

## Decisions and boundaries

**Appetite:** One experiment-sized slice: a storyboard plus scroll joining on short recordings in the HTML viewer. Enough to decide whether spatial geometry earns its cost.

**Key decision:** Build the change-selected storyboard first, then add stitching on top of it. The research treats the storyboard only as a comparison. It is also the refusal fallback (every rejected join becomes a card) and a usable result if stitching disappoints. This gives a working viewer after the first step and makes the value comparison free. Develop stitching against synthetic scroll clips cut from tall screenshots with FFmpeg, where every offset is known, before touching real recordings.

**Boundary:** Analysis is a separate, optional script; capture, transcription, marks, and Product Grid export are untouched. Deleting canvas output restores today's behavior. No browser instrumentation, server, or new frontend stack. Lecture and general video are out of scope for this slice.

**First proof:** **Try:** Synthetic scroll clips plus one 60–90 s real walkthrough (three viewport heights of scrolling, one edit, one jump) through the analyzer and viewer. **Observe:** Join error against known offsets, false joins, readable seams, and whether clicks land on the correct frame. **Decide:** Continue to real-session value testing if synthetic error stays within 2 px, there are zero false joins, and the real clip produces a readable tall view. Otherwise stop at the storyboard.

**Open choices:** Whether one manual viewport selection is acceptable; whether purpose-made test clips are acceptable.

See the [intent brief](intent-brief.md), the [implementation plan](implementation-plan.md), and the original [research design](sources/design.md).
