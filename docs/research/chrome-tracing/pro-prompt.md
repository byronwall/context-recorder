# Full Chrome tracing in Context Recorder

https://github.com/byronwall/context-recorder

Ref: `main` at `1d9f29d4b38c8c964b948b9ba244289947476b9e`.
An attached file, `chrome-tracing-source-packet.txt`, holds the files listed below at that commit.

## Mission

Mode: **Design**.

Decision question: **How should Context Recorder capture as much Chrome tracing data as possible during a recording (network activity, performance profiles, and the rest of what Chrome can trace), and which analyses of that data are worth building?**

Today the Chrome extension records clicks, navigation, console errors, and failed or slow `fetch`/XHR calls through page-level patches. It sees nothing about timing, caching, priorities, layout, paint, long tasks, CPU, or memory. The recording already has a video, narration, marks, and a timeline on one clock. Full traces on that same clock could let a reviewer see why a moment was slow, not only that it was.

Byron will build from your answer. He is a personal developer who records narrated walkthroughs of his own web apps, then reviews them or hands them to coding agents (Claude, Codex) to fix. Design for that user. Prefer an ambitious, well-reasoned direction with a staged plan over the smallest safe change.

Research date: October 28, 2026. Verify current Chrome APIs, limits, and tools through web research. Don't rely on memory for API status.

## Role

Work as a senior browser-tooling engineer who has built on the Chrome DevTools Protocol and the Chrome trace event format, and who has shipped performance analysis tools (for example in the style of DevTools Performance panel, Perfetto, Lighthouse, WebPageTest, or Replay). Give candid judgment: strengths, weaknesses, tradeoffs, rejected options, and uncertainty.

## Access check

First confirm you can read the repository at the ref above, or the attached packet. The packet is a text snapshot, not a runnable checkout. If both are missing a file that decides the design, stop and name the smallest missing input. Don't claim a full review from partial access. One short paragraph is enough.

## Reading route

Read at minimum:

1. `README.md` (what the app does, session folder layout, the Chrome extension section).
2. `extension/manifest.json`, `extension/background.js`, `extension/relay.js`, `extension/page.js` (current capture: permissions, the WebSocket to the app, the event ring, `fetch`/XHR patches, snapshots, MHTML capture).
3. `Sources/ContextRecorder/BrowserBridge.swift` (local WebSocket protocol on `127.0.0.1:47823`, message types, 128 MB message limit).
4. `Sources/ContextRecorder/RecorderController.swift`, `Session.swift`, `ContextProbe.swift`, `ChromeExtension.swift` (session lifecycle, where `browser.jsonl` is written, how marks get browser context, how the extension is installed and reloaded).
5. `scripts/process_session.py` (post-processing: edits/cut mapping of page events, Markdown, `session.json`).
6. `Sources/ContextRecorder/Library/SessionData.swift`, `EventLog.swift`, `SessionTimeline.swift` (how page events reach the timeline and Events tab).
7. `docs/research/session-performance/audit.md`, `scripts/summarize-session-har.py`, `scripts/audit-session.js`, `scripts/audit-session.md` (a prior manual DevTools/HAR audit; shows what Byron does by hand today).
8. `cloud/README.md` (the cloud viewer that also shows sessions; size budgets matter there).

## Ranked questions

