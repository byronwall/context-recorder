# Handoff: remove the old Mac service token from Cloudflare Access

Date: 2026-10-22. For an agent (or person) working in the Cloudflare dashboard. No code changes.

## Context

- **Site:** `https://context-recorder-cloud.byron-711.workers.dev` (Worker `context-recorder-cloud`, account
  `711e96a3534ceef4677e610cb54c12b9`, Zero Trust team `byronwall.cloudflareaccess.com`).
- **What changed:** the Mac app now signs in with OAuth (browser sign-in, refresh tokens). It no longer uses the
  Access service token `context-recorder-mac`.
  - Byron's Mac is signed in this way, and a push through it was confirmed on 2026-10-22.
  - The app deleted its local copy of the service token.
- **This task:** remove the now-unused Service Auth policy and the service token.

**Do not touch:**
- The `Byron browser access` Allow policy (email `byron@byroni.us`).
- The `Context Recorder signed files` Bypass app and its paths: `/f/*`, `/api/*`, `/mcp`, `/token`, `/register`,
  `/.well-known/*`.
- One-time PIN login, DNS, the Worker, or anything for `byroni.us` / `home.byroni.us`.

## Step 1 — remove the Service Auth policy from the main app

1. Go to dash.cloudflare.com → **Zero Trust** → **Access** → **Applications**.
2. Open the main app for `context-recorder-cloud.byron-711.workers.dev`
   (app ID `1f4ff390-d73a-438f-9d20-d119ccecf084`, the one whose destination is the whole host) and click
   **Configure** (or **Edit**) → **Policies**.
3. Remove the policy named **`Context Recorder Mac`** (action **Service Auth**) from this app.
4. Check that **`Byron browser access`** (Allow, `byron@byroni.us`) is still attached, then **Save**.
5. If `Context Recorder Mac` also exists as a reusable policy under **Access** → **Policies**, delete it there
   too, but only if no other application uses it. The policy page lists the applications that use it.

## Step 2 — delete the service token

1. Go to **Zero Trust** → **Access** → **Service Auth** → **Service Tokens**.
2. Find **`context-recorder-mac`** (created 2026-10-22, one-year duration).
3. Delete it. Any policy that still references the token would block the delete, so finish Step 1 first.

## Step 3 — check it (any terminal, no credentials)

```bash
U=https://context-recorder-cloud.byron-711.workers.dev
for p in / /s/x/ /authorize /.well-known/oauth-authorization-server /api/me /mcp; do
  printf '%-42s %s\n' "$p" "$(curl -s -o /dev/null -w '%{http_code}' "$U$p")"
done
```

Expected, the same as before the change:

| Path | Expected |
| --- | --- |
| `/`, `/s/x/`, `/authorize` | `302` (to `byronwall.cloudflareaccess.com`) |
| `/.well-known/oauth-authorization-server` | `200` |
| `/api/me`, `/mcp` | `401` |

If any of these changed, don't change anything else. Report what you saw.

## Report back

- The main app's policy list after the change (it should show only `Byron browser access`).
- Confirmation that the `context-recorder-mac` token no longer appears under Service Tokens.
- The Step 3 table with the codes you actually got.
