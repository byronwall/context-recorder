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
  chrome.action.setBadgeText({ text: connected ? "" : "off" });
  chrome.action.setBadgeBackgroundColor({ color: "#888" });
}

async function handle(msg) {
  if (msg.type !== "snapshot") return;
  let data;
  try {
    const [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
    if (!tab || tab.id === undefined) {
      data = { error: "no active tab" };
    } else {
      try {
        data = await chrome.tabs.sendMessage(tab.id, { type: "snapshot" });
      } catch {
        // chrome:// pages, the Web Store, or tabs opened before the extension was installed/reloaded
        data = { error: "content script not available on this tab (reload the tab?)" };
      }
      data = { ...data, tabId: tab.id, windowId: tab.windowId };
    }
  } catch (err) {
    data = { error: String(err) };
  }
  send({ type: "snapshot-result", id: msg.id, data });
}

chrome.runtime.onMessage.addListener((msg, sender) => {
  if (msg.type === "event") {
    send({ type: "event", event: { ...msg.event, tabId: sender.tab && sender.tab.id } });
  } else if (msg.type === "status") {
    return Promise.resolve({ connected: !!(socket && socket.readyState === WebSocket.OPEN) });
  }
});

// Wake periodically to reconnect if the app was started after Chrome.
chrome.alarms.create("reconnect", { periodInMinutes: 0.5 });
chrome.alarms.onAlarm.addListener(connect);
chrome.runtime.onStartup.addListener(connect);
chrome.runtime.onInstalled.addListener(connect);
connect();
