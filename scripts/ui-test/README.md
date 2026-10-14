# Context Recorder UI test harness

Run these commands from the repository root. All generated files go under the gitignored `tmp/ui-test/` folder.

```sh
python3 scripts/ui-test/harness.py prepare
python3 scripts/ui-test/harness.py launch --session 2026-10-13_00-57-10 --tab marks --mark 1
python3 scripts/ui-test/harness.py stop
```

`prepare` rebuilds the debug executable and replaces only the fixture directory created by this harness. It copies these sessions from `~/Movies/ContextRecorder`: `2026-10-13_00-57-10`, `2026-10-13_20-48-53`, and two sessions with empty transcripts, `2026-10-12_22-42-47` and `2026-10-12_22-51-23`. The real library is read-only input. The harness rejects symlinks and refuses to replace an unmarked fixture directory.

The app opens the full fixture library. `--session` selects the initial session. `--tab` accepts `marks`, `transcript`, `page`, or `activity`. `--recording-fixture` selects a fixture that the app treats as the active recording for protection checks.

For direct SwiftPM launch and development flags, use `run`:

```sh
python3 scripts/ui-test/harness.py run --session 2026-10-13_00-57-10 --tab transcript --mark 1
python3 scripts/ui-test/harness.py run --session 2026-10-13_00-57-10 --recording-fixture 2026-10-13_00-57-10
python3 scripts/ui-test/harness.py run --session 2026-10-13_00-57-10 --export "$PWD/tmp/ui-test/project"
python3 scripts/ui-test/harness.py run --session 2026-10-13_20-48-53 --timeline-hover 0.5
python3 scripts/ui-test/harness.py run --session 2026-10-13_20-48-53 --window-width 980 --timeline-hover 0
python3 scripts/ui-test/harness.py run --session 2026-10-13_20-48-53 --window-width 980 --timeline-hover 1
python3 scripts/ui-test/harness.py run --capture --session 2026-10-13_20-48-53
```

`run` calls `swift run ContextRecorder --library <fixtures-root>` and passes `--session`, `--tab`, `--recording-fixture`, `--mark`, `--export`, `--timeline-hover`, `--window-width`, and `--capture`. Width must be at least 980 points. The timeline flag opens the hover card at a deterministic fraction, including the `0` and `1` edges. It checks the hover-card renderer; it does not simulate a mouse move.

For non-UI checks, run:

```sh
python3 scripts/ui-test/harness.py check
```

This checks exact transcript sentence starts, including a 0.05-second sentence. It then requests 60 preview frames from the first fixture and requires more than one distinct frame.

For GUI automation, use `launch`. It runs the debug executable from a small app bundle with bundle ID `com.byronwall.ContextRecorder.UITest` and display name **Context Recorder UI Test**. The CUA driver binds to this bundle by its full path under the supplied repository root. The harness records the launched PID and start time. `stop` verifies both before signaling, and checks again before force termination. It never searches for or kills processes by app name. If the test app has exited, `stop` removes the stale PID file.

Check that `launch` succeeds before binding CUA. If a sandbox blocks `ps`, rerun with approved process access. The harness stops its child when identity checks fail. The test bundle exits without `--library`, so an argument-free reopen cannot use the real library. Each launch rechecks fixture and bundle paths for symlinks.

Load the reusable CUA driver from the CUA REPL. Pass the REPL's `cua`, `nodeRepl`, Node `fs`, and repository root:

```js
let fs = await import("node:fs/promises");
let repositoryRoot = "/path/to/context-recorder";
let source = await fs.readFile(`${repositoryRoot}/scripts/ui-test/cua.js`, "utf8");
await eval(source);
await crUiTest.start(cua, nodeRepl, fs, repositoryRoot);
await crUiTest.dumpLabels();
```

The parser reads numbered rows, buttons, radio buttons, text fields, standard windows, sheets, Quick Look windows, and menu actions from the plain-text AX tree. It ignores OCR text. It checks the app name and main standard window before typing. Before typing, it reads fresh AX state and checks the focused text field. It raises the main window only when AX exposes the `Raise` secondary action. Screenshot capture checks the app identity and supports a sheet or Quick Look window.

`runPR08({...})` checks transcript seeking. `runPR09({...})` walks Return and context-menu rename cancel/save/empty, Command/Shift selection, trash confirmation, and recording protection. `runPR10({...})` checks inspector tabs and counts, folding across J/K, and Quick Look. Call `crUiTest.dumpLabels()` first, then pass the current labels. The driver saves screenshots into `tmp/ui-test/`.

For sidebar protection checks, launch with `--recording-fixture 2026-10-13_00-57-10`.
Run transcript and sidebar checks with the 20:48 session selected. Select the 00:57 session before inspector checks.

Example calls (check the labels with `dumpLabels()`):

