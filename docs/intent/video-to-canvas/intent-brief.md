---
title: "Video to canvas"
slug: "video-to-canvas"
phase: intent
status: current
last_updated: "2026-10-13"
---

# Video to canvas

## My read

You want a narrated screen recording to unfold into a canvas you can explore in space. Time becomes layout: a scrolled page becomes one tall view, a changed page sits to its right, and a return to earlier content is visible as a return rather than buried in a scrubber. Interaction then recovers time. Selecting any part of the canvas plays the moment in the original video that supplied it, with the narration from that moment beside it.

The audience is you first, reviewing your own product walkthroughs in Context Recorder. The canvas should show what an ordinary video player hides: how much content you passed through, where things changed, and what you said while looking at them. It should also be enjoyable to use, not just correct.

A narrated product walkthrough over scrolling, mostly static web content is the primary case. A lecture with slides and code is a second case. General video is a research question, not a promise.

## What matters most

- **Truthful images.** Every displayed pixel comes from a real frame at a known time. Unobserved areas stay visibly empty. Composites never pretend to show a single instant.
- **Always linked back to the video.** Every patch, card, and transcript chunk can jump to its source moment.
- **Better than the obvious alternative.** The canvas must beat ordinary video review and a simple change-selected storyboard on real review tasks. Otherwise the simpler view wins.
- **Preserve the full vision** even when the first proof covers only scrolling.

## The experience you appear to want

You stop a recording and, on request, get a canvas. It reads left to right through the session. Scrolled content forms tall columns. Edits start a new state beside the old one. Bursts of frequent change collapse into a stack of cards. Animation appears as a poster that plays in place. A later visit to an earlier page keeps its place in the sequence and shows an arrow back. Transcript chunks sit near the visits they were spoken during. You can select a region larger than any one frame and capture it, with its source times kept.

## Boundaries

### Must be true

- Each output patch maps to one decoded frame, its actual presentation time, and a source rectangle.
- Ordinary session review keeps working when canvas data is absent, stale, or broken.
- Analysis runs offline and only on request, never during capture or note edits.

### Must be avoided

- Blending different moments across text, or filling content that was never observed.
- Silently merging a changed state into an earlier one.
- Treating a matching URL or timing as proof of identity or meaning.
- Mandatory browser instrumentation, cloud services, or a new frontend stack for the first version.

## What seems settled

- Converting time into space, then recovering time through interaction, is the central idea.
- The portable HTML viewer is the first surface; native SwiftUI waits until the idea proves useful.
- Surfaces, states, and visits are distinct ideas but do not need separate stores or services.
- When a join cannot be verified, show a timed card with a reason instead of a guess.

## Possibilities, not decisions

- The one-, five-, and ten-second sampling intervals were examples. Change-based selection may be better.
- Rightward flow, card stacks, and return arrows express intent; exact layout is open.
- OpenCV phase correlation, scrollsnap reuse, and Apple Vision are candidate methods, not choices.
- The research's numeric gates (2 px p95 error, 20% time gain, memory budgets) are starting points, not accepted targets.
- Browser scroll events or DOM data might help later, but only to fix a measured failure.

## Current reality that matters

- The app records the main display at up to 1920 px wide and 15 fps; Python post-processing already produces frames, transcripts, and a self-contained `viewer.html` with inline session data and a shared player.
- Browser snapshots carry scroll coordinates only at marks. There is no continuous scroll capture and no canvas pipeline.
- Mark images and browser event offsets are not exact frame-exposure times, so the canvas needs its own decoded-frame mapping.
- There is no test suite and no tracked sample recording. OpenCV is not installed locally; FFmpeg is.
- Completed research and a proposed design live in [sources/](sources/design.md). Nothing has been built or measured.

## What still needs your input

1. Is one manual viewport selection per recording acceptable in the first proof, or must the canvas find the content area itself?
2. Are you willing to record two or three short purpose-made test clips, or should the proof use only existing sessions?

## Next step after confirmation

The [shape brief](shape-brief.md) and [implementation plan](implementation-plan.md) are drafted against this reading.
