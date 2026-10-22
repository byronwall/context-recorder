# Context Recorder cloud (Cloudflare Worker)

One Worker that stores pushed sessions, serves the shared viewer, signs in the Mac app and agents, and exposes
sessions over MCP. The format, API and sign-in are specified in
[docs/cloud-sessions.md](../docs/cloud-sessions.md) (code comments cite it as "§N"). Everything here runs
locally on Miniflare until you deploy.

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

Push from the Mac: `swift run ContextRecorder --push <session> --cloud http://localhost:8787`. A local Worker
needs no sign-in, and `/mcp` without a token runs as `DEV_IDENTITY`.

MCP from Claude Code on this Mac: `claude mcp add --transport http sessions http://localhost:8787/mcp`.

## Live deployment

| Item | Value |
| --- | --- |
| URL | https://context-recorder-cloud.byron-711.workers.dev/ (`workers_dev`; no custom domain yet) |
| Account | `711e96a3534ceef4677e610cb54c12b9`, Workers Paid |
| Worker | `context-recorder-cloud` |
| R2 / D1 / KV | `context-recorder-sessions` (`BUCKET`) / `context-recorder` (`DB`) / `OAUTH_KV` — IDs in `wrangler.jsonc` |
| Zero Trust team | `byronwall.cloudflareaccess.com` (Free; email one-time PIN) |
| Secret | `SIGNING_SECRET` (Worker secret; never stored locally) |

Deploy from `cloud/` (wrangler is a dev dependency, signed in with `wrangler login`):

```sh
pnpm typecheck && pnpm test
pnpm run copy-viewer && pnpm exec wrangler deploy
pnpm exec wrangler d1 migrations apply DB --remote   # only when migrations/ changed
```

Never set `DEV_IDENTITY` on the deployed Worker: it turns sign-in off.

### Access

Access signs a person in; the Worker checks everything else itself.

| Access app | Destinations | Policy |
| --- | --- | --- |
| Main app | the whole host (so `/`, `/s/*`, `/v/*`, `/authorize`) | Allow: `byron@byroni.us` |
| `Context Recorder signed files` | `/f/*`, `/api/*`, `/mcp`, `/token`, `/register`, `/.well-known/*` | Bypass: Everyone |

The main app's Audience tag is `ACCESS_AUD` in `wrangler.jsonc`. `/authorize` must stay behind Access: it's
where a person signs in before approving an app. Share links (`/share/*`) will need a bypass too.

### Checks after a deploy or an Access change

```sh
U=https://context-recorder-cloud.byron-711.workers.dev
for p in / /s/x/ /authorize /.well-known/oauth-authorization-server /api/me /mcp; do
  printf '%-42s %s\n' "$p" "$(curl -s -o /dev/null -w '%{http_code}' "$U$p")"
done
# expect 302 (Access) for the first three, 200 for the metadata, 401 for /api/me and /mcp
```

### Signing in

- **The Mac app:** Cloud Settings → **Sign In** (browser, Access email code, **Allow**). The sign-in is kept in
  `~/Library/Application Support/ContextRecorder/cloud-auth.json` (§6).
- **Agents:** `claude mcp add --transport http sessions <url>/mcp`, then `/mcp` in Claude Code signs in the same
  way. A Claude.ai custom connector works the same.
- **Revoking:** the library page lists **Signed-in apps**; **Sign out** revokes one.

### Cost

Workers Paid ($5/mo) covers Workers, D1 and KV at this use. R2 is free to 10 GB (about 250 sessions), then
$0.015/GB, with free egress. Zero Trust Free.

## What's next

- **Share links** (`shares` table, `/share/:token`, revoke), and asking on trash whether to delete the cloud copy.
- **Frames from Media Transformations** (`FRAMES=media`, `src/frames/media.ts`): needs a zone on Cloudflare,
  so it waits for a custom domain. Until then `get_frame` returns the nearest 2 s thumbnail.
- Rewrite `transcript.json` and the logs into edited time in the cloud copy (§1, known gap).
