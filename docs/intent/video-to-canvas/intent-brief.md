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

The audience is you alone, reviewing your own product walkthroughs of under five minutes in the Sessions window. The job that matters most is finding content you scrolled or navigated past, faster than scrubbing. The canvas should show what an ordinary video player hides: how much content you passed through, where things changed, and what you said while looking at them. It should also be enjoyable to use, not just correct.

A narrated product walkthrough over scrolling, mostly static web content is the primary case. A lecture with slides and code is a second case. General video is a research question, not a promise.

## What matters most

- **Truthful images.** Every displayed pixel comes from a real frame at a known time. Unobserved areas stay visibly empty. Composites never pretend to show a single instant.
- **Always linked back to the video.** Every patch, card, and transcript chunk can jump to its source moment.
- **Earns its place in real use.** You judge, on your own sessions, whether it beats scrubbing. If stitching doesn't, the storyboard is enough.
- **Preserve the full vision** even when the first proof covers only scrolling.

## The experience you appear to want

In the Sessions window you choose **Build canvas**, drag a box around the content once, and switch the stage from video to Canvas. It reads left to right: one tall column per scrolled page, with edits, navigation, and animation shown as plain cards between columns. Hovering shows that moment's narration in the existing now strip and inspector. Clicking switches back to the video at that frame. You can copy or export a column as a PNG, and add a review mark straight from the canvas.

The longer-term vision remains: changed states beside earlier ones, card stacks, motion that plays in place, return arrows, and lecture review.

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
- The native Sessions window is the surface; Canvas mode replaces the video stage through a toggle.
- Canvas is built on request per session; one manual content box is fine.
- A storyboard comes first; stitching builds on it.
- Scripted test recordings are acceptable.
- Surfaces, states, and visits are distinct ideas but do not need separate stores or services.
- When a join cannot be verified, show a timed card with a reason instead of a guess.

## Possibilities, not decisions

- The one-, five-, and ten-second sampling intervals were examples. Change-based selection may be better.
- Rightward flow, card stacks, and return arrows express intent; exact layout is open.
- Python + OpenCV vs in-app Apple Vision will be decided by whichever proves better on test clips.
- The research's numeric gates (2 px p95 error, 20% time gain, memory budgets) are starting points, not accepted targets.
- Browser scroll events or DOM data might help later, but only to fix a measured failure.

## Current reality that matters

- The app records the main display at up to 1920 px wide and 15 fps; Python post-processing already produces frames and transcripts. The Sessions window already has a shared player with `seek`, a region picker, a now strip, and a review-mark path the canvas can reuse.
- Browser snapshots carry scroll coordinates only at marks. There is no continuous scroll capture and no canvas pipeline.
- Mark images and browser event offsets are not exact frame-exposure times, so the canvas needs its own decoded-frame mapping.
- There is no test suite and no tracked sample recording. OpenCV is not installed locally; FFmpeg is.
- Completed research and a proposed design live in [sources/](sources/design.md). Nothing has been built or measured.

## Next step after confirmation

Scope was set through three rounds of questions. The [shape brief](shape-brief.md) and [implementation plan](implementation-plan.md) reflect it.