1. **Capture mechanism.** What are the real options to collect full traces from the user's everyday Chrome profile while recording? Cover at least: `chrome.debugger` (CDP from the extension: `Tracing`, `Network`, `Performance`, `Profiler`, `HeapProfiler`, `Page`, `Runtime`, `Log`, `Audits`); Chrome launched with `--remote-debugging-port` and CDP from the Swift app; `chrome://tracing`/`--trace-startup` style system traces and Perfetto; `PerformanceObserver` and other in-page APIs (Resource Timing, Long Animation Frames, Event Timing, LCP/CLS/INP, `measureUserAgentSpecificMemory`); `chrome.webRequest`; and the DevTools-panel extension APIs (`chrome.devtools.network.getHAR`). For each: what data it gets, what it costs (the "is debugging this browser" infobar, CPU and file-size overhead, multi-tab and cross-origin iframe/worker coverage, service-worker lifetime under MV3, conflicts with an open DevTools window), and whether it works without the user changing how they launch Chrome. **Decide which one (or which combination) to build, and why.**
2. **What to collect, at what level.** Define capture tiers (for example: always-on lightweight; on-demand "deep" around a mark; full trace for a short window). For each tier, name the exact CDP domains, trace categories, and observers, the expected data rate per minute for a typical SPA, and what is excluded. Include response bodies, WebSocket frames, and request/response headers, with a clear rule on sensitive data (cookies, `Authorization`, tokens) given this is a local, personal tool.
3. **Storage and time alignment.** How should the files sit in the session folder (raw `trace.json`/`.pftrace`, HAR, CPU profiles, a compact index)? How do trace timestamps (monotonic `ts` in microseconds) map to the recording's clock and survive cuts and joins (see `process_session.py` edits mapping)? What does the cloud bundle carry, given its size budget?
4. **Analysis scenarios.** Propose five to eight concrete scenarios for analyzing this data, ranked by value to Byron. For each one: the question the reviewer asks, the trace data that answers it, the algorithm or heuristic, what the user sees in the Sessions window (timeline lane, mark detail, Events tab, canvas), and what goes into the Markdown handed to a coding agent. Candidates include, but are not limited to: "why was this mark slow" (critical path from input event to next paint); network waterfall per mark with cache/priority/blocking; long tasks and long animation frames attributed to scripts and source files; layout shift and re-render storms tied to what was said in narration; duplicate or chatty requests; memory growth across the session; a per-mark performance summary that an agent can act on; and diffing two sessions of the same flow (before and after a fix).
5. **Viewing.** Should the app render traces itself, link out to Perfetto UI or the DevTools Performance panel (which can load trace files), or both? Which parts must be native for the timeline to stay one clock?
6. **Plan.** A milestone plan, each milestone shippable on its own.

## Evidence rules

- Cite repository paths and symbols for claims about the code.
- Cite current primary sources (Chrome docs, CDP protocol docs, Chromium source, Perfetto docs, W3C specs) with URLs for decisive claims about APIs and limits.
- Label facts, inferences, and proposals where it isn't obvious.
- Say when evidence is missing or conflicting, especially about MV3 service-worker behavior while `chrome.debugger` is attached.

## Scope and constraints

- Stack: Swift/SwiftUI macOS 26 app, Python post-processor, plain JavaScript MV3 extension loaded unpacked, a Cloudflare Workers cloud viewer (TypeScript, pnpm). No new heavy runtime unless it earns its place; say so if it does.
- One user, one Mac, one Chrome profile. No multi-tenant, enterprise, or compatibility layers.
- Out of scope: Safari/Firefox, mobile devices, replacing the screen video with DOM replay, and a general APM/RUM product.
- Keep the current page events working; you may propose replacing their mechanism.

## Deliverable

Attach these as downloadable files and link each one in your final message. If you can't create files, put the full content inline.

1. **`chrome-tracing-report.md`**: starts with a one-paragraph **Decision** (what to build). Then answers each ranked question with sources. Include a comparison table for the capture options in question 1, and the tier table for question 2.
2. **`chrome-tracing-scenarios.md`**: the ranked analysis scenarios from question 4, each with data needed, method, UI, agent Markdown example, and a small worked example on a realistic trace excerpt.
3. **`chrome-tracing-implementation-plan.md`**: milestones in order. Each names the files or modules it changes, the new session files and their format, the checks that prove it (with exact expected values where they apply, for example a fixture trace with known long tasks and the expected attribution), the README section it needs, and its main risk.
4. **Recommendations** with stable IDs (`CT-01`, …), each classified **Build**, **Explore** (prototype first), **Defer**, or **Avoid**, with a one-line reason. Put them at the end of the report.

Claude will review the result against the code and make all repository changes. Don't write commits or pull requests.

## Final status

End with: access status, files read, what you checked versus what you propose, links to each deliverable, and open questions.
