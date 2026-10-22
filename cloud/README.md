# Context Recorder cloud (Cloudflare Worker)

One Worker that stores pushed sessions, serves the shared viewer, and exposes them to agents over MCP.
The binding spec is [`docs/intent/cloud-sessions/contract.md`](../docs/intent/cloud-sessions/contract.md)
(§2 HTTP API, §4 MCP, §6 sign-in). Everything here runs locally on Miniflare; nothing touches a Cloudflare account
until you deploy.

## Layout

| Path | What |
| --- | --- |
| `src/index.ts` | `workers-oauth-provider` in front (`/token`, `/register`, `/.well-known/*`, bearer-only `/mcp`), then the router |
| `src/identity.ts` | Bearer token, Access JWT header, `CF_Authorization` cookie (same-origin writes), or `DEV_IDENTITY` |
| `src/authorize.ts` | `/authorize` consent page (Access signs the person in; Allow completes the grant) |
| `src/store.ts` | R2 blobs (`blobs/<sha256>`), D1 sessions/files/blobs, hash checks, multipart, orphan GC |
| `src/api.ts` | `/api/*` routes, including `/api/me` and `/api/grants` (signed-in apps, revoke) |
| `src/files.ts` | `/s/:id/<path>` and `/f/:id/<path>`: Range/206, ETag, viewer at `/s/:id/` |
| `src/library.ts` | `GET /` |
| `src/signing.ts` | HMAC-SHA256 signed `/f/*` URLs (≤ 1 h) |
| `src/frames/` | `Frames` port: `thumbs` (default) and `media` (Media Transformations) |
| `src/markdown.ts` | Port of the viewer's `markdownFor()`; keep in sync with `scripts/viewer.html` |
| `src/mcp/` | MCP tools (`server.ts`) and the stateless `createMcpHandler` wiring (`handler.ts`) |
| `migrations/` | D1 schema |
| `public/viewer.html` | Copied from `../scripts/viewer.html` by `pnpm copy-viewer` (gitignored) |

## Local development

```sh
pnpm --dir cloud install
cp cloud/.dev.vars.example cloud/.dev.vars     # DEV_IDENTITY + SIGNING_SECRET
pnpm --dir cloud db:migrate:local              # creates the local D1 tables (once)
pnpm --dir cloud dev                           # http://localhost:8787 (copies the viewer first)
pnpm --dir cloud test                          # vitest in workerd (copies the viewer first)
pnpm --dir cloud typecheck
pnpm --dir cloud build                         # bundle check only (wrangler deploy --dry-run)
```

Local R2/D1/KV state lives in `cloud/.wrangler/` (gitignored); delete it to start over.

Push from the Mac: `swift run ContextRecorder --push <session> --cloud http://localhost:8787`.

MCP from Claude Code on this Mac: `claude mcp add --transport http sessions http://localhost:8787/mcp`.

### Notes for clients

- `PUT /api/blobs/:sha256` needs `Content-Length` and accepts up to 90 MiB (94,371,840 bytes). Use the
  multipart routes above that.
- `POST` bodies must be JSON. `text/plain`, form and multipart content types get `415` (they skip the
  browser's CORS preflight, so refusing them blocks cross-site writes with the Access cookie).
- `/s/:id/<path>` responses carry `ETag: "<sha256>"` and `Cache-Control: private, no-cache` (paths keep
  their URL across pushes while the bytes change). Add `?v=<sha256>` to get immutable caching.

## Deploy

Fill these in before the first `wrangler deploy`; the account setup itself is covered in the separate
handoff.

| What | Where | How to get it |
| --- | --- | --- |
| D1 `database_id` | `wrangler.jsonc` → `d1_databases[0].database_id` | `wrangler d1 create context-recorder` |
| KV `id` | `wrangler.jsonc` → `kv_namespaces[0].id` (`OAUTH_KV`, used from M5) | `wrangler kv namespace create OAUTH_KV` |
| R2 bucket | `wrangler.jsonc` → `r2_buckets[0].bucket_name` (`context-recorder-sessions`) | `wrangler r2 bucket create context-recorder-sessions` |
| `ACCESS_TEAM_DOMAIN` | `wrangler.jsonc` → `vars` | Zero Trust team domain, e.g. `myteam.cloudflareaccess.com` (no scheme) |
| `ACCESS_AUD` | `wrangler.jsonc` → `vars` | The Access application's Audience (AUD) tag |
| `FRAMES` | `wrangler.jsonc` → `vars` | `thumbs` (default) or `media` after the M4 spike |
| `SIGNING_SECRET` | secret | `wrangler secret put SIGNING_SECRET` (long random string) |
| Route / custom domain | `wrangler.jsonc` → add `"routes": [{ "pattern": "sessions.<domain>", "custom_domain": true }]` | |

Then `wrangler d1 migrations apply DB --remote` and `pnpm --dir cloud copy-viewer && wrangler deploy`
(from `cloud/`).

Never set `DEV_IDENTITY` on the deployed Worker: it turns off Access verification.

Access must allow these paths through without a sign-in (Bypass policies), because the Worker checks
them itself: `/f/*` (signed URLs, also the Media Transformations source), `/api/*`, `/mcp`, `/token`,
`/register`, `/.well-known/*` (bearer tokens; the browser's `CF_Authorization` cookie still works on
`/api/*`) and, from M6, `/share/*`. `/authorize`, `/` and `/s/*` stay behind Access: that's where a
person signs in.

## What's next

- **Agents.** `claude mcp add --transport http sessions <origin>/mcp`, then `/mcp` in Claude Code
  signs in: it registers itself, opens the browser to `/authorize` (Access, then **Allow**), and keeps a
  refresh token. A Claude.ai custom connector works the same way. Each shows up under **Signed-in apps**
  on the library page, where **Sign out** revokes it.
- **Frames.** `FRAMES=media` asks Media Transformations (`src/frames/media.ts`) instead of thumbnails.
  It needs a zone on Cloudflare, so it waits for a custom domain.
- **M6.** A `shares` table and `/share/*`, which skip Identity like `/f/*`.
