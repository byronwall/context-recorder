---
title: "In-app image viewer and annotator"
slug: "in-app-image-viewer"
phase: intent
status: confirmed
last_updated: "2026-10-13"
---

# In-app image viewer and annotator

## My read

When you click a mark's screenshot or frame in the Sessions window today, the app hands it to the system Quick Look panel. That panel is a different surface with different controls, and it pulls you out of the session. You want image viewing to stay entirely inside Context Recorder, and you want it to be good: smooth pan and zoom, and the same quick annotation set RegionShot has. You should be able to look closely at a capture and mark it up in one place without ever reaching for Preview or Quick Look.

This is the still-image partner of the video annotation layer in the session-editing initiative. Both should share one annotation model and one feel: RegionShot's tools, keys and handling. The browser `viewer.html` lightbox already got pan and zoom. The native app has not.

## What matters most

- Never leave the app. No Quick Look panel, no Preview, no external app for viewing or marking up an image.
- Pan and zoom that feel native and fast: pinch, wheel toward the pointer, drag or two-finger pan, fit and 1:1.
- RegionShot-level annotation with nothing more: rectangle, arrow, text, highlight, freehand and crop, plus select, move, resize, delete, undo and redo.
- One annotation model and feel shared with the video annotation layer.

## The experience or behavior you appear to want

You click a mark image and it opens large as an overlay inside the session window. You pinch or scroll to zoom toward the pointer, drag to pan, and press a key to fit or go to 1:1. Arrow keys step through the session's other mark images. When something needs calling out, you press a single key for a tool and draw: a box around a bug, an arrow at a button, a short note, a highlight. You can move, resize and delete what you drew, then undo or redo. Escape closes the viewer and puts you back where you were. The marked-up image is what the session and its exports show from then on.

## Boundaries

### Must be true

- Every place that opens an image today (the mark card, mark detail, the full-frame thumbnail and the "Quick Look" menu item) opens the in-app viewer instead.
- Pan and zoom match RegionShot's handling: zoom toward the pointer, trackpad pan, keyboard zoom, fit and 1:1.
- The annotation tools and shortcuts match RegionShot and the video annotation layer.

### Must be avoided

- Any route through Quick Look, Preview or another external app.
- Growing into an image editor: no layers, filters, shape libraries or styles beyond RegionShot's.
- Losing the original capture when you annotate. (This is derived, not stated, but marks are one-of-a-kind evidence.)

## What seems settled

- RegionShot is the reference for feel and tool set, not a component to embed. It is Objective-C/AppKit and this app is SwiftUI.
- The annotation tools come from the session-editing brief: rectangle, arrow, text, highlight, freehand, plus crop as RegionShot has it.
- This lives in the native Sessions window, not only the browser viewer.
- The viewer is an overlay inside the session window, not a separate window.
- Annotations appear in the exports: mark Markdown, `session.md` and the Product Grid export show the marked-up image.

## Possibilities, not decisions

- Keeping annotations as editable data beside the original PNG and writing a flattened copy that exports point at. (Exports need the marks baked in, and you need the original kept, so a flattened copy plus editable data is the likely route.)
- Stepping through all of a session's images (marks and frames) as a filmstrip.
- RegionShot extras such as pasting images, canvas growth beyond the image and exact resize.

## Current reality that matters

- `SessionView` uses SwiftUI's `.quickLookPreview` over every mark image and frame. `MarkImage` in `MarkDetail.swift` and `SidePanel.swift` set that binding, so there is one seam to replace.
- `ImageCache` already loads downsampled images. The viewer will need full resolution.
- `scripts/viewer.html` has a pan/zoom lightbox (commit `1284221`) whose controls (−, +, Fit, 1:1; keys + − 0 1, arrows, Esc) are a ready spec for the native keys.
- Mark Markdown, `session.md` and the Product Grid export reference the mark's image file, so how annotations are saved decides whether they appear downstream.

## Next step after confirmation

Shape the work. The likely first proof is the in-app viewer with pan and zoom replacing Quick Look everywhere. Annotation comes next, sharing its model with the video layer.
