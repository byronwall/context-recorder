const $ = (id) => document.getElementById(id);

const STATES = {
  on: ["Connected", "Recording context to Context Recorder"],
  off: ["App not running", "Open Context Recorder; retrying every 30s"],
};

let tabCapturable = false;

function render(connected) {
  renderTabState(connected);
  const state = connected ? "on" : "off";
  $("status").dataset.state = state;
  [$("headline").textContent, $("detail").textContent] = STATES[state];
  $("retry").hidden = connected;
}

async function refresh() {
  const res = await chrome.runtime.sendMessage({ type: "status" }).catch(() => null);
  render(!!(res && res.connected));
  return !!(res && res.connected);
}

$("retry").addEventListener("click", async () => {
  const btn = $("retry");
  btn.disabled = true;
  btn.textContent = "Retrying…";
  await chrome.runtime.sendMessage({ type: "connect" }).catch(() => {});
  // The socket opens asynchronously; poll briefly for the result.
  for (let i = 0; i < 6 && !(await refresh()); i++) await new Promise((r) => setTimeout(r, 250));
  btn.disabled = false;
  btn.textContent = "Retry";
});

async function showTab() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab || !tab.url) return;
  let url;
  try { url = new URL(tab.url); } catch { return; }
  const capturable = url.protocol === "http:" || url.protocol === "https:" || url.protocol === "file:";
  $("host").textContent = url.protocol === "file:" ? url.pathname.split("/").pop() || "Local file" : url.host || tab.title || tab.url;
  tabCapturable = capturable;
  renderTabState($("status").dataset.state === "on");
  if (tab.favIconUrl && /^https?:|^data:/.test(tab.favIconUrl)) $("favicon").src = tab.favIconUrl;
  else $("favicon").hidden = true;
  $("tab").hidden = false;
}

function renderTabState(connected) {
  const el = $("tabState");
  el.textContent = !tabCapturable ? "Chrome blocks extensions on this page"
    : connected ? "Capturing on this tab" : "Will capture once the app connects";
  el.className = "tab-state" + (tabCapturable && connected ? " ok" : "");
}

$("version").textContent = "v" + chrome.runtime.getManifest().version;
refresh();
showTab();
