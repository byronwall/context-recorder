# Context Recorder

A macOS menu-bar app that records your screen while you use your apps. You mark the moments that need fixing, and afterwards you get a "control center" page with the video, the marks, a timeline of what was on screen, and your narration.

## Use

```bash
./scripts/build-app.sh
open build/ContextRecorder.app
```

| Hotkey | Action |
| --- | --- |
| ⌃⌥R | Start / stop recording |
| ⌃⌥M | Mark this moment (context saved now, a frame is taken from the video later) |
| ⌃⌥S | Region screenshot: drag a rectangle (click = full screen, Esc = cancel) plus context |

A floating control panel (shown at launch and whenever you open the app again) has the same actions, a live timer and the mark count, because the menu-bar item can be hidden when the bar is crowded. While recording, the menu bar shows `● 3:42 · 5` (elapsed time · number of marks). Use the menu's **Record Microphone** item to turn narration on or off. Turn it off for silent sessions: you still get video, screenshots and context.

When you stop, the app transcribes your narration (if there is any), writes markdown and opens `viewer.html` for the session.

First run asks for **Screen Recording**, **Microphone** and (the first time you mark in Chrome) **Automation → Chrome** permissions. The build is signed with a stable local identity, so macOS keeps these permissions across rebuilds.

## Chrome extension (page context)

`extension/` is an unpacked MV3 extension. It sends page context to the app over `ws://127.0.0.1:47823`. Your web apps don't need any changes.

1. Open `chrome://extensions`, turn on **Developer mode**, click **Load unpacked** and pick the `extension/` folder.
2. Reload any tabs that were already open.
3. The panel shows **Chrome ● connected** once the extension finds the running app. It retries every 30 s, so the app and Chrome can start in either order.

What it records:

- **As it happens** (`browser.jsonl`): clicks (selector, text, React/Vue component chain), SPA navigation, `console.error`/`console.warn`, uncaught exceptions and unhandled promise rejections, and failed or slow `fetch`/XHR requests (status, timing and the first 800 characters of an error response body).
- **On each mark when Chrome is in front** (`mark.browser`): the element under the mouse, the focused element, the selected text, the viewport and window position, and the page's last 40 events.

Input values are never recorded, only which field changed. The app accepts connections only from `chrome-extension://` origins, so web pages can't connect to it.

## Session output

`~/Movies/ContextRecorder/<timestamp>/`

| File | What it holds |
| --- | --- |
| `recording.mp4` | Main display at 15 fps, ≤1920 px wide, plus mic audio when enabled |
| `marks.jsonl` | One line per mark: time offset, kind, context (app, window, Chrome URL and title, mouse position) |
| `activity.jsonl` | A new line whenever the front app, window title or Chrome tab changes |
| `browser.jsonl` | Page events from the Chrome extension |
| `screenshots/` | Region screenshots |
| `frames/` | Full-screen video frame for every mark |
| `transcript.json` | Parakeet output, with timestamps for every sentence and token |
| `marks/NNN.md`, `session.md` | Markdown for each mark, with the narration window (20 s before and 10 s after the mark; ⚑ shows where the mark landed) |
| `session.json` | Everything above in one file, for the viewer and exporters |
| `viewer.html` | The control center. Opens straight from disk, no server needed |

To re-run processing, for example with a different narration window:

```bash
python3 scripts/process_session.py ~/Movies/ContextRecorder/<session> --before 30 --after 5
```

Delete `transcript.json` first if you want the audio transcribed again.

## Layout

- `Sources/ContextRecorder/`: Swift app. `Recorder` (ScreenCaptureKit and AVAssetWriter), `HotKeys` (Carbon), `ContextProbe` (front app, window, Chrome tab), `ActivityLog`, `Session`.
- `scripts/process_session.py`: post-processing (ffmpeg, parakeet-mlx). Standard library only.
- `scripts/viewer.html`: viewer template. The session data gets embedded in it.

Requires the Command Line Tools (Xcode isn't needed), `ffmpeg`, and `parakeet-mlx` on the login-shell `PATH`.

## Next

- Map a region screenshot back to the DOM elements inside it, using the `window` and `viewport` values in the snapshot.
- Export marks to Product Grid (`pgm image add` plus a context node).
