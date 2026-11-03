# Context Recorder: adopt, integrate, or keep building?

https://github.com/byronwall/context-recorder

Source commit: `1d9f29d4b38c8c964b948b9ba244289947476b9e`.
Research branch: `codex/narrated-review-comparison`. Use the source commit, not changing branch contents.
Mode: Strategy, with a concrete comparison plan and conditional build milestones.

## Mission

Which existing tools should Byron adopt or integrate, and which parts of Context Recorder remain worth building for his narrated-review-to-coding-agent workflow?

Search broadly for as many relevant competing products as possible, up to 15 products total including Context Recorder. Aim to fill that comparison with substantive candidates. Do not stop at a narrow shortlist. Compare, contrast, and harmonize their complete feature sets, then apply Byron's workflow to the adoption decision. Include screenshots plus written instructions as an additional workflow baseline, not a product slot.

Act as a developer-tools researcher who has shipped browser capture and agent integrations. Make the strongest case for an existing product. Give candid tradeoffs and a recommendation grounded in the actual code and current primary sources. Competitors do not invalidate a useful personal tool. Personal utility does not establish commercial differentiation.

## Access check

First confirm access to the exact repository commit or the attached source packet. The packet contains selected public source files at that commit and local static observations. Inspect source before claiming a feature works. If decisive source is missing from both sources, stop and name the smallest missing input. Disclose inaccessible blog or prior-review content. Do not claim a full review from partial access.

## Workflow and baseline

Byron records a deliberate narrated walkthrough of a web application. He marks interface states and gives the evidence to a coding agent. The recording can cover bugs, design feedback, interaction changes, and new features in one sitting. The desired result is several understood requests and reviewed, verified changes without manually writing separate tickets. The developer still reviews the changes.

Workflow account: https://byroni.us/blog/from-a-narrated-review-to-sixteen-stacked-prs
Byron reports twelve minutes, thirteen diagrams, forty-four marked frames, twenty-eight extracted requests, and sixteen stacked PRs. Treat this as personal workflow evidence, not an independently measured outcome. Some requests remained unresolved.

Prior adversarial review: https://chatgpt.com/c/6add7081-a3cc-83ea-82dc-3b7325045e46
Its conclusions are hypotheses to verify independently. It rejected Breadcrumbs as a public name and identified substantial Jam overlap and Innerloop's adjacent Breadcrumb product. The private conversation is not included in the source packet. Disclose if you cannot access it; independently assess those stated conclusions from primary sources.

## Reading route

Read at minimum these files. Broaden repository discovery when a conclusion needs it.

1. `README.md`, `Package.swift`, `cloud/package.json`, and packet project rules.
2. `Sources/ContextRecorder/Recorder.swift`, `Session.swift`, `ContextProbe.swift`, `BrowserBridge.swift`, and `extension/{manifest.json,page.js,background.js,relay.js}`.
3. `scripts/process_session.py`, `Sources/ContextRecorder/Library/{Review.swift,SessionData.swift,MarkText.swift,Edits.swift}`, and `Sources/ContextRecorder/Export/PgmExport.swift`.
4. `docs/cloud-sessions.md`, `Sources/ContextRecorder/Cloud/CloudBundle.swift`, `cloud/src/{manifest.ts,markdown.ts,mcp/server.ts}`, and `cloud/test/mcp.test.ts`.
5. `docs/research/recording-tools/{baseline-notes.md,research-review.md}`. These describe an older commit. Several limitations have since changed. Recheck all decisive claims.

The current source contains canvas, image/video annotation, editing, text search, portable exports, and optional cloud MCP paths. Their presence is code evidence, not proof of a successful live test. Source inspection still finds `extension/page.js:describe` reading `target.innerText || target.value`; do not repeat blanket claims that input values cannot enter captured context. No private recording, native capture test, or competitor trial accompanies this packet.

## Ranked questions

