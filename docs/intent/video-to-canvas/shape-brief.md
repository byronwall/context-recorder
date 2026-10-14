---
title: "Video to canvas — shape brief"
slug: "video-to-canvas"
phase: shape
status: current
last_updated: "2026-10-13"
---

# Video to canvas — what we are adding

**Outcome:** In the Sessions window, you can find content you scrolled or navigated past faster than by scrubbing the video. Every piece of it leads back to the moment it came from.

**Primary flow:** Open a session → **Build canvas** → drag a box around the content once → switch the stage to Canvas → scan left to right → click content → the stage switches to the video at that moment.

## Feature scope

```text
Sessions window: Canvas stage mode
├── PLANNED ADDITIONS
│   ├── Build canvas (on request, per session)
│   │   ├── Content box chosen once with the existing region picker
│   │   └── Offline analysis writes canvas data into the session folder
│   ├── Storyboard
│   │   ├── Cards for meaningful visual changes, in time order
│   │   └── Fallback for anything that cannot be joined
│   ├── Tall columns
│   │   ├── One column per scrolled page, laid out left to right
│   │   └── Changes, returns, and motion appear as plain cards between columns
│   ├── Back to the video
│   │   ├── Click content → video stage, seeked to the frame that supplied it
│   │   └── Hover → existing now strip and inspector show that moment's narration
│   ├── Copy or export a column as PNG
│   └── Add a review mark from selected canvas content
├── EVALUATE BEFORE COMMITTING
│   ├── Analysis engine: Python + OpenCV vs in-app Apple Vision
│   └── Reusing scrollsnap's stitching
└── LATER POSSIBILITIES
    ├── Changed states placed beside earlier states
    ├── Return arrows, motion posters, card stacks
    ├── Automatic content-area detection
    ├── Long sessions (tiling, memory budgets)
    └── Lecture mode, Product Grid canvas export
```

## Behavior

| Situation | Expected result |
| --- | --- |
| Smooth scroll over static content | One tall column; seams avoid cutting text |
| Edit, navigation, or animation | A plain card between columns |
| Jump with too little overlap | A card labeled "not joined: no overlap" |
| Fixed header, cursor, repeated text | No false join; header appears once |
| Mark from canvas | Review mark at the source frame's time, cropped to the selected source area, through the normal review-mark path |
| Exported column | PNG named with its time range; it may combine several moments |
| No canvas built, or video changed since | Canvas toggle unavailable or shows **Rebuild**; video review unchanged |
| Note edited, session reprocessed | Canvas reused, not rebuilt |

## Decisions and boundaries

**Appetite:** One experiment-sized slice for recordings under five minutes. It is enough for you to judge on your own sessions whether spatial review beats scrubbing.

**Key decision:** Build the storyboard before stitching. It makes Canvas mode usable early. It also handles every rejected join and remains a result if stitching disappoints. Stitching is developed on fake scroll videos made by cropping tall screenshots with FFmpeg. Every true offset is known, so accuracy is checked against exact answers before real footage. Python + OpenCV and Apple Vision are compared on those same clips. The better one is kept and the other is dropped.

**Boundary:** Canvas data lives in a versioned file in the session folder, which the native view reads. Deleting that file restores today's behavior. Capture, transcription, marks, and export are untouched, except that marks from the canvas use the existing review-mark path. No browser instrumentation or HTML viewer work.

**First proof:** **Try:** Fake scroll clips, plus two or three short scripted walkthroughs you record, through Build canvas into Canvas mode. **Observe:** Offset error and false joins on fake clips; readable columns and correct frame-on-click on real clips. **Decide:** Use it on your own sessions if fake-clip error stays within 2 px with zero false joins and real clips produce readable columns. Otherwise keep the storyboard and stop stitching.

See the [intent brief](intent-brief.md), [implementation plan](implementation-plan.md), and original [research design](sources/design.md).
