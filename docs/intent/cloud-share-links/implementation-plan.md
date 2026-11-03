---
title: "Cloud share links — implementation plan"
slug: "cloud-share-links"
phase: plan
status: building
last_updated: "2026-11-02"
---

# Cloud share links — implementation plan

## Plan at a glance

The risk is small and mostly in two places: the viewer must work unchanged under a second path, and the view
count must count people, not preview bots. So milestone 1 proves links and revoke on `wrangler dev` with no
stats. Milestone 2 adds the beacon and the stats panel. Milestone 3 adds the Mac menu item, and milestone 4
deploys and opens the Access bypass. Each milestone leaves a working system. Why it's shaped this way is in
[shape-brief.md](shape-brief.md).

## Data (one migration: `cloud/migrations/0002_shares.sql`)

```sql
CREATE TABLE shares (
  token TEXT PRIMARY KEY,                -- 16 random bytes, base64url (22 chars)
  session_id TEXT NOT NULL REFERENCES sessions (id) ON DELETE CASCADE,
  label TEXT,                            -- optional, ≤ 100 chars ("Sam", "#design")
  created_at TEXT NOT NULL,
  created_by TEXT NOT NULL,
  revoked_at TEXT                        -- null = active
);
CREATE INDEX shares_session ON shares (session_id);

CREATE TABLE share_views (
  token TEXT NOT NULL REFERENCES shares (token) ON DELETE CASCADE,
  viewed_at TEXT NOT NULL,
  viewer TEXT NOT NULL,                  -- random id from the viewer's localStorage
  country TEXT, region TEXT, city TEXT,  -- request.cf
  referrer TEXT,                         -- host only, null = direct
  device TEXT                            -- "mobile" | "desktop"
);
CREATE INDEX share_views_token ON share_views (token, viewed_at DESC);
```

Check first: D1 enforces `ON DELETE CASCADE` only with foreign keys on. If `sessions` → `session_files`
already cascades in tests, this does too. If not, `Store.deleteSession` deletes the shares itself.

## Routes

| Method & path | Who | Result |
| --- | --- | --- |
| `POST /api/sessions/:id/shares` | owner | `{ label? }` → `{ token, url, label, createdAt }` |
| `GET /api/sessions/:id/shares` | owner | `[{ token, url, label, createdAt, revokedAt, views, viewers, lastViewedAt, places: [{ name, views }], referrers: [{ host, views }] }]` |
| `POST /api/shares/:token/revoke` | owner | `204` |
| `GET /share/:token` | anyone | `301` → `/share/:token/` |
| `GET /share/:token/` | anyone | the viewer, or the "no longer shared" page (`410`, unknown token `404`, same page) |
| `GET /share/:token/<path>` | anyone | `serveSessionFile` for the token's session (Range, ETag as now) |
| `POST /share/:token/view` | anyone | `{ viewer, referrer }` → `204`. Skipped when the request has a valid Access cookie |

`/share/*` is handled in `handleRequest` before `identify()`, next to `/f/*`. A `shareSession(token)` lookup
in `Store` returns the session id for an active token or throws `410`/`404`.

The beacon accepts any body type (it is not authenticated, so the 415 CSRF rule adds nothing). Limit
`viewer` to 40 characters and `referrer` to a host name. Store `request.cf?.country`, `region`, `city`.

## Milestone 1: links and revoke, local

- **Change — Worker:** the migration (`shares` only is enough here), `Store.createShare/listShares/revokeShare/
  shareSession`, the routes above without `/view`, and a small `notShared()` HTML page in the library's style.
- **Change — viewer:** none expected. Its fetches are relative, and the eyebrow's library link already
  matches only `/s/<id>/`. Check that **Copy as Markdown** builds share URLs, which is what a guest wants.
- **Checks (vitest):** create → open → file with Range → revoke → `410`; unknown token → `404`; a token for
  session A can't read session B's files; a share request never reaches `/api`.
- **Done when:** a signed-out browser on `wrangler dev` plays a session from `/share/<token>/` and gets the
  "no longer shared" page after revoke.

## Milestone 2: view stats

- **Change — viewer:** when `location.pathname` matches `/share/<token>/`, after the first render, send
  `navigator.sendBeacon("view", JSON.stringify({ viewer, referrer: document.referrer }))`. `viewer` comes
  from `localStorage` (made once with `crypto.randomUUID()`), in a `try`, so a blocked store still counts
  the view with a throwaway id.
- **Change — Worker:** `share_views`, the `/view` route, owner skip, and the aggregates in
  `GET /api/sessions/:id/shares` (plain `GROUP BY` queries; the data is tiny).
- **Change — library page:** a **Share** button per row opens a panel under the row: each link with label,
  **Copy**, **Revoke**, views, viewers, last viewed, top 5 places, top 5 referrers. **New link** with an
  optional label. Same cookie-auth pattern as **Delete** and **Sign out**.
- **Checks (vitest):** one beacon = one row; owner cookie = no row; aggregates count views and distinct
  viewers. One manual check: fetching the share page with `curl` (a stand-in for a preview bot) adds no row.

## Milestone 3: Mac app

- **Change:** `CloudClient.shares(id)` and `createShare(id)`. In the session menu beside **Copy Cloud Link**:
  **Copy Share Link** (the newest active link, or a new one) and **Manage Shares…** (opens `/#<id>` in the
  library with the panel open).
- **Change:** `--share <session> [--label <text>]` on the CLI prints the URL, for scripts and tests.
- **Done when:** one click copies a link that opens signed out.

## Milestone 4: live

- **Change — Access:** add `/share/*` to the `Context Recorder signed files` bypass app (Cloudflare
  dashboard; Byron does this or approves it).
- **Deploy:** `wrangler d1 migrations apply DB --remote`, then deploy as in `cloud/README.md`.
- **Checks:** add `/share/x/` to the README's post-deploy curl loop (expect `404`, not Access's `302`).
  Open a real link on a phone on cellular, signed out, and confirm one view with the right city.
- **Docs:** add the routes to `docs/cloud-sessions.md` §2, the bypass to the README's Access table, and
  remove "Share links" from the README's "What's next".

## Open decisions

Settled 2026-11-02: share links serve an allowlist, watch depth waits, and stats show on the library page.
