---
title: "Video to canvas — automatic reconstruction and stable pages"
slug: "video-to-canvas"
phase: shape
status: current
last_updated: "2026-10-15"
---

# Video to canvas — next changes

**Outcome:** Whole-screen recordings become readable, stable pages with accurate source links and visible change history.

**Primary flow:** Open a session → build its canvas automatically from the full screen → explore pages and visits → click content → open full video at the active visit.

## Feature scope

```text
Native Sessions canvas
├── PLANNED ADDITIONS
│   ├── Stage 1 — Automatic whole-screen analysis
│   │   ├── Find scrolling content beside stationary sidebars and headers
│   │   ├── Recover across temporary matching failures
│   │   └── Keep slow scrolling continuous with minimal manual correction
│   ├── Stage 2 — Stable page layout
│   │   ├── Keep reconstructed pages in consistent spatial positions
│   │   ├── Compact visit ribbon shows the recorded journey
│   │   └── Group related unaligned fragments with an explicit gap
│   ├── Stage 1 — Local events and changes
│   │   ├── Small event markers open source playback for menus and overlays
│   │   └── Persistent edits have local markers with before/after views
│   └── Stage 2 — Visit-aware source access
│       ├── Selection uses the active visit for narration and playback
│       ├── Other visits remain available
│       └── Content click keeps the existing switch to full video
└── LATER POSSIBILITIES
    ├── Selected multi-frame composite capture
    ├── Embedded motion playback or inline source video
    ├── Browser geometry capture if measured failures justify it
    └── Folding, advanced zoom detail, and long-session tiling
```

## Behavior

| Situation | Expected result |
| --- | --- |
| Full screen includes a detailed sidebar and header | Identify the scrolling pane without requiring a manual crop |
| Temporary overlay interrupts matching | Recover verified page continuity and retain an event marker |
| Small persistent edit occurs during scrolling | Preserve before/after content without losing page position |
| Content appears again | Keep its page position; add a visit with the appropriate narration |
| Geometry cannot be verified | Retain related fragments with a visible gap; do not invent a seam |
| User clicks content | Switch to full video at a moment in the active visit that shows that content |

## Decisions and boundaries

**Appetite:** Two stages. **Stage 1** repairs reconstruction (automatic region discovery, continuity, local events and before/after changes) inside the existing card/column layout, then you use it on real recordings. **Stage 2** (stable pages, visit ribbon, visit-aware source access) starts only after that use and a short layout design pass for the ribbon. Personal walkthroughs under five minutes remain the target. Composite capture adds no scope until real scrolling works.

**Screen conditions:** The target is one maximized browser window on a single display: macOS menu bar, browser tab strip and bookmarks bar, Dock, and stationary sidebars on the left and/or right of the scrolling document, plus a sticky header. Recordings are at logical resolution (1512×982 in current sessions). Moving or resized windows, nested scrolling panes inside web apps, and non-browser apps are below the cut for Stage 1.

**Key decision:** Automatic full-screen processing is required. Manual crop correction can help diagnosis, but a crop-dependent result does not meet the product goal. This rules out the smaller manual-crop counterproposal as the delivered solution.

Reuse the current matcher as a candidate generator and the existing CLI as the local proof loop. Independent moving-region checks, bounded recovery, and suitable geometry anchors address the reported failures before an engine replacement. Preserve small edits while tuning; reduced fragmentation cannot compensate for lost content or false joins.

Separate pixel contributors from visits. Contributor records explain where pixels came from. Visit records select the narration and video context for a later appearance. This supports the chosen layout without a database or graph service. A return uses the existing page only when identity is supported; uncertainty remains visible.

The combined scope does not require every improvement in Pro’s report. Prove the minimum automatic tracking needed for the target web page. Add broader motion estimation or temporal masks only when that proof exposes a remaining failure.

**Boundary:** Keep analysis offline and on request. Preserve ordinary video review as the bypass. Fixed screen context and uncertain observations remain available through source video. Do not infer identity from a URL alone or certify geometry through grouping.

**Canary:** A disposable copy of session `2026-10-13_00-57-10` (97 s, explorEDA docs in maximized Chrome with left nav, right “On this page” rail, sticky header, slow scrolls, and returns to `/docs`) runs alongside fixtures from Milestone 6 onward. Record a new clip only for scenarios it lacks (overlay, small edit).

**First proof:** **Try:** A whole-screen narrated web page with a detailed sidebar and header, slow scrolling, a temporary overlay, a small persistent edit, a return visit, and a genuine jump. **Observe:** A stable readable page, correct event/change markers, distinct visit narration, correct full-video seeks, and an explicit gap at unverified geometry. **Decide:** Proceed only when native fixtures and a representative personal recording show useful reconstructed coverage without false joins or lost edits. A manually supplied crop is diagnostic evidence, not a pass.

See the [intent](intent-brief.md) and [Pro findings](sources/pro-follow-up-2026-10-14/canvas-review.md). The [implementation plan](implementation-plan.md) sequences Stage 1 as Milestones 6–7 and gates Stage 2 (Milestones 8–9) on real use.
