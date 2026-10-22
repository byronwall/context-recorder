# Handoff: Cloudflare Access changes for OAuth sign-in

Date: 2026-10-22. For an agent (or person) working in the Cloudflare dashboard. No code changes.

## Context

- **Site:** `https://context-recorder-cloud.byron-711.workers.dev` (Worker `context-recorder-cloud`, account
  `711e96a3534ceef4677e610cb54c12b9`, Zero Trust team `byronwall.cloudflareaccess.com`).
- **What's new:** Worker version `a5728b8a-4ed6-4379-bee2-cdeb641301fc` (deployed 2026-10-22) is now an OAuth
  server. The Mac app and MCP agents sign in through `/authorize` and then call the API with bearer tokens.
- **The problem:** Access still guards every path, so bearer-token requests get a 302 to the Access login
  before they reach the Worker.
- **The fix:** add five paths to the existing Bypass app. The Worker checks tokens on those paths itself.

**Do not touch:**
- DNS, Namecheap, `byroni.us` or `home.byroni.us`.
- The Worker code or its settings.
- The main Access app's **Allow** policy for `byron@byroni.us`.

## Current Access setup (from the setup handoff)

| App | ID | Destination | Policies |
| --- | --- | --- | --- |
| Main (browser) app | `1f4ff390-d73a-438f-9d20-d119ccecf084` | `context-recorder-cloud.byron-711.workers.dev` (whole host) | `Byron browser access` (Allow, email `byron@byroni.us`); `Context Recorder Mac` (Service Auth, token `context-recorder-mac`) |
| `Context Recorder signed files` | `a3ea4e91-ed6d-4fdb-9f46-88744e52a546` | `context-recorder-cloud.byron-711.workers.dev/f/*` | `Worker validates signed file URLs` (Bypass, Everyone) |

## Step 1 — add the OAuth and API paths to the Bypass app

1. Go to dash.cloudflare.com → **Zero Trust** → **Access** → **Applications**, open
   **Context Recorder signed files**, and click **Configure** (or **Edit**).
2. Under **Destinations** (also labelled **Public hostnames** / **Application domain**), keep the existing
   `/f/*` row and add one row per path below. Each row uses the same hostname,
   `context-recorder-cloud.byron-711.workers.dev`:

   | Subdomain/host | Path |
   | --- | --- |
   | `context-recorder-cloud.byron-711.workers.dev` | `api/*` |
   | `context-recorder-cloud.byron-711.workers.dev` | `mcp` |
   | `context-recorder-cloud.byron-711.workers.dev` | `token` |
   | `context-recorder-cloud.byron-711.workers.dev` | `register` |
   | `context-recorder-cloud.byron-711.workers.dev` | `.well-known/*` |

   Enter the path without a leading slash if the field already shows a `/` before it.
3. Leave its policy as it is: `Worker validates signed file URLs`, **Bypass**, **Everyone**.
4. **Save.**

**Paths that must stay behind the main app's sign-in:** `/`, `/s/*`, `/v/*` and **`/authorize`**. `/authorize`
is where the person signs in with the email code; bypassing it would let anyone approve a sign-in. Don't
add a bypass that matches `/authorize` or the whole host, such as `*` or `/a*`.

If the dashboard won't accept a path containing a dot (`.well-known/*`), add it as its own self-hosted app
with the same Bypass/Everyone policy instead, and say so in the report.

## Step 2 — check it (from any terminal, no credentials needed)

```bash
U=https://context-recorder-cloud.byron-711.workers.dev
for p in /.well-known/oauth-authorization-server /.well-known/oauth-protected-resource/mcp /api/me /mcp /authorize / /s/x/; do
  printf '%-45s %s\n' "$p" "$(curl -s -o /dev/null -w '%{http_code}' "$U$p")"
done
```

Expected:

| Path | Expected | Means |
| --- | --- | --- |
| `/.well-known/oauth-authorization-server` | `200` | bypassed; the Worker serves the OAuth metadata |
| `/.well-known/oauth-protected-resource/mcp` | `200` | bypassed |
| `/api/me` | `401` | bypassed; the Worker refuses the request because it has no token |
| `/mcp` | `401` | bypassed; the Worker answers with a sign-in challenge |
| `/authorize` | `302` to `byronwall.cloudflareaccess.com` | **still guarded** (required) |
| `/` | `302` to Access | still guarded |
| `/s/x/` | `302` to Access | still guarded |

Also: `curl -s $U/.well-known/oauth-authorization-server` should return JSON whose `authorization_endpoint` is
`https://context-recorder-cloud.byron-711.workers.dev/authorize`.

**Undo:** if any guarded path returns something other than a 302 to Access, remove the row you just added and
report what happened.

## Step 3 — leave the service token in place (for now)

Don't delete the `Context Recorder Mac` policy or the `context-recorder-mac` service token yet. Byron will
remove them after the new app has signed in and pushed (clean-up step 4 in `cloudflare-handoff.md`).

## Report back

- A screenshot or list of the signed-files app's destinations after the change.
- The Step 2 table with the codes you actually got.
- Anything that didn't match these instructions, such as dashboard wording or a path that was rejected.
