chrome.runtime.sendMessage({ type: "status" }).then((res) => {
  const connected = res && res.connected;
  document.getElementById("status").className = connected ? "on" : "";
  document.getElementById("label").textContent = connected ? "Connected to Context Recorder" : "App not running (retrying every 30s)";
});
