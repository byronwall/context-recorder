// Load in the CUA REPL, then call crUiTest.start(cua, nodeRepl, fs, repositoryRoot).
// This parser reads the plain-text accessibility tree and ignores OCR text.
globalThis.crUiTest = (() => {
  const APP_NAME = "Context Recorder UI Test";
  const CONTROL = /^(standard window|radio button|row|button|text field|window|sheet)\b/;
  let app;
  let repl;
  let fsApi;
  let screenshotDir;
  let axText = "";

  function parseAX(value) {
    if (typeof value !== "string") throw new Error("getAXState did not return its plain-text accessibility tree.");
    const controls = [];
    for (const line of value.split(/\r?\n/)) {
      const match = line.match(/^(\s*)(\d+) (.+)$/);
      if (!match) continue;
      const [, indent, rawIndex, body] = match;
      const role = body.match(CONTROL)?.[1];
      const isMenuAction = !role && /\bID: menuAction:/.test(body);
      if (!role && !isMenuAction) continue;
      let label = body;
      if (role) label = label.replace(new RegExp(`^${role}\\b\\s*`), "");
      if (isMenuAction) label = label.replace(/,?\s*ID: menuAction:.*$/, "");
      label = label.replace(/\s*\([^)]*\)\s*/g, " ").trim();
      const description = label.match(/\bDescription: ([^,]+)/);
      if (description) label = description[1].trim();
      controls.push({ index: Number(rawIndex), depth: indent.length, role: role ?? "menuAction", label, line: body });
    }
    const focused = value.match(/^The focused UI element is (\d+) (.+)$/m);
    return { text: value, controls, focusedIndex: focused ? Number(focused[1]) : null };
  }

  function transcriptPosition(value, rowLabel) {
    const timeAndSentence = rowLabel.match(/^(\d+:\d{2}),\s*(.+)$/);
    if (!timeAndSentence) throw new Error(`Transcript row has no playhead time: ${rowLabel}`);
    const [, expectedTime, expectedSentence] = timeAndSentence;
    const said = value.match(/^\s*\d+ text .*?\bSaid:\s*(.+)$/m)?.[1]?.trim();
    const playhead = value.match(/^\s*\d+ unknown Description: Playhead, Details: (\d+:\d{2})\b/m)?.[1];
    const normalize = text => text.replace(/\s+/g, " ").trim().toLocaleLowerCase();
    return { expectedTime, expectedSentence, said, playhead,
      matches: Boolean(said) && normalize(said) === normalize(expectedSentence) && playhead === expectedTime };
  }

  function playheadTime(value = axText) {
    return value.match(/^\s*\d+ unknown Description: Playhead, Details: (\d+:\d{2})\b/m)?.[1] ?? null;
  }

  function isBoundApp(value) {
    return new RegExp(`^Window: .+, App: ${APP_NAME.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\.?$`, "m").test(value);
  }

  function selfCheck() {
    const sample = `Window: "Oct 13, 2026 · 20:48", App: Context Recorder UI Test.\n0 standard window Oct 13, 2026 · 20:48 – 3:44 · 6 marks · 2 apps · Narrated, Secondary Actions: Raise\n\t5 row (selected) 3:44, 20:48, 6 marks, Narrated\n\t63 button (selected) Marks, 6\n\t64 button Transcript, 50\n\t77 text field (settable) Description: Session name, Value: UI test name, Placeholder: Name\n\t140 Rename…, ID: menuAction:\nThe focused UI element is 77 text field (settable) Description: Session name, Value: UI test name`;
    const parsed = parseAX(sample);
    if (parsed.controls.length !== 6 || parsed.focusedIndex !== 77) throw new Error("AX parser self-check failed.");
    if (!isBoundApp(sample)) throw new Error("AX app identity self-check failed.");
    if (!parsed.controls.some(node => node.role === "button" && /Marks, 6/.test(node.label))) throw new Error("AX button label self-check failed.");
    if (!parsed.controls.some(node => node.role === "text field" && node.label === "Session name")) throw new Error("AX text field self-check failed.");
    if (!parsed.controls.some(node => node.role === "menuAction" && /Rename/.test(node.label))) throw new Error("AX menu action self-check failed.");
    const surfaces = parseAX(`Window: "Confirm", App: ${APP_NAME}.\n0 sheet Description: alert, Secondary Actions: Raise\nWindow: "Quick Look", App: ${APP_NAME}.\n0 window Quick Look, Secondary Actions: Raise`);
    if (!surfaces.controls.some(node => node.role === "sheet") || !surfaces.controls.some(node => node.role === "window")) {
      throw new Error("AX sheet and Quick Look window self-check failed.");
    }
    const position = transcriptPosition(`0 row 0:43, Maybe what I want is like a multi-select.\n1 text Description: Now strip, Said: Maybe what I want is like a multi-select.\n2 unknown Description: Playhead, Details: 0:43`, "0:43, Maybe what I want is like a multi-select.");
    if (!position.matches) {
      throw new Error("Transcript seek state self-check failed.");
    }
    return true;
  }

  function controls() { return parseAX(axText).controls; }
  function treeText() { return axText; }
  function focusedIndex() { return parseAX(axText).focusedIndex; }

  async function fresh() {
    axText = await app.getAXState({ emit: false, disableDiffing: true });
    parseAX(axText);
    return axText;
  }

  function find(pattern, rolePattern) {
    const labelPattern = pattern instanceof RegExp ? pattern : new RegExp(pattern, "i");
    const role = rolePattern && (rolePattern instanceof RegExp ? rolePattern : new RegExp(rolePattern, "i"));
    return controls().find(node => labelPattern.test(node.label) && (!role || role.test(node.role)));
  }

  function requireNode(pattern, rolePattern) {
    const node = find(pattern, rolePattern);
    if (!node) throw new Error(`No accessible control matched ${pattern}. Labeled controls:\n${dumpText()}`);
    return node;
  }

  function dumpText() {
    return controls().map(node => `[${node.index}] ${node.role}: ${node.label}`).join("\n");
  }

  function mainWindow() {
    assertBoundApp();
    const candidate = controls().find(node => node.role === "standard window" && node.depth === 0 && !/quick ?look|sheet/i.test(node.label));
    if (!candidate) throw new Error("No main standard window is exposed in the current AX tree.");
    return candidate;
  }

  function assertBoundApp() {
    if (!isBoundApp(axText)) {
      throw new Error(`CUA is not focused on ${APP_NAME}.`);
    }
  }

  async function focusTextField(fieldPattern) {
    await fresh();
    let field = requireNode(fieldPattern, /^text field$/i);
    const window = mainWindow();
    if (focusedIndex() !== field.index) {
      await app.click(field.index);
      await fresh();
      mainWindow();
      field = requireNode(fieldPattern, /^text field$/i);
    }
    if (focusedIndex() !== field.index) {
      const raisedWindow = mainWindow();
      if (/Secondary Actions:.*\bRaise\b/i.test(raisedWindow.line)) {
        await app.performSecondaryAction(raisedWindow.index, "Raise");
        await fresh();
        mainWindow();
        field = requireNode(fieldPattern, /^text field$/i);
        if (focusedIndex() !== field.index) {
          await app.click(field.index);
          await fresh();
          mainWindow();
          field = requireNode(fieldPattern, /^text field$/i);
        }
      }
    }
    if (focusedIndex() !== field.index) {
      throw new Error(`Expected editable text field ${field.index} to have focus; focused index is ${focusedIndex() ?? "missing"}.`);
    }
  }

  async function start(cua, nodeRepl, fs, repositoryRoot) {
    if (!repositoryRoot) throw new Error("Pass repositoryRoot to keep screenshot paths independent of the REPL working directory.");
    selfCheck();
    repl = nodeRepl;
    fsApi = fs;
    screenshotDir = `${repositoryRoot.replace(/\/$/, "")}/tmp/ui-test`;
    const launch = JSON.parse(await fs.readFile(`${screenshotDir}/ui-test.pid`, "utf8"));
    if (!Number.isInteger(launch.pid) || launch.pid <= 0 || !launch.started) {
      throw new Error("Launch the fixture app with harness.py before binding CUA.");
    }
    app = await cua.getApp(`${repositoryRoot.replace(/\/$/, "")}/tmp/ui-test/Context Recorder UI Test.app`);
    await fresh();
    mainWindow();
    repl.write(`Bound to ${APP_NAME} at ${repositoryRoot}; parsed ${controls().length} labeled controls.`);
    return app;
  }

  async function click(pattern, options = {}, rolePattern) {
    await fresh();
    const target = requireNode(pattern, rolePattern);
    await app.click(target.index, options);
    await fresh();
    return target;
  }

  async function key(value) {
    await fresh();
    await app.pressKey(value);
    await fresh();
  }

  async function type(value, fieldPattern = /./) {
    await fresh();
    await focusTextField(fieldPattern);
    await app.typeText(value);
    await fresh();
  }

  function assertVisible(pattern, message = `Expected visible control ${pattern}`) {
    if (!find(pattern)) throw new Error(`${message}. Labeled controls:\n${dumpText()}`);
  }

  async function screenshot(name) {
    await fresh();
    assertBoundApp();
    await fsApi.mkdir(screenshotDir, { recursive: true });
    const bytes = await app.getScreenshot({ emit: false });
    const path = `${screenshotDir}/${name}`;
    await fsApi.writeFile(path, bytes);
    repl.write(`Saved ${path}`);
    return path;
  }

  async function clickSession(pattern, options = {}) {
    return click(pattern, options, /^row$/i);
  }

  async function renameWithReturn(sessionLabel, newName, mode = "save") {
    await clickSession(sessionLabel);
    await key("Return");
    await fresh();
    const fieldPattern = /session name|name/i;
    await focusTextField(fieldPattern);
    if (mode === "empty") {
      await app.pressKey("super+a");
      await app.pressKey("BackSpace");
      await fresh();
      await focusTextField(fieldPattern);
      await app.pressKey("Return");
    } else {
      await app.pressKey("super+a");
      await fresh();
      await focusTextField(fieldPattern);
      await app.typeText(newName);
      await fresh();
      await focusTextField(fieldPattern);
      await app.pressKey(mode === "cancel" ? "Escape" : "Return");
    }
    await fresh();
    return treeText();
  }

  async function contextRename(sessionLabel) {
    await fresh();
    const row = requireNode(sessionLabel, /^row$/i);
    await app.click(row.index, { mouseButton: "right" });
    await fresh();
    await click(/rename/i, {}, /^menuAction$/i);
    await fresh();
    requireNode(/session name|name/i, /^text field$/i);
  }

  async function transcriptSeek(sentenceAfterShort) {
    await click(/Transcript/i, {}, /^(button|radio button)$/i);
    await fresh();
    const sentence = requireNode(sentenceAfterShort, /^row$/i);
    await app.click(sentence.index);
    await fresh();
    const position = transcriptPosition(axText, sentence.label);
    if (!position.matches) {
      throw new Error(`Transcript click did not update both Now strip and playhead. Expected ${position.expectedTime} / ${position.expectedSentence}; got ${position.playhead ?? "no time"} / ${position.said ?? "no sentence"}.`);
    }
    await screenshot("PR-08-transcript-seek.png");
  }

  async function multiSelectionAndTrash(rowA, rowB, rowC) {
    await clickSession(rowA);
    await clickSession(rowB, { key: "super" });
    await clickSession(rowC, { key: "shift" });
    const selectedRows = controls().filter(node => node.role === "row" && /\(selected\)/i.test(node.line));
    if (selectedRows.length < 2) throw new Error("Command/Shift selection did not expose multiple selected rows.");
    await screenshot("PR-09-selection-summary.png");
    await key("super+BackSpace");
    assertVisible(/trash|delete/i, "Trash confirmation did not open");
    await screenshot("PR-09-trash-confirmation.png");
    await key("Escape");
  }

  async function singleSelectionTrash(row) {
    await clickSession(row);
    await key("super+BackSpace");
    if (!controls().some(node => node.role === "sheet")) throw new Error("Single-session trash did not open its confirmation sheet.");
    await screenshot("PR-09-single-trash-confirmation.png");
    await click(/Cancel/i, {}, /^button$/i);
    if (controls().some(node => node.role === "sheet")) throw new Error("AX Cancel did not close the single-session trash confirmation.");
  }

  async function recordingProtection(recordingRow) {
    await clickSession(recordingRow);
    await key("super+BackSpace");
    if (/confirm.*trash|move .*trash/i.test(dumpText())) throw new Error("Active recording opened a trash confirmation.");
    await screenshot("PR-09-recording-protection.png");
  }

  async function runPR08(options) {
    await transcriptSeek(options.transcriptAfterShort);
  }

  async function runPR09(options) {
    const afterCancel = await renameWithReturn(options.rowA, "Cancelled rename", "cancel");
    if (/Cancelled rename/i.test(afterCancel)) throw new Error("Escape did not cancel the rename.");
    await renameWithReturn(options.rowA, "UI test rename", "save");
    assertVisible(/UI test rename/);
    await screenshot("PR-09-rename-save.png");
    const afterEmpty = await renameWithReturn(/UI test rename/, "ignored", "empty");
    if (/UI test rename/i.test(afterEmpty)) throw new Error("Saving an empty name did not clear the session title.");
    await contextRename(options.rowB);
    await key("Escape");
    await singleSelectionTrash(options.rowA);
    await multiSelectionAndTrash(options.rowA, options.rowB, options.rowC);
    await recordingProtection(options.recordingRow);
  }

  async function inspectorTabs(patterns) {
    for (const pattern of patterns) {
      await click(pattern, {}, /^(button|radio button)$/i);
      const tab = find(pattern, /^(button|radio button)$/i);
      if (!tab || !/\b\d+\b/.test(tab.label)) throw new Error(`Inspector tab does not expose an item count: ${pattern}`);
    }
  }

  async function foldAndNavigate(sectionPattern) {
    let section = requireNode(sectionPattern, /^button$/i);
    if (/Value: Expanded/i.test(section.line)) {
      await click(sectionPattern, {}, /^button$/i);
      section = requireNode(sectionPattern, /^button$/i);
    }
    if (!/Value: Collapsed/i.test(section.line)) throw new Error("AX state did not confirm the inspector section is collapsed.");
    await key("j");
    await key("k");
    section = requireNode(sectionPattern, /^button$/i);
    if (!/Value: Collapsed/i.test(section.line)) throw new Error("Inspector section expanded after J/K navigation.");
    await screenshot("PR-10-inspector-folded.png");
  }

  async function quickLook(imagePattern) {
    await click(imagePattern);
    if (!controls().some(node => node.role === "window" && node.depth === 0 && /quick ?look/i.test(node.label))) {
      throw new Error("Top-level Quick Look window did not appear in the AX tree.");
    }
    await screenshot("PR-10-quick-look.png");
    await key("Escape");
  }

  async function runPR10(options) {
    await inspectorTabs(options.tabs);
    await click(/Marks/i, {}, /^(button|radio button)$/i);
    await click(options.mark ?? /^Shot 1 at /, {}, /^(row|button)$/i);
    await fresh();
    await foldAndNavigate(options.foldSection);
    await quickLook(options.image);
  }

  async function timelineGesture(point, drag, screenshotName) {
    if (point) {
      await fresh();
      const before = playheadTime();
      if (!before) throw new Error("Playhead time is unavailable before the timeline click.");
      await app.click(point);
      await fresh();
      const after = playheadTime();
      if (!after || after === before) throw new Error(`Timeline click did not change the playhead (${before} → ${after ?? "missing"}).`);
      await screenshot(screenshotName);
    }
    if (drag) {
      await fresh();
      const before = playheadTime();
      if (!before) throw new Error("Playhead time is unavailable before the timeline drag.");
      await app.drag(drag.from, drag.to);
      await fresh();
      const after = playheadTime();
      if (!after || after === before) throw new Error(`Timeline drag did not change the playhead (${before} → ${after ?? "missing"}).`);
      await screenshot(screenshotName);
    }
  }

  async function runPR11(options = {}) {
    if (options.timelineHoverFraction !== undefined) {
      const percent = String(Math.round(options.timelineHoverFraction * 100)).padStart(3, "0");
      await screenshot(`PR-11-simulated-hover-${percent}.png`);
    }
    await fresh();
    const pinPattern = options.pin ?? /^Shot 3 at/;
    await click(pinPattern, {}, /^(button|radio button|row)$/i);
    const pin = requireNode(pinPattern, /^(button|radio button|row)$/i);
    if (!/\(selected\)/i.test(pin.line)) throw new Error(`Ruler pin is not selected: ${pin.line}`);
    const pinTime = pin.label.match(/\b(\d+:\d{2})\b/)?.[1];
    const time = playheadTime();
    if (!pinTime || time !== pinTime) throw new Error(`Selected pin time ${pinTime ?? "missing"} does not match playhead ${time ?? "missing"}.`);
    await screenshot("PR-11-ruler-pins.png");
    await timelineGesture(options.seekPoint, null, "PR-11-timeline-click.png");
    await timelineGesture(null, options.drag, "PR-11-timeline-drag.png");
  }

  async function dumpLabels() {
    await fresh();
    repl.write(dumpText());
  }

  return { start, fresh, controls, text: treeText, find, click, key, type, assertVisible,
    screenshot, dumpLabels, selfCheck, parseAX, transcriptPosition, playheadTime, isBoundApp, renameWithReturn, contextRename, transcriptSeek,
    multiSelectionAndTrash, recordingProtection, inspectorTabs, foldAndNavigate, quickLook,
    singleSelectionTrash, timelineGesture, runPR08, runPR09, runPR10, runPR11 };
})();
