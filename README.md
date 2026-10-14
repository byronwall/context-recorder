# Context Recorder

A macOS menu-bar app that records your screen while you use your apps. You mark the moments that need fixing, and afterwards you get a "control center" page with the video, the marks, a timeline of what was on screen, and your narration.

## Use

```bash
./scripts/build-app.sh
open "/Applications/Context Recorder.app"
```

The build script also installs the app to `/Applications`, so you can launch it from Spotlight or Raycast. Set `INSTALL_DIR=` (empty) to skip that step, or point it somewhere else such as `~/Applications`.

| Hotkey | Action |
| --- | --- |
| ⌃⌥R | Start / stop recording |
| ⌃⌥M | Mark this moment (context saved now, a frame is taken from the video later) |
| ⌃⌥S | Region screenshot: drag a rectangle (click = full screen, Esc = cancel) plus context |

A floating control panel (shown at launch and whenever you open the app again) has the same actions, a live timer and the mark count, because the menu-bar item can be hidden when the bar is crowded. While recording, the menu bar shows a red record dot with `3:42  ⚑5` (elapsed time and number of marks). Use the menu's **Record Microphone** item to turn narration on or off. Turn it off for silent sessions: you still get video, screenshots and context.

When you stop, the app transcribes your narration (if there is any), writes markdown and opens the session in the **Sessions** window.

## Sessions window

A native library of every recording (menu bar → **Sessions…**, or the play button on the control panel). While it's open the app gets a Dock icon and menus; close it and the app goes back to living in the menu bar.

- **Sidebar:** sessions by day, with thumbnail, length, mark count, a waveform when the session has narration, and the apps you used. Drop a session folder (or a folder of sessions) on the window, or use **File → Open Session Folder…**, to add one from elsewhere.
  - **Rename** (right-click, or Return on the selected session) gives a session a name. It's kept in `session-info.json`, so the folder keeps its timestamp; clear the name to go back to the date.
  - **Move to Trash** (right-click, or ⌘⌫) works on one session or several: ⌘- or ⇧-click to select more. Trashed sessions can be put back from the Trash. The session being recorded can't be trashed.
- **Stage:** the recording, with floating playback controls.
- **Timeline:** active app, page events and narration on one time axis, with the marks pinned on the time ruler. Click or drag to seek; hover for a preview of the frame at that moment plus the app, window, narration and any mark or page event there.
- **Now strip:** the app, window and URL at the playhead, and the sentence being spoken.
- **Inspector:** marks (with the full page context for the selected one), transcript, page events and activity. **Copy as Markdown** is per mark and for the whole session (toolbar).

| Key | Action |
| --- | --- |
| Space | Play / pause |
| J / K | Next / previous mark |
| → / ← | Skip 5 s |
| M | Add a mark at the playhead |
| S | Capture a region of the current frame (drag; click for the whole frame; Esc cancels) |

### Marking up a recording afterwards

You can mark things you notice while reviewing, not just while recording. **M** (or the flag in the playback controls) adds a mark at the playhead. **S** (or the viewfinder) pauses and lets you drag a box on the video; the region is cut from the frame at full resolution. Every mark has a **Note** field, and a note becomes the mark's title.

Review marks carry what the recording knows at that moment: the app, window and URL from the activity log, the narration around it, and page events from the 30 s before. There's no live Chrome snapshot (element under the pointer, saved page). They're stored in `marks.jsonl` with `"source": "review"` and the session is re-processed, so Markdown, Copy as Markdown and export treat them like any other mark. Review marks can be deleted; marks made while recording can't.

The window updates on its own when a session is re-processed.

### Export to Product Grid

**Export to Product Grid** (toolbar) sends a session's marks to the grid stored in a project folder: `<folder>/pgm/data`, the folder `pgm viewer` uses by default, so the grid lives next to the code it describes. Exports only ever use `pgm --local`; nothing goes to a remote server.

- Pick a recent project folder (or **Add Folder…**), a project in its grid (or **New Project…**) and optionally a top-level node to put the session under.
- The session becomes one node (summary and narration) with one child per mark: context is the mark's Markdown, images are its screenshot and full frame.
- Exporting again updates the same nodes: their context and the images this app added are replaced, and edits made in the grid (title, status, other images) are kept. Nodes deleted in the grid are recreated. The mapping is kept in `<session>/exports/pgm.json`.
- **Open Grid** runs `pgm viewer` on the folder.

Requires the `pgm` CLI (`npm install -g @byronwallrus/product-grid-cli`). `viewer.html` is still written to every session folder as a portable copy (**Session → Open in Browser**).

To work on the window without touching an installed copy of the app, run the debug build on a folder of sessions: `swift run ContextRecorder --library tmp/` (add `--mark 2` to open a mark, or `--export <project-folder>` to open the export sheet; `--export-run` also starts the export). This skips recording, hotkeys and permission prompts. Set `CR_APPEARANCE=dark` to check dark mode.

First run asks for **Screen Recording**, **Microphone** and (the first time you mark in Chrome) **Automation → Chrome** permissions. The build is signed with a stable local identity, so macOS keeps these permissions across rebuilds.

## Chrome extension (page context)

`extension/` is an unpacked MV3 extension. It sends page context to the app over `ws://127.0.0.1:47823`. Your web apps don't need any changes.

