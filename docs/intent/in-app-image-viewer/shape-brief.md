---
title: "In-app image viewer and annotator — shape brief"
slug: "in-app-image-viewer"
phase: shape
status: draft
last_updated: "2026-10-13"
---

# In-app image viewer and annotator — what we are adding

**Outcome:** Every mark image opens, zooms and gets marked up inside the session window. The marked-up version is what the Markdown and Product Grid exports show.

**Primary flow:** Click a mark image → an overlay opens over the session → pan, zoom and step through images → press a tool key and draw → Escape → the card, `session.md` and the next export show the annotated image.

## Feature scope

```text
Image overlay (replaces Quick Look everywhere)
├── PLANNED ADDITIONS
│   ├── Viewer
│   │   ├── Opens from the mark card, mark detail, full-frame thumbnail and the "Quick Look" menu item (renamed "View")
│   │   ├── Full-resolution image on the dark stage, fit to the window by default
│   │   ├── Zoom: pinch, ⌘+ / ⌘−, wheel toward the pointer, ⌘0 = fit, ⌘1 = 1:1, zoom readout with presets
│   │   ├── Pan: two-finger scroll, middle-drag, or Space-drag with any tool
│   │   └── ← / → step through the session's mark images; Esc closes
│   ├── Annotation (RegionShot's set and keys)
│   │   ├── Select (V), Rectangle (R), Arrow (A), Text (T), Highlight (H), Freehand (P), Crop (C)
│   │   ├── Select, move, resize via handles, arrow end anchors, Delete
│   │   ├── One stroke color plus a separate highlight color (yellow by default)
│   │   └── Undo and redo (⌘Z / ⇧⌘Z) for every edit, including crop
│   └── Saving and export
│       ├── Edits save on close, with no save dialog
│       ├── Original capture is never touched; a "Revert to original" action clears the edits
│       ├── Annotated cards show a small "annotated" badge
│       └── Markdown, session.md and the Product Grid export use the flattened annotated image
├── EVALUATE BEFORE COMMITTING
│   └── Annotating the full-screen frame as well as the screenshot (same mechanism; decide after M2)
└── LATER POSSIBILITIES
    ├── RegionShot extras: paste images, canvas that grows past the image, exact resize
    └── Copy annotated image to the clipboard
```

## Behavior

| Situation | Expected result |
| --- | --- |
| Click an image with the Select tool | Nothing is drawn. Drag pans the image when nothing is under the pointer. |
| Press a tool key while editing text | The key types; tool keys only work outside text editing. |
| Esc while drawing or cropping | Cancels that gesture. A second Esc closes the overlay. |
| Close after edits | Saves the annotation data and the flattened PNG, then refreshes the card thumbnail. |
| The session is re-processed (review marks) | Annotations survive. Exports keep pointing at the annotated image. |
| Revert to original | Removes the annotation data and the flattened copy. Exports fall back to the original. |
| ← / → with unsaved edits | Saves first, then moves on. |

## Examples

Files added beside the originals (*names not final*):

```text
shots/004.png                    original, never written
annotations/004.json             editable shapes, in image-pixel coordinates
annotations/004.png              flattened copy that the exports point at
```

```json
{ "version": 1, "crop": null,
  "shapes": [ { "kind": "arrow", "from": [812, 140], "to": [640, 300], "color": "#ff3b30", "width": 4 } ] }
```

## Decisions and boundaries

**Appetite:** Medium. The viewer is small. The annotation canvas is the bulk of the work. Hold the tool set at RegionShot's basics.

**Key decision — this initiative owns the annotation model.** Session-editing needs the same shapes on video, plus a time range. Build the shape model and canvas here first, on a still image, which is easier to test. The video layer then adds time to shapes it already knows. Building the two separately would mean two models that drift apart.

**Key decision — editable data plus a flattened copy, not in-place edits.** Exports need the drawing baked in, and you need the raw capture kept. The flattened PNG is a cache, so it can always be rebuilt from the JSON and the original.

**Boundary:** No layers, filters, shape styles or fonts beyond RegionShot's. The browser `viewer.html` stays view-only. It shows the annotated image but does not edit. `process_session.py` changes in one place only: it prefers `annotations/NNN.png` when choosing a mark's image. Deleting the `annotations/` folder returns everything to the originals.

**First proof:** **Try:** Show the overlay viewer, with pan and zoom, from every place that opens Quick Look today, with the `.quickLookPreview` modifier removed. **Observe:** You can review a real session's marks at 1:1 and step through them without ever seeing Quick Look, and gestures feel like RegionShot's. **Decide:** If pan and zoom feel right in SwiftUI, build the annotation canvas on the same view. If gestures fight SwiftUI, drop to an AppKit `NSView` canvas for both before any annotation work starts.

**Open choices:** none blocking. The tool keys above copy RegionShot's. Change them now if you use different ones.

Intent: [intent-brief.md](intent-brief.md)
