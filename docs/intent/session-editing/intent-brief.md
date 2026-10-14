---
title: "Session editing: trim, combine, annotate"
slug: "session-editing"
phase: intent
status: draft
last_updated: "2026-10-13"
---

# Session editing: trim, combine, annotate

## My read

A raw Context Recorder session is honest but loose. It has dead air at the start, a detour in the middle and fumbling at the end, and the point you were making is often spread across more than one recording. You want to shape a session into something tight without leaving the app. You want to select any span of the recording (start, middle, end or anywhere else), mark it for removal and have it cut. You want to join several sessions ("traces") into one. And you want to draw over the video with a quick annotation layer: the same small set of tools RegionShot has (rectangle, arrow, text, highlight, freehand), not a design suite.

What sets this apart from a generic video editor is that a session is more than a video. Marks, narration, the transcript, the activity log and page events all sit on the same clock as `recording.mp4`. A cut or a join only works if every one of those lanes moves with the video. Otherwise a mark's frame, its narration window and its Markdown end up describing the wrong moment.

## What matters most

- Removing any span is one gesture: select a range on the timeline and remove it. The start, the middle and the end are not special cases.
- After a cut or a join, every lane stays true to the video: marks, narration, page events, activity and transcript.
- Joining sessions produces one coherent session that the window, the Markdown and the Product Grid export can treat like any other.
- Annotations feel like RegionShot: fast, keyboard-driven, few choices, drawn straight onto the frame.

## The experience or behavior you appear to want

You open a session in the Sessions window and drag across the timeline to select a range. The range shows across every lane, and you press Delete. Playback now skips the span, and the timeline closes the gap or shows it collapsed. You repeat this until the session is tight. To combine recordings, you pick two or more sessions and join them, and the result opens as one session with one timeline. To annotate, you pause on a frame, pick a tool with a single key, and draw a box or type a note over the video. The annotation stays on screen for a stretch of time and can be moved, resized or deleted the way RegionShot objects can.

## Boundaries

### Must be true

- Cuts can land anywhere and there can be any number of them.
- Every time-based lane moves with the video after a cut or a join.
- The annotation tools are RegionShot's set at most: rectangle, arrow, text, highlight, freehand, plus select, move, resize, delete, undo and redo.
- Edited sessions keep working with the Sessions window, Copy as Markdown and the Product Grid export.

### Must be avoided

- Growing into a general video editor: no multitrack, transitions, effects stacks or keyframe curves.
- Losing the original capture through any edit.
- Marks or narration that point at the wrong moment after an edit.

## What seems settled

- "Trace" means a Context Recorder session: the video plus its context.
- Editing happens inside the native Sessions window, next to the existing review tools (M, S, notes).
- RegionShot is the reference for how annotations should look and handle, not a component to embed. It is Objective-C/AppKit and this app is SwiftUI.
- The edited result is for you and your exports (the Sessions window, Copy as Markdown, Product Grid), not mainly a video to share. Annotations stay a layer in the app. They do not need to be rendered into the video.
- Combining traces means joining whole sessions end to end, then trimming the result with the normal cut tools.
- The original capture is always kept. Edits are stored beside it and can always be undone.
- Each annotation shows for a fixed span by default (about 3 s from where you drew it), and appears as a bar on the timeline that you can drag to change.

## Possibilities, not decisions

- Stored as an edit list beside `recording.mp4` and played through an AVFoundation composition, so no file is rendered while you edit.
- A joined session as a new session folder that refers to its source sessions rather than copying them.
- Exporting an MP4 with annotations burned in, as a later addition.
- Cropping the frame to a region, the video version of RegionShot's Crop tool.

## Current reality that matters

- Each session folder holds one `recording.mp4` (15 fps, up to 1920 px wide, optional mic audio). Marks, activity, page events and the transcript are stored as offsets in seconds from the start of that file.
- `scripts/process_session.py` turns the raw `.jsonl` files into `session.json`, frames, narration windows and Markdown. Review marks already work by adding a line and re-processing, so that path can carry edits too.
- Playback is a single `AVPlayer` on `recording.mp4`. AVFoundation compositions can play a cut list without rendering a new file first.
- The timeline (`SessionTimeline`) already has lanes, a playhead, hover and drag-to-seek, but no range selection.

## Next step after confirmation

Shape the work. The first proof is a cut list on one session that plays back with every lane still lined up. Joining and annotation come next, built on the same time mapping.
