---
title: "Cloud sessions — Cloudflare setup handoff"
slug: "cloud-sessions"
phase: build
status: current
last_updated: "2026-10-22"
---

# Cloudflare setup handoff

Milestone 4 needs a real Cloudflare account. Most of it can be scripted, but a few steps need a person
(signing up, payment, your registrar, a browser sign-in). The split:

- **Part A — you, now, in the dashboard (~20 min of clicking, then a wait for DNS).** None of it depends on the code.
- **Part B — an agent with the CLI and API, once Part A is done.** Creates the resources, deploys, and sets up Access.

Replace `<domain>` with your domain and `<team>` with the Zero Trust team name you pick. The app lives at
`sessions.<domain>`.

## Part A — human-only steps (do these now)

1. **Account.** Sign in or sign up at <https://dash.cloudflare.com>. Add a payment method
   (Manage Account → Billing). R2, Workers Paid and Zero Trust all need one, even where they cost $0.
2. **Move the domain's DNS to Cloudflare.**
   - Add a domain → enter `<domain>` → **Free** plan.
   - Check the imported DNS records against your current DNS host **before** switching. Pay special attention
     to email: MX, SPF/DKIM/DMARC `TXT`, and any verification `TXT` records. Anything missing breaks when the
     nameservers change.
   - At your registrar, replace the nameservers with the two that Cloudflare shows. Turn off DNSSEC at the
     registrar first if it's on (you can turn it back on via Cloudflare later).
   - Wait until the zone shows **Active**. It usually takes minutes, but it can take up to 24 h.
   - Why the whole domain? A subdomain-only (CNAME) setup needs the Business plan.
3. **Workers Paid plan ($5/mo).** Workers & Pages → Plans → Paid. This is needed: the Worker checks the
   SHA-256 of each uploaded 30–40 MB video, which is far over the Free plan's 10 ms CPU limit.
4. **Turn on R2.** R2 Object Storage → Purchase / Enable. The free tier is 10 GB, about 250 sessions.
5. **Zero Trust (Access).** Open Zero Trust from the dashboard sidebar.
   - Choose a team name, for example `byronwall`. Your sign-in domain becomes `<team>.cloudflareaccess.com`.
   - Choose the **Free** plan (up to 50 users).
   - Settings → Authentication: One-time PIN is on by default, which is enough. Add GitHub if you'd rather.
6. **Media Transformations** (for the frames spike). Pick the `<domain>` zone → Stream → Transformations →
   enable for the zone. Free up to 5,000 transformations a month. If you can't find it, skip it; the agent
   can check through the API, and frames fall back to thumbnails anyway.
7. **API token for the agent.** My Profile → API Tokens → Create Token → **Custom token**:

   | Scope | Permission | Level |
   | --- | --- | --- |
   | Account | Workers Scripts | Edit |
   | Account | Workers R2 Storage | Edit |
   | Account | D1 | Edit |
   | Account | Workers KV Storage | Edit |
   | Account | Access: Apps and Policies | Edit |
   | Account | Access: Service Tokens | Edit |
   | Account | Access: Organizations, Identity Providers, and Groups | Edit |
   | Account | Account Settings | Read |
   | Zone (`<domain>` only) | Workers Routes | Edit |
   | Zone (`<domain>` only) | DNS | Edit |
   | Zone (`<domain>` only) | Zone | Read |
   | Zone (`<domain>` only) | Zone Settings | Edit (for Media Transformations) |

   Store it in your login Keychain. **Don't paste it into chat.** In Terminal:

   ```bash
   security add-generic-password -a "$USER" -s cloudflare-api-token-context-recorder -w
   ```

   It prompts for the token. The agent reads it with `security find-generic-password -w -s …` into
   `CLOUDFLARE_API_TOKEN` for `wrangler` and `curl`, and never prints it.

8. **Tell the agent:** the domain, the account ID (dashboard → any zone → right sidebar, or Account Home →
   ⋯ → Copy account ID), the Zero Trust team name, the email address Access should allow, and that the zone is
   Active.

`wrangler login` isn't needed, because the API token covers wrangler.

## Part B — what the agent then does (CLI and API, no dashboard)

All from `cloud/` with `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` set from the Keychain.

1. **Resources:** `wrangler r2 bucket create context-recorder-sessions`, `wrangler d1 create
   context-recorder`, `wrangler kv namespace create OAUTH_KV`. Put the IDs in `wrangler.jsonc`, then
   `wrangler d1 migrations apply context-recorder --remote`.
2. **Secrets:** `wrangler secret put SIGNING_SECRET` (random 32 bytes).
3. **Deploy:** add a custom-domain route `sessions.<domain>` in `wrangler.jsonc`, then `wrangler deploy`.
   Wrangler creates the DNS record and certificate.
4. **Access (API: `POST /accounts/:id/access/apps`):**
   - Self-hosted app `sessions.<domain>`. Policy **Allow**: your email. Policy **Service Auth**: the Mac's
     service token. Record the app's `aud` tag → `ACCESS_AUD`; `ACCESS_TEAM_DOMAIN = <team>.cloudflareaccess.com`.
   - A second self-hosted app on `sessions.<domain>/share/*` and `sessions.<domain>/f/*` with a **Bypass**
     (Everyone) policy. The Worker checks share tokens and signed URLs itself.
   - Service token `context-recorder-mac` (`POST /access/service_tokens`). Write its client id and secret
     straight into the Mac's Keychain (service `ContextRecorder.Cloud`), never to stdout or a file.
5. **Redeploy** with `ACCESS_AUD` and `ACCESS_TEAM_DOMAIN`, then check: unauthenticated `curl` → 302 to Access;
   with the service-token headers → 200.
6. **First live push:** set the cloud URL in the app (or `CR_CLOUD_URL`), push a real session, open
   `https://sessions.<domain>/` on your phone, sign in with a one-time PIN, and watch it.
7. **Media Transformations spike:** confirm transformations are on for the zone (API or a test URL). Fetch
   `https://sessions.<domain>/cdn-cgi/media/mode=frame,time=10s,width=1280/<signed /f/ url>` and record the
   latency, cold and cached. If it works, set `FRAMES=media`; otherwise keep `thumbs`.
8. **Milestone 5 (agents from anywhere):** create an Access for SaaS (OIDC) app for the MCP OAuth flow, put its
   client id, secret and endpoints in Worker secrets, wrap `/mcp` with `workers-oauth-provider`, and add Access
   **Bypass** for `/mcp`, `/authorize`, `/token`, `/register` and `/.well-known/*` (the Worker's OAuth guards
   them). Then `claude mcp add --transport http sessions https://sessions.<domain>/mcp` from a second machine.

## Cost check

| Item | Monthly |
| --- | --- |
| Workers Paid (includes D1, KV and Workers requests well past this use) | $5.00 |
| R2: 10 GB storage free, then $0.015/GB; egress free | $0 until ~250 sessions |
| Zero Trust Free, Media Transformations free tier | $0 |
| **Total** | **≈ $5** |
