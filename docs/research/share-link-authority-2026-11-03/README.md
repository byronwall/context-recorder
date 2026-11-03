---
title: "Keep share-link authority inside the intended boundary"
origin: repo-reading-brief
edition: "2026-11-03"
edition_url: "https://chatgpt.com/space/page_63bddd80dbe48191992e196af5aff2d7"
topic_id: context-recorder-capability-url-disclosure
source_title: "Lessons learned: Using a cybersecurity vendor to check for malicious links"
source_date: "2023-05-09"
source_url: "https://dropbox.tech/security/changing-how-we-identify-malicious-urls-in-shared-documents"
reviewed_at: "2026-11-03"
repository_baseline: "81a890c946d0872ceebc2861b6bed28a6662bfbd"
status: proposal
---

# Keep share-link authority inside the intended boundary

**Proposal:** before adding link-preview cards, map where a share URL can travel and test the revocation contract with a disposable local session. Keep the existing no-sign-in sharing choice. This note proposes a bounded investigation, not a new authentication system or a claim that a production leak occurred.

[Repo Reading Brief, November 3, 2026](https://chatgpt.com/space/page_63bddd80dbe48191992e196af5aff2d7) selected this reading because [the share-link stack beginning with PR 64](https://github.com/byronwall/context-recorder/pull/64) just added revocable share links, view counts and Mac/CLI entry points. The [cloud README](https://github.com/byronwall/context-recorder/blob/81a890c946d0872ceebc2861b6bed28a6662bfbd/cloud/README.md) still lists preview cards and watch depth as future work.

## What the reading adds

In its [May 9, 2023 incident account](https://dropbox.tech/security/changing-how-we-identify-malicious-urls-in-shared-documents), Dropbox says a malware-scanning integration made submitted URLs from shared documents visible to the vendor's other paid subscribers and partners. Dropbox submitted URLs, not files. Existing authentication and password controls remained intact, and Dropbox reported no evidence of malicious exploitation. It stopped submissions and had the URLs removed.

The applicable lesson is an inference: a URL that grants access is itself authority-bearing data. Sending it to a preview, scanner or analytics service can widen access without uploading the recording. The report does not establish that Context Recorder uses this vendor or has the same failure.

The W3C TAG's [capability-URL draft](https://www.w3.org/TR/capability-urls/) supplies related design vocabulary: address exposure, multiple links and targeted revocation. It is a historical working draft, not a W3C Recommendation. The proposal below is grounded in the current repository, rather than adopting every recommendation in that draft.

## What the repository already does

Checked at [`81a890c`](https://github.com/byronwall/context-recorder/commit/81a890c946d0872ceebc2861b6bed28a6662bfbd):

| Boundary | Source evidence | Consequence for this investigation |
| --- | --- | --- |
| Access to one session | [`handleShare`](https://github.com/byronwall/context-recorder/blob/81a890c946d0872ceebc2861b6bed28a6662bfbd/cloud/src/share.ts) resolves the active token before serving the viewer, files or a view beacon. [The reference](https://github.com/byronwall/context-recorder/blob/81a890c946d0872ceebc2861b6bed28a6662bfbd/docs/cloud-sessions.md#8-share-links) allows multiple 16-byte random tokens and per-link revocation. | Retain the per-link model. Test every resource path, not only the landing page. |
| What is readable | `isSharedPath` allows the manifest, session JSON, recording, drawings and listed folders, including `pages/` and `sources/`. Raw log paths and `marks/` are excluded. | A file allowlist does not itself redact fields inside session JSON or saved pages. Inventory the payloads without assuming either that they are safe or that they contain a leak. |
| Outgoing links | The viewer response sets `Referrer-Policy: no-referrer` and `X-Robots-Tag: noindex`. File responses use `nosniff` and a sandbox CSP. | Preserve these controls. They do not prevent a recipient, scanner or service that already has the full URL from copying it. |
| Browser caching | [`serveSessionFile`](https://github.com/byronwall/context-recorder/blob/81a890c946d0872ceebc2861b6bed28a6662bfbd/cloud/src/files.ts) emits `private, no-cache` ordinarily, but `?v=<matching hash>` gets `private, max-age=31536000, immutable`. [The viewer](https://github.com/byronwall/context-recorder/blob/81a890c946d0872ceebc2861b6bed28a6662bfbd/scripts/viewer.html#L347-L361) uses these pinned image URLs. | A request that reaches the Worker checks the token; a browser may reuse a fresh cached image without making that request. |
| View counts | [The viewer](https://github.com/byronwall/context-recorder/blob/81a890c946d0872ceebc2861b6bed28a6662bfbd/scripts/viewer.html#L861-L870) sends a beacon after rendering. [The tests](https://github.com/byronwall/context-recorder/blob/81a890c946d0872ceebc2861b6bed28a6662bfbd/cloud/test/share.test.ts) demonstrate that an HTML-only fetch adds no view and a beacon to a revoked link fails. | Counts measure received beacons and distinct local IDs. They are not proof of recipient identity, exclusively human access or absence of a URL disclosure. |

The [shape brief](https://github.com/byronwall/context-recorder/blob/81a890c946d0872ceebc2861b6bed28a6662bfbd/docs/intent/cloud-share-links/shape-brief.md) says no cache keeps serving a revoked link. The versioned-file path above makes that broader statement unsupported by source inspection alone. [RFC 9111](https://www.rfc-editor.org/rfc/rfc9111.html#section-5.2.2.7) allows private browser caching; `private` excludes shared-cache storage, not storage by that browser. [RFC 8246 §2](https://www.rfc-editor.org/rfc/rfc8246.html#section-2) tells clients to avoid conditional requests for fresh immutable responses. This is a concrete test target, not an executed browser finding.

## A small validation plan

Use only an artificial recording, invented transcript and disposable tokens on a local Worker. Do not paste real share URLs into scanners or public test services. Any capture must redact token strings before it is committed.

1. **Write down the authority and exposure map.** List Copy Share Link, CLI output, Copy as Markdown, logs, network traces, browser history, saved pages, third-party requests and proposed preview fetches. For each destination, record whether the full token is sent, who receives it and whether that recipient is necessary. Inspect the actual session JSON, manifest and saved-page payloads separately from their allowed filenames.
2. **Separate network denial from retained bytes.** Fetch the landing page, manifest, session JSON, one unversioned image, its hash-pinned form, video Range and a saved page. Warm a browser cache, revoke the link, then try a fresh browser, a normal reload, an already-open tab and the cached image URL. Record response status, whether a request reached the Worker, cache source and visible bytes. Include conditional GET and HEAD requests. Repeat with another link to the same session; it must remain usable.
3. **Check disclosure separately from counting.** Fetch only HTML, then run a browser that sends the beacon. Confirm what each records. Follow a harmless link to a local request collector from the viewer and from an allowed saved page; record the actual Referer behavior. Do not turn a zero view count into a security assertion.
4. **Choose the narrow contract.** If revocation means deny future service requests, say that explicitly and acknowledge already-fetched or downloaded content. If ordinary reloads must recheck access for share resources, evaluate share-specific revalidation headers and their image-load cost. Changing headers cannot erase files or screenshots a recipient already retained.
5. **Gate preview work on its own disclosure choice.** Decide what metadata a chat preview may fetch before adding it. A generic card exposes less than a title, poster or transcript. Record the intended data and recipient classes, and avoid putting a capability token into unrelated telemetry. Per-link expiry, passwords and authenticated sharing remain separate product decisions.

Acceptance evidence is a compact matrix of these paths and states with synthetic fixture identity, browser/version, statuses, headers and observed network/cache behavior. Stop when the exposure map and revocation semantics are supported by that matrix. Do not expand into a general security audit.

## Recommendation and limits

- **Investigate now:** the cache-versus-revocation boundary and token exposure map. They directly concern the newly merged feature.
- **Preserve:** per-link revocation, server-side checks, resource allowlisting, no-referrer on the viewer, and signed-in control of link management.
- **Decide before building previews:** allowed metadata and third-party disclosure. The Dropbox incident explains why a safety or convenience integration belongs in this decision.
- **Do not infer:** a production compromise, successful exploitation, human-only view counts, or erasure of previously delivered bytes.

This documentation-only proposal changes no application code, sharing defaults, deployment or permissions. Source files and existing tests were inspected through GitHub; tests were not executed here. No production share was opened, generated, revoked or submitted elsewhere. Browser-cache behavior, deployed headers, vendor behavior and saved-page payload safety remain unverified.

## Sources and duplication check

- Primary reading: Dropbox Security Team, May 9, 2023, [incident account](https://dropbox.tech/security/changing-how-we-identify-malicious-urls-in-shared-documents).
- Supporting references: [W3C TAG capability-URL draft](https://www.w3.org/TR/capability-urls/), [RFC 9111](https://www.rfc-editor.org/rfc/rfc9111.html), [RFC 8246](https://www.rfc-editor.org/rfc/rfc8246.html).
- Current implementation: [share-link stack](https://github.com/byronwall/context-recorder/pull/64), [contract](https://github.com/byronwall/context-recorder/blob/81a890c946d0872ceebc2861b6bed28a6662bfbd/docs/cloud-sessions.md#8-share-links), [share handler](https://github.com/byronwall/context-recorder/blob/81a890c946d0872ceebc2861b6bed28a6662bfbd/cloud/src/share.ts), [file handler](https://github.com/byronwall/context-recorder/blob/81a890c946d0872ceebc2861b6bed28a6662bfbd/cloud/src/files.ts), [existing share tests](https://github.com/byronwall/context-recorder/blob/81a890c946d0872ceebc2861b6bed28a6662bfbd/cloud/test/share.test.ts).
- Checked open PRs on November 3: #58 (OpenTelemetry proposal), #59 (narrated review tools) and #60 (Chrome tracing). None owns capability-URL exposure or cache-aware revocation. This note supplements the built share-link plan rather than duplicating its implementation.
