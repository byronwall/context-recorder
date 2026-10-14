---
title: "In-app image viewer and annotator — implementation plan"
slug: "in-app-image-viewer"
phase: plan
status: draft
last_updated: "2026-10-13"
---

# In-app image viewer and annotator — implementation plan

## Plan at a glance

There are three milestones. Each one leaves the app shippable.

1. **Viewer overlay.** Remove `.quickLookPreview` and open every mark image in an in-session overlay with pan and zoom. This gets you out of Quick Look immediately and answers the one real technical question: whether SwiftUI gestures can deliver RegionShot's feel, or whether the canvas needs to be an AppKit `NSView`.
2. **Annotation in memory.** Add the shape model and RegionShot's tools on that canvas, with undo and redo. Nothing is written to disk yet, so mistakes cost nothing.
3. **Save and export.** Write `annotations/<stem>.json` and a flattened `annotations/<stem>.png`, have `process_session.py` prefer the flattened copy, and re-run the existing Review reprocess path. The Markdown, `session.md` and the Product Grid export then follow with no export code changes.

The main pushback is to keep the model, hit-testing and flattening as pure Swift with no UI, in a small library target with unit tests. The repo has no tests today, and this is the code most likely to regress when the video layer reuses it.

## Implementation strategy

- **First proof:** Clicking a mark image opens the overlay. Pinch, wheel, drag and the zoom keys work, ← / → steps through marks, and Quick Look never appears.
- **Primary seam:** `SessionView`'s `quickLook: URL?` binding becomes `viewing: URL?`, and the overlay replaces `.quickLookPreview`. `MarkImage`, `MarkDetail` and `SidePanel` keep the same call shape.
- **Fast local loop:** `swift build && .build/debug/ContextRecorder`, opening a real session folder from the Sessions window. Add `swift test` for the new `Annotation` target once it exists.
- **Local dependencies:** none beyond what the app already uses (ffmpeg and python3 for reprocessing). There are no network or provider dependencies.
- **Rollout and rollback:** Each milestone is a separate PR. Deleting a session's `annotations/` folder and reprocessing restores the originals. The Python change is one fallback branch.

## Milestone 1: Mark images open in an in-app overlay with pan and zoom

This is the fastest visible win and settles the canvas technology. It deliberately leaves out annotation.

- **Change — Overlay in `SessionView`**
  - Replace `.quickLookPreview($quickLook, in:)` with a full-content overlay (the dark stage colour, a toolbar, Esc to close). Drop `import QuickLook` and the QuickLook linker entry in `Package.swift`.
  - Rename the binding and its uses in `MarkDetail.MarkImage` and the `SidePanel` menu item ("Quick Look" → "View"), along with their help text and accessibility hints.
  - Verify: a grep finds no `quickLook` uses. Every entry point (card, detail, frame thumbnail, menu) opens the overlay.
- **Change — `ZoomCanvas` view (new `Library/ImageViewer.swift`)**
  - Load the image at full resolution, not through `ImageCache`'s downsampled path. Fit it by default.
  - Zoom toward the pointer with pinch and the mouse wheel. Two-finger scroll and drag pan the image. ⌘+ / ⌘− zoom, ⌘0 fits, ⌘1 goes to 1:1, and a zoom readout offers presets. ← / → step through `quickLookItems` (renamed to `viewerItems`).
  - Mirror the key map in `scripts/viewer.html`'s lightbox, and update `ShortcutsSheet`'s "Close Quick Look" row.
- **Spike — SwiftUI gestures or an AppKit canvas**
  - Decision required: should the canvas be a SwiftUI view or an `NSViewRepresentable` wrapping an `NSView`?
  - Evidence to gather: try pinch with drag at the same time, wheel zoom anchored on the pointer, and middle-drag on a 1920 px frame and a small screenshot. Middle-drag and the difference between a wheel and a trackpad are AppKit-only events.
  - Fallback: an `NSView` canvas that handles `magnify`, `scrollWheel`, `otherMouseDragged` and key events, hosted in SwiftUI. Choose it if the SwiftUI version needs more than one workaround.

