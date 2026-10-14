# Recording, dictation and annotation tools
## Current landscape and Context Recorder decision report

**Research/access date:** 2026-10-13, America/Indiana/Indianapolis  
**Repository:** `byronwall/context-recorder`  
**Immutable source baseline:** `6c74158ca96abd36819d2a58f75bacdc44107bb0`  
**Status:** research complete within the stated evidence scope; recommendations and product proofs remain **proposed and unrun**.

## Executive decision

**Recommend a focused local evidence workbench, not an all-in-one recording suite.** Preserve deliberate capture, local originals, context/source clues, time-linked marks and later review notes. First make collection/output claims truthful, preserve notes across native and portable handoff, and distinguish failed transcription from silence. Then test a small **find → inspect → note → select → hand off** improvement against the app’s existing native review and an honest no-build alternative. [R004](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108) [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) [R006](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/viewer.html#L295-L334) [R008](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L473-L484) [R011](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L194-L215) [R015](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) [R017](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SidePanel.swift#L265-L310)

The strongest alternative is **specialist reuse**. If the primary goal is polished communication, a presentation/editor tool is a better boundary. If it is general dictation, use a speech-input tool rather than extending a post-recording recognizer into a systemwide product. If another person must report a browser bug, hosted bug-capture products may win. These are different tasks, not cosmetic variants of one roadmap. [S009](https://screen.studio/) [S013](https://cleanshot.com/screen-recording) [S083](https://www.descript.com/) [S049](https://superwhisper.com/) [S058](https://www.macwhisper.com/) [S028](https://jam.dev/) [S033](https://www.browserstack.com/bug-capture)

Context Recorder’s combination is useful, but **not demonstrated unique**. Loom now documents console/network capture and agent prompts with selected keyframes; Jam combines visual capture and diagnostics; Replay provides execution evidence; Screenpipe offers broader local history. The defensible proposal is personal control of a deliberate review and its evidence, not the claim that competitors only produce videos. [S006](https://support.atlassian.com/loom/docs/capture-console-and-network-logs/) [S007](https://support.atlassian.com/loom/docs/record-for-agent/) [S028](https://jam.dev/) [S090](https://docs.replay.io/reference/replay-cli/commands) [S087](https://github.com/screenpipe/screenpipe)

### What most changes the decision

The repository has more capability than a generic README-only gap analysis would credit: review marks, typed notes, cropped frames, source opening/copying, keyboard help, native timeline/transcript navigation, local Product Grid update mappings, a transcript regression script and a UI harness. It also has narrower but consequential mismatches: structured element descriptions can read input values; portable HTML omits typed findings; initial processing failures can look silent; selecting mark children does not necessarily select the entire export payload. These take priority over adding webcam effects or a new canvas. [R003](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/HotKeys.swift#L5-L44) [R004](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108) [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) [R009](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168) [R011](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L194-L215) [R006](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/viewer.html#L295-L334) [R008](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L473-L484) [R015](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) [R020](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/check-transcript.py#L1-L16)

## Access preflight and evidence method

**GO for a static, repository-grounded analysis.** Connected GitHub exposed the baseline README, and the authorized attached packet contains the required reading route. All **48 packet sections** matched their manifest byte counts and SHA-256 hashes: **47 baseline files and one local research prompt**. The separate uploaded brief is byte-identical to that prompt section. Live web research was available. No repository write access was needed or used.

The packet is selected text, **not a runnable checkout**. It contains no personal recordings, credentials, binaries, dependency folders or build output; it does not independently establish the entire Git tree. The README spot-check is not an independent byte-by-byte Git audit of all 47 baseline files. Source absence is qualified to the inspected files and recorded scopes in the gap analysis. The local checkout path in the brief was context only and was not accessed.

External verification means a current primary page, policy, release or public source was read on the access date. It does not mean the product was installed or every plan/platform path tested. Official facts are separated from user reports, independent examples, inference and proposals. Dated reports retain incident/version context; no single complaint becomes a reliability verdict. Numeric prices are secondary and shown only where cadence and scope were readable. Ambiguous pricing, release patch versions and unsupported negative claims stay unknown.

The survey contains **32 unique products, 18 deep profiles, six categories, 46 feature fields and 99 external sources**. It is a purposive convenience sample of workflow overlap, not market share, a popularity ranking or an exhaustive catalog. Vendor expansion stopped when all categories were covered and additional tools no longer changed the proposed boundary. Additional breadth was not allowed to displace checking the actual export and state paths.

The full source ledger provides titles, publishers, direct URLs, dates, types and limitations. This report includes its own compact source index and immutable repository evidence map so the main reasoning stands alone. The CSV carries row-level and cell-level source IDs; unknown feature cells are intentional, not negative votes.

## Question 1 — Landscape and real workflow overlap

### Category assignment and counting rules

Assign each product one primary category even when it spans several. CleanShot X is counted in C1 and discussed as an annotation complement, not counted again in C4. BrowserStack Bug Capture and Bird Eats Bug are one lineage. Camtasia Editor and Camtasia Snagit are different applications despite bundling. Screenshot/QuickTime capture is one native capture unit; Apple Dictation is a distinct speech-input utility. Excluding both Apple utilities still leaves 30 distinct surveyed products, above the breadth gate.

“Direct/overlapping” means a product can compete for the actual capture-to-finding task or an important part of it. “Adjacent” solves a different deliverable, such as an instructional guide, execution replay or all-day memory. “Complement” can improve the current workflow without becoming the new product. These are analytical roles, not exclusive vendor classifications.

| Category | Unique products / deep profiles | Primary output |
| --- | --- | --- |
| C1 — Screen recorders and narrated async video | 8 / 5 | Watchable recorded explanation |
| C2 — Developer bug capture and contextual feedback | 5 / 3 | Actionable website/bug report |
| C3 — Speech input and local transcription | 6 / 3 | Recognized, inserted or exported speech text |
| C4 — Screenshot and on-screen annotation | 5 / 2 | Legible annotated still or live presentation overlay |
| C5 — Step capture, tutorials and interactive demos | 4 / 2 | Instructional steps or guided demo |
| C6 — Transcript-led editing, review and screen memory | 4 / 3 | Edited media, review decisions, execution evidence or searchable history |



### C1 — Screen recorders and narrated async video

**P01 — [Loom](https://www.loom.com/)** (deep profile)  
**Role:** direct / broader cloud alternative. **Platform:** macOS; Windows; Chrome extension; iOS/Android companions.

Narrated capture and review, now with developer-context and agent modes. Starter: 25 recordings/person, 5 min/video. Bug Report is Chrome-only on Business + AI/Enterprise; response bodies not yet supplied. Agent mode is beta, max 5 min, camera off; desktop 2.0+; Jira creation has account/subscription conditions. Word corrections have diacritic/grammar limits. Downloads are plan/role dependent. [S001](https://www.loom.com/pricing) [S002](https://support.atlassian.com/loom/docs/use-looms-different-capture-modes/) [S003](https://support.atlassian.com/loom/docs/capture-internal-audio-system-audio/) [S004](https://support.atlassian.com/loom/docs/edit-your-loom-video/) [S005](https://support.atlassian.com/loom/docs/correct-your-transcript/) [S006](https://support.atlassian.com/loom/docs/capture-console-and-network-logs/) [S007](https://support.atlassian.com/loom/docs/record-for-agent/) [S008](https://support.atlassian.com/loom/docs/loom-ai-features/)

**P02 — [Screen Studio](https://screen.studio/)** (deep profile)  
**Role:** adjacent / polished-communication alternative. **Platform:** macOS; Apple speech option requires macOS 26+.

Presentation-oriented screen capture with local post-production. Local transcript/caption modes coexist with optional cloud transcription and AI voiceover. Caption guide requires microphone narration. Polished cursor/video output is derived presentation, not untouched evidence. Current checkout price not quoted because indexed variants conflict. [S009](https://screen.studio/) [S010](https://screen.studio/guide/captions) [S011](https://screen.studio/guide)

**P03 — [CleanShot X](https://cleanshot.com/)** (deep profile)  
**Role:** adjacent / capture-and-annotation complement. **Platform:** macOS.

Screenshot utility also provides narrated video and a current Studio Mode editor. One-time Basic license includes one year of updates; cloud plans are separate. Video editor/Studio Mode is current; do not describe it as only a GIF recorder. Cloud comments do not make a local screenshot bundle a comment archive. [S012](https://cleanshot.com/) [S013](https://cleanshot.com/screen-recording) [S014](https://cleanshot.com/pricing)

**P04 — [Cap](https://cap.so/)** (deep profile)  
**Role:** direct / reusable local recorder alternative. **Platform:** macOS; Windows; Linux; Chrome extension offering.

Local Studio versus immediate hosted Instant workflows. Personal local workflow is free; packaged commercial use requires paid rights. Studio/local and Instant/cloud are different modes. Pricing prose and one free-plan unlimited-recordings cell conflict; verify entitlement before relying on it. Main license is AGPLv3 with MIT crate exceptions, not all MIT. [S015](https://cap.so/pricing) [S016](https://cap.so/faq) [S017](https://github.com/CapSoftware/Cap/blob/main/LICENSE) [S096](https://cap.so/download/versions) [S018](https://github.com/CapSoftware/Cap/issues/1696)

**P05 — [OBS Studio](https://obsproject.com/)** (deep profile)  
**Role:** adjacent / capture-engine alternative. **Platform:** macOS; Windows; Linux.

Local recording and compositing rather than a managed issue-review workspace. Pause availability depends on encoder setup. Current macOS 13+ audio sources avoid the old blanket virtual-driver requirement. Region recording may use source crop/transform rather than a dedicated region picker. Transcript and issue-review features were not established in inspected core docs. [S019](https://obsproject.com/) [S020](https://obsproject.com/kb/macos-desktop-audio-capture-guide) [S021](https://obsproject.com/kb/audio-video-formats-guide) [S022](https://obsproject.com/forum/threads/no-pause-recording-in-mac-obs.194427/)

**P06 — [ScreenFlow](https://www.telestream.net/screenflow/overview.htm)** (breadth profile)  
**Role:** adjacent / video editor. **Platform:** macOS Intel / Apple silicon.

Mac capture and multitrack post-production. Caption editor is documented, but automatic transcription and arbitrary-app dictation are not established. Stock-media subscription is optional. Current macOS 26 compatibility of every path remains untested. [S023](https://www.telestream.net/screenflow/overview.htm)

**P07 — [Camtasia Editor](https://www.techsmith.com/camtasia/)** (breadth profile)  
**Role:** adjacent / production suite. **Platform:** macOS; Windows.

Screen capture and multitrack editing; Audiate and Snagit are separate bundled apps. Text-based editing is an Audiate-to-Editor integration, not an Editor-only capability. Screenshot capture belongs to Snagit. Plan bundles do not collapse these into one executable. [S024](https://www.techsmith.com/camtasia/) [S025](https://support.techsmith.com/hc/en-us/articles/40967481935885-Getting-Started-with-a-Camtasia-Essentials-Plan) [S026](https://www.techsmith.com/camtasia/features/ai-text-based-editing/) [S068](https://www.techsmith.com/blog/snagit-vs-camtasia/)

**P08 — [macOS Screenshot / QuickTime capture](https://support.apple.com/en-us/102618)** (breadth profile)  
**Role:** adjacent / no-build capture baseline. **Platform:** macOS.

Built-in full-screen or selected-portion video, reviewed as one native capture workflow. Screenshot and QuickTime entry points count once, not twice. The inspected Apple page does not establish native system-audio capture or application-window recording in every OS version. MOV handoff is not a contextual issue bundle. [S027](https://support.apple.com/en-us/102618)

### C2 — Developer bug capture and contextual feedback

**P09 — [Jam](https://jam.dev/)** (deep profile)  
**Role:** direct. **Platform:** Chrome/browser workflow; native Mac and iOS offerings.

Bug capture joins video or screenshots with technical evidence and agent/issue handoff. Free: 30 Jams/month, 5 min recordings. Team: 15 min recording limit and metered AI/recording links. Two-minute Instant Replay is an opt-in local DOM buffer; sharing changes the data boundary. Recording-link masking is not proven in every mode. [S028](https://jam.dev/) [S029](https://jam.dev/pricing) [S030](https://jam.dev/docs/instant-replay) [S031](https://jam.dev/docs/recording-links) [S032](https://jam.dev/integrations/github)

**P10 — [BrowserStack Bug Capture (formerly Bird Eats Bug)](https://www.browserstack.com/bug-capture)** (deep profile)  
**Role:** direct. **Platform:** Browser extension; hosted Testing Toolkit review.

Captures bugs or manual tests with video, replay and diagnostic logs. Current documentation moved under Testing Toolkit. Video FAQ states no duration cap, warns longer captures affect browser/upload cost. WebM can be downloaded before upload; MP4 after upload. Technical logs still require Bug Capture URL. Ordinary videos cannot be trimmed; only Replay can. Replay is a two-minute opt-in DOM reconstruction; iframe contents and some fonts are documented limitations. Local buffering precedes explicit upload. [S033](https://www.browserstack.com/bug-capture) [S034](https://www.browserstack.com/press/browserstack-acquires-bird-eats-bug-launches-bug-capture-to-accelerate-its-test-platform-vision) [S097](https://www.browserstack.com/docs/testing-toolkit/bug-capture/faqs/recording-videos) [S098](https://www.browserstack.com/docs/testing-toolkit/bug-capture/faqs/replays)

**P11 — [Marker.io](https://marker.io/)** (deep profile)  
**Role:** direct. **Platform:** Web widget and browser extension; hosted review.

Visual feedback couples screenshot annotations and context with issue-tracker workflows. Session replay requires Team or above. Console/network/replay evidence is linked, not attached. Sensitive-data classes and network filtering need configuration; page content can contain personal information. [S040](https://marker.io/pricing) [S036](https://help.marker.io/en/articles/6673880-session-replay-videos) [S037](https://help.marker.io/en/articles/14430683-why-are-console-logs-network-requests-and-replays-linked-instead-of-attached) [S038](https://help.marker.io/en/articles/9657817-sensitive-data-masking) [S039](https://help.marker.io/en/articles/12383990-data-privacy-security-overview)

**P12 — [BugHerd](https://bugherd.com/)** (breadth profile)  
**Role:** direct / website-feedback alternative. **Platform:** Web/browser extension; hosted task board.

Element-pinned feedback becomes tasks with visual/environment context. Website feedback/task-board scope; full local archive, network payload capture and recording fidelity not established. [S041](https://bugherd.com/features) [S042](https://bugherd.com/feature/mcp)

**P13 — [Userback](https://userback.io/)** (breadth profile)  
**Role:** direct / broader feedback platform. **Platform:** Web widget/browser; hosted workspace.

Visual reports and replay coexist with requests, surveys and feedback portal. Broader customer-feedback product; exact desktop capture, local export completeness and network-log fields not established. [S043](https://userback.io/)

### C3 — Speech input and local transcription

**P14 — [Wispr Flow](https://wisprflow.ai/)** (deep profile)  
**Role:** complement / dictation alternative. **Platform:** macOS; Windows; iOS; Android; feature parity varies.

Speak into arbitrary apps; separate from recording a review session. Dictation requires network/cloud processing. Pro $15 monthly or $12/month billed annually. Free table: 2,000 words/week desktop, 1,000 mobile. Saved history/retry is device-local and does not recover uncaptured microphone audio. Notetaker is a different workflow, not used to infer dictation privacy. [S044](https://wisprflow.ai/pricing) [S045](https://docs.wisprflow.ai/articles/2772472373-what-is-flow) [S046](https://docs.wisprflow.ai/articles/4048537120-what-to-expect-from-flow-accuracy-and-known-limitations) [S047](https://docs.wisprflow.ai/articles/2503460374-retry-failed-transcriptions) [S048](https://wisprflow.ai/privacy)

**P15 — [Superwhisper](https://superwhisper.com/)** (deep profile)  
**Role:** complement / local speech alternative. **Platform:** macOS 14+; Windows; iOS; Android; model availability varies.

Hotkey speech insertion, modes and file transcription with local/cloud choices. Mac insertion requires Microphone and Accessibility. Offline means a selected downloaded local model, not every model/mode. Pro $8.49/month, $84.99/year or $249.99 lifetime. Prompt/mode errors can be distinct from recognizer errors. [S049](https://superwhisper.com/) [S050](https://superwhisper.com/docs/billing/plans) [S051](https://superwhisper.com/docs/get-started/quickstart) [S052](https://superwhisper.com/docs/modes/built-in) [S053](https://superwhisper.com/docs/common-issues/troubleshooting)

**P16 — [FluidVoice](https://github.com/altic-dev/FluidVoice)** (breadth profile)  
**Role:** complement / local-first speech choice. **Platform:** macOS; other-platform release maturity not established here.

Local speech-to-text, app insertion and model/history tools. GPLv3 app does not make the privately maintained Fluid Intelligence runtime open source. Only documented official domains accepted. Historical v1.6.5 AirPods-switch issue is closed; no current defect claim. [S054](https://github.com/altic-dev/FluidVoice) [S055](https://github.com/altic-dev/FluidVoice/releases) [S056](https://github.com/altic-dev/FluidVoice/issues/709)

**P17 — [VoiceInk](https://tryvoiceink.com/)** (breadth profile)  
**Role:** complement / local dictation alternative. **Platform:** macOS 14.4+ on Apple silicon; iOS companion advertised.

Local recognition with dictionary/replacements and optional enhancement. Mac $25 one device / $39 two / $49 three one-time. Optional cloud enhancement sends text. Do not imply the optional text service remains local. [S057](https://tryvoiceink.com/)

**P18 — [MacWhisper](https://www.macwhisper.com/)** (deep profile)  
**Role:** complement / transcription and dictation alternative. **Platform:** macOS.

File/audio transcription, correction and export, plus systemwide dictation. Model/provider and local/optional-cloud AI settings change the data boundary. Transcript correction/export does not prove transcript-led video cutting. CLI and paid features should be checked against installed entitlement. [S058](https://www.macwhisper.com/) [S059](https://docs.macwhisper.com/article/57-macwhisper-command-line-tool) [S060](https://macwhisper.helpscoutdocs.com/article/28-keyboard-shortcuts) [S099](https://simonwillison.net/2025/Nov/18/macwhisper-speaker-recognition/)

**P19 — [Apple Dictation](https://support.apple.com/guide/mac-help/use-dictation-mh40584/mac)** (breadth profile)  
**Role:** complement / no-build speech baseline. **Platform:** macOS (other Apple-platform variants not scored).

Built-in speech insertion is a distinct task from native screen capture. Check Keyboard settings for on-device general-text processing; search-box dictation is distinguished. Languages/regions vary. Voice Control is separate and replaces standard Dictation when enabled. [S061](https://support.apple.com/guide/mac-help/use-dictation-mh40584/mac)

### C4 — Screenshot and on-screen annotation

**P20 — [Shottr](https://shottr.cc/)** (deep profile)  
**Role:** complement / focused screenshot tool. **Platform:** macOS.

Rapid still capture, scrolling images, annotations and pixel-level review. Raster operations can apply differently to base capture and added overlays. Flatten/rasterize relevant layers before treating a redacted export as safe; preserve private originals separately. [S062](https://shottr.cc/) [S063](https://shottr.cc/newversion.html) [S064](https://shottr.cc/kb/faq)

**P21 — [Camtasia Snagit](https://www.techsmith.com/snagit/)** (deep profile)  
**Role:** complement / richer annotation and tutorial tool. **Platform:** macOS; Windows; feature parity varies.

Still capture/editor plus basic video and automatic step capture. Separate application from Camtasia Editor even when bundled. Basic trim/combination and step capture do not establish full transcript-led editing. Screen Draw platform/mode parity should be checked before relying on it. [S065](https://www.techsmith.com/snagit/) [S066](https://www.techsmith.com/snagit/features/) [S067](https://www.techsmith.com/learn/tutorials/snagit/step-capture/) [S068](https://www.techsmith.com/blog/snagit-vs-camtasia/)

**P22 — [Presentify](https://presentifyapp.com/)** (breadth profile)  
**Role:** complement. **Platform:** macOS.

Live drawing and cursor guidance can overlay an existing recorder. Records through a companion recorder, not a new capture pipeline. Verify overlay inclusion against Context Recorder’s excluded-window filter. No claim of exportable timed annotation semantics. Live drawing over a displayed image does not establish a native saved-image editing/export workflow. [S069](https://presentifyapp.com/) [S070](https://presentifyapp.com/use-cases/cursor-highlight-tool-for-screen-recording)

**P23 — [ScreenBrush](https://www.screenbrush.app/)** (breadth profile)  
**Role:** complement. **Platform:** macOS; iOS remote companion.

Drawing overlay, whiteboard, cursor halo and saved drawing snapshots. Plus tier gates arrows/text/shapes/undo. Drawing snapshot exports can be PSD/PNG/PDF, not a timestamped evidence record. Saved drawing layers can be reloaded and edited; this is partial annotation support, not evidence of a full captured-image editor. Selective Flashlight separately supports a region screenshot to the clipboard. [S071](https://apps.apple.com/us/app/screenbrush/id1233965871?mt=12)

**P24 — [ShareX](https://getsharex.com/)** (breadth profile)  
**Role:** adjacent / non-macOS reference. **Platform:** Windows.

Free/open-source capture and annotation with configurable output actions. Not a native macOS replacement. Upload behavior depends on configured after-capture tasks and destination; local capture is not proof that uploads are disabled. [S072](https://getsharex.com/) [S073](https://getsharex.com/docs/region-capture.html)

### C5 — Step capture, tutorials and interactive demos

**P25 — [Scribe](https://scribe.com/)** (deep profile)  
**Role:** adjacent / procedural documentation. **Platform:** Chrome/Edge; paid macOS/Windows desktop capture; mobile workflow support.

Turns performed steps into screenshot-based instructions rather than a forensic recording. Desktop capture and richer redaction/export require Pro/Enterprise. Free web guide is not a universal desktop capture tool. Conflicting duplicated pricing blocks prevent a dependable numeric quote. Autocapture marketing does not prove historical source/frame grounding. [S074](https://scribe.com/pricing) [S075](https://support.scribehow.com/hc/en-us/articles/8813841761181-Choosing-the-Right-Scribe-Pro-Plan)

**P26 — [Tango](https://www.tango.ai/)** (breadth profile)  
**Role:** adjacent / in-app guidance. **Platform:** Web/browser; desktop scope depends on plan.

Step guide creation plus contextual Guide Me/Pins; speech can become written steps. tango.us now redirects to tango.ai. PDF/link/embed exports and in-app guidance are different deliverables. Exact plan price and universal desktop support not established; guidance/automation includes enterprise scope. [S076](https://www.tango.ai/) [S077](https://www.tango.ai/pricing)

**P27 — [Guidde](https://www.guidde.com/)** (deep profile)  
**Role:** adjacent / narrated tutorial alternative. **Platform:** Web/Chrome/Edge; higher-tier desktop/mobile.

Capture workflow steps, edit voiceover/captions and publish instructional output. Free: 25 web guiddes. MP4 export requires active paid subscription, not just trial. Desktop/mobile capture listed for Business/Enterprise. Magic Mic cleanup can turn speech into generated step voiceover; not original audio evidence. Duplicated price-card content conflicts; explicit FAQ gates are used instead. [S078](https://www.guidde.com/) [S079](https://www.guidde.com/pricing)

**P28 — [Arcade](https://www.arcade.software/)** (breadth profile)  
**Role:** adjacent / interactive-demo alternative. **Platform:** Browser; documented Mac desktop; other desktop parity not established.

Click screenshots and motion snippets become guided interactive demos or separate AI video. Interactive-demo extension differs from AI-video footage extension. Interactive state/hotspots are not automatically preserved by a plain video export. Current credits/plans supersede old three-demo pricing snippets. [S080](https://docs.arcade.software/kb/build/interactive-demo/record) [S081](https://www.arcade.software/pricing) [S082](https://www.arcade.software/post/how-to-record-interactive-demos)

### C6 — Transcript-led editing, review and screen memory

**P29 — [Descript](https://www.descript.com/)** (deep profile)  
**Role:** adjacent / transcript-led production alternative. **Platform:** macOS 14+; Windows 11+; hosted workflow.

Video/audio are edited by changing transcript text. Media-hour, AI-credit and export-quality caps depend on plan. Current screen-recorder page lists free 720p watermarked output. Editing a transcript is not a faithful forensic copy of original narration/video; retain source separately. [S083](https://www.descript.com/) [S084](https://www.descript.com/pricing) [S085](https://www.descript.com/screen-recording) [S086](https://www.descript.com/download) [S095](https://www.reddit.com/r/Descript/comments/17z5bkh/an_honest_review_of_descript_and_why_i_cancelled/)

**P30 — [Screenpipe](https://screenpipe.com/)** (deep profile)  
**Role:** adjacent / broader memory boundary. **Platform:** macOS; Windows; Linux; capabilities differ.

Continuously captured screen/audio history, searchable context and agent integrations. Source-available commercial license, not unrestricted open source. Local-only mode differs from opt-in cloud AI, sync, exports, connectors and teams. Continuous collection raises scope/retention costs. Historical indexing-backlog report is not current measured reliability. [S087](https://github.com/screenpipe/screenpipe) [S088](https://screenpipe.com/privacy) [S089](https://github.com/screenpipe/screenpipe/issues/3498)

**P31 — [Replay.io](https://www.replay.io/)** (deep profile)  
**Role:** adjacent / deeper developer debugging. **Platform:** Replay Browser and CLI; hosted debugging; platform build support must be checked.

Records execution for inspection and agent debugging rather than just narrated MP4. Special recording browser and upload/source-map workflow. Local raw recording exists, but a portable standalone debugger was not established. No microphone or native-desktop narration capability is inferred. [S090](https://docs.replay.io/reference/replay-cli/commands) [S091](https://www.replay.io/blog/replay-time-travelogue-how-replay-mcp-helped-find-a-react-bug-faster-than-dan-abramov-did)

**P32 — [Frame.io V4](https://frame.io/)** (breadth profile)  
**Role:** complement / collaborative review. **Platform:** Web; connected creative applications.

Frame/range/spatial comments and filtered review export, without a recording engine. Upload/import media for review. Current V4 comment export supports CSV/XML/text/FIOJSON and current filters; older legacy help is not used to infer current behavior. [S094](https://frame.io/features/review-and-approval) [S092](https://help.frame.io/en/articles/9105251-commenting-on-your-media) [S093](https://help.frame.io/en/articles/9105278-comments-panel-overview)

### Current-status corrections that prevent a stale survey

Bird Eats Bug’s current comparison is BrowserStack Bug Capture; its help moved under Testing Toolkit. Tango’s public site redirects to `tango.ai`. Current TechSmith branding connects Snagit with Camtasia, but the Editor/Snagit/Audiate seams remain important. MacWhisper now advertises systemwide dictation as well as transcription. Screen Studio documents transcript-led video editing and local caption options; CleanShot’s current video workflow includes a Studio editor. [S034](https://www.browserstack.com/press/browserstack-acquires-bird-eats-bug-launches-bug-capture-to-accelerate-its-test-platform-vision) [S097](https://www.browserstack.com/docs/testing-toolkit/bug-capture/faqs/recording-videos) [S076](https://www.tango.ai/) [S068](https://www.techsmith.com/blog/snagit-vs-camtasia/) [S058](https://www.macwhisper.com/) [S009](https://screen.studio/) [S010](https://screen.studio/guide/captions) [S013](https://cleanshot.com/screen-recording)

Inspect license reality before calling an alternative open source: OBS and ShareX are open-source choices; FluidVoice’s app is GPLv3 while a named runtime is privately maintained; Cap’s inspected license is mixed; Screenpipe explicitly describes itself as source-available. Local-first, open source, free personal use and unrestricted commercial reuse are different properties. No adoption or license interpretation beyond the cited text is approved here. [S019](https://obsproject.com/) [S072](https://getsharex.com/) [S054](https://github.com/altic-dev/FluidVoice) [S017](https://github.com/CapSoftware/Cap/blob/main/LICENSE) [S087](https://github.com/screenpipe/screenpipe)

No surveyed seed was treated as shut down based on memory. Some vendors/routes were difficult to parse, but primary pages for all 32 included offerings were available. A reachable offering is not proof of future support, service uptime or every operating-system version’s compatibility.

## Question 2 — Taxonomy, prevalence, strengths and limitations

### Define the feature states before counting

The matrix uses the following exact strings. A native capability can be paid, optional or mode-specific; restrictions remain part of the cell’s meaning. “Partial” is not a subjective half-star rating. Unsupported claims stay unknown rather than becoming absence.

| Value | Meaning | Counting rule |
| --- | --- | --- |
| native | A documented first-party capability in at least one current supported plan/mode. | Do not assume every platform, free tier or combination includes it. |
| partial | A documented constrained/incomplete path or a capability that loses an important part of this task. | Keep the restriction; do not collapse into native. |
| integration-only | The task requires a separate product/plugin or an explicitly linked workflow. | A bundle does not erase the application boundary. |
| absent with evidence | A direct source explicitly rules the capability out for the scored workflow. | No inference from a quiet landing page. |
| unknown | The consulted evidence did not resolve the specific capability. | Include in the denominator and disclose it. |


Feature presence is not performance. Microphone narration is not dictation. A transcript can support seeking without correction or video cutting. A timestamp is temporal association, not proof that a sentence semantically refers to a particular DOM element. A crop does not redact its full-frame original. Ordinary video playback, reconstructed DOM replay and execution replay are different evidence types. A share link is not a portable local archive. A local file does not prove offline processing or an absence of optional cloud transfer.

### Feature data dictionary — all 46 fields

The CSV has one row per product and no summary rows. UTF-8, comma-separated, quoted when necessary; `source_ids` is a semicolon-separated list. `feature_evidence_json` is JSON inside one properly quoted CSV cell and maps each resolved feature to source IDs. Row sources also cover restrictions, platforms, versions and historical reports. Unknown features deliberately have no asserted supporting source.

| CSV metadata field | Meaning |
| --- | --- |
| product_id / product | Stable P01–P32 key and current product name or explicit former-name alias. |
| category_id / category | Exactly one primary C1–C6 assignment for denominator consistency. |
| url / platform | Current product entry URL and documented platform scope; not full parity. |
| relationship / category_rationale | Researcher classification and why the workflow belongs. |
| deep_profile | true for the 18 profiles expanded below; false for the 14 breadth profiles. |
| version | Displayed version or version family when established; otherwise explicit unknown/not stated. |
| quality_fps | Verified quality/frame-rate restriction where available; no inferred benchmark. |
| replay_kind | DOM reconstruction, execution replay, recorded history or unknown; not all ordinary video playback. |
| restrictions | Plan, platform, licensing, data-boundary, portability and evidence caveats. |
| source_ids / access_date | Resolvable S IDs and the ISO research-access date. |
| feature_evidence_json | Object mapping each non-unknown feature to one or more sources; no numeric score. |


| Feature field | Operational definition |
| --- | --- |
| screen_recording | Continuous screen video, not merely a sequence of click screenshots. |
| microphone_narration | Microphone voice attached to a screen/video capture workflow; arbitrary speech input alone is not counted. |
| system_audio | Computer/application playback audio captured separately from microphone sound. |
| webcam | Camera capture/compositing in the product recording workflow. |
| display_selection | User can select the display/full screen capture target. |
| window_selection | A selected application window can be the recording target. |
| region_video | Continuous recording of a selected rectangle; a cropped screenshot is not enough. |
| pause_recording | Pause/resume capture, not pause playback. |
| post_transcription | Speech-to-text for a completed recording or voice segment. |
| live_captions | Text captions available during ongoing speech, not only generated after stopping. |
| app_dictation | Speech text inserted into another application’s text field. |
| transcript_correction | User can correct recognized text; does not imply cutting video. |
| language_choice | User-facing recognition or caption language choice; translation alone is insufficient. |
| model_choice | User can select recognition/processing model or provider. |
| vocabulary | Custom words, dictionary, prompt hints or replacements; partial marks limited hints. |
| speech_cleanup | Filler/punctuation/style cleanup; not a claim of verbatim fidelity. |
| live_drawing | Draw over the captured/presented screen during capture. |
| image_annotation | Post-capture arrows, boxes, text or other marks on an image. |
| screenshot_crop | Still screenshot or region/crop extraction, distinct from video selection. |
| timed_notes | Notes/comments explicitly anchored to media time; untimed step comments do not qualify. |
| blur_redaction | Documented hiding/masking/removing sensitive capture content; no claim of completeness. |
| cursor_emphasis | Highlight, enlarge or reconstruct cursor/clicks beyond simply recording the pointer. |
| auto_zoom | Automatic/smart presentation zoom; manual viewer magnification alone is not counted. |
| transcript_search | Search recognized speech text, not a library name filter. |
| transcript_seek | Navigate media from transcript timing; not transcript edit. |
| text_video_editing | Changing/deleting transcript text changes corresponding media. |
| clip_export | Extract/trim a bounded video into an output clip, not only a timestamp link. |
| chapters | Named navigable media sections, manually or automatically supplied. |
| summaries | Generated or authored condensed account in the product workflow. |
| action_items | Explicit task extraction/assignment from recorded material. |
| dom_context | Page element/DOM-associated context; OCR text is not DOM. |
| dev_source_location | File/line or executable source location associated with evidence; issue integration alone is insufficient. |
| console_errors | Captured browser console/error diagnostics. |
| network_evidence | Request/response metadata or bodies captured; completeness varies. |
| replay | Revisit prior captured interactions/state; type must be read in replay_kind. Ordinary MP4 playback alone is not counted. |
| code_handoff | Documented handoff to issue/code/agent workflow; not proof of source-level grounding. |
| local_files | User-controlled local media/text output or project artifacts; hosted cache alone insufficient. |
| offline_core | Useful category-core task can run disconnected after setup/model download. Partial means a limited/configured path. |
| cloud_processing | Optional or required remote media/text/AI processing. Native does not mean mandatory. |
| cloud_storage | Optional or required vendor/self-hosted remote artifact storage. |
| portable_export | Files usable independently of the original hosted viewer; partial if important context remains link-dependent. |
| share_links | Hosted or controlled link-based handoff in the product. |
| collaboration | Shared comments/workspace/review, beyond emailing a file. |
| integrations | Documented connectors or API/tool handoff, not hypothetical scripts. |
| keyboard_workflow | Documented shortcuts for core capture/review tasks. |
| recovery | Documented recovery/retry/resilient artifact path, not a guarantee of reliability. |


Onboarding, permission friction, discoverability, reliability and performance are assessed as **qualitative evidence**, not falsely precise ordinal scores. Keyboard controls and a documented recovery path have their own feature cells; neither is a measured usability/reliability outcome. This report does not rank accent recognition, CPU cost, battery use or crash frequency without data.

### Prevalence within categories

All counts below are calculated from the delivered CSV. Every product assigned to that category is in the denominator; unknowns are not dropped. Counts represent documented availability across the sampled plans/modes, not observed adoption. A “common” capability here means at least half the category has native support in the coded sample; partial/integration-only counts remain visible and are not silently added to native.

Across all 1,472 feature cells, the distribution is: **343 native, 72 partial, 6 integration-only, 1 absent with evidence, 1050 unknown**. The unknowns are largely cross-category or insufficiently documented details; their prevalence is not evidence of product weakness.


#### C1: n = 8

| Feature | Native / partial / integration / absent | Unknown / total |
| --- | --- | --- |
| microphone_narration | 8 / 0 / 0 / 0 | 0 / 8 |
| system_audio | 7 / 0 / 0 / 0 | 1 / 8 |
| webcam | 7 / 0 / 0 / 0 | 1 / 8 |
| display_selection | 5 / 0 / 0 / 0 | 3 / 8 |
| region_video | 2 / 1 / 0 / 0 | 5 / 8 |
| pause_recording | 2 / 1 / 0 / 0 | 5 / 8 |
| post_transcription | 2 / 1 / 1 / 0 | 4 / 8 |
| text_video_editing | 2 / 0 / 1 / 0 | 5 / 8 |
| local_files | 7 / 1 / 0 / 0 | 0 / 8 |
| portable_export | 7 / 1 / 0 / 0 | 0 / 8 |


Narration and file output are table stakes in this sample. Computer audio is common but must be distinguished from microphone capture. Text-based editing is a stronger subset, not a universal recorder requirement. Cursor/zoom polish is highly relevant to a presentation task, not automatically to evidence review. Capture selection, pause and exact quality remain under-verified for several breadth products, so their lower known counts must not be read as proven rarity. [S009](https://screen.studio/) [S013](https://cleanshot.com/screen-recording) [S020](https://obsproject.com/kb/macos-desktop-audio-capture-guide) [S026](https://www.techsmith.com/camtasia/features/ai-text-based-editing/)

#### C2: n = 5

| Feature | Native / partial / integration / absent | Unknown / total |
| --- | --- | --- |
| screenshot_crop | 5 / 0 / 0 / 0 | 0 / 5 |
| image_annotation | 4 / 0 / 0 / 0 | 1 / 5 |
| console_errors | 4 / 0 / 0 / 0 | 1 / 5 |
| network_evidence | 3 / 0 / 0 / 0 | 2 / 5 |
| replay | 4 / 0 / 0 / 0 | 1 / 5 |
| share_links | 5 / 0 / 0 / 0 | 0 / 5 |
| integrations | 5 / 0 / 0 / 0 | 0 / 5 |
| portable_export | 0 / 2 / 0 / 0 | 3 / 5 |


Issue-system integration and a shareable visual report are the category’s center. Console/network evidence and replay are common documented extensions, but complete portable diagnostics are not established for most of this sample. BrowserStack’s downloadable video and Marker.io’s linked logs illustrate why export must be evaluated at the evidence-bundle level. Context Recorder already captures a useful local subset. [S028](https://jam.dev/) [S097](https://www.browserstack.com/docs/testing-toolkit/bug-capture/faqs/recording-videos) [S037](https://help.marker.io/en/articles/14430683-why-are-console-logs-network-requests-and-replays-linked-instead-of-attached) [R010](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L9-L31) [R018](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294)

#### C3: n = 6

| Feature | Native / partial / integration / absent | Unknown / total |
| --- | --- | --- |
| app_dictation | 6 / 0 / 0 / 0 | 0 / 6 |
| post_transcription | 5 / 0 / 0 / 0 | 1 / 6 |
| language_choice | 4 / 2 / 0 / 0 | 0 / 6 |
| model_choice | 3 / 1 / 0 / 0 | 2 / 6 |
| vocabulary | 4 / 1 / 0 / 0 | 1 / 6 |
| offline_core | 4 / 1 / 0 / 1 | 0 / 6 |
| cloud_processing | 3 / 2 / 0 / 0 | 1 / 6 |


All six products document speech insertion into another app: this is the task boundary that Context Recorder’s post-stop recognizer does not cross. Several offer model/vocabulary choices; offline status depends on selected local models and setup, while Flow’s scored dictation path requires internet. A local recognizer plus optional cloud cleanup should not be coded as exclusively offline or exclusively cloud. [S045](https://docs.wisprflow.ai/articles/2772472373-what-is-flow) [S051](https://superwhisper.com/docs/get-started/quickstart) [S057](https://tryvoiceink.com/) [S058](https://www.macwhisper.com/) [S061](https://support.apple.com/guide/mac-help/use-dictation-mh40584/mac) [R007](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L56-L96) [R023](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionData.swift#L62-L66)

#### C4: n = 5

| Feature | Native / partial / integration / absent | Unknown / total |
| --- | --- | --- |
| screenshot_crop | 4 / 0 / 0 / 0 | 1 / 5 |
| image_annotation | 3 / 1 / 0 / 0 | 1 / 5 |
| live_drawing | 2 / 1 / 0 / 0 | 2 / 5 |
| blur_redaction | 3 / 0 / 0 / 0 | 2 / 5 |
| portable_export | 4 / 0 / 0 / 0 | 1 / 5 |
| keyboard_workflow | 4 / 0 / 0 / 0 | 1 / 5 |


Annotations and keyboard-driven visual explanation dominate. Live presentation overlays and screenshot editors are related but not identical; Presentify records through a companion, while Shottr and Snagit focus on saved output. Redaction semantics need more than a visible blur control, especially when multiple image layers or a preserved full frame exist. [S070](https://presentifyapp.com/use-cases/cursor-highlight-tool-for-screen-recording) [S064](https://shottr.cc/kb/faq) [S066](https://www.techsmith.com/snagit/features/) [R015](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) [R024](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionView.swift#L190-L244)

#### C5: n = 4

| Feature | Native / partial / integration / absent | Unknown / total |
| --- | --- | --- |
| screenshot_crop | 4 / 0 / 0 / 0 | 0 / 4 |
| image_annotation | 4 / 0 / 0 / 0 | 0 / 4 |
| post_transcription | 2 / 0 / 0 / 0 | 2 / 4 |
| portable_export | 3 / 1 / 0 / 0 | 0 / 4 |
| share_links | 4 / 0 / 0 / 0 | 0 / 4 |
| collaboration | 3 / 1 / 0 / 0 | 0 / 4 |


Step screenshots and links are common; portable document/video exports are also offered, often with plan gates. Speech may become generated instructions or voiceover, not a verbatim time-linked source. Scribe, Guidde and Arcade can outperform a recorder for teaching a workflow while remaining the wrong source of forensic truth. [S074](https://scribe.com/pricing) [S079](https://www.guidde.com/pricing) [S080](https://docs.arcade.software/kb/build/interactive-demo/record)

#### C6: n = 4

| Feature | Native / partial / integration / absent | Unknown / total |
| --- | --- | --- |
| post_transcription | 2 / 0 / 0 / 0 | 2 / 4 |
| transcript_search | 2 / 0 / 0 / 0 | 2 / 4 |
| text_video_editing | 1 / 0 / 0 / 0 | 3 / 4 |
| replay | 1 / 1 / 0 / 0 | 2 / 4 |
| timed_notes | 1 / 0 / 0 / 0 | 3 / 4 |
| portable_export | 2 / 2 / 0 / 0 | 0 / 4 |
| integrations | 4 / 0 / 0 / 0 | 0 / 4 |


This intentionally heterogeneous adjacent group is not a single coherent feature market. Descript edits media through text; Frame.io manages review comments; Screenpipe indexes history; Replay inspects execution. Integrations and extracted files overlap, but low counts for any one specialized capability cannot justify adding that capability to Context Recorder. [S083](https://www.descript.com/) [S092](https://help.frame.io/en/articles/9105251-commenting-on-your-media) [S093](https://help.frame.io/en/articles/9105278-comments-panel-overview) [S087](https://github.com/screenpipe/screenpipe) [S090](https://docs.replay.io/reference/replay-cli/commands)

Live captions, exact capture limits, niche integrations and every platform’s permissions were not exhaustively resolved for all 32 products. No prevalence conclusion is drawn where unknowns dominate. The CSV makes those missing answers visible rather than manufacturing a clean yes/no chart.

### Workflow comparison: what each category actually completes

| Task and completed handoff | Strongest relevant alternatives | Context Recorder implication |
| --- | --- | --- |
| Personal narrated bug/product review → selected source-linked findings | Jam/Loom challenge diagnostics-plus-video; MacWhisper/Frame.io demonstrate retrieval/export patterns. | Keep local raw context, improve semantic handoff and retrieval. Do not claim uniqueness. |
| Polished narrated demo → watchable video | Screen Studio, CleanShot Studio Mode, Descript, Camtasia. | Reuse; avoid cinematic cursor/video editing in the first proposal. |
| General speech → editable text in arbitrary apps | Flow, Superwhisper, VoiceInk, FluidVoice, MacWhisper, Apple Dictation. | Not the current post-recording task. Reuse in NoteEditor first. |
| One spatial issue → legible annotated image | Shottr, CleanShot, Snagit; Presentify/ScreenBrush for live emphasis. | Preserve raw crop/frame; label any annotated derivative. |
| Repeatable procedure → guide or interactive demo | Scribe, Tango, Guidde, Arcade. | A tutorial is a different deliverable; generated instructions are not source evidence. |
| Hard browser state bug → executable investigation | Replay; DOM replay in Jam/BrowserStack/Marker for a different evidence tier. | Use specialist escalation; MHTML is not execution replay. |
| Forgotten context across the day → searchable history | Screenpipe. | Only consider always-on scope after an explicit missed-capture need. |


The alternatives above are supported by the category sources and detailed profiles, not by hands-on task measurements. Strength means an evidenced capability aligns with a task; it does not mean demonstrated superior accuracy or reliability.

## Deep profiles — 18 products across all six groups

Selection favors high workflow overlap and meaningful alternative boundaries. Five recorder profiles cover hosted handoff, polished Mac output, screenshot crossover, local-source reuse and configurable capture. Three bug-capture profiles cover reporter/diagnostic, renamed lineage and privacy/export constraints. Three speech profiles cover cloud insertion, local-model choice and transcript correction/export. Two annotation profiles cover focused and richer authoring. Two tutorial profiles distinguish procedural capture from generated narration. Three adjacent profiles distinguish text editing, all-day memory and executable replay.

Each profile follows capture → speech → mark/annotate → review → extraction → handoff where those stages apply. A stage outside the product’s task is explicitly not inferred. The named tradeoffs are research judgments, not hands-on ratings.


<a id="p01"></a>
### Deep profile P01 — Loom

**Category / role:** C1 · direct / broader cloud alternative. **Version:** Agent mode desktop >=2.0; exact latest app patch not established. **Access:** 2026-10-13.

Selected because its current bug-report and agent modes overlap the actual developer task, not just narrated screen video.

**End-to-end workflow:** Capture with desktop or Chrome, narrate, mark selected elements or draw in agent mode, then review transcript/keyframes and produce a share link or agent prompt. Bug Report mode adds timestamped diagnostics. These are distinct modes, not a promise that every feature is simultaneously available. [S002](https://support.atlassian.com/loom/docs/use-looms-different-capture-modes/) [S006](https://support.atlassian.com/loom/docs/capture-console-and-network-logs/) [S007](https://support.atlassian.com/loom/docs/record-for-agent/)

**Documented strength:** the recipient can follow an explanation and jump to associated evidence without first assembling loose files. Corrections and transcript-led cuts are supported, while AI chapters/summaries reduce authored navigation work. This directly challenges any claim that Context Recorder alone connects narration, pixels and developer handoff. [S004](https://support.atlassian.com/loom/docs/edit-your-loom-video/) [S005](https://support.atlassian.com/loom/docs/correct-your-transcript/) [S008](https://support.atlassian.com/loom/docs/loom-ai-features/)

**Documented limits:** agent recording is an open beta on Business + AI/Enterprise, limited to five minutes with camera disabled; desktop requires 2.0+. Bug logs use Chrome and paid tiers; network response data is not yet included in that documented mode. Starter has recording/library caps. A hosted report is not equivalent to a self-contained local evidence folder. [S007](https://support.atlassian.com/loom/docs/record-for-agent/) [S006](https://support.atlassian.com/loom/docs/capture-console-and-network-logs/) [S001](https://www.loom.com/pricing)

**Evidence quality:** no Loom recording was made here. Vendor documentation supplies the mode restrictions. No current independent failure rate, capture latency or transcription-accuracy comparison was established. The burden of selecting the correct mode is a workflow inference, not a measured usability defect.

**Fit and tradeoff:** strongest ready-made alternative when convenient communication and an agent-ready summary matter more than retaining every artifact beside local code. Reuse the handoff pattern, not its cloud workspace. Keep generated intent explicitly separate from what the recording proves.

<a id="p02"></a>
### Deep profile P02 — Screen Studio

**Category / role:** C1 · adjacent / polished-communication alternative. **Version:** Not stated. **Access:** 2026-10-13.

Selected as the strongest polished-macOS communication counterfactual, with newly verified transcript editing.

**End-to-end workflow:** Capture a screen with voice/camera, pause when needed, then refine cursor movement, zoom and presentation. Generate captions from a selected local recognizer or optional cloud path, correct text, edit video through its transcript and export/share the finished piece. [S009](https://screen.studio/) [S010](https://screen.studio/guide/captions)

**Documented strength:** presentation automation and text-based editing shorten the conceptual path from an unpolished demonstration to a watchable explanation. Caption settings expose language, model and vocabulary hints rather than treating speech recognition as one opaque step. Apple speech recognition is an option on macOS 26+. [S009](https://screen.studio/) [S010](https://screen.studio/guide/captions)

**Documented limits:** the caption workflow requires microphone voiceover. Whisper model selection and Apple recognition do not establish equivalent accuracy. The product is macOS-focused. Local projects do not mean every optional service is local: cloud transcription and AI voiceover have separate transfer paths. Older indexed copy conflicts with the current page, so no numeric price is relied on. [S010](https://screen.studio/guide/captions) [S009](https://screen.studio/) [S011](https://screen.studio/guide)

**Evidence quality:** recovery and audio/image enhancement claims are vendor claims, not tests performed in this research. No current hands-on comparative failure rate was found. Automatic zoom should be judged on the intended audience’s comprehension, not accepted as an inherently better rendering.

**Fit and tradeoff:** use it when the deliverable is a polished demonstration. Context Recorder should not grow a competing cursor-animation or multitrack studio. For evidence review, preserve raw screen coordinates and original timing even when a separate polished copy changes both.

<a id="p03"></a>
### Deep profile P03 — CleanShot X

**Category / role:** C1 · adjacent / capture-and-annotation complement. **Version:** Not stated. **Access:** 2026-10-13.

Selected because CleanShot spans the two most plausible complements: daily screenshots and short narrated clips.

**End-to-end workflow:** Capture a still or video, add microphone/system audio/camera as appropriate, annotate images or use Studio Mode video tools, review the result, export MP4/GIF or an image, and optionally share through CleanShot Cloud with time-based comments. [S012](https://cleanshot.com/) [S013](https://cleanshot.com/screen-recording)

**Documented strength:** image annotation and short-video production share one capture-oriented workflow. The current video page includes Studio Mode editing, zoom and cursor treatment; describing it as only a basic GIF recorder would be stale. It offers an immediate reuse path for an arrow or explanation without modifying Context Recorder’s evidence model. [S012](https://cleanshot.com/) [S013](https://cleanshot.com/screen-recording)

**Documented limits:** the local application and cloud service are separate entitlements. Basic is listed at $35 one-time with one year of updates; Pro is $10 per user per month billed annually, before tax. These are access-date prices, not a purchase recommendation. A cloud comment stream does not substitute for structured DOM/source evidence. [S014](https://cleanshot.com/pricing)

**Evidence quality:** advertised synchronization and speed advantages were not measured. No substantiated current product-wide reliability weakness was established. The integration cost is concrete but unmeasured: moving an annotated derivative back to its Context Recorder mark can break provenance unless the original and derived image remain separately identified.

**Fit and tradeoff:** a strong no-build companion for isolated annotation and polished clips. Prefer manual open/export first. Build a direct integration only after repeated handoff friction appears; do not duplicate its screenshot editor merely to avoid one application switch.

<a id="p04"></a>
### Deep profile P04 — Cap

**Category / role:** C1 · direct / reusable local recorder alternative. **Version:** 0.6.0 labeled Latest, 2026-09-15. **Access:** 2026-10-13.

Selected as a local-file and inspectable-source recorder alternative, with licensing and current-platform verification.

**End-to-end workflow:** Choose Instant or Studio capture, record screen/voice/camera, refine the result in the relevant mode, then keep a local file or publish through Cap’s sharing/storage routes. Current downloads list version 0.6.0 dated September 15, 2026, including macOS, Windows and Linux packages. [S016](https://cap.so/faq) [S015](https://cap.so/pricing) [S096](https://cap.so/download/versions)

**Documented strength:** local recording and export make it a meaningful alternative to an exclusively hosted workflow. Advertised higher-quality output and custom storage are useful when presentation or file ownership is the bottleneck, rather than developer context collection. Inspectable code also supports targeted evaluation before adopting components. [S015](https://cap.so/pricing) [S016](https://cap.so/faq)

**Documented limits/conflict:** personal local use and commercial rights differ. Pricing prose says local personal recordings have no time limit, while a comparison cell is inconsistent; this survey does not invent a cap to reconcile them. The repository license is mixed: MIT for named capture crates, AGPLv3 for other covered first-party code, plus third-party exceptions—not uniformly MIT. [S015](https://cap.so/pricing) [S017](https://github.com/CapSoftware/Cap/blob/main/LICENSE)

**Dated user report:** issue 1696 describes audio saved on disk but missing in the editor after pause/resume in a camera-only 0.4.81 recording. The issue is closed and predates the displayed current download. It supports a recovery fixture, not a claim that 0.6.0 remains broken. [S018](https://github.com/CapSoftware/Cap/issues/1696)

**Fit and tradeoff:** evaluate as a recorder to reuse, especially if local exports dominate. Component adoption is not approved: inspect an exact file/version and its license first. Avoid importing a whole recorder stack into a small Swift application to obtain one missing capture control.

<a id="p05"></a>
### Deep profile P05 — OBS Studio

**Category / role:** C1 · adjacent / capture-engine alternative. **Version:** Not stated. **Access:** 2026-10-13.

Selected to distinguish capture flexibility and recovery architecture from downstream review convenience.

**End-to-end workflow:** Configure sources and audio, narrate while recording, use scenes/crops for presentation, then review or edit the resulting file elsewhere. Modern macOS audio capture has native routes; the older assumption that every OBS Mac setup needs a virtual audio driver is wrong. [S019](https://obsproject.com/) [S020](https://obsproject.com/kb/macos-desktop-audio-capture-guide)

**Documented strength:** configurable capture and audio routing are its useful comparison, not agent-ready issue extraction. Its format guide explains resilient hybrid containers, illustrating that crash recoverability depends partly on how media is written rather than simply adding a Retry button. [S019](https://obsproject.com/) [S021](https://obsproject.com/kb/audio-video-formats-guide)

**Task limitation, inferred from scope:** a flexible recording engine does not itself complete this research’s find-note-source-handoff task. No native Context Recorder-style package of typed mark notes, DOM snapshots and development source locations was established in the inspected OBS sources. This is not a blanket assertion that plugins could never provide such features.

**Dated user report:** a February 2026 Mac question about a missing Pause control was answered in terms of the stream encoder setting. This is evidence of configuration-dependent discovery friction, not evidence that OBS lacks recording pause. No performance ranking against Context Recorder was run. [S022](https://obsproject.com/forum/threads/no-pause-recording-in-mac-obs.194427/)

**Fit and tradeoff:** the no-purchase capture baseline when audio/source flexibility is essential. Use it to test whether better capture alone solves the task before extending Recorder.start. Borrow the recovery question and inspect container tradeoffs; do not replace the existing native capture path without an end-to-end benefit.

<a id="p09"></a>
### Deep profile P09 — Jam

**Category / role:** C2 · direct. **Version:** Not stated. **Access:** 2026-10-13.

Selected as a direct developer-capture alternative, including current desktop/mobile reach and replay.

**End-to-end workflow:** Capture a screen or screenshot with diagnostics, narrate as supported by the chosen surface, annotate/explain, review the report, and send a link or issue integration. Instant Replay can retain a short prior DOM interval. Recording Links are a separate recipient-capture workflow with domain-connected diagnostics. [S028](https://jam.dev/) [S030](https://jam.dev/docs/instant-replay) [S031](https://jam.dev/docs/recording-links) [S032](https://jam.dev/integrations/github)

**Documented strength:** technical evidence travels with a report rather than requiring the developer to ask for console details afterward. Current Mac and iOS offerings mean the comparison is not limited to a Chrome-only screen-recorder stereotype. Its issue integration tests whether structured local handoff actually earns the maintenance of Context Recorder. [S028](https://jam.dev/) [S032](https://jam.dev/integrations/github)

**Documented limits:** free usage is 30 Jams per month with five-minute recordings; Team is listed at $14 per creator per month billed annually and has its own recording/AI limits. Instant Replay is an opt-in rolling DOM buffer, not executable time-travel debugging or a complete desktop-media archive. Recording Link masking/domain setup should not be generalized to all capture modes. [S029](https://jam.dev/pricing) [S030](https://jam.dev/docs/instant-replay) [S031](https://jam.dev/docs/recording-links)

**Evidence quality:** the advertised workflow is well documented, but no Jam installation or measured reduction in bug-resolution time occurred here. No reliable current product-wide defect claim was established. Hosted convenience versus local raw-artifact control is an architectural tradeoff, not evidence that one product is universally better.

**Fit and tradeoff:** the strongest practical alternative when the job is getting another person’s browser bug report or quickly creating an issue. Context Recorder needs to win on personal local review and evidence retention, not on the claim that diagnostics-plus-video is unique.

<a id="p10"></a>
### Deep profile P10 — BrowserStack Bug Capture (formerly Bird Eats Bug)

**Category / role:** C2 · direct. **Version:** Not stated. **Access:** 2026-10-13.

Selected as the renamed Bird Eats Bug lineage, counted once, with explicit file portability limits.

**End-to-end workflow:** Record a browser issue with screen/voice and logs, pause as needed, review the captured evidence, then share a Bug Capture link or download the video. BrowserStack’s acquisition announcement establishes the Bird Eats Bug lineage; current help now lives under Testing Toolkit. [S034](https://www.browserstack.com/press/browserstack-acquires-bird-eats-bug-launches-bug-capture-to-accelerate-its-test-platform-vision) [S033](https://www.browserstack.com/bug-capture) [S097](https://www.browserstack.com/docs/testing-toolkit/bug-capture/faqs/recording-videos)

**Documented strength:** a reproduction and diagnostic context are collected together. The video FAQ explicitly supports full-screen recording with microphone/camera, and does not impose a recording-duration limit. This distinguishes an actual limit from an assumed free-recorder cap. [S033](https://www.browserstack.com/bug-capture) [S097](https://www.browserstack.com/docs/testing-toolkit/bug-capture/faqs/recording-videos)

**Documented limits:** WebM can be downloaded before or after upload; MP4 requires upload. Sharing technical evidence with the video still uses the report URL. The FAQ distinguishes trimming a replay from trimming an ordinary recorded video, which is not supported there. Long recordings can still face browser/performance/upload constraints despite having no numeric duration cap. [S097](https://www.browserstack.com/docs/testing-toolkit/bug-capture/faqs/recording-videos) [S098](https://www.browserstack.com/docs/testing-toolkit/bug-capture/faqs/replays) Replay reconstructs at most two minutes of DOM history and documents iframe/font limitations; it is not pixel-perfect video. [S098](https://www.browserstack.com/docs/testing-toolkit/bug-capture/faqs/replays)

**Access/evidence quality:** old documentation routes redirected; the current video and replay FAQs were followed successfully. No account was created, and none of the capture or export steps were exercised. Therefore the existence of a download option does not establish complete offline portability of the developer evidence.

**Fit and tradeoff:** strong for browser reproduction and team diagnosis. It is a weaker match when the acceptance condition is an independently movable folder containing all original context. Copy its distinction between video and diagnostic payloads into the export contract rather than labeling every download a portable report.

<a id="p11"></a>
### Deep profile P11 — Marker.io

**Category / role:** C2 · direct. **Version:** Not stated. **Access:** 2026-10-13.

Selected because client-side masking and issue-system handoff illuminate both a missing feature and a desirable boundary.

**End-to-end workflow:** A reporter captures feedback against a website, adds an image annotation, and submits to a connected issue workflow. On eligible plans, a replay and browser diagnostics accompany the report. The maintainer follows links to those details and acts on the issue. [S036](https://help.marker.io/en/articles/6673880-session-replay-videos) [S037](https://help.marker.io/en/articles/14430683-why-are-console-logs-network-requests-and-replays-linked-instead-of-attached) [S040](https://marker.io/pricing)

**Documented strength:** masking can be configured before the relevant DOM content is captured. The documented mask/exclude classes show a narrower, inspectable control than a broad promise that local data is private. Team-tier replay and issue integration focus the product on obtaining actionable website feedback. [S038](https://help.marker.io/en/articles/9657817-sensitive-data-masking) [S036](https://help.marker.io/en/articles/6673880-session-replay-videos)

**Documented limits:** replay is plan-gated, and console/network/replay evidence is linked rather than attached to the destination issue. The privacy guide distinguishes masking, request filtering and disabling collection; none supplies proof that every pixel, URL and response body is safe. A selected screenshot alone does not define the entire report’s data boundary. [S037](https://help.marker.io/en/articles/14430683-why-are-console-logs-network-requests-and-replays-linked-instead-of-attached) [S039](https://help.marker.io/en/articles/12383990-data-privacy-security-overview)

**Evidence quality:** these are current vendor controls and restrictions, not a privacy audit. No current independent defect rate was established. A widget and managed issue destination also change the product boundary: this is not a drop-in local review library for arbitrary applications.

**Fit and tradeoff:** useful when collecting customer or teammate website feedback is the primary job. For Byron’s personal workflow, reuse the idea of explicit capture exclusions and a visible outgoing payload. Avoid building a widget distribution, tenant administration or issue-routing service without that distinct reporter task.

<a id="p14"></a>
### Deep profile P14 — Wispr Flow

**Category / role:** C3 · complement / dictation alternative. **Version:** Not stated. **Access:** 2026-10-13.

Selected as a strong general-dictation alternative whose cloud and recovery boundaries matter more than recorder parity.

**End-to-end workflow:** Trigger speech in a target text field, speak, stop, let Flow recognize/clean the text, and insert it into the application. Review or retry supported historical attempts on that device; the handoff is editable application text, not a timestamped video mark. [S045](https://docs.wisprflow.ai/articles/2772472373-what-is-flow) [S047](https://docs.wisprflow.ai/articles/2503460374-retry-failed-transcriptions)

**Documented strength:** cross-application insertion, vocabulary/snippets and cleanup target the writing task directly. Mac, Windows and mobile offerings broaden where that task can happen. Using such a tool in Context Recorder’s existing NoteEditor can test speech-assisted review without implementing global dictation. [S044](https://wisprflow.ai/pricing) [S045](https://docs.wisprflow.ai/articles/2772472373-what-is-flow)

**Documented limits:** the dictation workflow needs an internet connection and cloud processing. The free table lists 2,000 words weekly on desktop and 1,000 on mobile; Pro is $15 monthly or $12 per month billed annually. Retry does not recover audio that the microphone never captured, and history is device-local. Separate Notetaker claims must not be used to infer dictation’s processing boundary. [S044](https://wisprflow.ai/pricing) [S045](https://docs.wisprflow.ai/articles/2772472373-what-is-flow) [S047](https://docs.wisprflow.ai/articles/2503460374-retry-failed-transcriptions) [S048](https://wisprflow.ai/privacy)

**Vendor-documented friction:** accuracy and contextual rewriting have known limitations. These statements support checking proper names, code identifiers and unwanted cleanup; they do not establish a comparative error rate. No accent, latency or transcription benchmark was conducted. [S046](https://docs.wisprflow.ai/articles/4048537120-what-to-expect-from-flow-accuracy-and-known-limitations)

**Fit and tradeoff:** a ready-made alternative when general writing is the main objective and cloud processing is acceptable. It does not eliminate the need to distinguish a reviewer’s later interpretation from contemporaneous recorded narration. Keep the dictated note and source transcript semantically separate.

<a id="p15"></a>
### Deep profile P15 — Superwhisper

**Category / role:** C3 · complement / local speech alternative. **Version:** Not stated. **Access:** 2026-10-13.

Selected for local-model choice and contextual modes, a different boundary from mandatory-cloud dictation.

**End-to-end workflow:** Install/download an appropriate model, grant microphone and insertion permissions, trigger dictation or file transcription, optionally apply a mode, review the output, then insert or export text. Local and cloud choices are different processing paths. [S049](https://superwhisper.com/) [S051](https://superwhisper.com/docs/get-started/quickstart) [S052](https://superwhisper.com/docs/modes/built-in)

**Documented strength:** model and mode control allow a user to trade local operation against provider convenience. Its contextual modes can use selected or recently copied material, making it relevant to naming code and writing review notes. That is an input-workflow improvement, not a reason to attach a universal speech stack to every recording session. [S049](https://superwhisper.com/) [S052](https://superwhisper.com/docs/modes/built-in)

**Documented limits:** on Mac, app insertion requires Microphone and Accessibility permissions. Offline operation requires a downloaded local model; it does not describe every mode/provider. Pro is listed at $8.49 monthly, $84.99 yearly or $249.99 lifetime. Platform availability does not establish identical model availability or controls on each platform. [S051](https://superwhisper.com/docs/get-started/quickstart) [S050](https://superwhisper.com/docs/billing/plans)

**Vendor-documented friction:** troubleshooting separates paste/focus problems, wrong language, silence hallucinations and prompts that answer rather than transcribe. These are distinct failure classes. No incidence rate or superiority over Flow/Parakeet was measured. [S053](https://superwhisper.com/docs/common-issues/troubleshooting)

**Fit and tradeoff:** a strong alternative for local-first dictation trials. The smallest experiment is dictating into the existing note field with an appropriate literal-output mode. Judge correction burden and focus reliability separately from whether local speech recognition itself succeeds.

<a id="p18"></a>
### Deep profile P18 — MacWhisper

**Category / role:** C3 · complement / transcription and dictation alternative. **Version:** Not stated. **Access:** 2026-10-13.

Selected because file transcription, correction, structured export and dictation all touch existing Python/native seams.

**End-to-end workflow:** Import or capture audio, choose a recognizer, generate and correct a transcript, navigate timed segments, then export text/subtitles/structured files or insert dictated text elsewhere. The command-line tool exposes model/output controls, making it a possible complement rather than an obligatory GUI replacement. [S058](https://www.macwhisper.com/) [S059](https://docs.macwhisper.com/article/57-macwhisper-command-line-tool) [S060](https://macwhisper.helpscoutdocs.com/article/28-keyboard-shortcuts)

**Documented strength:** it separates recognizing speech from reviewing and exporting the recognized result. The CLI’s JSON/CSV/Markdown/HTML and subtitle formats are practical comparison points for Context Recorder’s fixed sentence projection. Systemwide dictation is also advertised, so classifying it as file-transcription-only would be stale. [S058](https://www.macwhisper.com/) [S059](https://docs.macwhisper.com/article/57-macwhisper-command-line-tool)

**Documented limits:** local models and optional cloud/AI paths have different data boundaries. Entitlements and the installed tool must be checked before relying on a CLI option. Editing a transcript is not evidence of transcript-driven video cuts. No such editing capability is inferred here. [S058](https://www.macwhisper.com/) [S059](https://docs.macwhisper.com/article/57-macwhisper-command-line-tool)

**Independent firsthand observation:** Simon Willison’s November 18, 2025 example shows a Parakeet v3 transcription with speaker/timestamp JSON from a council recording and shares inspectable output. It establishes that particular workflow, not a general accuracy or performance ranking on Byron’s narration. [S099](https://simonwillison.net/2025/Nov/18/macwhisper-speaker-recognition/)

**Fit and tradeoff:** use as the correction/export baseline before implementing a native transcript editor. Integration would still need a stable mapping back to original times and a clear distinction between raw recognition and corrected interpretation. Do not replace the existing cached Parakeet pipeline merely because a different UI has more options.

<a id="p20"></a>
### Deep profile P20 — Shottr

**Category / role:** C4 · complement / focused screenshot tool. **Version:** 1.9.3 displayed. **Access:** 2026-10-13.

Selected as the focused annotation complement with a particularly relevant redaction caveat.

**End-to-end workflow:** Capture a still or scrolling area, point out the issue with annotations, inspect/crop the image, and export a local derivative. Pair it with the original video mark when motion or spoken context matters; it is not counted as a continuous video recorder. [S062](https://shottr.cc/) [S063](https://shottr.cc/newversion.html)

**Documented strength:** a small still-image tool directly serves the task of making one defect legible. Pixel inspection, annotations and scrolling captures target a useful subset of the broader review problem. The displayed version is 1.9.3; no speed or resource advantage is asserted from the product’s positioning. [S062](https://shottr.cc/) [S063](https://shottr.cc/newversion.html)

**Documented limit:** the FAQ distinguishes raster operations on the base image from later annotation layers. Flattening the relevant result matters before treating a masked export as safe. A crop is not a redaction of its original, and a tall screenshot is not a source-mapped multi-time reconstruction. [S064](https://shottr.cc/kb/faq)

**Evidence quality:** no screenshot or canary-redaction test was run. No current product-wide reliability complaint was sufficiently substantiated. The meaningful risk is at the integration seam: replacing the mark’s original image with a flattened annotated copy would erase information about what was actually observed.

**Fit and tradeoff:** preferable to building an image editor for occasional arrows. Keep the original crop/frame, save an explicitly labeled derivative, and retain its source mark/time. An automated round-trip is below the first cut line until manual use proves both frequent and troublesome.

<a id="p21"></a>
### Deep profile P21 — Camtasia Snagit

**Category / role:** C4 · complement / richer annotation and tutorial tool. **Version:** Not stated. **Access:** 2026-10-13.

Selected to represent richer annotation and current automatic tutorial capture without conflating it with Camtasia Editor.

**End-to-end workflow:** Capture a still, simple narrated video or a sequence of actions, add visual callouts, trim/combine supported video, review the result, and export/share images or instructional material. The current branding is Camtasia Snagit; it remains a distinct application. [S065](https://www.techsmith.com/snagit/) [S066](https://www.techsmith.com/snagit/features/) [S067](https://www.techsmith.com/learn/tutorials/snagit/step-capture/)

**Documented strength:** visual explanation can be more economical than narrating a whole new recording. The image editor and step-capture workflow fit documentation that needs a clear sequence and annotated details, rather than a complete developer diagnostic record. [S066](https://www.techsmith.com/snagit/features/) [S067](https://www.techsmith.com/learn/tutorials/snagit/step-capture/)

**Documented boundary:** TechSmith distinguishes Snagit’s screenshot/basic-video role from Editor’s richer timeline. Audiate-driven text edits belong to the related Camtasia workflow, not automatically to Snagit. Screen Draw and capture capabilities must be checked for the actual platform/mode; the matrix does not assume Mac/Windows parity. [S068](https://www.techsmith.com/blog/snagit-vs-camtasia/) [S026](https://www.techsmith.com/camtasia/features/ai-text-based-editing/)

**Evidence quality:** TechSmith’s own comparison is evidence about its product boundaries, not an independent quality verdict. No contemporary hands-on benchmark or broad failure claim was established. Additional authoring controls can be useful, but their value here depends on how often the task really is making a tutorial.

**Fit and tradeoff:** choose it when recurrent annotated documentation justifies a dedicated tool. The lesson for Context Recorder is to export an intelligible finding, not to copy a mature editor’s whole feature set. Preserve source images separately from the polished explanatory asset.

<a id="p25"></a>
### Deep profile P25 — Scribe

**Category / role:** C5 · adjacent / procedural documentation. **Version:** Not stated. **Access:** 2026-10-13.

Selected as the strongest no-video procedural documentation counterfactual.

**End-to-end workflow:** Perform a workflow while Scribe captures steps, review the generated screenshots/instructions, edit or redact them on an eligible plan, then share a guide or export a document. Speaking is not required to obtain the basic procedural output; microphone narration is not inferred from AI guide generation. [S074](https://scribe.com/pricing) [S075](https://support.scribehow.com/hc/en-us/articles/8813841761181-Choosing-the-Right-Scribe-Pro-Plan)

**Documented strength:** it makes a sequence of actions readable without requiring the recipient to watch the whole recording. That overlaps with the desired outcome of faster extraction, but its unit is a documented step rather than a temporally grounded developer finding. [S074](https://scribe.com/pricing) [S075](https://support.scribehow.com/hc/en-us/articles/8813841761181-Choosing-the-Right-Scribe-Pro-Plan)

**Documented limits:** Basic is browser-oriented; desktop capture, image editing/redaction and PDF/HTML/Markdown outputs are paid capabilities. The current pricing page contains duplicated inconsistent Team price blocks, so this research does not select a convenient dollar value. Current marketing around autocapture does not prove that generated instructions preserve all original context. [S074](https://scribe.com/pricing) [S075](https://support.scribehow.com/hc/en-us/articles/8813841761181-Choosing-the-Right-Scribe-Pro-Plan)

**Evidence quality:** the documentation verifies the offered task, not instruction completeness or user learning outcomes. No comparative guide-authoring session was conducted. It is an inference that omission of wait states, failures and alternate paths may matter for bug evidence; no claim is made that Scribe always omits those states.

**Fit and tradeoff:** a better boundary when the deliverable is ‘how to do this’ rather than ‘what failed here and why.’ Use a guide as a complement where needed. Do not make Context Recorder infer a full tutorial by default from every narrated bug review.

<a id="p27"></a>
### Deep profile P27 — Guidde

**Category / role:** C5 · adjacent / narrated tutorial alternative. **Version:** Not stated. **Access:** 2026-10-13.

Selected because speech-to-tutorial cleanup differs fundamentally from evidence-preserving transcription.

**End-to-end workflow:** Capture a workflow, speak through Magic Mic or record voiceover, let the product build narrated steps, then edit captions/shapes/video and publish or download the instructional result. Separate screen-recording and interactive-demo offerings are listed alongside step creation; their tier placement is not inferred from lost table icons. [S078](https://www.guidde.com/) [S079](https://www.guidde.com/pricing)

**Documented strength:** one authored workflow can become both video and document-like guidance. Magic Mic explicitly transcribes and cleans speech before generating the step voiceover. That can be desirable for teaching even when it is undesirable for preserving exactly what was said during a failure. [S079](https://www.guidde.com/pricing)

**Documented limits:** explicit pricing prose gives 25 free web guiddes and higher-tier desktop/mobile capture. MP4 export requires an active paid subscription, not merely the Business trial. Parsed feature-table icons lose some plan membership; this report does not pretend all listed controls are free. Duplicated pricing blocks also conflict, so numeric prices are not a deciding input. [S079](https://www.guidde.com/pricing)

**Evidence quality:** no generated tutorial was reviewed for correctness or voice quality. Negative claims beyond documented gates are unsubstantiated. The important distinction is the transformation contract: cleanup and generated narration are authored output, not independent confirmation of the source recording.

**Fit and tradeoff:** strong for repeatable instructional communication. Context Recorder should not automatically replace original narration with polished generated speech. An optional derived explanation may be useful only when its source interval and the reviewer’s edits remain inspectable.

<a id="p29"></a>
### Deep profile P29 — Descript

**Category / role:** C6 · adjacent / transcript-led production alternative. **Version:** Not stated. **Access:** 2026-10-13.

Selected as the transcript-led editing reference against which transcript seeking must be distinguished.

**End-to-end workflow:** Record or import screen/voice media, transcribe it, edit words and corresponding video, refine the composition, then export a finished file or publish for review. This is not merely clicking a transcript sentence to move a playhead. [S083](https://www.descript.com/) [S085](https://www.descript.com/screen-recording)

**Documented strength:** the transcript becomes an editing interface rather than only an index. For a spoken explanation that needs cutting and cleanup, this is a meaningfully different task completion model from Context Recorder’s recorded-source library. [S083](https://www.descript.com/) [S085](https://www.descript.com/screen-recording)

**Documented limits:** current desktop requirements list macOS 14/Windows 11+. Media-hour, AI-credit and export-quality limits vary by plan; the screen-recorder page lists free 720p watermarked output. Public Hobbyist pricing is $16/person/month annual or $24 monthly. Edited transcript/video output should not replace forensic originals. [S086](https://www.descript.com/download) [S084](https://www.descript.com/pricing) [S085](https://www.descript.com/screen-recording)

**Historical user report:** a November 2023 cancellation account describes editing/correction friction. It is too old to establish a current defect and is not used to score present reliability. It identifies a task worth testing: the total effort of transcript correction plus visual correction, not just the speed of the first draft. [S095](https://www.reddit.com/r/Descript/comments/17z5bkh/an_honest_review_of_descript_and_why_i_cancelled/)

**Fit and tradeoff:** a stronger alternative when the goal is publishable spoken video. Reuse it rather than implementing transcript-to-video cuts. For personal bug review, simpler correction overlays and source seeking can be enough; editing the original may actually undermine the record of the bug.

<a id="p30"></a>
### Deep profile P30 — Screenpipe

**Category / role:** C6 · adjacent / broader memory boundary. **Version:** Not stated. **Access:** 2026-10-13.

Selected as the broader local-context end-state counterfactual, not a direct short-session recorder substitute.

**End-to-end workflow:** Continuously collect computer history, index screen/audio context, query what happened, extract a relevant interval, and provide it to an agent or integration. Current project positioning also includes company workflows and automation; it is no longer accurate to describe the entire product as only a personal offline memory tool. [S087](https://github.com/screenpipe/screenpipe) [S088](https://screenpipe.com/privacy)

**Documented strength:** capture can precede a person knowing which moment will matter. That directly attacks missed-mark and cross-session retrieval problems. Searchable history plus integration is a substantial overlap with any proposed broad Context Recorder memory hub. [S087](https://github.com/screenpipe/screenpipe)

**Documented limits:** local capture is a default boundary, not a guarantee for cloud AI, sync, connectors, exports or managed team storage. The project describes itself as source-available under a commercial license, not unrestricted open source. Continuous collection expands storage, retention and privacy decisions; advertised resource estimates are not adopted as measured results. [S087](https://github.com/screenpipe/screenpipe) [S088](https://screenpipe.com/privacy)

**Dated user report:** issue 3498 describes recorded audio remaining on disk while transcription reconciliation stopped advancing. The reported incident dates to May 2026. It illustrates why capture-success and search-index freshness need separate states; it does not establish the current release’s failure rate. [S089](https://github.com/screenpipe/screenpipe/issues/3498)

**Fit and tradeoff:** worth evaluating only if forgotten context across a workday is the real problem. For a personal developer deliberately narrating a review, session-bounded capture is a defensible omission, not an inferior feature count. Do not expand collection just to emulate the larger category.

<a id="p31"></a>
### Deep profile P31 — Replay.io

**Category / role:** C6 · adjacent / deeper developer debugging. **Version:** Not stated. **Access:** 2026-10-13.

Selected to separate deeper debugging evidence from screen capture and DOM replay.

**End-to-end workflow:** Record in the Replay Browser through its workflow/CLI, upload as needed, inspect execution and source information, then investigate or hand evidence to an agent using the documented debugging integration. Speech and native-desktop narration are not established components of this path. [S090](https://docs.replay.io/reference/replay-cli/commands) [S091](https://www.replay.io/blog/replay-time-travelogue-how-replay-mcp-helped-find-a-react-bug-faster-than-dan-abramov-did)

**Documented strength:** browser execution can answer questions about program state that an MP4 and an MHTML snapshot cannot. A vendor worked example shows how an agent uses this form of evidence. The example’s outcome is not treated as a benchmark against other debuggers. [S090](https://docs.replay.io/reference/replay-cli/commands) [S091](https://www.replay.io/blog/replay-time-travelogue-how-replay-mcp-helped-find-a-react-bug-faster-than-dan-abramov-did)

**Documented boundary:** it requires its recording-browser/upload/source-map workflow. Local recording files exist, but the inspected sources do not establish a complete portable standalone debugger. Source mapping has its own setup and fidelity requirements; recording a viewport is not a substitute for those requirements. [S090](https://docs.replay.io/reference/replay-cli/commands)

**Evidence quality:** no browser execution was recorded or replayed here. No negative claim about current reliability is substantiated. The higher setup cost is a workflow inference from the documented steps, not a measured number of minutes.

**Fit and tradeoff:** choose deeper execution replay for a class of reproducible browser bugs that ordinary context cannot explain. It should be a specialist escalation path, not a mandatory dependency of every personal walkthrough. Context Recorder can preserve source clues and hand off an issue without promising deterministic replay.

### What the experiential evidence does and does not establish

The current evidence is strongest for offered workflows, platform/plan gates and explicit limitations. Independent firsthand evidence is thinner: a MacWhisper worked example, current-year OBS configuration discussion and product issue reports, plus one clearly historical Descript account. These are useful for choosing failure fixtures, not for ranking whole products. A vendor’s promise of perfect synchronization, minimal resource use or faster resolution is not adopted as a measured result. No product was installed or used on Byron’s recordings. [S099](https://simonwillison.net/2025/Nov/18/macwhisper-speaker-recognition/) [S022](https://obsproject.com/forum/threads/no-pause-recording-in-mac-obs.194427/) [S018](https://github.com/CapSoftware/Cap/issues/1696) [S056](https://github.com/altic-dev/FluidVoice/issues/709) [S089](https://github.com/screenpipe/screenpipe/issues/3498) [S095](https://www.reddit.com/r/Descript/comments/17z5bkh/an_honest_review_of_descript_and_why_i_cancelled/)

The recurring **failure classes**, not product verdicts, are lost editor projection despite saved audio, stale transcription despite successful capture, focus/paste problems despite recognition, configuration-dependent controls, and partial portability despite a download button. Context Recorder’s proof should distinguish these states rather than add another undifferentiated “AI failed” message. [S018](https://github.com/CapSoftware/Cap/issues/1696) [S089](https://github.com/screenpipe/screenpipe/issues/3498) [S053](https://superwhisper.com/docs/common-issues/troubleshooting) [S022](https://obsproject.com/forum/threads/no-pause-recording-in-mac-obs.194427/) [S097](https://www.browserstack.com/docs/testing-toolkit/bug-capture/faqs/recording-videos) [R008](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L473-L484)

## Question 3 — What gaps exist, and which matter here?

### Existing capability deserves credit

The baseline already captures the main display at requested 15 fps up to 1920 pixels wide, with optional microphone and explicit exclusion of system audio. It writes local evidence, samples app/window/page activity, saves bounded Chrome diagnostics and MHTML snapshots at live marks, and can expose development source clues. Native review offers crops, later marks, notes, transcript seeking, a timeline, names and a library. These are implementation facts, not runtime test results. [R002](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Recorder.swift#L21-L80) [R004](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108) [R007](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L56-L96) [R009](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168) [R010](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L9-L31) [R021](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionLibrary.swift#L102-L122)

Local Product Grid export already uses `--local`, serial command execution and mapping checkpoints while preserving user-owned title/status/other images. A transcript regression and isolated UI harness exist. The earlier spatial canvas proposal is not implemented, and its earlier “no checks” statement does not describe this baseline. [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) [R020](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/check-transcript.py#L1-L16) [R019](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/docs/research/video-to-canvas/design.md#L3-L10)

### Ranked repository-grounded findings

The companion gap analysis contains the full 25-row capability inventory, 16 detailed findings, exact absence scopes, costs and rejection proofs. The priorities below are conditional on personal review and do not assert measured frequency.

| Gap / priority | Why it matters | Repository evidence |
| --- | --- | --- |
| G01 / P0 | Truthful input exclusion and sensitive-content boundaries — correctness / data minimization | [R011](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L194-L215) [R010](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L9-L31) [R015](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) [R012](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/BrowserBridge.swift#L26-L50) |
| G02 / P0 | Native, Markdown and portable HTML disagree about notes and time — implemented-path divergence | [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) [R006](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/viewer.html#L295-L334) [R018](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294) [R020](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/check-transcript.py#L1-L16) |
| G03 / P0 | Processing failure can look like silence or endless processing — failure-state / recovery gap | [R007](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L56-L96) [R008](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L473-L484) [R021](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionLibrary.swift#L102-L122) |
| G04 / P1 | Search across notes, transcript and context — retrieval feature gap | [R017](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SidePanel.swift#L265-L310) [R004](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108) [R009](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168) |
| G05 / P1 | Selected handoff is not selected content — scope / portability gap | [R015](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) [R018](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294) |
| G06 / P1 | Artifact time and temporal association need honest labels — provenance / precision gap | [R014](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L366-L420) [R013](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L23-L31) [R004](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108) |
| G07 / P1 | Browser connection, session freshness and tab identity — discoverability / context attribution gap | [R012](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/BrowserBridge.swift#L26-L50) [R013](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L23-L31) [R010](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L9-L31) |
| G08 / P2 | Source links need honest framework-specific confidence — grounding boundary, not wholesale absence | [R009](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168) [R010](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L9-L31) |
| G09 / P2 conditional | Display/window selection, system audio and recording pause — capture parity gap | [R002](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Recorder.swift#L21-L80) [R024](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionView.swift#L190-L244) [R014](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L366-L420) |
| G10 / P2 conditional | Visual arrows and masking are not the existing crop tool — annotation feature gap / reuse candidate | [R024](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionView.swift#L190-L244) [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) [R018](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294) |
| G11 / P2 conditional | Transcript correction and general dictation are separate opportunities — speech workflow boundary | [R007](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L56-L96) [R023](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionData.swift#L62-L66) [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) |
| G12 / P2 conditional | Portable clip and evidence handoff beyond local paths — extraction / recipient access gap | [R018](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294) [R015](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) |
| G13 / P3 proof only | Spatial storyboard / video-to-canvas — exploratory product direction | [R019](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/docs/research/video-to-canvas/design.md#L3-L10) [R014](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L366-L420) [R004](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108) |
| G14 / Below cut | Continuous DOM or execution replay — desirable omission unless a distinct debugging task appears | [R025](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L134-L137) [R010](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L9-L31) [R009](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168) |
| G15 / Below cut | Cloud collaboration and autonomous issue/agent workflows — desirable omission / product-boundary choice | [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) [R018](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294) [R001](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Package.swift#L1-L20) |
| G16 / P1 proof gate | Reliability, performance and test coverage are not established by source — untested implementation, not feature absence | [R020](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/check-transcript.py#L1-L16) [R021](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionLibrary.swift#L102-L122) [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) [R008](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L473-L484) |


**Most decisive correction:** input values are not categorically excluded. `describe()` falls back to `.value` and is called from change/focus/hover paths. That corrects the brief’s inherited assertion with the authorized source. It is not a claim that a real password was captured in this run. Other sensitive surfaces remain independently relevant. [R011](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L194-L215) [R010](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L9-L31)

**Most direct user-output defect:** a typed review conclusion can be present in native Markdown and absent in portable HTML’s visible/copied output. That deserves correction before adding another representation. Likewise initial transcription failure should not be called silence. These are narrower, better-grounded improvements than a speculative new editor. [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) [R006](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/viewer.html#L295-L334) [R008](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L473-L484)

**Leading additive candidate:** local lexical retrieval over findings/transcript/context, followed by explicit selected handoff. Existing seeking and mark-type filters remain useful; they do not constitute text search. Benefit remains unmeasured, so the current workflow and editor search are mandatory comparisons. [R017](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SidePanel.swift#L265-L310) [R015](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) [R018](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294)

### Parity versus desirable omissions

Missing system audio or target selection can be a real blocker, but only for some recordings. Native arrows can make one finding clearer, but external image editors may be enough. Global dictation is a different application boundary. A full transcript-driven video editor, hosted collaboration, continuous memory and execution replay each introduce a different product and maintenance burden. Treat them as deliberate omissions until a concrete task changes the boundary. [R002](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Recorder.swift#L21-L80) [R023](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionData.swift#L62-L66) [R024](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionView.swift#L190-L244) [R025](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L134-L137) [S020](https://obsproject.com/kb/macos-desktop-audio-capture-guide) [S062](https://shottr.cc/) [S049](https://superwhisper.com/) [S083](https://www.descript.com/) [S088](https://screenpipe.com/privacy) [S090](https://docs.replay.io/reference/replay-cli/commands)

## Question 4 — Keep, improve, explore, reuse or decline?

### Seven meaningfully different directions


<a id="o1"></a>
#### O1 — No build: use the existing local review loop

**User task:** Personal review already succeeds; find out where effort actually goes.

**Product boundary:** Current capture, marks, notes, native seeking, Markdown and PGM; manual Finder/browser retrieval.

**Benefit:** No new dependencies or maintenance. Establishes a credible comparison rather than a deliberately weak video-only baseline.

**Cost/tradeoff:** Retains current divergences and retrieval friction. Treat privacy wording/output defects as separately justified corrections, not proof of a new product.

**Wins when:** A handful of short sessions; current marks usually identify the needed moment. 

<a id="o2"></a>
#### O2 — Compose specialists rather than expand Context Recorder

**User task:** Write notes by voice, add an arrow, or make an occasional polished clip.

**Product boundary:** Existing review plus Apple Dictation/Superwhisper/MacWhisper, Shottr/CleanShot, and manual derived assets.

**Benefit:** Tests missing tasks with mature tools while preserving the Swift/Python/browser core.

**Cost/tradeoff:** Application switching, entitlement/setup and derivative-to-source bookkeeping; cloud settings must be intentional.

**Wins when:** General dictation or occasional visual editing is the real unmet need. [S061](https://support.apple.com/guide/mac-help/use-dictation-mh40584/mac) [S049](https://superwhisper.com/) [S058](https://www.macwhisper.com/) [S062](https://shottr.cc/) [S013](https://cleanshot.com/screen-recording)

<a id="o3"></a>
#### O3 — Focused local evidence workbench — recommended first direction

**User task:** Turn a deliberate narrated walkthrough into a few correct, findable, source-linked findings.

**Product boundary:** Session-bounded local capture; reliable processing state; search/select; faithful portable read/copy/export. No new cloud backend.

**Benefit:** Builds on existing marks, source context and files; targets a complete task instead of feature-count parity.

**Cost/tradeoff:** A few shared output semantics, scoped export rules and modest retrieval UI; benefit still needs proof.

**Wins when:** Personal bug/product review where local evidence and later interpretation both matter. [S006](https://support.atlassian.com/loom/docs/capture-console-and-network-logs/) [S007](https://support.atlassian.com/loom/docs/record-for-agent/) [S028](https://jam.dev/) [S093](https://help.frame.io/en/articles/9105278-comments-panel-overview)

<a id="o4"></a>
#### O4 — Browser-first reporter and diagnosis workflow

**User task:** Obtain a reproducible report from another person or diagnose a difficult web failure.

**Product boundary:** Prefer Jam/BrowserStack/Marker.io; use Replay for execution-level escalation. Context Recorder is a companion, not the hosted reporter.

**Benefit:** Existing diagnostics/report distribution can remove the need to build this workflow.

**Cost/tradeoff:** Hosted evidence, plan limits, browser instrumentation and incomplete standalone portability.

**Wins when:** Recipient/report collection and technical reproduction dominate local personal review. [S028](https://jam.dev/) [S033](https://www.browserstack.com/bug-capture) [S037](https://help.marker.io/en/articles/14430683-why-are-console-logs-network-requests-and-replays-linked-instead-of-attached) [S090](https://docs.replay.io/reference/replay-cli/commands)

<a id="o5"></a>
#### O5 — Polished asynchronous communication

**User task:** Teach or persuade with an edited narrated demo or tutorial.

**Product boundary:** Screen Studio/CleanShot/Descript for video; Scribe/Guidde/Arcade for instructions and interactive demos.

**Benefit:** Presentation, editing and distribution are already first-class.

**Cost/tradeoff:** Polished output can change timing, pixels and speech; maintain a separate raw evidence record when needed.

**Wins when:** Audience comprehension and publishing quality matter more than diagnostics or source fidelity. [S009](https://screen.studio/) [S013](https://cleanshot.com/screen-recording) [S083](https://www.descript.com/) [S074](https://scribe.com/pricing) [S078](https://www.guidde.com/) [S080](https://docs.arcade.software/kb/build/interactive-demo/record)

<a id="o6"></a>
#### O6 — Source-linked reading board, then optional spatial canvas

**User task:** Compare changed states and read scrolled content without serial playback.

**Product boundary:** Explicit offline derived view with one shared player. Begin with a simple board; use prior canvas proof only for incremental geometric value.

**Benefit:** Potentially distinctive reading/comparison workflow beyond ordinary screen recording.

**Cost/tradeoff:** Unproven benefit; alignment/refusal/source-map/export complexity. No invented unseen content.

**Wins when:** Long scrolling reviews repeatedly defeat the existing timeline and a useful storyboard. [S062](https://shottr.cc/) [S087](https://github.com/screenpipe/screenpipe)

<a id="o7"></a>
#### O7 — Broad local context-memory hub

**User task:** Recover missed moments across sessions and applications without deliberate marking.

**Product boundary:** Continuous history, searchable screen/audio/context, agent queries and potentially replay; evaluate Screenpipe before building.

**Benefit:** Can address forgotten context rather than only deliberate review.

**Cost/tradeoff:** Largest retention, performance, permissions and maintenance burden; exceeds evidenced personal-project need.

**Wins when:** A measured missed-capture problem across the workday, with an explicitly accepted collection boundary. [S087](https://github.com/screenpipe/screenpipe) [S088](https://screenpipe.com/privacy)

### Narrow recommendation and stronger alternatives

O3 wins provisionally because the repository already does the expensive context-collection and review work. Repairing its output contract and adding a small retrieval step can test value without another capture engine, frontend stack or cloud service. The hypothesis is that a reviewer can convert a narrated session into correct actionable findings with less searching and packaging. That hypothesis is not yet proven. [R004](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108) [R009](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168) [R010](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L9-L31) [R015](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) [R017](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SidePanel.swift#L265-L310)

The stronger alternative is O2/O1 when sessions are short or missing features are occasional. Existing Markdown search, typed notes and a specialist image/speech tool may satisfy the task with almost no application code. For customer or teammate bug collection, O4 may beat a local personal app outright. O6 could beat chronological review for long scrolling/comparison tasks, but must beat a useful simple board—not merely a weak video baseline. [S028](https://jam.dev/) [S033](https://www.browserstack.com/bug-capture) [S062](https://shottr.cc/) [S058](https://www.macwhisper.com/) [R019](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/docs/research/video-to-canvas/design.md#L3-L10)

| Primary goal | Recommended boundary | Changes to the proposal |
| --- | --- | --- |
| Personal bug/product review | O3, with O1/O2 as required comparisons. | Prioritize output truth, failure states, retrieval and selected local handoff; retain original context. |
| Polished communication/tutorials | O5 specialist reuse. | Prioritize audience comprehension and editing; preserve raw evidence separately when needed. Do not build a studio. |
| General dictation | O2 speech tool. | Choose local/cloud, language and focus behavior; dictate into existing NoteEditor. Do not equate Parakeet post-processing with app insertion. |


### Ordered recommendations with stable IDs

These are proposals. The JSON companion carries every required field, repository locator, source ID, dependency, proof and failure rule. Cost is relative maintenance/complexity, not an invented development-time estimate.


#### RT-01 — Keep original local evidence and the existing review model

**keep · P0 invariant** — Keep the Swift/Python/plain-JavaScript stack, session-bounded capture, raw local files, review marks, source links and --local PGM handoff. Treat edited output and future summaries as derivatives, not replacements.

**Simpler alternative:** O1: current app plus manual Markdown/Finder workflow.

**Proof / rejection:** PF-01: No unintended raw mutation; existing review remains usable when optional derived output is absent. Reject a proposed addition that destroys source evidence or requires a new service before showing task value.

Evidence: [R001](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Package.swift#L1-L20) [R004](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108) [R009](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168) [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) [R018](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294) [S028](https://jam.dev/) [S007](https://support.atlassian.com/loom/docs/record-for-agent/) [S037](https://help.marker.io/en/articles/14430683-why-are-console-logs-network-requests-and-replays-linked-instead-of-attached)

#### RT-02 — Make collection and export scope truthful

**improve · P0** — Correct categorical privacy wording; remove value-derived structured input text; preview outgoing transcript/image/page scope. Keep private originals and clearly labeled selected derivatives. Evaluate the minimal intended localhost peer policy, not enterprise security infrastructure.

**Simpler alternative:** Keep artifacts local/private, avoid sharing raw sessions and manually inspect copied findings.

**Proof / rejection:** PF-02: No prohibited canary in the claimed selected derivative; all inclusion decisions visible; benign source clue preserved. Do not call output sanitized if any included surface lacks a tested exclusion contract. Fall back to local-private-only rather than broad automatic redaction.

Evidence: [R011](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L194-L215) [R015](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) [R012](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/BrowserBridge.swift#L26-L50) [R024](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionView.swift#L190-L244) [S038](https://help.marker.io/en/articles/9657817-sensitive-data-masking) [S039](https://help.marker.io/en/articles/12383990-data-privacy-security-overview) [S064](https://shottr.cc/kb/faq) [S093](https://help.frame.io/en/articles/9105278-comments-panel-overview)

#### RT-03 — Preserve notes, provenance and sentence semantics across outputs

**improve · P0** — Define a small shared semantic fixture for native Markdown, processor Markdown and portable viewer read/copy. Preserve note-first title, note body, review provenance and exact sentence-start behavior. Do not introduce a general rendering framework.

**Simpler alternative:** Use native Copy as Markdown and processor session.md; explicitly warn that the current HTML view is incomplete for notes.

**Proof / rejection:** PF-03: 100% of required semantic fields preserved; selected sentence matches expected source start in both views. Reject any new surface that drops the review conclusion or invents live DOM evidence. Keep current native review while fixing parity.

Evidence: [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) [R006](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/viewer.html#L295-L334) [R020](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/check-transcript.py#L1-L16) [S093](https://help.frame.io/en/articles/9105278-comments-panel-overview) [S005](https://support.atlassian.com/loom/docs/correct-your-transcript/) [S059](https://docs.macwhisper.com/article/57-macwhisper-command-line-tool)

#### RT-04 — Expose processing outcomes and bounded retry

**improve · P0** — Use a compact stage/result state and a local retry path. Distinguish no audio, not requested, pending, unavailable, failed and ready. Reuse Review.reprocess behavior and existing logs where practical; preserve raw files.

**Simpler alternative:** Manual processor re-run with visible process.log; document unavailable dependencies rather than pretending silence.

**Proof / rejection:** PF-04: Every outcome correctly labeled; retry produces no duplicate findings or unintended raw mutation. Reject a service/queue abstraction unless a demonstrated multi-job need defeats one explicit local processing action.

Evidence: [R007](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L56-L96) [R008](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L473-L484) [R021](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionLibrary.swift#L102-L122) [S047](https://docs.wisprflow.ai/articles/2503460374-retry-failed-transcriptions) [S089](https://github.com/screenpipe/screenpipe/issues/3498) [S021](https://obsproject.com/kb/audio-video-formats-guide)

#### RT-05 — Prove the find–select–handoff local review task

**improve · P1 conditional first additive slice** — First benchmark O1 with existing mark navigation and Markdown. Then propose only in-session lexical search with match context/time plus faithful selected handoff. Keep one player and existing notes; no vector database or cloud search.

**Simpler alternative:** Search generated Markdown in an existing editor or browser and use native marks/Copy.

**Proof / rejection:** PF-05: No accuracy loss; median completion time at least 20% lower and at least four of six pairs faster than the stronger no-build baseline; raw provenance intact. If gains are below the predeclared target or correction overhead removes them, keep O1/O2 and do not build cross-session search or a new review surface.

Evidence: [R017](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SidePanel.swift#L265-L310) [R004](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108) [R009](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168) [R015](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) [R018](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294) [S060](https://macwhisper.helpscoutdocs.com/article/28-keyboard-shortcuts) [S093](https://help.frame.io/en/articles/9105278-comments-panel-overview) [S006](https://support.atlassian.com/loom/docs/capture-console-and-network-logs/) [S028](https://jam.dev/)

#### RT-06 — Qualify temporal and browser-source evidence

**improve · P1 when exercised** — Expose existing source-kind/precision distinctions first. Preserve occurrence/receipt identity where useful, label stale/unknown context, and validate the existing Solid source-attribute path. Add exact media provenance only when clipping/canvas or a measured mismatch requires it.

**Simpler alternative:** Treat all context as approximate and manually verify the original interval/source file.

**Proof / rejection:** PF-06: No false same-instant, wrong-tab or exact-line assertion; usable fallback when provenance is unavailable. Do not add a generalized clock service or framework adapter layer when explicit labels and bounded capture/session rules solve the observed task.

Evidence: [R012](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/BrowserBridge.swift#L26-L50) [R013](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L23-L31) [R014](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L366-L420) [R009](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168) [S090](https://docs.replay.io/reference/replay-cli/commands) [S030](https://jam.dev/docs/instant-replay) [S092](https://help.frame.io/en/articles/9105251-commenting-on-your-media)

#### RT-07 — Reuse speech, annotation and polished-video specialists

**reuse · P1 reuse; build deferred** — Try a single appropriate specialist manually with existing local artifacts. Keep dictated notes separate from original narration and annotated/edited derivatives separate from source. Select local versus cloud processing deliberately.

**Simpler alternative:** Use typed notes, native crops and unedited MP4 only.

**Proof / rejection:** PF-07: Task-specific gain after correction/round-trip effort, with original evidence preserved and intended data boundary respected. Do not build an integration when the task is rare or a manual copy/open/export is sufficient.

Evidence: [R023](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionData.swift#L62-L66) [R024](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionView.swift#L190-L244) [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) [R002](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Recorder.swift#L21-L80) [S061](https://support.apple.com/guide/mac-help/use-dictation-mh40584/mac) [S049](https://superwhisper.com/) [S045](https://docs.wisprflow.ai/articles/2772472373-what-is-flow) [S058](https://www.macwhisper.com/) [S062](https://shottr.cc/) [S013](https://cleanshot.com/screen-recording) [S009](https://screen.studio/) [S083](https://www.descript.com/)

#### RT-08 — Keep a source-linked board/canvas as a conditional alternative

**explore · P3 exploratory** — Preserve prior intent without overwriting it. Compare a useful change-selected board with existing review; only then run the bounded one-viewport automatic scroll/edit/refused-join proof. Use the existing HTML player/JSON seam first; native canvas comes later only if earned.

**Simpler alternative:** Chronological marks or a simple contact sheet/storyboard linked to original video.

**Proof / rejection:** PF-08: Every displayed patch maps to a real frame/crop; no harmful accepted join or lost required change; clear incremental value over the stronger simple view. Prefer the simpler board if geometry adds no task value. Refuse uncertain joins; do not render unobserved content or claim general-video support.

Evidence: [R019](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/docs/research/video-to-canvas/design.md#L3-L10) [R014](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L366-L420) [R018](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294) [S062](https://shottr.cc/) [S074](https://scribe.com/pricing) [S087](https://github.com/screenpipe/screenpipe)

#### RT-09 — Add capture breadth only for a recurring blocked task

**explore · P2 conditional** — Use a specialist capture as a counterfactual. If the task is recurring, propose one target or audio capability and validate coordinates/timing/permissions; retain existing defaults. Leave webcam, cinematic effects and blanket 4K/60 below the cut line.

**Simpler alternative:** Move the relevant window to the main display or use OBS/CleanShot for that recording.

**Proof / rejection:** PF-09: Current workflow demonstrably blocked, specialist baseline succeeds, proposed single capability restores completion without source/time regression. Reject a bundled capture rewrite when a simpler operating habit or external recorder is adequate.

Evidence: [R002](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Recorder.swift#L21-L80) [R014](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L366-L420) [R024](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionView.swift#L190-L244) [S020](https://obsproject.com/kb/macos-desktop-audio-capture-guide) [S013](https://cleanshot.com/screen-recording) [S009](https://screen.studio/) [S027](https://support.apple.com/en-us/102618)

#### RT-10 — Decline cloud-team, always-on and full editor expansion by default

**avoid · Below cut; default avoid** — Do not add a hosted workspace, team accounts, autonomous issue creation, mandatory DOM/execution replay, a systemwide dictation engine or a full video studio in the first direction. Keep deliberate manual/structured handoff and specialist escalation.

**Simpler alternative:** O4, O5 or O7 as explicit new product-boundary decisions after evidence, primarily by reuse.

**Proof / rejection:** PF-10: A concrete unmet need is demonstrated before a separate proposal is considered. A competitor checkbox or unverified uniqueness claim is insufficient. Keep the omission when no task-level case exists.

Evidence: [R001](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Package.swift#L1-L20) [R016](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) [R019](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/docs/research/video-to-canvas/design.md#L3-L10) [R023](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionData.swift#L62-L66) [R025](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L134-L137) [S007](https://support.atlassian.com/loom/docs/record-for-agent/) [S032](https://jam.dev/integrations/github) [S090](https://docs.replay.io/reference/replay-cli/commands) [S088](https://screenpipe.com/privacy) [S083](https://www.descript.com/) [S079](https://www.guidde.com/pricing)

## Question 5 — Smallest useful proof and path forward

Start with one synthetic session contract, not a new application. Include live and review marks, a typed correction, a crop/full frame, source-location fallbacks, adjacent short transcript sentences, a missing page and explicit processing outcomes. Check note/provenance and selected-export semantics first. Use cached transcripts so recognition quality does not obscure whether the review interaction is useful. [R004](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108) [R005](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) [R006](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/viewer.html#L295-L334) [R007](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L56-L96) [R015](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) [R020](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/check-transcript.py#L1-L16)

For value, use six matched retrieval-to-handoff tasks across three synthetic session variants. Compare the current native app plus generated-Markdown search with the smallest candidate query/selected-handoff surface. Rotate order; include correction and packaging time. Proposed acceptance: no accuracy loss, at least 20% lower median full-task time and at least four of six pairs faster. These are unapproved thresholds to set before testing, not research results. A no-build outcome remains valid.

Keep checks few: one semantic golden test, one failure/no-source-loss set and one observed end-to-end reviewer task. Use the existing Swift/Python/browser seams. Do not run the existing harness’s personal-fixture prepare unchanged. No recordings or fixtures were created here; fixture definitions are in the proof-plan companion. [R020](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/check-transcript.py#L1-L16)

Measure product value, provider accuracy, permission/focus behavior, performance/recovery and exact source provenance separately. A cached-transcript UI proof cannot establish speech accuracy; a screen-permission preflight cannot establish successful capture; an MP4 on disk cannot establish complete indexing. Add exact decoded frame mapping before a clip or canvas makes an exposure-time claim. [R007](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L56-L96) [R008](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L473-L484) [R013](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L23-L31) [R014](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L366-L420) [S047](https://docs.wisprflow.ai/articles/2503460374-retry-failed-transcriptions) [S089](https://github.com/screenpipe/screenpipe/issues/3498) [S021](https://obsproject.com/kb/audio-video-formats-guide)

Valid intermediate states are: existing local review with truthful labels; faithful read-only portable output; one-session search that can be absent without breaking normal review; explicit selected local handoff. Wider capture, native transcript correction and spatial geometry stay separate conditional decisions. An optional failure must never remove access to original capture or previously reviewed findings.

### Unresolved human choices — exactly three


**H1: Which primary outcome should govern the next proof: personal bug/product review, polished communication, or general dictation?** Personal local review is provisional, not a discovered preference. Review selects O3/RT-05; communication selects O5 specialist reuse; dictation selects O2/RT-07. Do not approve a broad implementation before this choice.

**H2: What data may leave the private session folder, and who must consume it?** Local private originals; explicit selected, previewed derivatives; no automatic upload. Determines export scope and whether a hosted specialist is acceptable. A raw full-session handoff requires a deliberate broader choice.

**H3: How much measured benefit must a new local-review surface deliver to justify its maintenance cost?** Keep the simpler workflow unless it clears a predeclared provisional 20% full-task time gain with no accuracy loss. Set the acceptance budget before evaluation, for lexical retrieval or a separately justified spatial-reading alternative. Do not move the threshold afterward or expand scope merely because a prototype exists.

## Deliverable gates, checks and material limitations

| Gate | Result | Limit |
| --- | --- | --- |
| Repository/source/web access | GO: requested identity/ref, packet route and current web available. | Packet is selected text; only README independently accessed through connected GitHub. |
| Breadth | 32 unique products across six categories. | Purposeful sample, not market share; 30 excluding both native Apple utilities. |
| Depth | 18 expanded profiles, with every category represented. | Documented workflow analysis, not a hands-on benchmark. |
| Feature taxonomy / prevalence | 46 explicit-state feature columns; within-category denominators and unknowns. | Sparse/cross-category unknowns remain unknown; no absence by silence. |
| Repository gap evidence | 25 capability rows, 16 detailed findings and 25 grouped immutable source records. | Absence qualified by six searched scopes; untested behavior stays untested. |
| Alternatives / recommendation | Seven directions, ten stable recommendations, exactly three human choices. | Conditional proposal, not approval or implementation. |
| Artifacts | Seven companions plus ZIP with identical copies. | Manifest records parsing, IDs, references, counts, sizes and integrity checks. |


Executed safe checks: 48 section/hash comparisons; three Python AST parses; processor `--help` on an extracted scratch script; five standalone JavaScript syntax checks plus the embedded viewer script; six scoped static searches; CSV and JSON parsing, required recommendation fields, unique IDs, source/repository/dependency/proof references, category/profile counts, local companion links, file hashes and ZIP/standalone identity. The manifest is the machine-readable record.

Not run: native build, native transcript regression execution, UI harness, PGM CLI export, speech inference, media decoding, capture permissions, recordings, privacy-canary experiments, crash tests, performance benchmarks or usability trials. Historical checks from prior canvas research are not this run’s results. Vendor claims of accuracy, performance, privacy and recovery remain unmeasured; exact app versions or prices are unknown where current evidence did not resolve them.

No repository files, commits, branches, issues or PRs were created or changed. Codex will preserve/reconcile the outputs and apply the full software-design-sleuth process before any review PR. This package supplies evidence and proposals, not a completed Sleuth validation or permission to implement.

## Companion guide

- [recording-tools-matrix.csv](recording-tools-matrix.csv): 32 product rows, 46 feature states and source mappings; the dictionary is above.
- [recording-tools-gap-analysis.md](recording-tools-gap-analysis.md): detailed capability/gap matrices, absence scope, evidence, costs and rejection proofs.
- [recording-tools-sources.md](recording-tools-sources.md): complete external and immutable repository ledger.
- [recording-tools-recommendations.json](recording-tools-recommendations.json): ten complete machine-readable recommendations.
- [recording-tools-proof-plan.md](recording-tools-proof-plan.md): fixtures, intermediate states, acceptance/rejection and conditional next outcomes.
- [recording-tools-manifest.json](recording-tools-manifest.json): exact inspection/check/count/hash record.
- [recording-tools-research.zip](recording-tools-research.zip): byte-identical copies of those companions and this report, seven entries total.

## Appendix A — Compact immutable repository evidence map

All locators refer to the authorized packet at `6c74158ca96abd36819d2a58f75bacdc44107bb0`. This map supports the report without relying on a mutable main branch. Full file/absence inventories appear in the gap analysis and manifest.


<a id="r001"></a>
### R001 — Stack and platform

Swift package targets macOS 26; the supplied manifest contains Swift, Python and plain JavaScript, but no package.json. The packet is not a full Git tree.

- [`Package.swift:1-20`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Package.swift#L1-L20) — `// swift-tools`.

- [`README.md:124-137`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L124-L137) — `## Layout`.

<a id="r002"></a>
### R002 — Capture configuration

Main display, 1920-pixel width cap, requested 15 fps, visible cursor, optional default microphone; system audio explicitly disabled. Recording stop is distinct from playback pause.

- [`Sources/ContextRecorder/Recorder.swift:21-80`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Recorder.swift#L21-L80) — `static let maxWidth`.

- [`Sources/ContextRecorder/Recorder.swift:81-97`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Recorder.swift#L81-L97) — `func stop()`.

<a id="r003"></a>
### R003 — Controls and keyboard access

Global Carbon hotkeys and floating control panel already exist; keyboard help and review shortcuts are implemented. Registration failure logs do not establish visible conflict recovery.

- [`Sources/ContextRecorder/HotKeys.swift:5-44`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/HotKeys.swift#L5-L44) — `final class HotKeys`.

- [`Sources/ContextRecorder/ControlPanel.swift:153-191`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/ControlPanel.swift#L153-L191) — `func update(`.

- [`Sources/ContextRecorder/Library/LibraryView.swift:303-336`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/LibraryView.swift#L303-L336) — `struct ShortcutsSheet`.

<a id="r004"></a>
### R004 — Review marks already work in source

Add review marks/cropped frames/notes; use recorded activity and prior page events, not a historical DOM snapshot. Only review marks can be deleted.

- [`Sources/ContextRecorder/Library/Review.swift:13-108`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L13-L108) — `extension SessionModel`.

- [`Sources/ContextRecorder/Library/Review.swift:108-117`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L108-L117) — `private func recentPageEvents`.

<a id="r005"></a>
### R005 — Native note and provenance output

Native title and Markdown include typed note and review provenance. MarksFile atomically rewrites loose JSON, preserving unmodeled fields; note edits rerun processing.

- [`Sources/ContextRecorder/Library/MarkText.swift:59-115`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L59-L115) — `static func title`.

- [`Sources/ContextRecorder/Library/Review.swift:64-78`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L64-L78) — `func setNote`.

- [`Sources/ContextRecorder/Library/Review.swift:179-196`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L179-L196) — `enum MarksFile`.

<a id="r006"></a>
### R006 — HTML/native semantic divergence

HTML titleOf, markdownFor and renderList omit typed notes and review provenance. HTML sentenceAt uses first matching sentence with a lead-in; native uses last started sentence.

- [`scripts/viewer.html:295-334`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/viewer.html#L295-L334) — `const titleOf`.

- [`scripts/viewer.html:365-404`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/viewer.html#L365-L404) — `function renderList`.

- [`Sources/ContextRecorder/Library/SessionModel.swift:143-146`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionModel.swift#L143-L146) — `func sentenceAt`.

<a id="r007"></a>
### R007 — Post-capture local transcription

Processor caches transcript.json; extracts 16 kHz mono audio with ffmpeg and runs parakeet-mlx. Missing recognizer returns no transcript. Tokens drive narration windows; native rollup keeps sentence times.

- [`scripts/process_session.py:56-96`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L56-L96) — `def has_audio`.

- [`scripts/process_session.py:98-117`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L98-L117) — `def tokens_of`.

- [`scripts/process_session.py:337-339`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L337-L339) — `"transcript":`.

<a id="r008"></a>
### R008 — Failure and silence states differ by path

Initial processing completion ignores exit status; missing script logs and completes. Native empty transcript is labeled silent. Review reprocessing does check nonzero status and exposes an error.

- [`Sources/ContextRecorder/main.swift:473-484`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L473-L484) — `private func runPostProcessing`.

- [`Sources/ContextRecorder/Library/SessionView.swift:27-48`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionView.swift#L27-L48) — `@ViewBuilder private var content`.

- [`Sources/ContextRecorder/Library/SessionView.swift:359-415`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionView.swift#L359-L415) — `struct NowStrip`.

- [`Sources/ContextRecorder/Library/Review.swift:150-169`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L150-L169) — `func reprocess`.

<a id="r009"></a>
### R009 — Developer source grounding exists, with limits

sourceFor reads framework/build attributes and marks React 19 post-transform lines. SourceButton opens an existing path in VS Code or copies it. Solid needs source attributes; production source fidelity is not assured.

- [`extension/page.js:135-168`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L135-L168) — `function sourceFor`.

- [`Sources/ContextRecorder/Library/MarkDetail.swift:400-436`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkDetail.swift#L400-L436) — `struct SourceButton`.

- [`Sources/ContextRecorder/Library/SessionData.swift:97-110`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionData.swift#L97-L110) — `struct SourceLocation`.

<a id="r010"></a>
### R010 — Browser context and bounded diagnostics

Click/navigation/errors plus failed/slow requests are streamed; ring size 60, recent 40; error bodies truncated to 800 characters. Mark snapshot includes DOM descriptions, selection, viewport and source candidates.

- [`extension/page.js:9-31`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L9-L31) — `const RING_SIZE`.

- [`extension/page.js:296-350`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L296-L350) — `function recordRequest`.

- [`extension/page.js:365-384`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L365-L384) — `function snapshot`.

- [`extension/background.js:98-111`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/background.js#L98-L111) — `async function capturePage`.

<a id="r011"></a>
### R011 — Input exclusion claim contradicted

describe() falls back to target.value and is called by change handling and focused/hovered snapshots. No password guard is present in that path. This is reachable sensitive-data collection in source, not an observed leak.

- [`extension/page.js:194-215`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L194-L215) — `function describe`.

- [`extension/page.js:234-237`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L234-L237) — `// Never record values`.

- [`extension/page.js:365-383`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L365-L383) — `function snapshot`.

- [`README.md:96-96`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L96-L96) — `Input values are never`.

<a id="r012"></a>
### R012 — Local connection and indicator boundaries

Bridge binds localhost but accepts empty Origin as well as chrome-extension origins. Popup equates connectivity with capturing. Native event writing is gated on an active session.

- [`Sources/ContextRecorder/BrowserBridge.swift:26-50`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/BrowserBridge.swift#L26-L50) — `func start()`.

- [`extension/popup.js:3-14`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/popup.js#L3-L14) — `const STATES`.

- [`extension/popup.js:49-54`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/popup.js#L49-L54) — `function renderTabState`.

- [`Sources/ContextRecorder/main.swift:167-170`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L167-L170) — `bridge.onEvent`.

<a id="r013"></a>
### R013 — Event time, queue and tab projection

Page has wall-clock event.t; native assigns receipt offset. Extension reconnect queue holds up to 200 messages. Raw events carry tabId; native PageEvent projection and review recent-event selection do not retain/filter all identity fields.

- [`extension/page.js:23-31`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L23-L31) — `function record(event`.

- [`extension/background.js:3-49`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/background.js#L3-L49) — `const MAX_QUEUE`.

- [`extension/background.js:131-139`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/background.js#L131-L139) — `chrome.runtime.onMessage`.

- [`Sources/ContextRecorder/main.swift:167-170`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L167-L170) — `bridge.onEvent`.

- [`Sources/ContextRecorder/Library/SessionData.swift:124-145`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionData.swift#L124-L145) — `struct PageEvent`.

- [`Sources/ContextRecorder/Library/Review.swift:108-116`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L108-L116) — `private func recentPageEvents`.

<a id="r014"></a>
### R014 — Mark time is not all artifact exposure times

Live region mark offset/context are taken before selection, then pixels are captured later. Review saveFrame discards actual returned time; extract_frame stores requested seek, not decoded exposure metadata.

- [`Sources/ContextRecorder/main.swift:366-420`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L366-L420) — `private func addMark`.

- [`Sources/ContextRecorder/main.swift:422-440`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L422-L440) — `private func addRegionMark`.

- [`Sources/ContextRecorder/Library/Review.swift:126-147`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L126-L147) — `private func saveFrame`.

- [`scripts/process_session.py:131-141`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L131-L141) — `def extract_frame`.

<a id="r015"></a>
### R015 — Selected export has broader payload

Export sheet selects mark children, but sessionMarkdown includes full transcript; imageFiles includes full frame alongside a region still. Selection is not a complete content boundary.

- [`Sources/ContextRecorder/Export/ExportSheet.swift:115-121`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/ExportSheet.swift#L115-L121) — `let marks = session.marks.filter`.

- [`Sources/ContextRecorder/Export/PgmExport.swift:155-161`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/PgmExport.swift#L155-L161) — `private func imageFiles`.

- [`Sources/ContextRecorder/Export/PgmExport.swift:166-181`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/PgmExport.swift#L166-L181) — `private var sessionMarkdown`.

<a id="r016"></a>
### R016 — Local and partly recoverable Product Grid export

Pgm always appends --local; arguments avoid shell interpolation; queue serializes CLI operations. Re-export updates owned context/images and preserves user title/status/other images. Mapping checkpoints avoid some duplicate work.

- [`Sources/ContextRecorder/Export/Pgm.swift:41-77`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L41-L77) — `private func runOnce`.

- [`Sources/ContextRecorder/Export/Pgm.swift:206-218`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/Pgm.swift#L206-L218) — `actor PgmQueue`.

- [`Sources/ContextRecorder/Export/PgmExport.swift:98-152`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Export/PgmExport.swift#L98-L152) — `func run(progress`.

<a id="r017"></a>
### R017 — Navigation is not text retrieval

Native transcript and page lists seek on click. Marks filter by kind, library by date groups; no app-level text query found across all 13 Library/viewer files in scope A01_search.

- [`Sources/ContextRecorder/Library/SidePanel.swift:265-310`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SidePanel.swift#L265-L310) — `struct TranscriptList`.

- [`Sources/ContextRecorder/Library/SessionModel.swift:112-119`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionModel.swift#L112-L119) — `var filteredMarks`.

- [`Sources/ContextRecorder/Library/LibraryView.swift:134-152`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/LibraryView.swift#L134-L152) — `private var groups`.

<a id="r018"></a>
### R018 — Local output and portability boundary

Processor embeds JSON into viewer HTML, but video/images/pages remain relative external files. Native Markdown embeds absolute folder video paths plus text times; a copied link is not a bundled session.

- [`scripts/process_session.py:290-294`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L290-L294) — `def write_viewer`.

- [`scripts/viewer.html:191-191`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/viewer.html#L191-L191) — `<div class="player"><video`.

- [`Sources/ContextRecorder/Library/MarkText.swift:78-109`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkText.swift#L78-L109) — `static func markdown(_`.

- [`scripts/process_session.py:330-342`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L330-L342) — `data = {`.

<a id="r019"></a>
### R019 — Spatial canvas is proposal only

Prior design explicitly says not implemented and preserves observed pixel/source semantics. Current timeline Canvas draws lanes, not a reconstructed page. Old research uses another baseline and is not product proof.

- [`docs/research/video-to-canvas/design.md:3-10`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/docs/research/video-to-canvas/design.md#L3-L10) — `Status:`.

- [`docs/research/video-to-canvas/design.md:50-81`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/docs/research/video-to-canvas/design.md#L50-L81) — `## What an image means`.

- [`docs/research/video-to-canvas/proof-plan.md:85-105`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/docs/research/video-to-canvas/proof-plan.md#L85-L105) — `## 5. Decide whether to continue`.

- [`Sources/ContextRecorder/Library/SessionTimeline.swift:148-169`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionTimeline.swift#L148-L169) — `private func ruler`.

<a id="r020"></a>
### R020 — Existing tests and fixture dependency

Transcript regression script exercises native exact sentence starts. UI harness exists with path/process protections but prepare copies specified personal sessions. It was not run; synthetic replacements are needed for a shareable proof.

- [`scripts/check-transcript.py:1-16`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/check-transcript.py#L1-L16) — `#!/usr/bin`.

- [`scripts/ui-test/harness.py:24-28`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/ui-test/harness.py#L24-L28) — `SOURCE =`.

- [`scripts/ui-test/harness.py:95-146`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/ui-test/harness.py#L95-L146) — `def prepare`.

- [`scripts/ui-test/README.md:86-113`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/ui-test/README.md#L86-L113) — `## PR #8`.

<a id="r021"></a>
### R021 — Library and preview implementation, not measured performance

Library rename and recoverable Trash paths exist; preview requests are coalesced and cache capped at 150. These are design choices, not measured responsiveness or crash guarantees.

- [`Sources/ContextRecorder/Library/SessionLibrary.swift:102-122`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionLibrary.swift#L102-L122) — `func rename`.

- [`Sources/ContextRecorder/Library/SessionTimeline.swift:384-422`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionTimeline.swift#L384-L422) — `final class FramePreviews`.

<a id="r022"></a>
### R022 — Permission/onboarding paths

README describes Screen Recording, microphone and Chrome Automation; main requests screen permission outside library-only mode. Extension injection/retry and restricted-page errors exist; no runtime permission success was tested.

- [`README.md:65-74`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L65-L74) — `First run asks`.

- [`Sources/ContextRecorder/main.swift:188-195`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L188-L195) — `if devLibraryFolder == nil {`.

- [`extension/background.js:60-93`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/background.js#L60-L93) — `async function handle`.

- [`Sources/ContextRecorder/main.swift:198-200`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/main.swift#L198-L200) — `// Ask for screen-recording permission`.

<a id="r023"></a>
### R023 — Native transcript model is not a dictation/editor

Sentence only stores start/end/text; NoteEditor edits a mark note, not the recognized transcript. No arbitrary-app speech insertion path found in A03_speech.

- [`Sources/ContextRecorder/Library/SessionData.swift:62-66`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionData.swift#L62-L66) — `struct Sentence`.

- [`Sources/ContextRecorder/Library/MarkDetail.swift:440-478`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/MarkDetail.swift#L440-L478) — `struct NoteEditor`.

- [`scripts/process_session.py:77-96`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/scripts/process_session.py#L77-L96) — `def transcribe`.

<a id="r024"></a>
### R024 — Crop and visual markup boundaries

Review and capture both have rectangle selection. RegionPicker dims an overlay for selection; saved output is a crop, not an irreversible privacy mask or an annotation editor.

- [`Sources/ContextRecorder/Library/SessionView.swift:190-244`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/SessionView.swift#L190-L244) — `struct RegionPicker`.

- [`Sources/ContextRecorder/Recorder.swift:126-140`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Recorder.swift#L126-L140) — `func screenshot`.

- [`Sources/ContextRecorder/Library/Review.swift:126-147`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/Sources/ContextRecorder/Library/Review.swift#L126-L147) — `private func saveFrame`.

<a id="r025"></a>
### R025 — Snapshots do not supply replay

README lists rrweb as future work. Extension streams event summaries and captures MHTML on demand; it does not implement continuous DOM mutation replay or browser execution replay in A05_canvas_replay.

- [`README.md:134-137`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/README.md#L134-L137) — `## Next`.

- [`extension/page.js:21-30`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/page.js#L21-L30) — `const STREAM`.

- [`extension/background.js:98-111`](https://github.com/byronwall/context-recorder/blob/6c74158ca96abd36819d2a58f75bacdc44107bb0/extension/background.js#L98-L111) — `async function capturePage`.

## Appendix B — Direct source index

All sources accessed **2026-10-13 (America/Indiana/Indianapolis)**. Full publication/update dates, evidence types, versions and limits are in the source-ledger companion. IDs remain stable across every artifact.

- **S001** — [Loom pricing](https://www.loom.com/pricing); Atlassian / Loom; accessed 2026-10-13.
- **S002** — [Use Loom’s different capture modes](https://support.atlassian.com/loom/docs/use-looms-different-capture-modes/); Atlassian; accessed 2026-10-13.
- **S003** — [Capture system audio](https://support.atlassian.com/loom/docs/capture-internal-audio-system-audio/); Atlassian; accessed 2026-10-13.
- **S004** — [Edit your Loom video](https://support.atlassian.com/loom/docs/edit-your-loom-video/); Atlassian; accessed 2026-10-13.
- **S005** — [Correct your transcript](https://support.atlassian.com/loom/docs/correct-your-transcript/); Atlassian; accessed 2026-10-13.
- **S006** — [Capture console and network logs](https://support.atlassian.com/loom/docs/capture-console-and-network-logs/); Atlassian; accessed 2026-10-13.
- **S007** — [Record for AI agents](https://support.atlassian.com/loom/docs/record-for-agent/); Atlassian; accessed 2026-10-13.
- **S008** — [Loom AI features](https://support.atlassian.com/loom/docs/loom-ai-features/); Atlassian; accessed 2026-10-13.
- **S009** — [Screen Studio product page](https://screen.studio/); Screen Studio; accessed 2026-10-13.
- **S010** — [Captions](https://screen.studio/guide/captions); Screen Studio; accessed 2026-10-13.
- **S011** — [Screen Studio guide](https://screen.studio/guide); Screen Studio; accessed 2026-10-13.
- **S012** — [CleanShot X](https://cleanshot.com/); CleanShot; accessed 2026-10-13.
- **S013** — [Screen recording](https://cleanshot.com/screen-recording); CleanShot; accessed 2026-10-13.
- **S014** — [CleanShot pricing](https://cleanshot.com/pricing); CleanShot; accessed 2026-10-13.
- **S015** — [Cap pricing](https://cap.so/pricing); Cap Software; accessed 2026-10-13.
- **S016** — [Cap FAQs](https://cap.so/faq); Cap Software; accessed 2026-10-13.
- **S017** — [Cap LICENSE at main](https://github.com/CapSoftware/Cap/blob/main/LICENSE); Cap Software; accessed 2026-10-13.
- **S018** — [Camera-only recording: editor audio missing, issue 1696](https://github.com/CapSoftware/Cap/issues/1696); Cap user chrisspiegl; accessed 2026-10-13.
- **S019** — [OBS Studio](https://obsproject.com/); OBS Project; accessed 2026-10-13.
- **S020** — [macOS desktop audio capture guide](https://obsproject.com/kb/macos-desktop-audio-capture-guide); OBS Project; accessed 2026-10-13.
- **S021** — [Audio/video formats guide](https://obsproject.com/kb/audio-video-formats-guide); OBS Project; accessed 2026-10-13.
- **S022** — [No Pause Recording in Mac OBS](https://obsproject.com/forum/threads/no-pause-recording-in-mac-obs.194427/); OBS community participants; accessed 2026-10-13.
- **S023** — [ScreenFlow overview](https://www.telestream.net/screenflow/overview.htm); Telestream; accessed 2026-10-13.
- **S024** — [Camtasia](https://www.techsmith.com/camtasia/); TechSmith; accessed 2026-10-13.
- **S025** — [Getting started with Camtasia Essentials](https://support.techsmith.com/hc/en-us/articles/40967481935885-Getting-Started-with-a-Camtasia-Essentials-Plan); TechSmith; accessed 2026-10-13.
- **S026** — [AI text-based editing](https://www.techsmith.com/camtasia/features/ai-text-based-editing/); TechSmith; accessed 2026-10-13.
- **S027** — [How to record the screen on Mac](https://support.apple.com/en-us/102618); Apple; accessed 2026-10-13.
- **S028** — [Jam](https://jam.dev/); Jam; accessed 2026-10-13.
- **S029** — [Jam pricing](https://jam.dev/pricing); Jam; accessed 2026-10-13.
- **S030** — [Instant Replay](https://jam.dev/docs/instant-replay); Jam; accessed 2026-10-13.
- **S031** — [Recording Links](https://jam.dev/docs/recording-links); Jam; accessed 2026-10-13.
- **S032** — [Jam GitHub integration](https://jam.dev/integrations/github); Jam; accessed 2026-10-13.
- **S033** — [Bug Capture](https://www.browserstack.com/bug-capture); BrowserStack; accessed 2026-10-13.
- **S034** — [BrowserStack acquires Bird Eats Bug](https://www.browserstack.com/press/browserstack-acquires-bird-eats-bug-launches-bug-capture-to-accelerate-its-test-platform-vision); BrowserStack; accessed 2026-10-13.
- **S035** — [Bug Capture FAQs](https://www.browserstack.com/docs/bug-capture/faqs); BrowserStack; accessed 2026-10-13.
- **S036** — [Session Replay videos](https://help.marker.io/en/articles/6673880-session-replay-videos); Marker.io; accessed 2026-10-13.
- **S037** — [Why logs and replays are linked instead of attached](https://help.marker.io/en/articles/14430683-why-are-console-logs-network-requests-and-replays-linked-instead-of-attached); Marker.io; accessed 2026-10-13.
- **S038** — [Sensitive Data Masking](https://help.marker.io/en/articles/9657817-sensitive-data-masking); Marker.io; accessed 2026-10-13.
- **S039** — [Data Privacy & Security Overview](https://help.marker.io/en/articles/12383990-data-privacy-security-overview); Marker.io; accessed 2026-10-13.
- **S040** — [Marker.io pricing](https://marker.io/pricing); Marker.io; accessed 2026-10-13.
- **S041** — [BugHerd features](https://bugherd.com/features); BugHerd; accessed 2026-10-13.
- **S042** — [BugHerd MCP](https://bugherd.com/feature/mcp); BugHerd; accessed 2026-10-13.
- **S043** — [Userback product](https://userback.io/); Userback; accessed 2026-10-13.
- **S044** — [Wispr Flow pricing](https://wisprflow.ai/pricing); Wispr; accessed 2026-10-13.
- **S045** — [What is Wispr Flow?](https://docs.wisprflow.ai/articles/2772472373-what-is-flow); Wispr; accessed 2026-10-13.
- **S046** — [Accuracy and known limitations](https://docs.wisprflow.ai/articles/4048537120-what-to-expect-from-flow-accuracy-and-known-limitations); Wispr; accessed 2026-10-13.
- **S047** — [Retry and recover a failed transcription](https://docs.wisprflow.ai/articles/2503460374-retry-failed-transcriptions); Wispr; accessed 2026-10-13.
- **S048** — [Wispr privacy](https://wisprflow.ai/privacy); Wispr; accessed 2026-10-13.
- **S049** — [Superwhisper](https://superwhisper.com/); Superwhisper; accessed 2026-10-13.
- **S050** — [Plans & pricing](https://superwhisper.com/docs/billing/plans); Superwhisper; accessed 2026-10-13.
- **S051** — [Quickstart](https://superwhisper.com/docs/get-started/quickstart); Superwhisper; accessed 2026-10-13.
- **S052** — [Built-in modes](https://superwhisper.com/docs/modes/built-in); Superwhisper; accessed 2026-10-13.
- **S053** — [Troubleshooting overview](https://superwhisper.com/docs/common-issues/troubleshooting); Superwhisper; accessed 2026-10-13.
- **S054** — [FluidVoice source](https://github.com/altic-dev/FluidVoice); altic-dev; accessed 2026-10-13.
- **S055** — [FluidVoice releases](https://github.com/altic-dev/FluidVoice/releases); altic-dev; accessed 2026-10-13.
- **S056** — [AirPods microphone switching hang, issue 709](https://github.com/altic-dev/FluidVoice/issues/709); FluidVoice user report; accessed 2026-10-13.
- **S057** — [VoiceInk](https://tryvoiceink.com/); VoiceInk; accessed 2026-10-13.
- **S058** — [MacWhisper](https://www.macwhisper.com/); MacWhisper / Good Snooze; accessed 2026-10-13.
- **S059** — [MacWhisper command-line tool](https://docs.macwhisper.com/article/57-macwhisper-command-line-tool); MacWhisper; accessed 2026-10-13.
- **S060** — [Keyboard shortcuts](https://macwhisper.helpscoutdocs.com/article/28-keyboard-shortcuts); MacWhisper; accessed 2026-10-13.
- **S061** — [Dictate messages and documents on Mac](https://support.apple.com/guide/mac-help/use-dictation-mh40584/mac); Apple; accessed 2026-10-13.
- **S062** — [Shottr](https://shottr.cc/); Shottr; accessed 2026-10-13.
- **S063** — [Shottr version notes](https://shottr.cc/newversion.html); Shottr; accessed 2026-10-13.
- **S064** — [Shottr FAQ](https://shottr.cc/kb/faq); Shottr; accessed 2026-10-13.
- **S065** — [Camtasia Snagit](https://www.techsmith.com/snagit/); TechSmith; accessed 2026-10-13.
- **S066** — [Snagit features](https://www.techsmith.com/snagit/features/); TechSmith; accessed 2026-10-13.
- **S067** — [Step capture tutorial](https://www.techsmith.com/learn/tutorials/snagit/step-capture/); TechSmith; accessed 2026-10-13.
- **S068** — [Snagit versus Camtasia](https://www.techsmith.com/blog/snagit-vs-camtasia/); TechSmith; accessed 2026-10-13.
- **S069** — [Presentify](https://presentifyapp.com/); Presentify; accessed 2026-10-13.
- **S070** — [Cursor highlighting with screen recorders](https://presentifyapp.com/use-cases/cursor-highlight-tool-for-screen-recording); Presentify; accessed 2026-10-13.
- **S071** — [ScreenBrush App Store listing](https://apps.apple.com/us/app/screenbrush/id1233965871?mt=12); Image Studio Production / Apple listing; accessed 2026-10-13.
- **S072** — [ShareX](https://getsharex.com/); ShareX project; accessed 2026-10-13.
- **S073** — [Region capture](https://getsharex.com/docs/region-capture.html); ShareX project; accessed 2026-10-13.
- **S074** — [Scribe pricing](https://scribe.com/pricing); Scribe; accessed 2026-10-13.
- **S075** — [Choosing the right Scribe Pro plan](https://support.scribehow.com/hc/en-us/articles/8813841761181-Choosing-the-Right-Scribe-Pro-Plan); Scribe; accessed 2026-10-13.
- **S076** — [Tango](https://www.tango.ai/); Tango; accessed 2026-10-13.
- **S077** — [Tango pricing](https://www.tango.ai/pricing); Tango; accessed 2026-10-13.
- **S078** — [Guidde](https://www.guidde.com/); Guidde; accessed 2026-10-13.
- **S079** — [Guidde Create pricing](https://www.guidde.com/pricing); Guidde; accessed 2026-10-13.
- **S080** — [Record an interactive demo](https://docs.arcade.software/kb/build/interactive-demo/record); Arcade; accessed 2026-10-13.
- **S081** — [Arcade pricing](https://www.arcade.software/pricing); Arcade; accessed 2026-10-13.
- **S082** — [How to record interactive demos](https://www.arcade.software/post/how-to-record-interactive-demos); Arcade; accessed 2026-10-13.
- **S083** — [Descript](https://www.descript.com/); Descript; accessed 2026-10-13.
- **S084** — [Descript pricing](https://www.descript.com/pricing); Descript; accessed 2026-10-13.
- **S085** — [Descript screen recorder](https://www.descript.com/screen-recording); Descript; accessed 2026-10-13.
- **S086** — [Descript download](https://www.descript.com/download); Descript; accessed 2026-10-13.
- **S087** — [Screenpipe repository](https://github.com/screenpipe/screenpipe); Screenpipe / Negentropy Labs; accessed 2026-10-13.
- **S088** — [Screenpipe privacy policy](https://screenpipe.com/privacy); Screenpipe / Negentropy Labs; accessed 2026-10-13.
- **S089** — [Transcription reconciliation silently stops, issue 3498](https://github.com/screenpipe/screenpipe/issues/3498); Screenpipe user pleasedodisturb; accessed 2026-10-13.
- **S090** — [Replay CLI commands](https://docs.replay.io/reference/replay-cli/commands); Replay; accessed 2026-10-13.
- **S091** — [Replay MCP and a React debugging example](https://www.replay.io/blog/replay-time-travelogue-how-replay-mcp-helped-find-a-react-bug-faster-than-dan-abramov-did); Replay; accessed 2026-10-13.
- **S092** — [Commenting on your media](https://help.frame.io/en/articles/9105251-commenting-on-your-media); Adobe / Frame.io; accessed 2026-10-13.
- **S093** — [Comments panel overview](https://help.frame.io/en/articles/9105278-comments-panel-overview); Adobe / Frame.io; accessed 2026-10-13.
- **S094** — [Review and approval](https://frame.io/features/review-and-approval); Adobe / Frame.io; accessed 2026-10-13.
- **S095** — [An honest review of Descript and why I cancelled](https://www.reddit.com/r/Descript/comments/17z5bkh/an_honest_review_of_descript_and_why_i_cancelled/); Reddit r/Descript participant; accessed 2026-10-13.
- **S096** — [Cap downloads and versions](https://cap.so/download/versions); Cap Software; accessed 2026-10-13.
- **S097** — [Recording videos FAQs, Testing Toolkit](https://www.browserstack.com/docs/testing-toolkit/bug-capture/faqs/recording-videos); BrowserStack; accessed 2026-10-13.
- **S098** — [Replay FAQs, Testing Toolkit](https://www.browserstack.com/docs/testing-toolkit/bug-capture/faqs/replays); BrowserStack; accessed 2026-10-13.
- **S099** — [MacWhisper has Automatic Speaker Recognition now](https://simonwillison.net/2025/Nov/18/macwhisper-speaker-recognition/); Simon Willison; accessed 2026-10-13.
