import type { GrantRow } from "./api";
import { escapeHtml as esc } from "./http";
import { fmt } from "./markdown";
import { encodePath } from "./signing";
import type { SessionRow, ShareSummary } from "./store";

const mb = (bytes: number) => (bytes >= 1e9 ? `${(bytes / 1e9).toFixed(1)} GB` : `${(bytes / 1e6).toFixed(1)} MB`);

function when(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return esc(iso);
  // Rendered in UTC on the server; the inline script rewrites it in the viewer's time zone.
  return `<time datetime="${esc(iso)}">${esc(d.toISOString().slice(0, 16).replace("T", " "))}</time>`;
}

function row(s: SessionRow, share?: ShareSummary): string {
  const href = `/s/${encodeURIComponent(s.id)}/`;
  const poster = s.poster
    ? `<img src="${href}${esc(encodePath(s.poster))}" alt="" loading="lazy" width="112" height="63" onerror="this.style.visibility='hidden'">`
    : `<span class="noposter"></span>`;
  return `<tr data-id="${esc(s.id)}">
  <td class="thumb"><a href="${href}" tabindex="-1">${poster}</a></td>
  <td class="title"><a href="${href}">${esc(s.title || s.id)}</a><div class="sub">${esc(s.id)}</div></td>
  <td class="num">${when(s.recordedAt)}</td>
  <td class="num">${fmt(s.duration)}</td>
  <td class="num">${s.markCount}</td>
  <td class="num">${mb(s.size)}</td>
  <td class="shared">${shareButton(s, share)}</td>
  <td class="act"><button type="button" data-delete="${esc(s.id)}" title="Delete the cloud copy">Delete</button></td>
</tr>`;
}

/** Opens the share links popover. It shows views once a link is active, else just "Share". */
function shareButton(s: SessionRow, share?: ShareSummary): string {
  const text = share?.active ? `${share.views} ${share.views === 1 ? "view" : "views"}` : "Share";
  const tip = share?.active ? `${share.active} active ${share.active === 1 ? "link" : "links"}` : "Make a link anyone can open without signing in";
  return `<button type="button" class="plain${share?.active ? " on" : ""}" data-share="${esc(s.id)}" data-title="${esc(s.title || s.id)}" title="${tip}">${text}</button>`;
}

function grantRow(g: GrantRow): string {
  const iso = new Date(g.createdAt * 1000).toISOString();
  return `<li><span class="name">${esc(g.name)}</span><span class="sub">signed in ${when(iso)}</span><button type="button" data-revoke="${esc(g.id)}" title="Sign this app out of your cloud">Sign out</button></li>`;
}

