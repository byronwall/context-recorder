---
title: "Recording tools and local review"
slug: recording-tools
phase: intent
status: current
last_updated: "2026-10-14"
---

# Recording tools and local review

## My read

Byron wants a broad view of products that combine screen recording, speech, and visual explanation.
The request includes their common features, present strengths and weaknesses, and gaps in this repository.
The purpose is to make a better product decision. It is not a request to copy every competitor feature.

The research compares six related jobs: narrated recording, bug reporting, dictation, image annotation, procedural guides, and deeper review or memory.
These jobs share capture mechanisms but produce different outputs. A polished tutorial, a corrected note, and a faithful bug record need different behavior.
The repository can support a deliberate personal review workflow. That is the leading proposal, not a confirmed primary goal.

For that workflow, a useful result is a small set of clear findings with accessible source evidence.
The reviewer must retain the recorded moment, distinguish later interpretation, and understand what an export contains.
The most immediate gaps concern accuracy in existing paths. New search or editing work must show additional value.

The full research process includes collection, reconciliation, planning artifacts, and a review PR.
This phase ends before application implementation. Current planning documents describe proposals; their status does not grant approval to build them.

## What matters most

- Cover the range of products without confusing adjacent jobs or counting renamed products twice.
- Separate documented behavior, inferred value, historical complaints, and observed test results.
- Give existing repository features credit. Treat source code as current reality, not as proof of desired intent.
- Recommend a small useful direction with a credible simpler alternative.
- Preserve the source evidence and the user's choice about the next product boundary.

## The experience or behavior you appear to want

The provisional flow is: record a walkthrough, find the important moment, inspect context, add a conclusion, and hand off chosen evidence.
The same finding should remain understandable in native review, copied Markdown, and the portable viewer.
A later note must not pretend to be recorded speech or live page context.
The recipient should be able to tell which source supports the conclusion and which content was included.

If the main job is polished communication, an existing video or guide tool may be the better result.
If the job is writing by voice, dictation into existing note fields may solve it with no app expansion.

## Boundaries

### Must be true

- Keep this run limited to research and proposed planning, followed by an open review PR.
- Preserve original research files, the baseline, and clear links from claims to evidence.
- Keep the existing Swift, Python, and browser stack unless a later request changes it.
- Use small local proofs before committing to new dependencies or a broader product.

### Must be avoided

- Do not turn unknown feature cells into claims of absence.
- Do not equate local storage, cropped images, or selected marks with a sanitized export.
- Do not treat post-capture transcription as systemwide dictation.
- Do not infer demand for hosted teams, continuous capture, or a full editing suite.

## What seems settled

Byron explicitly requested wide research, repository comparison, and the full Sleuth process.
Personal-project scale and simple implementation apply. The current research branch is suitable for the review PR.
There is no authorization to merge, deploy, implement the proposals, or retire the earlier canvas documents.

## Possibilities, not decisions

One-session text search and selected handoff are the leading additive experiment.
Speech and annotation tools are reuse candidates. A source-linked board or spatial canvas remains an alternative.
None of these mechanisms is a requirement from the original request.

## Current reality that matters

The app already records local video, microphone narration, marks, notes, browser context, and source clues.
It offers transcript seeking and local export. Main-display capture and disabled system audio constrain some tasks.
Source inspection found input-value capture, lost portable notes, and unclear processing outcomes.
Runtime impact and frequency remain unmeasured. The [research review](../../research/recording-tools/research-review.md) records exact limits and evidence.

## What still needs your input

1. Which job leads: personal product review, polished communication, or general dictation?
2. Who consumes the output, and what may leave the private session folder?
3. What measured benefit justifies maintaining another review feature?

## Next step after confirmation

Review the [contrasting approaches](brainstorm.md) and [bounded proposal](shape-brief.md).
The [plan](implementation-plan.md) details output repairs and a decision proof. It leaves architecture-changing expansion behind the open choices.