```js
await crUiTest.runPR08({
  transcriptAfterShort: /Um looking through the current context recorder app/i,
});
await crUiTest.runPR09({
  rowA: /20:48/,
  rowB: /00:57/,
  rowC: /22:42/,
  recordingRow: /Recording…/,
});
await crUiTest.runPR10({
  tabs: [/Marks/, /Transcript/, /Page/, /Activity/],
  foldSection: /What was said/,
  image: /^Mark 1 image$/,
  // Defaults to /^Shot 1 at / when omitted.
  mark: /^Shot 1 at /,
});
await crUiTest.runPR11({
  timelineHoverFraction: 0.5, // set this to 0 or 1 to inspect an edge card
  pin: /^Shot 3 at/,
});
```

To test ruler clicks and drags, pass `seekPoint: [x, y]` and `drag: { from: [x, y], to: [x, y] }`. Read each point from a fresh screenshot. The driver refreshes the screenshot immediately before each gesture to restore coordinate mapping after AX reads. Playback must stay paused throughout the check.

## PR #8–11 review checklist

Record each item as pass, fail, or not covered. Keep a screenshot for each group. Use a fresh `prepare` before destructive sidebar or note actions.

- [ ] **PR #8, transcript and capture** (`PR-08-transcript-seek.png`): click a transcript sentence after a short sentence and confirm the Now strip sentence and playhead time match. Run the capture check below before real capture steps. If permission is unavailable, skip real capture checks. If granted, record with Sessions already open. Check that Sessions appears in the video and a region shot. Repeat with Sessions opened partway through recording. Check that the control panel and region overlay stay out of both captures.
- [ ] **PR #9, sidebar** (`PR-09-rename-save.png`, `PR-09-selection-summary.png`, `PR-09-single-trash-confirmation.png`, `PR-09-trash-confirmation.png`, `PR-09-recording-protection.png`): test Return and context-menu rename; cancel, empty name, title, and subtitle. Select sessions with Command and Shift. Check the selection summary and trash confirmation. Confirm the active recording cannot be trashed. Check narration badges and sidebar shortcuts while typing in a field.
- [ ] **PR #10, inspector** (`PR-10-inspector-folded.png`, `PR-10-quick-look.png`): switch inspector tabs and check counts and filters. Fold sections, move with J/K, and confirm folded state persists. Open Quick Look and inspect its inset and main image. Add and save a note, review the mark, and delete it. Check light and dark appearance.
- [ ] **PR #11, timeline** (`PR-11-simulated-hover-050.png`, `PR-11-ruler-pins.png`, `PR-11-timeline-click.png`, `PR-11-timeline-drag.png`): use `--timeline-hover 0.5` to inspect the real hover-card renderer at a deterministic point. This does not test pointer movement. Click a ruler pin and confirm seek. Drag the ruler and confirm seek. Check playhead and pin visibility across the ruler.

Check Screen Recording permission without prompting. Run the unique debug bundle executable, not the unbundled SwiftPM process:

```sh
"$PWD/tmp/ui-test/Context Recorder UI Test.app/Contents/MacOS/ContextRecorder" \
  --library "$PWD/tmp/ui-test/fixtures" --capture-check
```

If the result says `unavailable`, skip real capture checks. The check does not request permission.

macOS can show an additional capture prompt even when preflight reports permission. If it does, stop recording and mark capture checks as not verified. Preflight alone does not prove capture works.

When permission is granted, launch the isolated capture mode with the copied fixture library:

```sh
python3 scripts/ui-test/harness.py launch --capture --session 2026-10-13_20-48-53
```

Use the bound **Context Recorder UI Test** app's ControlPanel buttons: Start Recording, Region, and Stop. Do not send Ctrl-Alt hotkeys. The installed app owns those shortcuts. Capture mode uses the production recording flow with microphone input disabled. It writes video and region output only under `tmp/ui-test/fixtures/capture-output/<timestamp>`. Stop the test app with the harness command after the capture checks:

```sh
python3 scripts/ui-test/harness.py stop
```

Launch a specific appearance with, for example:

```sh
python3 scripts/ui-test/harness.py launch --session 2026-10-13_00-57-10 --appearance dark
```

Use `2026-10-13_20-48-53` for the example transcript sentence above:

```sh
python3 scripts/ui-test/harness.py launch --session 2026-10-13_20-48-53 --tab transcript
```

Open the simulated timeline hover card for a screenshot with:

```sh
python3 scripts/ui-test/harness.py launch --session 2026-10-13_20-48-53 --timeline-hover 0.5
python3 scripts/ui-test/harness.py stop
python3 scripts/ui-test/harness.py launch --session 2026-10-13_20-48-53 --window-width 980 --timeline-hover 0
python3 scripts/ui-test/harness.py stop
python3 scripts/ui-test/harness.py launch --session 2026-10-13_20-48-53 --window-width 980 --timeline-hover 1
```

For edge cards in a narrow window, use `--timeline-hover 0` or `--timeline-hover 1` with `--window-width 980`. `runPR11` checks a selected ruler pin against Playhead Details. It can also click and drag the timeline when you provide points measured from a fresh screenshot. Those gestures assert that the playhead changed; inspect the screenshot to judge pointer placement and preview details.

Screenshot files are temporary and must not be committed. Use the CUA REPL driver for all computer UI actions.
