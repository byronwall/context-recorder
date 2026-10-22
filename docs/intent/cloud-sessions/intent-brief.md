---
title: "Cloud sessions"
slug: "cloud-sessions"
phase: intent
status: current
last_updated: "2026-10-21"
---

# Cloud sessions

## My read

You want a recording made on one Mac to be usable anywhere: you watch and review it from another computer, and an agent works from it, either Claude Code on a second Mac or a cloud agent. Today a session lives only in `~/Movies/ContextRecorder/<timestamp>/` on the Mac that recorded it.

The cloud belongs to you. You're the only person who signs in, and you can send a private, revocable view link for one session to someone without an account. It runs on Cloudflare, using its own services, on a domain you own, for about $5 a month or less.

The cloud is a read-only copy. You push a session with a button. If you change it later on the Mac, the app says the cloud copy is out of date and you push again. Nothing changes in the cloud except deleting a copy or sharing it.

## What matters most

- Record on Mac A, then review the session from anywhere without copying files by hand.
- An agent elsewhere can turn marks into fixes or tickets and **see the video** at any moment, not only at marks.
- The data is private by default, stays on infrastructure you own, and every push is your decision.

## The experience you appear to want

You finish and edit a session, then press **Push to Cloud**. On another machine you sign in, open it, and it plays the way it does in the app: cuts applied, drawings showing at their moments, joined sessions as one, with the timeline, marks and transcript. You point Claude Code or a cloud agent at your cloud, and it reads a mark's Markdown, screenshot and page context, then asks for the frame at 2:14 to see what was on screen.

## Boundaries

### Must be true

- Local-first: nothing uploads without a push. The Mac folder stays the source of truth.
- The upload includes the video, narration, logs and saved pages. Saved pages are capped so a session's upload stays close to the size of its video.
- Trashing a pushed session on the Mac asks whether to delete the cloud copy too.

### Must be avoided

- Editing in the cloud, whether cuts, joins, canvas building, notes or drawings.
- Agent access that depends on the recording Mac being awake.

## What seems settled

- Cloudflare with native services, a custom domain, and a budget of at most $5 a month.
- Share links are view-only, never expire by default, and can be revoked.
- First-release parity covers cuts, drawings on video and joined sessions. The canvas view comes later.

## Possibilities, not decisions

- An MCP server or a ZIP download as the agent route. Both agent homes need something that works without the Mac.
- A second Mac pulling cloud sessions into its own app (later).
- Searching across sessions and "what happened" questions (later).

## Current reality that matters

- Recordings run 1.5–4 minutes. The mp4 is 26–41 MB, saved pages 0–12 MB, logs under 200 KB, and `audio.wav` (3–7 MB) repeats the mp4's audio.
- The app already composes cuts and joins (`EditMap.composition`) and renders drawings (`Annotation.Renderer`). `viewer.html` is a portable viewer, but it doesn't handle edits or drawings.

## Next step after confirmation

The shape and plan follow in this folder.
