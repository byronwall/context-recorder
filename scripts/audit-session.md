# Session performance capture

Use the signed-in Chrome profile. Open DevTools before opening the session.
Use only one debugger connection during capture. Competing browser agents distorted the first audit run.

1. Select Network. Enable Keep log. Clear the request list.
2. Enable Disable cache for the first run. Leave throttling off and record the viewport.
3. Open the session. Leave playback paused until requests stop.
4. Export a sanitized HAR as `initial.har`.
5. Paste `scripts/audit-session.js` into the Console.
6. Run `sessionAudit.snapshot('before-play')`. Play for 20 seconds, then pause.
7. Run `sessionAudit.snapshot('after-play')`. Export another HAR.
8. Seek to 10:00. Wait for the picture, then capture another snapshot and HAR.
9. Return to buffered footage. Repeat the snapshot and export.
10. Wait 30 seconds while paused. Check whether bytes or buffered ranges increase.
11. Run `sessionAudit.download()` to save media events and resource timings.
12. Turn Disable cache off. Clear Network, reload, and export a warm-load HAR.

Use these commands from the repository root:

```sh
python3 scripts/summarize-session-har.py /path/to/initial.har > tmp/initial-summary.json
node --check scripts/audit-session.js
```

The summary excludes cookies, query strings, and response bodies. Keep raw HAR files local.
The browser download contains resource paths and navigation URLs. Keep it local too.

Resource Timing can omit transferred video bytes when Chrome stops or suspends a response.
Use HAR `_transferSize` for Chrome's transfer count. A response's Content-Length describes the offered range.
It does not prove that Chrome received that entire range.

`seekable` shows where seeking is supported. `buffered` shows which time ranges have media available.
The script records events only after installation. Navigation and resource entries include earlier completed work.
Reinstall the script after each reload. Run `sessionAudit.stop()` when finished.

For slower-network tests, repeat the first run with a named throttle setting.
Report those results separately from unthrottled measurements.
