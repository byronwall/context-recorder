# Research validation

Source baseline: `1d9f29d4b38c8c964b948b9ba244289947476b9e`.
Reconciliation date: October 25, 2026.
[Pro conversation](https://chatgpt.com/c/6add7517-fa5c-83ea-a835-b48d3709a763).

## Collection and coverage

Pro finished in 31 minutes, 6 seconds. All six requested files were present in its ZIP.
The browser download event timed out. The normal download completed in Downloads and was found before any retry.
The ZIP was copied to ignored `tmp/pro/narrated-review-comparison/collected/`.
All archive paths were relative and had no parent traversal. The ZIP integrity check passed before extraction.
No downloaded program ran. No Library save was needed.
Pro reported a rejected Library save; its downloadable reports remained available. No retry of that save was attempted.

Read the report, plan, recommendations, and feature guide. Parsed both CSV files in full.
Validated 16 product/workflow rows, 65 feature IDs, and 1,040 matching feature/evidence records.
Also validated 48 operational records, unique evidence IDs, and matching state, qualification, evidence, and release fields.
Every row states that no hands-on trial ran.
States: 343 supported, 383 partial, 61 unsupported, 244 unknown, and 9 not-applicable.
The original reports, ZIP, and local collection files remain ignored and are not part of the PR.

The committed CSVs are reviewed projections. They remove duplicate fields and join operational sources to product records.
They preserve capability qualifiers, vendor terms, source locators, evidence status, and release status.
Baseline attachment references now point to the saved prompt.
Native Find has an additional direct source check in F32.
Most external cells retain Pro's assessment. They were not all independently checked.

## Decisive repository checks

| Claim | Direct check and conclusion |
| --- | --- |
| Notes and review origin disappear from web/cloud Markdown | `MarkText.title/markdown` and Python `mark_markdown` include them. Web/cloud `titleOf/markdownFor` omit them. Confirmed in current source. |
| Mark-only retrieval can omit unmarked asks | `cloud/src/mcp/server.ts:get_session` returns summary and mark Markdown. Raw files remain separately retrievable. Confirmed. |
| Default frames are approximate | `CloudBundle.thumbInterval` is two seconds. `frames/thumbs.ts:nearestThumb` rounds to the nearest interval. MCP reports actual time and drawings separately. Confirmed. |
| Input values can enter browser context | `extension/page.js:describe` uses `innerText || value`. Confirmed. No personal session was inspected. |
| Empty transcript can be mislabeled silent | Web header, transcript tab, and current narration use Silent wording. Python can skip transcription when Parakeet is absent. Confirmed. |
| Native Find exists; web Find differs | `Library/SidePanel.swift:findRow` binds `model.query`. The web viewer has kind filters and no text query. Confirmed statically. |
| Input hash does not identify the source build | `CloudBundle.inputHash` hashes session inputs. Cloud manifest has no established captured app-to-source relationship. Confirmed within inspected schemas. |

No native behavior, capture timing, UI flow, or application test was executed for these checks.

## Independent primary-source checks

Checked these decision sources on October 25. These establish documentation, not successful product use.

| Source | Finding |
| --- | --- |
| [Jam MCP](https://jam.dev/docs/jam-mcp) | Timed transcript/frame tools exist. Instant Replay excludes visual/video tools. |
| [Jam test recording](https://jam.dev/docs/cli-e2e-tests) | The wrapped check retains its exit code and connects to the recorder's browser proxy. |
| [Jam pricing](https://jam.dev/pricing) | Team is listed at $14 per creator/month annually. The visible plan card lists 15 minutes. Conflicting duration claims remain qualified. |
| [Clipy specification](https://clipy.online/spec) | AREC 1.3 includes requests, evidence, diagnostics, transcript, and capture gaps. |
| [Clipy local mode](https://clipy.online/docs/local-recording) | Local media stays on-device. Derived text/interactions go to processing; account and internet remain required. |
| [Vidmatic recording to issue](https://www.vidmatic.ai/docs/recording-to-issue) | One recording creates one issue with a row per ask and agent-found code anchors. |
| [Vidmatic workstreams](https://www.vidmatic.ai/docs/agent-workstreams) | Progress and stages come from agent reports. |
| [Loom agent mode](https://support.atlassian.com/loom/docs/record-for-agent/) | Tasks reference quotes, frames, and times. The agent-mode limit is five minutes. |
| [Breadcrumb MCP](https://innerloop.works/breadcrumb/mcp) | Developer/agent context overlaps. Image tools retain a development label. |
| [CaptureCat agent docs](https://capturecat.so/docs/ai-agents) | Current agent documentation is available. Detailed feature cells remain Pro assessments. |

The ThinkRun local-mode URL was inaccessible to the local web reader. Its claims remain qualified Pro research.
Pro could not access the workflow blog or private earlier review. It attributed workflow counts to Byron's supplied account.
Neither limitation blocks the comparison documents. Neither establishes missing product behavior.

## Local changes to Pro's proposal

Changed future run isolation from automatic worktrees to separate copies or clones, per Byron's explicit rule.
Changed REC-005 and REC-006 from conditional Build to Explore until a concrete problem justifies implementation.
Removed speculative validator/module proposals from the plan. Plain records and existing code seams come first.
Marked the adoption threshold as proposed, rather than an accepted user preference.
Kept the full feature breadth in derived data while making the decision and plan shorter.

No follow-up was needed. The six deliverables answered the priority questions and supplied a usable plan.
No document formatter or linter is configured for these files. Markdown links, CSV consistency, and Git whitespace checks are required here.
Application tests are unnecessary for this documentation-only change and were not run.

Final authored Markdown links and derived CSV product sets passed local checks.
The feature matrix has 16 rows and 65 feature columns. Each cell has a qualified record in the comparison CSV.
PR #59 is open against main. Its saved body and documentation-only file list were verified.
The PR uses stable GitHub document links. No generated media or original reports were committed.
