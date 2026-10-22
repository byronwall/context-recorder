import type { GrantRow } from "./api";
import { escapeHtml as esc } from "./http";
import { fmt } from "./markdown";
import { encodePath } from "./signing";
import type { SessionRow } from "./store";

const mb = (bytes: number) => (bytes >= 1e9 ? `${(bytes / 1e9).toFixed(1)} GB` : `${(bytes / 1e6).toFixed(1)} MB`);

function when(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return esc(iso);
  // Rendered in UTC on the server; the inline script rewrites it in the viewer's time zone.
  return `<time datetime="${esc(iso)}">${esc(d.toISOString().slice(0, 16).replace("T", " "))}</time>`;
}

function row(s: SessionRow): string {
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
  <td class="act"><button type="button" data-delete="${esc(s.id)}" title="Delete the cloud copy">Delete</button></td>
</tr>`;
}

function grantRow(g: GrantRow): string {
  const iso = new Date(g.createdAt * 1000).toISOString();
  return `<li><span class="name">${esc(g.name)}</span><span class="sub">signed in ${when(iso)}</span><button type="button" data-revoke="${esc(g.id)}" title="Sign this app out of your cloud">Sign out</button></li>`;
}

export function libraryPage(sessions: SessionRow[], identity: string, grants: GrantRow[] = []): string {
  const devices = grants.length
    ? `<section class="devices"><h2>Signed-in apps</h2><ul>${grants.map(grantRow).join("")}</ul></section>`
    : "";
  const body = sessions.length
    ? `<table><thead><tr><th></th><th>Session</th><th class="num">Recorded</th><th class="num">Length</th><th class="num">Marks</th><th class="num">Size</th><th></th></tr></thead>
<tbody>${sessions.map(row).join("")}</tbody></table>`
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
@media (prefers-reduced-motion: reduce) { tbody tr, button, .title a { transition:none; } }
</style></head>
<body>
<header><h1>Sessions</h1><span class="sub">${sessions.length} ${sessions.length === 1 ? "session" : "sessions"}</span><span class="who">${esc(identity)}</span></header>
<main>${body}${devices}</main>
<script>
for (const t of document.querySelectorAll("time")) {
  const d = new Date(t.dateTime);
  t.textContent = d.toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" });
}
document.addEventListener("click", async (e) => {
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
</script>
</body></html>`;
}
