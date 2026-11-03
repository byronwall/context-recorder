---
title: "Cloud share links — shape brief"
slug: "cloud-share-links"
phase: shape
status: built
last_updated: "2026-11-02"
---

# Cloud share links — what we are adding

**Outcome:** you can send someone a link to one cloud recording. The link is not the `/s/<id>/` address, it
needs no sign-in, and you can revoke it. For each link, you can see how many people opened it, from where,
and when.

**Primary flow:** **Share…** on a session (Mac app or the cloud library) → a new link `/share/<token>/` is
copied → the person opens it and watches in the normal viewer → the library shows views for that link →
**Revoke** stops the link at once.

This is milestone 6 of [cloud-sessions](../cloud-sessions/implementation-plan.md), less the trash/delete
lifecycle part. That initiative already set the rules: view-only, no expiry by default, revocable.

## Feature scope

```text
Cloud share links
├── PLANNED ADDITIONS
│   ├── Links
│   │   ├── D1 `shares`: token, session, label, created, revoked
│   │   ├── More than one link per session, each with an optional label ("Sam", "#design")
│   │   ├── /share/<token>/ serves the viewer; files resolve relative to it, as on /s/<id>/
│   │   ├── Revoke: the next request gets "This recording is no longer shared" (410)
│   │   └── Push Again keeps every link working (links point at the session id, not a version)
│   ├── View stats
│   │   ├── The viewer sends one beacon per page load on a share link
│   │   ├── D1 `share_views`: time, viewer id, country/region/city, referrer host, device
│   │   ├── Your own views (valid Access cookie) are not counted
│   │   └── Per link: views, unique viewers, last viewed, top places, top referrers
│   ├── Where you manage it
│   │   ├── Cloud library (/): a Shares panel per session — create, copy, revoke, stats
│   │   └── Mac app session menu: **Copy Share Link** (newest active link, or a new one)
│   └── Access: add /share/* to the bypass app
├── EVALUATE BEFORE COMMITTING
│   └── Watch depth (furthest point reached) from a second beacon on pagehide
└── LATER POSSIBILITIES
    ├── Link preview cards (og:title, og:image from the poster) for Slack and iMessage
    ├── Expiry date per link
    ├── A link that leaves out saved pages
    └── Stats in the Mac app
```

## Behavior

| Situation | Result |
| --- | --- |
| Open a share link signed out | The viewer plays the session. No library link in the eyebrow, no sign-in |
| Open `/s/<id>/` signed out | Access sign-in, as now. A share link gives no access to `/s/<id>/` |
| Revoke a link while someone watches | Their next file request fails. A reload shows "no longer shared" |
| Delete the cloud session | Its links and their stats go too (cascade). The link shows "no longer shared" |
| Paste the link in Slack | Slack's preview fetch loads only the HTML. It runs no JS, so it is not counted |
| Open the link twice in one browser | Two views, one unique viewer |
| Open your own link while signed in | Not counted |

## Decisions and boundaries

**Appetite:** two D1 tables, about five routes, one small viewer change, a panel on the library page and
one Mac menu item. No new Cloudflare products.

**Key decision: a random token, not the session id.** `/share/<22-char base64url token>/` (16 random bytes).
The session id is a timestamp, so anyone could guess it. A separate token per link also makes revoke and
per-link stats simple: revoke one person or one channel and keep the others. The token is kept in plain
text, so the library can show and copy it again. This is a personal tool, and the token gives view access
only.

**Key decision: count views with a beacon from the viewer, not on the HTML request.** Chat apps and mail
scanners fetch a link to build its preview. They load the HTML but do not run JS. The viewer already runs JS
to fetch `session.json`, so a `POST /share/<token>/view` after the first render counts people, not bots.
The beacon also carries `document.referrer`, which the HTML request would carry too, so nothing is lost.

**"Where they watch" means two things, and both are almost free.**
- *Place:* `request.cf` gives country, region and city for each request. No IP is stored.
- *Source:* the referrer host (`slack.com`, `mail.google.com`). Browsers send only the origin across sites,
  and many apps send nothing, so expect a large "direct" bucket.
- *Device:* mobile or desktop from the User-Agent.

**Unique viewers:** the viewer makes a random id once and keeps it in `localStorage`, then sends it in the
beacon. No cookie and no IP hash. A private window or a second device counts as a new viewer. That is
accurate enough for "how many people".

**Revocation is immediate.** Every `/share/*` request looks up the token in D1 (one indexed read). Responses
stay `private, no-cache`, so no cache keeps serving a revoked link.

**What a share link exposes:** the files the viewer loads: the video, thumbnails, mark frames,
screenshots, drawings, `session.json` (transcript included) and saved pages. The raw logs
(`activity.jsonl`, `browser.jsonl`, `marks.jsonl`) and `marks/` are not served, because activity logs hold
window titles and URLs.

**Boundary:** a share link can only read. It never reaches `/api/*`, the library or `/mcp`. Stats are
visible only behind Access (the library page and `/api/*`).

**First proof:** **Try:** on `wrangler dev`, create a link with `POST /api/sessions/<id>/shares`, open it in
a browser with `DEV_IDENTITY` off for `/share/*`, then revoke it. **Observe:** the video plays and seeks
(Range works), one `share_views` row appears per load, and the reload after revoke shows "no longer shared."
**Decide:** if the relative fetches all resolve under `/share/<token>/` with no viewer change except the
beacon, keep the viewer as one file for both modes.

## Open choices

1. **Raw logs on share links.** Decided (2026-11-02): an allowlist of the viewer's files, plus `pages/`.
2. **Watch depth.** One more beacon on `pagehide` with the furthest second reached gives "watched 3:10 of
   4:00". Cheap, but it adds an update path. Default: leave it out of the first cut.
3. **Where to show stats first.** Default: the cloud library page only. The Mac app gets Copy Share Link and
   an "Open Shares" item that opens the library at that session.

See [implementation-plan.md](implementation-plan.md).
