# Cloudflare sessions setup — handoff to Opus

Date: 2026-10-22
Status: Cloud resources deployed; Access checks passed. First real session upload remains.

## User decisions — these override cloudflare-setup.md

- Use `workers.dev` for this release.
- Do not move `byroni.us` to Cloudflare.
- Do not change Namecheap nameservers, DNS records, redirects, or dynamic DNS.
- Leave `home.byroni.us` alone.
- Byron approved Workers Paid at $5/month plus usage, R2, and Zero Trust Free.
- Byron may buy a dedicated domain later. Do not buy one or configure it now.

The DNS migration instructions in `cloudflare-setup.md` do not apply to this deployment.
No Namecheap settings changed. No domain was added to Cloudflare.

## Live configuration

| Item | Value |
| --- | --- |
| Sessions URL | https://context-recorder-cloud.byron-711.workers.dev/ |
| Cloudflare account | `711e96a3534ceef4677e610cb54c12b9` |
| Worker | `context-recorder-cloud` |
| Workers account subdomain | `byron-711.workers.dev` |
| R2 bucket / binding | `context-recorder-sessions` / `BUCKET` |
| D1 database / binding | `context-recorder` / `DB` |
| D1 database ID | `590495b5-15c6-49a3-aef5-f6ec49f61113` |
| KV binding | `OAUTH_KV` |
| KV namespace ID | `7a959f801b2c491aa0c0c642b094e11f` |
| Access team domain | `byronwall.cloudflareaccess.com` |
| Browser Access app ID | `1f4ff390-d73a-438f-9d20-d119ccecf084` |
| Access audience | `676c1ecca4c802bfba747a42a894ba5a402f67e95175cab45596a094eda88c67` |
| Signed-files Access app ID | `a3ea4e91-ed6d-4fdb-9f46-88744e52a546` |
| Deployed Worker version | `f8f5a529-12a4-4a67-82d4-07cb539f9f12` |

`cloud/wrangler.jsonc` contains these bindings and Access variables. It enables `workers_dev` and disables preview URLs.
`0001_sessions.sql` was applied to the remote D1 database. R2 uses Standard storage and has no public bucket endpoint configured by this setup.

## Access policies

The root hostname has two policies:

- `Byron browser access`: Allow the exact email `byron@byroni.us`.
- `Context Recorder Mac`: Service Auth with the specific `context-recorder-mac` token.

The separate `Context Recorder signed files` app matches only:

`context-recorder-cloud.byron-711.workers.dev/f/*`

Its `Worker validates signed file URLs` policy uses Bypass / Everyone.
The Worker still validates the file signature. An unsigned file request returned `403` with `{"error":"missing signature"}`.

One-time PIN was added as a login method. The live login page now shows Email and Send login code.
The existing Cloudflare login provider remains available. The root email allow rule still limits browser access.

No bypass was added for `/share/*`, `/mcp`, OAuth endpoints, or `/.well-known/*`.
The inspected Worker has no share handler yet. Configure those paths when their Worker guards exist.

## Credentials and local settings

- `SIGNING_SECRET`: generated from 32 random bytes and stored directly as a Worker secret. Its value was not printed or saved locally.
- Mac service token: `context-recorder-mac`, one-year duration.
- Mac Keychain service: `ContextRecorder.Cloud` in the login keychain.
- Keychain account: the service token client ID. Keychain password: its client secret.
- This matches `CloudSettings.token()` in `Sources/ContextRecorder/Cloud/CloudClient.swift`.
- App preference `com.byronwall.ContextRecorder`, key `cloudURL`, is set to the sessions URL above.

Wrangler 4.151.3 is already installed in `cloud/`. Use `pnpm exec wrangler`; no global installation is needed.
Wrangler OAuth login succeeded for `byron@byroni.us` in the account above.
Its credentials use an encrypted configuration file with the encryption key in macOS Keychain, service `wrangler`, account `default`.

OAuth scopes: account/user read; Workers, Workers Scripts, KV, and D1 write; offline refresh.
Wrangler warns about omitted scopes for unrelated products. Do not expand them merely to remove that warning.
No custom Cloudflare API token was created. Access setup used the dashboard; this OAuth login does not provide Access API administration.

macOS may request approval when the app or a CLI reads the service credential.
Keep credentials out of chat, command arguments, logs, repository files, and handoff text.

## Verification completed