1. What is the strongest relevant competitive landscape, up to 15 products total? Search beyond the named examples. Include Jam and Innerloop Breadcrumb, and assess Loom's agent mode. Cover deliberate review, bug capture, passive replay, personal screen memory, and live agent browser inspection. Select the strongest candidates across those categories. Do not pad the list with unrelated tools. Explain inclusion and substitution choices, and distinguish direct competitors from partial substitutes. For every product, establish how far it supports the complete deliberate, multi-request workflow and what the human must still do.
2. How do all discovered features compare and fit together? Build a shared feature taxonomy from the union of meaningful capabilities across the selected products. Preserve unique features as well as common ones. Map vendor terms to the same concept only when behavior matches; explain important differences, variants, prerequisites, and combinations. Cover capture, synchronization, review/editing, search/retrieval, agent handoff, integrations, collaboration, privacy, and export. Separate raw video, selected frames, transcript, DOM snapshots, accessibility trees, selectors, component/source hints, events, logs, and request/response payloads. Establish element grounding, multiple-request separation, corrections, canceled instructions, ambiguity, stale recordings, and rerendered interfaces. Separate implementation from documentation and untested inference. Identify complementary features and integration seams, not just a winner or feature count.
3. What context and links are missing? Check repository/ref, runtime, environment, dependencies, request-to-evidence links, change links, and verification results. Identify concrete gaps worth building versus gaps better solved by integration or agent workflow. Distinguish personal control from commercial differentiation.
4. What are the practical costs and constraints today? Check pricing, plans, platforms, setup, agent compatibility, export and service dependencies, local/self-hosted paths, data leaving the machine, redaction, retention, and sensitive fields. Do not treat local storage or a blur overlay as complete sanitization. Unknown is not absent. Mark shipped, beta, marketing, inferred, and hands-on tested status separately.
5. What small comparison would decide adoption versus continued building? Specify the same application, starting source commit, three to five real requested changes, agent configuration, separate clean runs, and acceptance criteria. Measure total human effort until accepted changes, including clarification, missed requests, wrong targets, cleanup, and verification failures. Recording speed and PR count are secondary. Give conditional next steps for adopt, integrate, and keep building, plus a stop rule.
6. Does the naming conclusion materially change after current research? Byron prefers Breadcrumbs, plural. Candidate domains included dropbreadcrumbs.dev, mybreadcrumbs.dev, and sendbreadcrumbs.com. None was bought and no rename was committed. Assess the relevant collision with Innerloop Breadcrumb separately from product utility. No legal clearance, domain purchase, or large naming brainstorm.

## Required competitor starting sources

- https://jam.dev/blog/meet-the-new-jam-mcp/ — March 5, 2026 announcement; independently check current scope and limits.
- https://jam.dev/docs/jam-mcp — follow current official documentation.
- https://innerloop.works/breadcrumb/mcp — establish actual capture and agent access, not assumed DOM parity.
- https://innerloop.works/blog/introducing-breadcrumb
- https://support.atlassian.com/loom/docs/record-for-agent/ — verify current availability and limits.

## Evidence and scope

Cite repository paths and symbols for code claims. Use current primary product docs, pricing pages, papers, and source repositories for decisive external claims. Give URLs and access dates. Separate facts, inferences, proposals, and unknowns. Independently check prior conclusions. Do not infer absence solely from marketing silence. Research the full set before recommending a finalist. Prefer feature-specific evidence over a generic homepage citation. Resolve high-value unknowns before adding peripheral features; disclose the remaining limits.

Research only. Do not modify repositories, install tools, purchase subscriptions, upload private recordings, contact vendors, or run comparative capture trials. Codex owns documentation integration and the review PR. Do not commit or push. Existing Swift and browser JavaScript stay as they are; new cloud work uses TypeScript and pnpm. Assume one personal developer, one server/client/version, with simple implementation and few meaningful tests. Do not add enterprise infrastructure or compatibility layers by default.

## Deliverable contract

Attach downloadable Markdown files and CSV matrices. Link each in the final response. A ZIP is optional. If attachments are unavailable, provide the full content inline.

1. `comparison-report.md`: lead with one paragraph deciding what to adopt, integrate, or keep building. Answer the ranked questions. Include the strongest adoption case, concrete remaining gaps, commercial versus personal judgment, and a short separate naming verdict. Cite each material recommendation.
2. `comparison-matrix.csv`: one row per product, up to 15 including Context Recorder, plus the simple workflow baseline. Cover the shared feature taxonomy, agent exposure, complete-workflow limits, pricing/platform/setup, privacy/export, and evidence status. Use explicit supported, partial, unsupported, unknown, and not-applicable states with qualifications. Keep evidence status separate from capability status.
3. `comparison-plan.md`: a reproducible three-to-five-change trial, scoring sheet, acceptance criteria, effort accounting, and decision/stop rules. Do not invent measured results. Follow with conditional, independently useful milestones, naming repository files/modules, a useful proof, main risk, and a suggested next Design-mode question for each capability bet. This is a proposal, not approval to build.
4. `recommendations.md`: stable IDs, ranked recommendations, each marked Build, Explore, Defer, or Avoid, with a one-line reason and evidence. Build means a planning recommendation only.
5. `feature-harmonization.md`: define the shared taxonomy and map each product's terms to it. Explain meaningful differences, unique strengths, redundant capabilities, complementary combinations, and integration boundaries. Include a concise feature-family comparison readable without opening the full matrix.
6. `feature-evidence.csv`: one row per product/feature claim, with the normalized feature ID, vendor term, capability state, qualification, evidence status, source URL or repository symbol, and access date. This supports the wide matrix without forcing one generic source across an entire product.

End with access status, files read, checks performed versus proposals, deliverable links, product count and selection coverage, and open questions. Give broad feature coverage within the 15-product limit and a clear final decision.
