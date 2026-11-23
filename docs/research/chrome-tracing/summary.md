# Chrome tracing research summary

Research: ChatGPT Pro, October 28, 2026. [Conversation](https://chatgpt.com/c/6ae2a37b-32f0-83e9-9818-e8847b10df9b).
Prompt: [pro-prompt.md](pro-prompt.md). Run record: [run.md](run.md).
Raw Pro output: [report](../../intent/chrome-tracing/sources/pro-output/chrome-tracing-report.md), [scenarios](../../intent/chrome-tracing/sources/pro-output/chrome-tracing-scenarios.md), [Pro's plan](../../intent/chrome-tracing/sources/pro-output/chrome-tracing-implementation-plan.md).
Our plan: [implementation-plan.md](../../intent/chrome-tracing/implementation-plan.md).

## Decision

The Swift app connects to the everyday Chrome over the DevTools Protocol (CDP). It uses Chrome's consent-based remote debugging (Chrome 144+). The app owns network capture, metrics and traces, and writes them straight to the session folder. The extension stays for page context (clicks, selectors, snapshots, MHTML).

When connected, every recording gets the full network log and 1 Hz metrics. A deep trace is armed for a short reproduction and written as a file that opens in Perfetto or DevTools. Mark-centered findings come next: slow interaction, request waterfall, main-thread work, and a compact Markdown block for agents.

The first step is a small spike that proves the connection on this Mac. Chrome 156 is installed, so the feature exists.

## Key findings

1. **Chrome 144 changed the answer.** At `chrome://inspect/#remote-debugging`, the user allows connections to the running profile. Chrome asks for each new connection and shows an automation banner. Discovery reads the `DevToolsActivePort` file. `/json/version` returns 404 in this mode. Verified in the [Chrome blog post](https://developer.chrome.com/blog/chrome-devtools-mcp-debug-your-browser-session).
2. **`chrome.debugger` in the extension is the weaker path.** Unpacked extensions are untrusted CDP clients. V8 gives `Profiler` and `HeapProfiler` only to trusted clients, and tracing scope is restricted. Native consented connections are trusted. (Pro cites Chromium and V8 source.)
3. **Launch flags no longer work on the default profile.** Since Chrome 136, `--remote-debugging-port` is ignored for the default data directory.
4. **Capture tiers.** Pro's estimates, none measured:
   - T0 in-page observers: about 0.05–0.5 MB/min.
   - T1 network and metrics: about 0.5–5 MB/min.
   - T2 armed deep trace: about 10–100 MB/min JSON. It uses a 64 MiB ring and lasts at most 60 s.
   - T3 browser-wide diagnostic: up to 500 MB/min JSON.
5. **Clock.** Video zero is `Recorder.startPTS`, the first frame. Match Chrome time to host time with timed `Performance.getMetrics` calls (the `Timestamp` metric) and an offset fit. Page events are stamped when they arrive today. New data should keep the time it happened.
6. **Cuts.** Split intervals at cuts, keep the original duration, and never report a faster request because its middle was cut. Pro ran the existing `to_edited` and confirmed it includes both ends: source 10 and source 20 both map to edited 10.
7. **Viewing.** Show compact lanes and mark findings in the app on the one playhead. Hand raw traces to Perfetto or the DevTools Performance panel. Do not rebuild flame charts in SwiftUI.
8. **Scenarios, in Pro's rank order:**
   1. Input-to-next-paint breakdown.
   2. Per-mark request waterfall.
   3. Long tasks and long animation frames with exclusive attribution.
   4. Agent evidence block.
   5. Duplicate or chatty requests.
   6. Layout shifts.
   7. Before/after comparison.
   8. Memory growth.

   Each finding has four parts: what was observed, what it is associated with, a hypothesis, and the next check. Overlap is not cause.

## Claims checked against the code

| Claim | Result |
| --- | --- |
| `page.js:describe` reads `target.value`, so the README's "input values are never recorded" is false | Confirmed, `extension/page.js:207` |
| Video offset is host time minus the first frame PTS | Confirmed, `Recorder.swift:120-124` |
| `to_edited` includes both segment ends | Confirmed, `process_session.py:169` (`<= t <=`) |
| Cloud budget `max(10 MiB, video/2)` applies to MHTML pages only | Confirmed, `CloudBundle.swift:54,151` |
| `cloud/README.md` still lists rewriting logs into edited time as a known gap, though `CloudBundle.writeLogs` already does it | Confirmed, `cloud/README.md:106`; `CloudBundle.swift:246` |
| The fetch patch reads the body with `clone().text()` before it truncates to 800 characters | Confirmed, `extension/page.js` fetch patch |
| Chrome 144+ consent flow, per-connection prompt, banner | Confirmed against the Chrome blog post |
| Installed Chrome supports it | Chrome 156.0.8078.49 is installed |

Not checked: the trust-gate claims (V8 and Chromium source), the category presets and the data rates. The spike tests the trust and category claims on the real browser.

## Dispositions

Pro's IDs, with our disposition. Where ours differs, the reason says why. Most changes follow the project rule: choose the simplest thing for one user on one Mac.

| ID | Pro | Ours | Reason |
| --- | --- | --- | --- |
| CT-01 Native consented CDP transport | Build | **Build** | Trusted client, everyday profile, no relaunch. |
| CT-02 Prototype discovery and consent | Explore | **Build first (M0)** | It decides everything else, and it is small. |
| CT-03 Keep extension and add observers | Build | **Build later (M4)** | Keep the extension as is. Observers matter when CDP is off; CDP comes first. |
| CT-04 `chrome.debugger` backend | Defer | **Defer** | Only if the spike fails. |
| CT-05 Full network log and metrics when connected | Build | **Build (M1)** | Replaces the manual HAR audit. |
| CT-06 One target registry and trace owner, coverage recorded | Build | **Build, smaller** | Selected tab plus auto-attached frames and workers. Write a coverage line; no lease system across recordings. |
| CT-07 Armed bounded deep trace | Build | **Build (M2)** | The core of "as much tracing as possible". |
| CT-08 Short browser-wide diagnostic | Build | **Build later (M6)** | Useful, but after the per-tab trace works. |
| CT-09 No wildcard, hi-res, screenshot, body or heap capture by default | Avoid | **Avoid as default** | Offer as explicit options later. |
| CT-10 Calibrate to first-frame host time | Build | **Build** | One offset fit with slope 1. Add a drift fit only if residuals show it. |
| CT-11 Original artifacts plus interval projections at cuts | Build | **Build (M5)** | Split at cuts, keep the original duration. |
| CT-12 Sidecar files, bounded drain, completion state | Build | **Build** | Simple `.partial` then rename. |
| CT-13 Deterministic mark findings | Build | **Build (M3)** | Observed, association, hypothesis, next check. |
| CT-14 Native lanes plus Perfetto/DevTools export | Build | **Build** | "Open in Perfetto" ships with M2; lanes with M3. |
| CT-15 Redact before persistence, raw stays local | Build | **Build, reduced** | Drop values of `Cookie`, `Set-Cookie`, `Authorization`, `Proxy-Authorization` and token-like headers. No allowlist, no keyed digests. Bodies off by default. Fix `describe()` to skip input values. |
| CT-16 Separate cloud performance budget and hashing | Build | **Defer (M5)** | Local first. Until then Push leaves `performance/` out. |
| CT-17 Perfetto `trace_processor` adapter | Explore | **Explore in M2** | Trace analysis in SQL may be simpler than a custom incremental JSON parser. Decide in M2. |
| CT-18 Duplicate-request and layout-work findings | Build | **Build (M4)** | Cheap once the network log exists. |
| CT-19 Before/after comparison | Build | **Defer (M6)** | After single-session findings are useful. |
| CT-20 Allocation sampling and heap retention | Explore | **Defer** | DevTools already does this well. |
| CT-21 Launch flags, startup traces, webRequest, DevTools panel | Defer | **Defer** | Not the main path. |
| CT-22 No "all Chrome", "root cause" or "leak" labels | Avoid | **Avoid** | Keep the four-part finding wording. |

## Where we changed Pro's plan

- **Order.** Pro starts with in-page observers and a clock contract (M1), then CDP (M2). We start with a CDP spike, because it decides the design and your Chrome supports it. Observers move to M4 as the no-CDP fallback.
- **Scope.** Pro's plan has 7 milestones and about 60 fixtures. We keep a few tests on the parts likely to break: clock mapping, interval splitting at cuts, trace stream drain, header redaction. The rest stays as reference in Pro's plan.
- **Removed:** cross-recording trace leases, per-origin query allowlists, keyed URL digests, cloud byte budgets in M1, and the 12 s drain deadline policy. Add any of these only if a real problem shows up.

## Open questions

- Can a signed macOS app read `DevToolsActivePort` from Chrome's profile folder? Answered by the M0 spike.
- What does the consent prompt do across app restarts? Chrome asks on every new connection. Should the app keep one connection open across recordings?
- How much history does the 64 MiB ring really hold for your apps? Measure in M2.
- Which tabs to capture: only the active tab at record start, or every tab you switch to? The plan defaults to the active tab and adds tabs on switch.
- `trace_processor` or a custom Python reader for analysis? Decide in M2.
