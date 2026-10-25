# Decide what to adopt, integrate, or build

Status: proposed. No trial or application change has run.
The [research summary](../../research/narrated-review-comparison/summary.md) explains the recommendation.
[Pro conversation](https://chatgpt.com/c/6add7517-fa5c-83ea-a835-b48d3709a763).

Keep Context Recorder available. Compare Jam and Clipy before broad capture or editor expansion.
Vidmatic can replace a challenger when its issue workflow or client support fits better.
Use [the feature comparison](../../research/narrated-review-comparison/feature-comparison.csv) to check that choice.

## Proposed comparison

Use the browser viewer at `1d9f29d4b38c8c964b948b9ba244289947476b9e` as the target application.
Prepare synthetic session fixtures with six marks, two screenshots, multiline notes, review origin, narration, and page events.
Include an audio recording without a transcript. Keep an ordinary and a flattened cloud session.
Use harmless HTML-like note text to check escaping.

The five final requests are:

| Request | Acceptance condition |
| --- | --- |
| R1: preserve typed notes | Notes and useful titles survive web display, per-mark copy, all-mark copy, and cloud MCP. |
| R2: add web Find | Case-insensitive query covers marks, notes, transcript, and page events. Counts and clear behavior are correct. |
| R3: add Copy visible marks | Two matching marks copy two. Copy all still copies six. No match never copies all. |
| R4: show review origin | Review marks say Added during review and explain that no new live page snapshot exists. |
| R5: label absent transcripts honestly | Empty transcript surfaces say No transcript available. Existing transcript rendering still works. |

These requests follow inspected source gaps. They are related tasks, not five independent experiments.
R3 depends on R2. This workload cannot rank production debugging or runtime-tracing depth.
Relevant paths are `scripts/viewer.html`, `cloud/src/markdown.ts`, `cloud/test/mcp.test.ts`, and `scripts/process_session.py`.
Native comparison paths are `Sources/ContextRecorder/Library/MarkText.swift` and `Review.swift`.

Record one roughly twelve-minute review for each capture product. Use the same outline and final intent.
First request marks-only search, then broaden it to all text.
First suggest changing Copy all, then cancel that change and request a separate Copy visible control.
Refer to This Copy control while two controls are visible. Keep the same clarification available for every agent.
Change tabs and filters to rebuild the DOM. Check whether current targets are identified again.
Count retakes, corrections, manual evidence transfer, and product-specific interruptions.

Compare four runs: Context Recorder, two eligible challengers, and screenshots plus written instructions.
Let the written baseline resolve final wording clearly. Charge its writing and image-selection time.
Let each competitor use its native strengths. Give every agent the same external browser and test tools.

Freeze the exact coding client/version, model ID, reasoning settings, tool access, common prompt, and budget.
Also freeze the source, fixture files, browser/runtime versions, viewport, app state, and dependency lockfile.
Use fresh agent history and separate clean directory copies or clones. Never create worktrees without Byron's explicit request.
Record run order before starting. Do not pass answers from an earlier run to a later run.

First spend at most 45 active minutes checking public compatibility, plan limits, and available prerequisites.
Choose two challengers and record eligible, conditional, or blocked with the reason and source.
Do not install tools, purchase access, or upload recordings under this research authorization.
If two challengers cannot qualify, report the missing prerequisites instead of inventing results.

Give every agent the same task: recover final requests, cite evidence, reconcile corrections, inspect the current app, and return verified changes.
Review its extracted plan once. Record missed asks, wrong targets, and clarification before implementation.
Require all five requests, preserved cancellation, no material regression, and evidence from the tested build.
Use the existing relevant cloud tests and type check only when the later implementation changes that behavior.

| Record for each run | Value |
| --- | --- |
| Exact client, model, source, configuration, and fixtures | Not run |
| Setup and learning time | Not run |
| Capture or writing; retakes and corrections | Not run |
| Handoff, request reconciliation, and clarification | Not run |
| Code review, wrong-target repair, verification, and cleanup | Not run |
| Total active human minutes; elapsed time; cost | Not run |
| Correct final requests on first plan, out of five | Not run |
| Missed, invented, duplicate, canceled, or wrong-target work | Not run |
| Accepted requests, remaining defects, and blocking reason | Not run |

Keep one row per request with its original evidence, final interpretation, change reference, tested build, check result, and reviewer decision.
Retain failed attempts and their effort. Separate capture, retrieval, intent, targeting, implementation, and verification failures.

Pro proposed an adoption threshold of 25% and ten active human minutes saved against Context Recorder.
Treat that as a suggested personal preference. Byron has not selected it.
Require acceptable cost and data handling, plus a result better than the written baseline.
An explicitly valued control benefit can justify extra effort. Record that choice rather than hiding it in a score.

Cap the first comparison at six active hours: 45 minutes for eligibility, 45 for setup, four 60-minute runs, and 30 for synthesis.
A tie or material interruption permits a second different batch between the two relevant runs, capped at two active hours.
At eight hours, decide provisionally or retain the existing workflow. Do not keep testing until a preferred tool wins.

## Conditional implementation

M1 is useful while Context Recorder sessions remain in use. Other milestones require an observed problem.
Each milestone can stand alone. These are proposed paths and checks, not approval to build.

| Milestone and trigger | Smallest useful change | Proof and main risk |
| --- | --- | --- |
| M1: handoff parity | Align note/title/review-origin content in `scripts/viewer.html` and `cloud/src/markdown.ts` with native/Python output. Add a focused fixture in `cloud/test/mcp.test.ts`. | Multiline notes and review origin survive copy and MCP with correct links. Risk: local/cloud URL and time rules drift. |
| M2: repeated request loss | Start with an ordinary Markdown request table. Add a small JSON sidecar only if another tool needs structured reads. | Corrections produce five final asks; canceled work stays canceled; each accepted ask has evidence. Risk: extra record keeping exceeds saved effort. |
| M3: wrong-base work | Record declared repository, source commit, dirty state, runtime/build identity, and explicit unknowns beside evidence. | A known mismatch is visible before editing. Risk: declared source appears to authenticate the running build. |
| M4: blocked sharing | Add explicit channel inclusion and preview at `Cloud/CloudBundle.swift` or `Export/PgmExport.swift`. Change cloud manifests only as needed. | Synthetic canaries are absent from all selected outputs. Risk: originals, audio, logs, or MHTML retain excluded data. |
| M5: weak acceptance evidence | Reuse current browser and test tools. Link request, changed source, tested build, check result, and observed behavior. | A rebuilt target is selected again. A failing check stays failed despite persuasive media. Risk: checks observe the wrong browser or build. |
| M6: costly Solid source lookup | Try existing development-only source attributes understood by `extension/page.js:sourceFor` in the target app. | A nested control maps to the right file and line after rerender. Risk: transformed lines or stale attributes mislead. |

Next Design questions follow the same order: What content must match? Does a plain table solve request loss?
Which declared build fields prevent actual errors? Which channels must an export exclude?
What evidence proves this request passed? Do existing source attributes remove lookup effort?
Document each result beside this plan before extending its milestone.
Do not add a new browser driver, tracker, format, validation framework, or cloud service without a measured need.

## Recommendation dispositions

These cover every Pro recommendation. Build means include in a plan, not start implementation.

| Pro ID | Local disposition | Reason |
| --- | --- | --- |
| REC-001 | Explore | Compare existing tools before broad expansion. No trial is authorized yet. |
| REC-002 | Build | Notes and review origin are lost in inspected handoff renderers. M1 has a small proof. |
| REC-003 | Explore | Existing live browser tools may solve stale-target and proof gaps. Use M5 only if needed. |
| REC-004 | Explore | Test a plain final-request table before adding request UI or a schema. |
| REC-005 | Explore | Pro marked Build conditionally. Require observed wrong-base cost before adding provenance fields. |
| REC-006 | Explore | Pro marked Build conditionally. Define a real blocked export and channels before adding controls. |
| REC-007 | Explore | CaptureCat merits consideration when local editing and agent access decide adoption. |
| REC-008 | Explore | ThinkRun may combine local capture and inspection. Its local-mode source was inaccessible during local spot-checking. |
| REC-009 | Explore | Existing source attributes may solve Solid mapping without a framework adapter. |
| REC-010 | Explore | Reuse runtime tools for a concrete debugging task. They complement narrated intent. |
| REC-011 | Defer | Existing AREC, JSON, or Markdown should fail a real transfer before another format is proposed. |
| REC-012 | Defer | Broad editor, collaboration, orchestration, and monitoring work lacks a demonstrated personal bottleneck. |
| REC-013 | Defer | Commercial claims require evidence beyond this useful personal workflow. |
| REC-014 | Avoid | Breadcrumbs has a close adjacent identity collision. No rename or legal conclusion follows. |
| REC-015 | Avoid | PR counts, generated tasks, and agent-reported success do not establish accepted changes. |
| REC-016 | Avoid | Blur, local storage, selectors, and hashes have separate privacy and freshness limits. |

## Open decisions

The exact trial client/model, fixtures, privacy constraints, acceptable spend, and adoption threshold remain unset.
No purchase, installation, trial, recording upload, or application change is needed to review this plan.
If later authorized, use the existing checkout rules and pnpm. Preserve the current stack.
