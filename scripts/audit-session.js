// Paste into Chrome DevTools Console on a session page. Keep Network recording too:
// Resource Timing can omit bytes from canceled or unfinished video requests.
(() => {
  window.sessionAudit?.stop();
  performance.setResourceTimingBufferSize(5000);
  const video = document.querySelector('video');
  if (!video) throw new Error('Open a session viewer first');
  const events = [], snapshots = [], listeners = [];
  const ranges = (r) => Array.from({ length: r.length }, (_, i) => [r.start(i), r.end(i)]);
  const media = () => ({ time: video.currentTime, duration: video.duration, paused: video.paused,
    readyState: video.readyState, networkState: video.networkState,
    buffered: ranges(video.buffered), seekable: ranges(video.seekable),
    quality: (() => { const q = video.getVideoPlaybackQuality?.(); return q && {
      total: q.totalVideoFrames, dropped: q.droppedVideoFrames }; })() });
  const resources = () => performance.getEntriesByType('resource')
    .filter((r) => new URL(r.name).origin === location.origin)
    .map((r) => ({ path: new URL(r.name).pathname, type: r.initiatorType,
      start: r.startTime, duration: r.duration, ttfb: r.responseStart - r.requestStart,
      transfer: r.transferSize, encoded: r.encodedBodySize, decoded: r.decodedBodySize,
      status: r.responseStatus }));
  const snapshot = (label) => {
    const rows = resources();
    const groups = {};
    for (const row of rows) {
      const group = groups[row.type] ??= { count: 0, transfer: 0, encoded: 0 };
      group.count++; group.transfer += row.transfer; group.encoded += row.encoded;
    }
    const result = { label, at: performance.now(), media: media(), groups };
    snapshots.push(result);
    console.log('SESSION AUDIT', JSON.stringify(result));
    return result;
  };
  for (const name of ['loadstart', 'loadedmetadata', 'loadeddata', 'canplay', 'play', 'playing',
    'pause', 'seeking', 'seeked', 'waiting', 'stalled', 'suspend', 'progress', 'error']) {
    const listener = () => {
      const row = { event: name, at: performance.now(), ...media() };
      events.push(row);
      if (name !== 'progress') console.log('SESSION MEDIA', JSON.stringify(row));
    };
    video.addEventListener(name, listener);
    listeners.push([name, listener]);
  }
  const longTasks = [];
  const observer = new PerformanceObserver((list) => {
    for (const row of list.getEntries()) longTasks.push({ start: row.startTime, duration: row.duration });
  });
  if (PerformanceObserver.supportedEntryTypes.includes('longtask')) observer.observe({ type: 'longtask', buffered: true });
  const report = () => ({ capturedAt: new Date().toISOString(), path: location.pathname,
    installedAt, navigation: performance.getEntriesByType('navigation').map((r) => r.toJSON()),
    paint: performance.getEntriesByType('paint').map((r) => r.toJSON()),
    resources: resources(), events, snapshots, longTasks,
    images: [...document.images].map((i) => ({ path: i.getAttribute('src'), loading: i.loading,
      complete: i.complete, width: i.naturalWidth, height: i.naturalHeight, visible: !!i.getClientRects().length })),
    note: 'Resource Timing is not a wire byte counter. Use sanitized HAR for Range headers and canceled transfers.' });
  const installedAt = performance.now();
  window.sessionAudit = { snapshot, report, stop() {
    observer.disconnect();
    for (const [name, listener] of listeners) video.removeEventListener(name, listener);
  }, download() {
    const url = URL.createObjectURL(new Blob([JSON.stringify(report(), null, 2)], { type: 'application/json' }));
    const a = Object.assign(document.createElement('a'), { href: url, download: 'session-audit.json' });
    a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
  } };
  snapshot('installed');
})();