- `pnpm run typecheck`: passed.
- `pnpm test`: 5 files, 52 tests passed.
- `pnpm build`: deployment dry run passed.
- Real Worker deployment: passed.
- Signing secret upload: passed.
- Unauthenticated `GET /`: `302` to `byronwall.cloudflareaccess.com`.
- Valid Mac service-token headers, `GET /`: `200`, HTML session library.
- Valid Mac service-token headers, `GET /api/sessions`: `200`, `[]`.
- Unsigned `GET /f/2026-10-22_00-00-00/video.mp4`: `403`, missing signature.
- Browser: email PIN entry is visible.

The first diagnostic request used Python urllib and received Cloudflare error 1010.
Repeating with curl and the same Keychain credentials passed. Use curl for the setup checks.

## Continue here

Work in the existing checkout:

`/Users/byronwall/Projects/context-recorder/.claude/worktrees/cloud-session-storage-viewer-408214`

From `cloud/`, deployment commands remain:

```sh
pnpm run copy-viewer
pnpm run typecheck
pnpm test
pnpm exec wrangler deploy
```

1. Build the Mac app with its new Cloud Settings UI. The currently installed app did not expose that menu.
2. Use the saved cloud URL and Keychain token. Confirm the new build can read both.
3. Push a session Byron chooses. No recordings were uploaded during setup.
4. Open the sessions URL on a phone, request an email PIN, and check video playback.
5. Verify a valid signed file URL, expiry, range requests, and duplicate push behavior against the live service.
6. Keep `FRAMES=thumbs`. The Media Transformations spike was not run on `workers.dev`.
7. Continue milestone 5 OAuth/MCP work separately. Its Access-for-SaaS app and secrets do not exist yet.

Do not claim the full milestone 4 acceptance check is complete until a real session plays on the phone.
No application source was changed by this setup. The local changes were deployment configuration, generated build output, this handoff, and app preferences.

## Live checks (2026-10-22, after setup)

From the CLI build (`.build/debug/ContextRecorder --push`, Keychain token, saved `cloudURL`):

- First push of the edited test session `2026-10-21_23-54-38` (3 cuts, drawings): 39 files, 13.6 MB.
- Re-push: 0 files uploaded.
- Unauthenticated `GET /s/<id>/recording.mp4`: `302` to Access.
- With the service token: viewer `200`, `Range: bytes=0-999` on the mp4 → `206`, 1000 bytes.
- MCP `get_file_url` → signed `/f/` URL, fetched with no credentials and a Range → `206`. A tampered signature → `403`.
  Expiry is covered by the vitest suite but wasn't checked live.
- MCP `get_frame` at 15.5 s → text plus a JPEG; `list_sessions` returns the session.

Still open: the phone playback check (needs Byron's email PIN), and installing the app build that has Cloud Settings.

## Switch-over to OAuth sign-in (contract §6)

The service token is replaced by browser sign-in. Live steps, in this order:

1. **Deploy** from `cloud/`: `pnpm run copy-viewer && pnpm exec wrangler deploy`. This changes nothing on its
   own: Access still guards every path, so the old service token keeps working.
2. **Access (dashboard → Zero Trust → Access → Applications → "Context Recorder signed files" → Edit).**
   Add these destinations on `context-recorder-cloud.byron-711.workers.dev`, next to `/f/*`, so its
   Bypass policy covers them: `/api/*`, `/mcp`, `/token`, `/register`, `/.well-known/*`.
   Leave `/`, `/s/*` and `/authorize` on the main app (that's where the email PIN sign-in happens).
   Wrangler's OAuth login has no Access scope, so this is a dashboard edit.
3. **App:** install the new build (`scripts/build-app.sh`), open **Cloud Settings… (⌘,)**, press **Sign In**,
   sign in with the email code, press **Allow**. Push a session.
4. **Clean-up:** in Zero Trust, delete the `Context Recorder Mac` Service Auth policy and the
   `context-recorder-mac` service token. The app already deleted its Keychain copy.
5. **Agents:** `claude mcp add --transport http sessions https://context-recorder-cloud.byron-711.workers.dev/mcp`,
   then `/mcp` in Claude Code to sign in the same way.

## Cloudflare references

- [Workers on workers.dev](https://developers.cloudflare.com/workers/configuration/routing/workers-dev/)
- [Cloudflare Access for Workers](https://developers.cloudflare.com/workers/configuration/cloudflare-access/)
- [Partial DNS setup requires Business or Enterprise](https://developers.cloudflare.com/dns/zone-setups/partial-setup/)