### Desired end state

- Reviewing a real session's marks at 1:1 never shows Quick Look.
- Gestures feel like RegionShot's, and Esc returns focus to the session (Space play and J/K still work).
- The spike's decision is recorded in the initiative map.

## Milestone 2: RegionShot's annotation tools work on the canvas (in memory)

This milestone adds editing without any risk to files.

- **Change — `Annotation` library target (pure Swift)**
  - Add `AnnotationDoc { version, crop: CGRect?, shapes: [Shape] }`, where a shape is a rect, arrow, text, highlight or freehand stroke, in image-pixel coordinates and `Codable`.
  - Add hit-testing, handle geometry, freehand smoothing, a linear undo stack, and `flatten(doc, onto: CGImage) -> CGImage` using Core Graphics with no AppKit view.
  - Add `Package.swift` targets `Annotation` and `AnnotationTests`. Tests cover encoding round trips, hit-testing and resize handles, undo/redo sequences, and flattening a fixture image followed by spot-checking pixel colours.
- **Change — tool layer on the canvas**
  - Tool keys: V, R, A, T, H, P, C. Esc cancels the current gesture. ⌘Z / ⇧⌘Z undo and redo.
  - Add select, move, resize handles, arrow anchors and Delete. Add inline text editing where Return commits, ⇧Return adds a line break, and tool keys are ignored while typing.
  - Add one stroke color plus a separate highlight color. Crop takes a drag, then Return.
  - Pan with Space-drag, middle-drag or two fingers whatever tool is active.

### Desired end state

- You can draw each tool's shape, edit it, undo and redo it on any mark image, and keep panning and zooming the whole time.
- `swift test` passes for the `Annotation` target.
- Closing the overlay discards edits. That is acceptable for this milestone, and the overlay says so.

## Milestone 3: Annotations save and show up in the session and its exports

- **Change — persistence**
  - On close or ← / →, write `annotations/<stem>.json` and the flattened `annotations/<stem>.png`. Reopening loads the JSON, so annotations stay editable.
  - Add "Revert to original" to delete both files.
  - Add invalidation to `ImageCache`, which currently assumes images never change. Drop that file's cache keys after a save. Add an "annotated" badge to `MarkImage`.
- **Change — make the Python processing step prefer the annotated copy**
  - In `process_session.py`, after `image` is chosen, use `annotations/<stem>.png` if it exists. Keep `mark["frame"]` and the original screenshot unchanged.
  - Call `SessionModel.reprocess()` after a save so `session.json`, `marks/NNN.md` and `session.md` update. Transcripts and frames are cached, so this is fast.
  - `PgmExport.imageFiles` already reads `mark.image`, so it needs no change. Confirm this with a dry export.
- Verify: annotate a screenshot, close, and check that the card shows the annotation and that Copy All as Markdown links `annotations/…png`. Reprocess from Review and check that the annotation survives. Revert, and check that the original is back everywhere.

### Desired end state

- Annotations are durable, editable and non-destructive.
- The Markdown, `session.md`, the browser viewer and the Product Grid export all show the marked-up image.
- Deleting `annotations/` and reprocessing restores the session exactly.

## Open decisions and spikes

- **Annotating frames:** the mechanism also works for `frames/NNN.jpg`, since annotation files are keyed by the image's file stem. Decide after M3 whether frames should be editable or view-only. Fallback: view-only.

## Below the cut line

- Pasting images, a canvas that grows past the image, and exact canvas resize
- Copying the annotated image to the clipboard, and editing in the browser `viewer.html`
- Time ranges on shapes for video (owned by session-editing, reusing the `Annotation` target)
- Font choices, stroke widths and shape styles beyond RegionShot's