export function libraryPage(
  sessions: SessionRow[],
  identity: string,
  grants: GrantRow[] = [],
  shares: Map<string, ShareSummary> = new Map(),
): string {
  const devices = grants.length
    ? `<section class="devices"><h2>Signed-in apps</h2><ul>${grants.map(grantRow).join("")}</ul></section>`
    : "";
  const body = sessions.length
    ? `<table><thead><tr><th></th><th>Session</th><th class="num">Recorded</th><th class="num">Length</th><th class="num">Marks</th><th class="num">Size</th><th class="shared">Shared</th><th></th></tr></thead>
<tbody>${sessions.map((s) => row(s, shares.get(s.id))).join("")}</tbody></table>`
    : `<p class="empty">No sessions yet. Push one from Context Recorder.</p>`;
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sessions</title>
<style>
:root { --bg:#fbfbfa; --text:#1d1d1f; --muted:#6e6e73; --line:#e6e6e3; --link:#2457c5; --hover:#f0f0ed; --danger:#b42318; }
@media (prefers-color-scheme: dark) { :root { --bg:#161617; --text:#ececec; --muted:#9a9aa0; --line:#2c2c2f; --link:#7aa5ff; --hover:#222225; --danger:#ff7b6e; } }
* { box-sizing:border-box; }
body { margin:0; background:var(--bg); color:var(--text); font:14px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
header { display:flex; align-items:baseline; gap:12px; padding:14px 16px 8px; max-width:1200px; margin:0 auto; }
h1 { font-size:16px; margin:0; }
header .who { color:var(--muted); font-size:12px; margin-left:auto; }
main { max-width:1200px; margin:0 auto; padding:0 16px 24px; overflow-x:auto; }
table { width:100%; border-collapse:collapse; }
th { text-align:left; font-weight:500; color:var(--muted); font-size:12px; padding:4px 8px; border-bottom:1px solid var(--line); }
td { padding:6px 8px; border-bottom:1px solid var(--line); vertical-align:middle; }
tbody tr { transition:background-color 140ms ease; }
tbody tr:hover { background:var(--hover); }
.num { text-align:right; white-space:nowrap; font-variant-numeric:tabular-nums; }
.thumb { width:128px; padding-right:0; }
.thumb img, .noposter { display:block; width:112px; height:63px; object-fit:cover; border-radius:3px; background:var(--line); }
.title a { color:var(--link); text-decoration:none; white-space:nowrap; transition:color 140ms ease; }
.title a:hover { color:var(--text); }
.sub { color:var(--muted); font-size:12px; }
.act { width:1%; text-align:right; }
button { font:inherit; font-size:12px; color:var(--muted); background:none; border:1px solid transparent; border-radius:4px; padding:2px 8px; cursor:pointer; transition:color 140ms ease, border-color 140ms ease; }
button:hover { color:var(--danger); border-color:var(--line); }
button:active { transform:translateY(1px); }
button:disabled { opacity:.5; cursor:default; }
.empty { color:var(--muted); padding:24px 0; }
.devices { margin-top:28px; }
.devices h2 { font-size:12px; font-weight:500; color:var(--muted); margin:0; padding:4px 8px; border-bottom:1px solid var(--line); }
.devices ul { list-style:none; margin:0; padding:0; }
.devices li { display:flex; align-items:baseline; gap:12px; padding:6px 8px; border-bottom:1px solid var(--line); }
.devices .name { white-space:nowrap; overflow:hidden; text-overflow:ellipsis; min-width:0; }
.devices button { margin-left:auto; }
.shared { width:1%; text-align:right; white-space:nowrap; }
button.plain:hover { color:var(--text); }
button.on { color:var(--link); font-variant-numeric:tabular-nums; }
#shares { position:fixed; inset:auto; margin:0; width:min(460px, calc(100vw - 32px)); max-height:min(70vh, 640px); overflow:auto; padding:0;
  background:var(--bg); color:var(--text); border:1px solid var(--line); border-radius:8px; box-shadow:0 8px 28px rgba(0,0,0,.14); }
#shares .head { display:flex; align-items:baseline; gap:8px; padding:10px 12px 6px; }
#shares .head b { font-size:13px; white-space:nowrap; }
#shares .head .sub { min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
#shares form { display:flex; gap:6px; padding:0 12px 10px; border-bottom:1px solid var(--line); }
#shares input { flex:1; min-width:0; font:inherit; font-size:13px; color:var(--text); background:none; border:1px solid var(--line); border-radius:4px; padding:3px 8px; }
#shares input:focus { outline:2px solid var(--link); outline-offset:-1px; border-color:transparent; }
button.primary { color:var(--link); border-color:var(--line); }
button.primary:hover { color:var(--text); }
#shares ul { list-style:none; margin:0; padding:0; }
#shares li { padding:8px 12px; border-bottom:1px solid var(--line); }
#shares li:last-child { border-bottom:0; }
#shares .l1 { display:flex; align-items:baseline; gap:8px; }
#shares .l1 .name { font-weight:500; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; min-width:0; }
#shares .l1 .sub { white-space:nowrap; }
#shares .l1 button:first-of-type { margin-left:auto; }
#shares .url { font:12px ui-monospace, SFMono-Regular, Menlo, monospace; color:var(--muted); overflow-wrap:anywhere; margin:2px 0 4px; }
#shares .stats { font-size:12px; font-variant-numeric:tabular-nums; }
#shares .stats b { font-weight:600; }
#shares .kv { display:grid; grid-template-columns:52px 1fr; gap:8px; font-size:12px; color:var(--muted); margin-top:2px; }
#shares .kv span:last-child { color:var(--text); }
#shares li.revoked { color:var(--muted); }
#shares li.revoked .name { font-weight:400; }
#shares .none { color:var(--muted); font-size:12px; padding:10px 12px; margin:0; }
#shares .toggle { display:block; width:100%; text-align:left; border-radius:0; padding:6px 12px; border-top:1px solid var(--line); }
button.copied { color:var(--link); animation:pulse 400ms ease; }
@keyframes pulse { 40% { transform:scale(1.08); } }
@media (prefers-reduced-motion: reduce) { tbody tr, button, .title a { transition:none; } button.copied { animation:none; } }
</style></head>
<body>
<header><h1>Sessions</h1><span class="sub">${sessions.length} ${sessions.length === 1 ? "session" : "sessions"}</span><span class="who">${esc(identity)}</span></header>
<main>${body}${devices}</main>
<div id="shares" popover></div>
<script>
for (const t of document.querySelectorAll("time")) {
  const d = new Date(t.dateTime);
  t.textContent = d.toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" });
}
document.addEventListener("click", async (e) => {
  if (await shareClick(e)) return;
  const out = e.target.closest("[data-revoke]");
  if (out) {
    const name = out.parentElement.querySelector(".name").textContent;
    if (!confirm("Sign " + name + " out? It will need to sign in again to push or read sessions.")) return;
    out.disabled = true;
    const res = await fetch("/api/grants/" + encodeURIComponent(out.dataset.revoke) + "/revoke", { method: "POST" });
    if (res.ok) {
      const list = out.closest("ul");
      out.closest("li").remove();
      if (!list.children.length) list.closest("section").remove();
    } else { out.disabled = false; alert("Sign out failed: " + res.status); }
    return;
  }
  const btn = e.target.closest("[data-delete]");
  if (!btn) return;
  const id = btn.dataset.delete;
  if (!confirm("Delete the cloud copy of " + id + "? The session on your Mac is not affected.")) return;
  btn.disabled = true;
  const res = await fetch("/api/sessions/" + encodeURIComponent(id), { method: "DELETE" });
  if (res.ok || res.status === 404) btn.closest("tr").remove();
  else { btn.disabled = false; alert("Delete failed: " + res.status); }
});

// Share links (docs/cloud-sessions.md §8): a popover per session with its links and their views.
const pop = document.getElementById("shares");
let open = null; // { id, title, button, showRevoked }
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const ago = (iso) => {
  const s = (Date.now() - new Date(iso)) / 1000;
  if (s < 60) return "just now";
  if (s < 3600) return Math.round(s / 60) + " min ago";
  if (s < 86400) return Math.round(s / 3600) + " h ago";
  return new Date(iso).toLocaleDateString(undefined, { dateStyle: "medium" });
};
const plural = (n, one, many) => n + " " + (n === 1 ? one : many);
const api = (id) => "/api/sessions/" + encodeURIComponent(id) + "/shares";

function linkItem(l) {
  const counts = l.views
    ? "<b>" + l.views + "</b> " + (l.views === 1 ? "view" : "views") + " · <b>" + l.viewers + "</b> " + (l.viewers === 1 ? "viewer" : "viewers") +
      " · last " + ago(l.lastViewedAt) + (l.devices.mobile ? " · " + l.devices.mobile + " on mobile" : "")
    : "No views yet";
  const list = (items) => items.map((i) => esc(i.name ?? i.host ?? "Direct") + " " + i.views).join(" · ");
  return '<li class="' + (l.revokedAt ? "revoked" : "") + '">' +
    '<div class="l1"><span class="name">' + esc(l.label || "Link") + '</span><span class="sub">' +
    (l.revokedAt ? "revoked " + ago(l.revokedAt) : "made " + ago(l.createdAt)) + "</span>" +
    (l.revokedAt ? "" : '<button type="button" class="plain" data-copy="' + esc(l.url) + '">Copy link</button><button type="button" data-revoke-share="' + esc(l.token) + '">Revoke</button>') +
    "</div>" + (l.revokedAt ? "" : '<div class="url">' + esc(l.url) + "</div>") +
    '<div class="stats">' + counts + "</div>" +
    (l.places.length ? '<div class="kv"><span>Places</span><span>' + list(l.places) + "</span></div>" : "") +
    (l.views ? '<div class="kv"><span>From</span><span>' + list(l.referrers) + "</span></div>" : "") +
    "</li>";
}

async function renderShares() {
  const links = await (await fetch(api(open.id))).json();
  const active = links.filter((l) => !l.revokedAt), revoked = links.filter((l) => l.revokedAt);
  pop.innerHTML = '<div class="head"><b>Share links</b><span class="sub">' + esc(open.title) + "</span></div>" +
    '<form><input name="label" maxlength="100" placeholder="Label, such as who gets it (optional)" aria-label="Label"><button type="submit" class="primary">New link</button></form>' +
    (active.length ? "<ul>" + active.map(linkItem).join("") + "</ul>" : '<p class="none">No active links. Anyone with a link can watch this session without signing in.</p>') +
    (revoked.length ? '<button type="button" class="plain toggle" data-toggle-revoked>' + (open.showRevoked ? "Hide " : "Show ") + plural(revoked.length, "revoked link", "revoked links") + "</button>" +
      (open.showRevoked ? "<ul>" + revoked.map(linkItem).join("") + "</ul>" : "") : "");
  const views = active.reduce((n, l) => n + l.views, 0);
  open.button.textContent = active.length ? plural(views, "view", "views") : "Share";
  open.button.classList.toggle("on", active.length > 0);
  pop.querySelector("form").addEventListener("submit", async (ev) => {
    ev.preventDefault();
    const label = ev.target.label.value.trim();
    ev.submitter.disabled = true;
    const res = await fetch(api(open.id), { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ label }) });
    if (!res.ok) { ev.submitter.disabled = false; alert("New link failed: " + res.status); return; }
    const made = await res.json();
    try { await navigator.clipboard.writeText(made.url); } catch {}
    await renderShares();
    pop.querySelector('[data-copy="' + CSS.escape(made.url) + '"]')?.classList.add("copied");
  });
}

function place() {
  const r = open.button.getBoundingClientRect();
  const w = pop.offsetWidth, h = pop.offsetHeight;
  pop.style.left = Math.max(16, Math.min(innerWidth - w - 16, r.right - w)) + "px";
  pop.style.top = (r.bottom + 6 + h > innerHeight - 16 ? Math.max(16, r.top - 6 - h) : r.bottom + 6) + "px";
}

async function showShares(button) {
  open = { id: button.dataset.share, title: button.dataset.title, button, showRevoked: false };
  pop.innerHTML = '<p class="none">Loading…</p>';
  pop.showPopover();
  place();
  await renderShares();
  place();
  pop.querySelector("input")?.focus();
  history.replaceState(null, "", "#share=" + encodeURIComponent(open.id));
}

addEventListener("resize", () => { if (open && pop.matches(":popover-open")) place(); });
pop.addEventListener("toggle", (e) => { if (e.newState === "closed" && location.hash.startsWith("#share=")) history.replaceState(null, "", location.pathname); });

async function shareClick(e) {
  const btn = e.target.closest("[data-share]");
  if (btn) { if (open?.button === btn && pop.matches(":popover-open")) pop.hidePopover(); else await showShares(btn); return true; }
  const copy = e.target.closest("[data-copy]");
  if (copy) {
    await navigator.clipboard.writeText(copy.dataset.copy);
    copy.classList.remove("copied"); void copy.offsetWidth; copy.classList.add("copied");
    return true;
  }
  const rev = e.target.closest("[data-revoke-share]");
  if (rev) {
    if (!confirm("Revoke this link? Anyone who has it will see “no longer shared.”")) return true;
    rev.disabled = true;
    const res = await fetch("/api/shares/" + encodeURIComponent(rev.dataset.revokeShare) + "/revoke", { method: "POST" });
    if (res.ok) await renderShares(); else { rev.disabled = false; alert("Revoke failed: " + res.status); }
    return true;
  }
  if (e.target.closest("[data-toggle-revoked]")) { open.showRevoked = !open.showRevoked; await renderShares(); return true; }
  return false;
}

// /#share=<id> (the Mac app's Manage Shares…) opens that session's popover.
const wanted = /^#share=(.+)$/.exec(location.hash);
if (wanted) {
  const b = document.querySelector('[data-share="' + CSS.escape(decodeURIComponent(wanted[1])) + '"]');
  if (b) showShares(b);
}
</script>
</body></html>`;
}
