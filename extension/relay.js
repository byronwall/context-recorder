// Isolated-world content script: bridges page.js (window.postMessage) <-> background.js (chrome.runtime).
// May be injected twice (manifest + programmatic injection into already-open tabs), so guard.
if (!globalThis.__contextRecorderRelay) {
globalThis.__contextRecorderRelay = true;
const SRC_PAGE = "context-recorder:page";
const SRC_RELAY = "context-recorder:relay";
const waiting = new Map();

window.addEventListener("message", (e) => {
  if (e.source !== window || !e.data || e.data.source !== SRC_PAGE) return;
  if (e.data.type === "event") {
    chrome.runtime.sendMessage({ type: "event", event: e.data.event }).catch(() => {});
  } else if (e.data.type === "snapshot-result") {
    const done = waiting.get(e.data.id);
    if (done) done(e.data.data);
  }
});

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg.type !== "snapshot") return;
  const id = Math.random().toString(36).slice(2);
  const timer = setTimeout(() => {
    waiting.delete(id);
    sendResponse({ error: "page did not answer" });
  }, 300);
  waiting.set(id, (data) => {
    clearTimeout(timer);
    waiting.delete(id);
    sendResponse(data);
  });
  window.postMessage({ source: SRC_RELAY, type: "snapshot", id }, "*");
  return true; // async sendResponse
});
}
