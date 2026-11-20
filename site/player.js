// The home page's demo player, screenshot gallery and copy buttons.
// The player reads the demo session the app processed (demo/session.json and demo/marks/*.md).

const $ = (id) => document.getElementById(id);
const esc = (s) => String(s ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const clock = (t) => `${Math.floor(t / 60)}:${String(Math.floor(t % 60)).padStart(2, '0')}`;
const path = (url) => { try { const u = new URL(url); return u.host + u.pathname; } catch { return url; } };

// Copy: a button inside .cmd[data-copy] copies that text; the button shows a check for a moment.
function flashCopied(btn) {
  btn.classList.add('done');
  setTimeout(() => btn.classList.remove('done'), 1200);
}
async function copy(text, btn) {
  try { await navigator.clipboard.writeText(text); flashCopied(btn); }
  catch { getSelection()?.selectAllChildren(btn.closest('.cmd, .view').querySelector('pre code')); }
}
document.querySelectorAll('.cmd[data-copy] .copy').forEach((btn) => {
  btn.addEventListener('click', () => copy(btn.closest('.cmd').dataset.copy, btn));
});

// Full-size view for any screenshot. It opens fitted; a click zooms to 2x at that point, and a drag pans.
const zoom = $('zoom');
const zimg = $('zimg');
const zwrap = zoom.querySelector('.zwrap');
function openZoom(src, alt) {
  zimg.src = src;
  zimg.alt = alt || '';
  zoom.classList.remove('zoomed');
  zoom.showModal();
}
let drag = null;
zwrap.addEventListener('pointerdown', (e) => {
  if (e.button !== 0) return;
  drag = { x: e.clientX, y: e.clientY, left: zwrap.scrollLeft, top: zwrap.scrollTop, moved: false };
});
zwrap.addEventListener('pointermove', (e) => {
  if (!drag || !zoom.classList.contains('zoomed')) return;
  const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
  if (Math.abs(dx) + Math.abs(dy) > 4) drag.moved = true;
  zwrap.scrollLeft = drag.left - dx;
  zwrap.scrollTop = drag.top - dy;
});
zwrap.addEventListener('pointerup', (e) => {
  const moved = drag?.moved;
  drag = null;
  if (moved) return;
  if (e.target !== zimg) return zoom.close();
  const r = zimg.getBoundingClientRect();
  const fx = (e.clientX - r.left) / r.width, fy = (e.clientY - r.top) / r.height;
  zoom.classList.toggle('zoomed');
  if (zoom.classList.contains('zoomed')) {
    const z = zimg.getBoundingClientRect();
    zwrap.scrollLeft = fx * z.width - (e.clientX - zwrap.getBoundingClientRect().left);
    zwrap.scrollTop = fy * z.height - (e.clientY - zwrap.getBoundingClientRect().top);
  }
});
$('zclose').addEventListener('click', () => zoom.close());

// Arrow keys, Home and End move between tabs in any tablist.
document.addEventListener('keydown', (e) => {
  const list = e.target.closest?.('[role=tablist]');
  if (!list || !['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(e.key)) return;
  const tabs = [...list.querySelectorAll('[role=tab]')];
  const i = tabs.indexOf(e.target);
  const next = { ArrowLeft: i - 1, ArrowRight: i + 1, Home: 0, End: tabs.length - 1 }[e.key];
  const tab = tabs[(next + tabs.length) % tabs.length];
  e.preventDefault();
  tab.focus();
  tab.click();
});

// Gallery of app screenshots.
const SHOTS = {
  mark: ['Mark 1 open in the Marks tab', 'Mark 1 is open. Its title is the sentence that was said, then the frame, the narration, and the element under the pointer with its props and source line.'],
  region: ['Mark 3, a region shot', 'A region mark: the shot beside the full frame, the 500 from the save request with its error body, and the button\'s source line.'],
  transcript: ['The Transcript tab', 'The Transcript tab. Each mark\'s number sits beside the sentence it landed in. Click one to open the mark.'],
  events: ['The Events tab', 'The Events tab: page loads, clicks, requests and console errors in one log, with problems in red.'],
};
function showShot(key) {
  document.querySelectorAll('#gtabs [role=tab]').forEach((b) => b.setAttribute('aria-selected', String(b.dataset.shot === key)));
  $('gimg').src = `img/${key}.webp`;
  $('gimg').alt = SHOTS[key][0] + ' in the Sessions window.';
  $('gcap').textContent = SHOTS[key][1];
}
document.querySelectorAll('#gtabs [role=tab]').forEach((b) => b.addEventListener('click', () => showShot(b.dataset.shot)));
$('gshot').addEventListener('click', () => openZoom($('gimg').src, $('gimg').alt));
showShot('mark');

// Demo player.
const player = $('demo');
const base = player.dataset.session;
const video = $('video');
let session, current = 0, view = 'context';
const markdown = {};

function sentenceAt(t) {
  return session.transcript.find((s) => t >= s.start && t < s.end);
}

function problems(mark) {
  return (mark.browser?.recent ?? []).filter((e) =>
    (e.kind === 'request' && (e.status >= 400 || e.status === 0)) || (e.kind === 'console' && e.level === 'error') || e.kind === 'exception');
}

function source(src) {
  if (!src) return '';
  return `<span class="src">${esc(src.file)}:${src.line}${src.column ? ':' + src.column : ''}</span>`;
}

function renderContext(mark) {
  const t = mark.offsetSeconds;
  const said = session.transcript.filter((s) => s.end > t - 20 && s.start < t + 10);
  const at = sentenceAt(t) ?? said.filter((s) => s.start <= t).at(-1);
  const h = mark.browser?.hovered;
  const region = mark.browser?.region?.elements ?? [];
  const probs = problems(mark);
  const img = mark.kind === 'screenshot' ? mark.image : mark.frame;
  const props = h?.props?.props ? Object.entries(h.props.props).map(([k, v]) => `<span class="prop"><span class="k">${esc(k)}</span> ${esc(typeof v === 'string' ? `"${v}"` : v)}</span>`).join('') : '';
  $('context').innerHTML = `
    <div class="m-head">
      <span class="m-kind ${mark.kind}">${mark.kind === 'screenshot' ? 'Shot' : 'Mark'}</span>
      <span>${clock(t)}</span><span class="dim">${esc(path(mark.browser?.url ?? mark.context?.browserURL))}</span>
    </div>
    <h3 class="m-title">${esc(at?.text ?? 'Mark ' + mark.index)}</h3>
    <div class="m-grid">
      <button type="button" class="thumb" data-src="${base + img}" aria-label="Open the ${mark.kind === 'screenshot' ? 'region shot' : 'frame'} at full size"><img src="${base + img}" alt=""></button>
      <div class="said"><span class="lbl">Said</span>${said.map((s) => s === at ? `<b>${esc(s.text)}</b>` : esc(s.text)).join(' ')}</div>
    </div>
    ${probs.length ? `<div class="block"><span class="lbl bad">Problems ${probs.length}</span>${probs.map((e) => e.kind === 'request'
      ? `<div class="prob"><span class="tag">${esc(e.method)} ${e.status}</span> ${esc(path(e.requestUrl))} <span class="dim">${e.ms} ms</span><div class="body">${esc(e.body)}</div></div>`
      : `<div class="prob"><span class="tag">console</span> ${esc(e.message)}</div>`).join('')}</div>` : ''}
    ${h ? `<div class="block"><span class="lbl">Under pointer</span>
      <div class="el"><b>“${esc(h.text)}”</b> <code>${esc(h.selector)}</code></div>
      <div class="chain">${(h.components ?? []).slice().reverse().map(esc).join(' › ')}</div>
      ${props ? `<div class="props">${props}</div>` : ''}
      ${source(h.source)}</div>` : ''}
    ${region.length ? `<div class="block"><span class="lbl">In the region</span>${region.map((r) => `<div class="el"><b>“${esc(r.text)}”</b> <code>${esc(r.selector)}</code> ${source(r.source)}</div>`).join('')}</div>` : ''}`;
  $('context').querySelector('.thumb').addEventListener('click', (e) => openZoom(e.currentTarget.dataset.src, 'Mark ' + mark.index));
}

// Light Markdown highlighting: headings and bold labels in the text color, markup characters dimmed.
function highlight(md) {
  return md.split('\n').map((line) => {
    const e = esc(line);
    if (/^#{1,6} /.test(line)) return `<span class="mk">${e.match(/^#+/)[0]}</span><b>${e.replace(/^#+/, '')}</b>`;
    return e
      .replace(/^(\s*)([-*]|&gt;)( )/, '$1<span class="mk">$2</span>$3')
      .replace(/\*\*(.+?)\*\*/g, '<span class="mk">**</span><b>$1</b><span class="mk">**</span>')
      .replace(/`([^`]+)`/g, '<span class="mk">`</span><span class="ic">$1</span><span class="mk">`</span>');
  }).join('\n');
}

async function renderMarkdown(mark) {
  const file = `marks/${String(mark.index).padStart(3, '0')}.md`;
  $('mdfile').textContent = file;
  markdown[file] ??= await fetch(base + file).then((r) => r.text());
  if (session.marks[current] === mark) $('md').innerHTML = highlight(markdown[file]);
}

function select(i, seek) {
  current = i;
  const mark = session.marks[i];
  document.querySelectorAll('#marknav button').forEach((b) => b.setAttribute('aria-selected', String(+b.dataset.i === i)));
  document.querySelectorAll('#marks button').forEach((b) => b.classList.toggle('on', +b.dataset.i === i));
  renderContext(mark);
  renderMarkdown(mark);
  if (player.classList.contains('novideo')) { video.poster = base + mark.frame; last = mark.offsetSeconds; tick(); }
  $('insbody').scrollTop = 0;
  if (seek) {
    // Before the video has its metadata, a seek is dropped, so wait for it.
    const go = () => { video.currentTime = last = mark.offsetSeconds; tick(); };
    video.readyState >= 1 ? go() : video.addEventListener('loadedmetadata', go, { once: true });
  }
}

function setView(v) {
  view = v;
  document.querySelectorAll('.seg [role=tab]').forEach((b) => b.setAttribute('aria-selected', String(b.dataset.view === v)));
  document.querySelectorAll('.ins-body .view').forEach((el) => { el.hidden = el.dataset.view !== v; });
}
document.querySelectorAll('.seg [role=tab]').forEach((b) => b.addEventListener('click', () => setView(b.dataset.view)));
$('copymd').addEventListener('click', (e) => copy($('md').textContent, e.currentTarget));

// Without a playable video (no H.264 in some browsers), the stage shows each mark's frame instead.
const noVideo = () => { player.classList.add('novideo'); if (session) select(current, false); };
video.addEventListener('error', noVideo);
if (video.error) noVideo();

let last = 0;
function tick(t = player.classList.contains('novideo') ? last : video.currentTime) {
  const pct = (t / session.duration) * 100;
  $('playhead').style.left = pct + '%';
  $('clock').textContent = clock(t);
  const s = sentenceAt(t);
  $('said').textContent = s ? s.text : '';
  document.querySelectorAll('#voice span').forEach((el, i) => el.classList.toggle('on', session.transcript[i] === s));
  // While playing, the inspector follows each mark as the playhead passes it.
  if (!video.paused) {
    session.marks.forEach((m, i) => { if (last < m.offsetSeconds && t >= m.offsetSeconds) select(i, false); });
  }
  last = t;
}
function loop() { tick(); if (!video.paused) requestAnimationFrame(loop); }

function togglePlay() { video.paused ? video.play() : video.pause(); }
$('play').addEventListener('click', togglePlay);
video.addEventListener('click', togglePlay);
video.addEventListener('play', () => { player.classList.add('playing'); $('play').setAttribute('aria-label', 'Pause'); loop(); });
video.addEventListener('pause', () => { player.classList.remove('playing'); $('play').setAttribute('aria-label', 'Play with sound'); tick(); });
video.addEventListener('seeked', () => tick());

$('rail').addEventListener('pointerdown', (e) => {
  if (e.target.closest('button')) return;
  const r = $('rail').getBoundingClientRect();
  const t = Math.max(0, Math.min(1, (e.clientX - r.left) / r.width)) * session.duration;
  video.currentTime = last = t;
  // The inspector shows the last mark at or before the new time.
  const before = session.marks.filter((m) => m.offsetSeconds <= t + 0.25);
  select(before.length ? session.marks.indexOf(before.at(-1)) : 0, false);
  tick();
});

// J / K step through marks and Space plays, as in the app, while focus is in the player.
player.addEventListener('keydown', (e) => {
  if (e.metaKey || e.ctrlKey || e.altKey) return;
  const n = session.marks.length;
  if (e.key === 'j' || e.key === 'k') { e.preventDefault(); select((current + (e.key === 'j' ? 1 : n - 1)) % n, true); }
  else if (e.key === ' ' && !e.target.closest('button')) { e.preventDefault(); togglePlay(); }
});

fetch(base + 'session.json').then((r) => r.json()).then((data) => {
  session = data;
  const pos = (t) => `${(t / session.duration) * 100}%`;
  $('voice').innerHTML = session.transcript.map((s) => `<span style="left:${pos(s.start)};width:calc(${pos(s.end - s.start)} - 2px)"></span>`).join('');
  const name = (m) => `${m.kind === 'screenshot' ? 'Shot' : 'Mark'} ${m.index}`;
  $('marks').innerHTML = session.marks.map((m, i) => `<button type="button" tabindex="-1" data-i="${i}" class="${m.kind}" style="left:${pos(m.offsetSeconds)}" aria-label="${name(m)} at ${clock(m.offsetSeconds)}">${m.index}</button>`).join('');
  $('marknav').innerHTML = session.marks.map((m, i) => `<button type="button" role="tab" data-i="${i}" aria-selected="false">${name(m)}</button>`).join('');
  document.querySelectorAll('#marknav button, #marks button').forEach((b) => b.addEventListener('click', () => { video.pause(); select(+b.dataset.i, true); }));
  select(0, true);
});
