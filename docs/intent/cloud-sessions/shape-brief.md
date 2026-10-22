---
title: "Cloud sessions — shape brief"
slug: "cloud-sessions"
phase: shape
status: draft
last_updated: "2026-10-21"
---

# Cloud sessions — what we are adding

**Outcome:** a pushed session can be watched from any browser, shared by link, and read by any agent (on another Mac or in the cloud), all without the recording Mac.

**Primary flow:** **Push to Cloud** on the Mac → the app builds a self-contained cloud copy and uploads it → open `sessions.<your-domain>` and sign in, or connect an agent to its MCP endpoint.

## Feature scope

```text
Cloud sessions
├── PLANNED ADDITIONS
│   ├── Push from the Mac
│   │   ├── Push to Cloud / Push Again per session, with progress and a "cloud copy is out of date" badge
│   │   ├── Cloud copy = the session as you see it: cuts and joins flattened into one video,
│   │   │   drawings rendered as overlay images, session.json in that same timeline
│   │   ├── Includes logs and saved pages up to a size budget; skipped pages are listed
│   │   └── Trashing a pushed session asks: keep cloud copy / delete it too
│   ├── Cloud site (one Cloudflare Worker on your domain)
│   │   ├── Library: your pushed sessions, newest first, with thumbnail, length, marks; delete
│   │   ├── Viewer: today's viewer.html grown up — video, timeline, marks, transcript,
│   │   │   now strip, image zoom, drawings shown at their moments, Copy as Markdown
│   │   └── Share: create or revoke a view-only link per session
│   └── Agent access (MCP on the same Worker, OAuth sign-in as you)
│       ├── list_sessions, get_session (summary + every mark as Markdown)
│       ├── get_mark (Markdown, screenshot, full frame, page context)
│       ├── get_frame(session, time) and get_frames(session, from, to) for any moment
│       └── get_file_url (short-lived link to the mp4 or a saved page)
├── EVALUATE BEFORE COMMITTING
│   └── Frames from Cloudflare Media Transformations vs. frames pre-cut on the Mac at push
└── LATER POSSIBILITIES
    ├── Canvas view; "Download as ZIP" for agents; search across sessions
    └── A second Mac pulling cloud sessions into its own library
```

## Behavior

| Situation | Expected result |
| --- | --- |
| Push a session that has cuts and drawings | The cloud plays only the kept ranges, drawings appear at their moments, and mark times match the app |
| Push a joined session | One video in the cloud. The source sessions don't upload and don't appear in the library |
| Cut or annotate after pushing | The sidebar shows "cloud copy out of date." **Push Again** replaces the whole copy, and share links keep working |
| Saved pages exceed the budget | The largest pages are skipped. Marks show "page not uploaded" in the cloud and to agents |
| Open a share link | That one session in the viewer, read-only, with no sign-in. A revoked link shows "no longer shared" |
| An agent asks for a frame at 2:14 | A JPEG of that moment in the edited timeline, without drawings. Drawings come as a separate list |

## Decisions and boundaries

**Appetite:** one Worker, one R2 bucket, one D1 database and one KV namespace, plus a push command in the app. No cloud-side processing besides frame extraction.

**Key decision: flatten on the Mac, keep the cloud simple.** For the browser to show cuts and joins, it would need the segment logic, all the source videos, and a second drawing renderer written in JavaScript. Instead, the push reuses the app's own `EditMap.composition` to export one edited mp4 and its own `Annotation.Renderer` to draw each drawing as a transparent PNG. The processing step already writes `session.json` in edited time. The cloud then serves a plain session that the viewer, share links and agents all read the same way. Parity comes from the app's own code, not from rebuilding it in the browser.

**Key decision: MCP before ZIP.** A remote MCP endpoint serves both Claude Code on another Mac and cloud agents, and only it can hand an agent the frame at any time. A ZIP helps only local agents, so it moves below the cut.

**Auth:** Cloudflare Access protects the whole hostname (you, one-time PIN or GitHub). The Mac pushes with an Access service token kept in the Keychain. Share pages bypass Access and are checked against D1. MCP clients sign in through OAuth, with Access as the identity provider.

**Boundary:** nothing in the cloud edits a session. Deleting the Worker or bucket loses nothing, because the Mac copy is the source. `audio.wav` never uploads, since the mp4 already has the audio.

**First proof:** **Try:** push one edited, annotated session to the Worker running locally (`wrangler dev`, with simulated R2 and D1). **Observe:** in the local viewer, cut points, mark times and drawing times match the app to within one frame. **Decide:** if they match, flattening on the Mac is the design. If timings drift, switch to the browser stepping through segments of the original mp4 before building anything more.

**Open choices:**
1. Flattening means agents and share links never see footage you cut. I'm treating that as intended.
2. The saved-page budget defaults to half the video size, with a 10 MB minimum. Adjust it if that feels wrong.

See [intent-brief.md](intent-brief.md) and [implementation-plan.md](implementation-plan.md).
