---
title: "Video to canvas"
slug: "video-to-canvas"
phase: intent
status: current
last_updated: "2026-10-14"
---

# Video to canvas

## My read

You want a narrated screen recording to become a canvas you can explore in space. A scrolled page should form a readable tall surface. Selecting content should recover the video moment and narration associated with it. The main job is finding content you passed through faster than scrubbing. You are the sole user, mainly reviewing your own product walkthroughs under five minutes.

The first native version exists. Your current complaint is that scrolling produces a little stitching, then many cards. That breaks the spatial experience you want. You describe the feature as close to amazing and want meaningful improvements to both reconstruction and presentation. This is a repair and refinement of the existing feature.

The next change combines automatic reconstruction and a stable page layout. You expect to record the whole screen and rely on processing, with very little manual correction. A page should stay useful as one surface through ordinary scrolling and temporary interruptions. Fewer cards alone cannot prove success. The canvas must retain visible edits and important interactions, and each displayed region must still lead to its source.

## What matters most

- Display real recorded pixels. Leave unobserved areas unknown and keep source times available.
- Preserve meaningful content changes, including small fields, numbers, and checkboxes.
- Keep the scrolling document understandable when a sidebar, header, or temporary overlay complicates matching.
- Let personal use on your recordings determine whether the result earns its place.
- Preserve the wider vision: changed states, return visits, motion playback, narration, and large captures.

## Boundaries

Keep analysis local and optional. Reuse the native implementation and CLI loop. Do not infer page identity from a URL or fill missing content. Browser geometry capture may help later; it is not yet a requirement.

## What seems settled

The native Sessions window is the review surface. Canvas replaces the video stage through a toggle. Analysis runs offline and on request. Whole-screen processing replaces the earlier requirement to select a content box. Existing narration, marks, source playback, and column PNG export remain part of the experience.

Clicking canvas content still switches to full video. Stable pages and a compact visit ribbon replace the initial layout of chronological runs. Selection uses the active visit for narration and playback, with other visits available.

Related fragments stay grouped with a visible gap when alignment is uncertain. Brief menus, tooltips, and overlays appear as small event markers with source playback. Persistent edits use local markers with before/after views. A web page with a sidebar and header defines the first success case.

Composite capture and other extra features wait until real scrolling works. The selected layout, visit ribbon, and active-visit source access belong in the combined next scope.

## What the new review adds

Pro reviewed the same revision as this checkout. Its controlled Swift experiments reproduced failures with stationary sidebars, temporary overlays, slow fractional scrolling, and small edits. It also found that a successful alignment can hide a content change.

These results support a focused continuity repair. They do not establish everyday accuracy. Known crops and skipped overlays were diagnostic interventions. Automatic detection, native playback, native composition, and real recordings still need proof.

The current code includes CanvasKit, canvas-tool, source-frame references, pixel contributors, and native canvas controls. The older brief’s statements that no pipeline or tests existed are obsolete.

## Next step after confirmation

The ten answers settle the next shape. The [implementation plan](implementation-plan.md) proves automatic whole-screen continuity and the stable page experience through four working steps. No application implementation is started by this planning update.

See the [current shape](shape-brief.md) and [collected follow-up](sources/pro-follow-up-2026-10-14/collection.md). Start with the automatic full-screen sidebar/header proof.
