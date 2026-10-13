// Service worker: keeps a WebSocket to the Context Recorder app and forwards page events / snapshots.
const APP_URL = "ws://127.0.0.1:47823";
const MAX_QUEUE = 200;

let socket = null;
let connecting = false;
let pingTimer = null;
const queue = [];

function connect() {
  if (connecting || (socket && socket.readyState === WebSocket.OPEN)) return;
  connecting = true;
  let ws;
  try {
    ws = new WebSocket(APP_URL);
  } catch {
    connecting = false;
    return;
  }
  ws.onopen = () => {
    connecting = false;
    socket = ws;
    send({ type: "hello", version: chrome.runtime.getManifest().version });
    while (queue.length) ws.send(JSON.stringify(queue.shift()));
    // Regular traffic keeps the MV3 service worker alive while the app is running.
    clearInterval(pingTimer);
    pingTimer = setInterval(() => send({ type: "ping" }), 20000);
    setBadge(true);
  };
  ws.onmessage = (e) => handle(JSON.parse(e.data));
  ws.onclose = ws.onerror = () => {
    connecting = false;
    if (socket === ws) socket = null;
    clearInterval(pingTimer);
    setBadge(false);
  };
}

function send(msg) {
  if (socket && socket.readyState === WebSocket.OPEN) {
    socket.send(JSON.stringify(msg));
    return;
  }
  if (msg.type === "event") {
    queue.push(msg);
    if (queue.length > MAX_QUEUE) queue.shift();
  }
  connect();
}

function setBadge(connected) {
  // A small amber dot when the app isn't reachable; no badge when connected.
  chrome.action.setBadgeText({ text: connected ? "" : " " });
  chrome.action.setBadgeBackgroundColor({ color: "#f5b041" });
  chrome.action.setTitle({ title: connected ? "Context Recorder: connected" : "Context Recorder: app not running" });
}

// App requests: {type: "snapshot" | "region", id, payload?, capturePage?}
async function handle(msg) {
  if (msg.type !== "snapshot" && msg.type !== "region") return;
  let data;
  let tab;
  try {
    [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
    if (!tab || tab.id === undefined) {
      data = { error: "no active tab" };
    } else {
      const request = { type: msg.type, payload: msg.payload };
      try {
        data = await chrome.tabs.sendMessage(tab.id, request);
      } catch {
        // Tab was open before the extension loaded: inject now and retry once.
        try {
          await injectInto(tab.id);
          data = await chrome.tabs.sendMessage(tab.id, request);
          data = { ...data, lateInjection: true };
        } catch {
          // chrome:// pages, the Web Store, PDFs, etc.
          data = { error: "page can't be inspected (chrome:// or restricted page)" };
        }
      }
      data = { ...data, tabId: tab.id, windowId: tab.windowId };
    }
  } catch (err) {
    data = { error: String(err) };
  }
  send({ type: "result", id: msg.id, data });

  // Save the whole page (DOM + styles + images) as MHTML so it can be opened and inspected later.
  if (msg.capturePage && tab && !data.error) {
    try {
      const blob = await chrome.pageCapture.saveAsMHTML({ tabId: tab.id });
      send({ type: "page-capture", id: msg.id, data: await toBase64(blob) });
    } catch (err) {
      send({ type: "page-capture", id: msg.id, error: String(err) });
    }
  }
}

async function toBase64(blob) {
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(binary);
}

// Content scripts declared in the manifest only reach tabs loaded after install, so inject into open ones.
async function injectInto(tabId) {
  await chrome.scripting.executeScript({ target: { tabId }, files: ["page.js"], world: "MAIN" });
  await chrome.scripting.executeScript({ target: { tabId }, files: ["relay.js"] });
}

async function injectIntoOpenTabs() {
  const tabs = await chrome.tabs.query({ url: ["http://*/*", "https://*/*", "file:///*"] });
  await Promise.all(tabs.map((t) => injectInto(t.id).catch(() => {})));
}

chrome.runtime.onMessage.addListener((msg, sender) => {
  if (msg.type === "event") {
    send({ type: "event", event: { ...msg.event, tabId: sender.tab && sender.tab.id } });
  } else if (msg.type === "connect") {
    connect();
  } else if (msg.type === "status") {
    return Promise.resolve({ connected: !!(socket && socket.readyState === WebSocket.OPEN) });
  }
});

// Wake periodically to reconnect if the app was started after Chrome.
chrome.alarms.create("reconnect", { periodInMinutes: 0.5 });
chrome.alarms.onAlarm.addListener(connect);
chrome.runtime.onStartup.addListener(connect);
chrome.runtime.onInstalled.addListener(() => {
  connect();
  injectIntoOpenTabs();
});
connect();