1. Open `chrome://extensions`, turn on **Developer mode**, click **Load unpacked** and pick the `extension/` folder.
2. Reload any tabs that were already open.
3. The panel shows **Chrome ● connected** once the extension finds the running app. It retries every 30 s, so the app and Chrome can start in either order.

What it records:

- **As it happens** (`browser.jsonl`): clicks (selector, text, React/Vue component chain), SPA navigation, `console.error`/`console.warn`, uncaught exceptions and unhandled promise rejections, and failed or slow `fetch`/XHR requests (status, timing and the first 800 characters of an error response body).
- **On each mark when Chrome is in front** (`mark.browser`):
  - the element under the mouse and the focused element: selector, text, component chain, the nearest named component's props (shallow), and the **source location** when the page is a dev build (see below)
  - the selected text, the viewport and window position, and the page's last 40 events
  - **the saved page** (`pages/<id>.mhtml`): the DOM, styles and images as they were at the mark. Open it in Chrome and inspect it with DevTools.
  - for region screenshots: **the elements inside the region** (`browser.region`), each with selector, text and source

Source locations come from whatever the dev build exposes, in this order:

1. React ≤ 18: `_debugSource`, the exact JSX file and line.
2. Svelte: `__svelte_meta`.
3. Vue 3: the component's `__file`.
4. Source attributes added by build plugins: `data-inspector-relative-path`/`data-inspector-line` (code-inspector), `data-source-loc`, `data-locatorjs`. Use one of these for Solid.
5. React 19: the `_debugStack` frame. The file is right, but the line refers to the transformed output.

Production builds have none of these, so you get selectors and readable component names only.

The region is mapped to page coordinates using the pointer position, which the app and the page both know at the moment of the keypress. If the pointer wasn't over the page, it falls back to the window geometry. Browser zoom is taken into account.

Input values are never recorded, only which field changed. The app accepts connections only from `chrome-extension://` origins, so web pages can't connect to it.

## Session output

`~/Movies/ContextRecorder/<timestamp>/`

| File | What it holds |
| --- | --- |
| `recording.mp4` | Main display at 15 fps, ≤1920 px wide, plus mic audio when enabled |
| `marks.jsonl` | One line per mark: time offset, kind, context (app, window, Chrome URL and title, mouse position) |
| `activity.jsonl` | A new line whenever the front app, window title or Chrome tab changes |
| `browser.jsonl` | Page events from the Chrome extension |
| `pages/*.mhtml` | Saved page for each mark made in Chrome |
| `screenshots/` | Region screenshots |
| `frames/` | Full-screen video frame for every mark |
| `transcript.json` | Parakeet output, with timestamps for every sentence and token |
| `marks/NNN.md`, `session.md` | Markdown for each mark, with the narration window (20 s before and 10 s after the mark; ⚑ shows where the mark landed) |
| `session.json` | Everything above in one file, for the viewer and exporters |
| `edits.json` | Only in edited sessions: the kept ranges of the recording, in play order (see below) |
| `viewer.html` | Portable web copy of the session. Opens straight from disk, no server needed |

### Edited sessions

A session with an `edits.json` plays only its kept ranges:

```json
{"segments": [{"source": ".", "start": 10, "end": 60}, {"source": ".", "start": 100, "end": 200}]}
```

Processing writes `session.json`, the Markdown and the export data in *edited* time: marks, activity, page events and the transcript move with the video, and anything inside a removed range drops out (cut marks are kept under `hiddenMarks`). Each mark keeps `sourceOffsetSeconds`, and Markdown video references point at the original recording and time. `recording.mp4` and the raw `.jsonl` files are never changed; marks added while reviewing an edited session are stored at their original time. Delete `edits.json` and re-process to get the session back as recorded.

The time mapping is tested by `python3 -m unittest scripts/test_process_session.py` and, in the app, `swift run ContextRecorder --library <session> --self-test edits`; both read the cases in `scripts/fixtures/edit-cases.json`.

To re-run processing, for example with a different narration window:

```bash
python3 scripts/process_session.py ~/Movies/ContextRecorder/<session> --before 30 --after 5
```

Delete `transcript.json` first if you want the audio transcribed again.

## Layout

- `Sources/ContextRecorder/`: Swift app. `Recorder` (ScreenCaptureKit and AVAssetWriter), `HotKeys` (Carbon), `ContextProbe` (front app, window, Chrome tab), `ActivityLog`, `Session`.
- `Sources/ContextRecorder/Library/`: the Sessions window (SwiftUI, macOS 26). `SessionLibrary` scans the folders, `SessionModel` owns one open session and its player, `SessionData` decodes `session.json`, `MarkText` builds titles and the Markdown.
- `scripts/process_session.py`: post-processing (ffmpeg, parakeet-mlx). Standard library only.
- `scripts/viewer.html`: viewer template. The session data gets embedded in it.
- `scripts/make-icon.swift`: draws the app icon and writes `Resources/AppIcon.icns` (`swift scripts/make-icon.swift`).

Requires macOS 26, the Command Line Tools (Xcode isn't needed), `ffmpeg`, and `parakeet-mlx` on the login-shell `PATH`.

## Next

- rrweb DOM recording, to replay the DOM over time alongside the video.
