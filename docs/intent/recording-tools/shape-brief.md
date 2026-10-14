---
title: "Recording tools — proposed local review improvements"
slug: recording-tools
phase: shape
status: current
last_updated: "2026-10-14"
---

# Recording tools — proposed local review improvements

**Outcome:** Keep a reviewed finding accurate and usable from its recorded source through its final handoff.

**Primary flow:** Record → find a moment → inspect context → add a conclusion → review included content → hand off.

This is a proposal for review. Personal product review remains the provisional direction. Implementation has not started.

## Feature scope

```text
Local review of a recorded session
├── PLANNED ADDITIONS — proposed, not approved
│   ├── Faithful portable findings
│   │   ├── Note title and body in visible and copied output
│   │   └── Review origin and correct transcript sentence
│   ├── Clear processing outcomes
│   │   ├── Ready, silent, unavailable, pending, or failed
│   │   └── Useful failure detail and one local retry
│   └── Truthful collection and output descriptions
│       └── State what is included; make no blanket sanitization claim
├── EVALUATE BEFORE COMMITTING
│   ├── One-session text search with source time and match context
│   ├── Selected findings with an explicit asset inventory
│   └── Specialist dictation or annotation on a preserved copy
└── LATER POSSIBILITIES
    ├── One demonstrated missing capture target or audio mode
    └── Source-linked reading board, then optional spatial reconstruction
```

## Behavior

| Situation | Expected result |
| --- | --- |
| A reviewer adds a conclusion | Native, Markdown, and portable reading show the same conclusion and its review origin. |
| A recognizer is missing or fails | The app reports the unavailable or failed stage. Raw capture remains accessible. |
| A user selects a crop | The output describes whether it also includes the full frame, transcript, or saved page. |
| A source location or artifact time is approximate | The result states that limit. A later image must not imply exact exposure at mark time. |
| A query or derived view fails its value test | Chronological review and current Markdown remain usable. |

## Decisions and boundaries

**Appetite:** Repair the existing output contract, then run one bounded task comparison. Do not build all researched features.
The first useful state requires no new provider, database, capture engine, or frontend stack.

**Key decision:** The current app plus editor Find and specialist tools is a credible alternative.
Measure interpretation, correction, and packaging as part of task time. A faster first search result is insufficient.
Use the existing note and source model. Preserve raw media and logs; permit intentional note edits and added review marks.

**Boundary:** Keep originals private by default in this proposal. No new automatic upload or remote action is included.
Selected output needs a user-chosen content policy before a detailed export design.
Repair proposals can stand alone. A systemwide dictation engine, hosted team service, and full video editor remain outside this shape.
The prior canvas vision remains intact as a separate alternative. A simple board does not prove spatial reconstruction.

**First proof:** **Try:** Reopen and copy one synthetic reviewed finding through native Markdown, processor Markdown, and portable HTML.
**Observe:** Check the note, review origin, source time, and exact adjacent sentence against a fixed answer key.
**Decide:** Keep a narrow repair only if all required meaning survives and originals remain intact. Reject a new rendering framework.
For later search, require a predeclared full-task benefit over the stronger manual baseline; the proposed numerical target is unapproved.

**Open choices:** Choose the primary job: personal review, polished communication, or general dictation.
Also choose the recipient and which content may leave the private session folder.
These decisions gate application expansion. The current plan covers narrow repairs and a decision spike without settling them.

See the [intent](intent-brief.md), [alternatives](brainstorm.md), [plan](implementation-plan.md), and [research](../../research/recording-tools/research-review.md).
