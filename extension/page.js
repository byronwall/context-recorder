// Runs in the page's own JS world (MAIN) so it can see console/fetch/XHR/history and framework
// internals (React fiber, Vue instance). Talks to relay.js via window.postMessage.
(() => {
  if (window.__contextRecorder) return;
  window.__contextRecorder = true;

  const SRC_PAGE = "context-recorder:page";
  const SRC_RELAY = "context-recorder:relay";
  const RING_SIZE = 60;
  const SLOW_MS = 3000;
  const ring = [];
  let lastHover = null;

  const now = () => Date.now();
  const trunc = (s, n = 300) => {
    s = String(s ?? "");
    return s.length > n ? s.slice(0, n - 1) + "…" : s;
  };

  // kinds that are streamed to the app as they happen; everything also lands in the ring for snapshots
  const STREAM = new Set(["click", "nav", "console", "error", "request"]);

  function record(event, { stream = true } = {}) {
    event.t = now();
    event.url = location.href;
    ring.push(event);
    if (ring.length > RING_SIZE) ring.shift();
    if (stream && STREAM.has(event.kind)) {
      window.postMessage({ source: SRC_PAGE, type: "event", event }, "*");
    }
  }

  // ---------- element description ----------

  const cssEscape = (s) => (window.CSS && CSS.escape ? CSS.escape(s) : s.replace(/[^\w-]/g, "\\$&"));
  const looksGenerated = (s) => /\d{3,}|^[a-f0-9]{6,}$|^(css|sc|jsx|svelte)-|^_|:r\d/i.test(s);
  const TEST_ATTRS = ["data-testid", "data-test", "data-test-id", "data-cy", "data-qa"];

  // Tailwind-style utility classes make brittle, unreadable selectors; keep only "semantic" ones.
  const UTILITY_WORDS = new Set("flex grid block inline inline-block inline-flex inline-grid hidden relative absolute fixed sticky static group peer container truncate italic uppercase lowercase capitalize underline antialiased visible invisible contents isolate grow shrink".split(" "));
  const UTILITY_PREFIX = /^-?(m|p|mx|my|mt|mb|ml|mr|ms|me|px|py|pt|pb|pl|pr|ps|pe|w|h|size|min-w|min-h|max-w|max-h|gap|gap-x|gap-y|space-x|space-y|text|font|leading|tracking|bg|border|rounded|shadow|ring|outline|opacity|z|top|left|right|bottom|inset|start|end|flex|grid|col|row|items|justify|content|self|place|overflow|cursor|select|pointer-events|transition|duration|delay|ease|animate|transform|translate|scale|rotate|skew|fill|stroke|object|aspect|order|shrink|grow|basis|whitespace|break|line-clamp|decoration|sr|not-sr|backdrop|blur|from|to|via|divide|list|align|origin|will-change|table|columns|auto-cols|auto-rows|scroll|snap|touch|resize|appearance|caret|accent|underline-offset|indent|hyphens|mix-blend|bg-blend|filter|drop-shadow|brightness|contrast|grayscale|saturate|sepia)(-|$)/;
  const isSemanticClass = (c) => !/[:\[\]\/.%!@]/.test(c) && !UTILITY_WORDS.has(c) && !UTILITY_PREFIX.test(c) && !looksGenerated(c);

  const isUnique = (sel) => {
    try {
      return document.querySelectorAll(sel).length === 1;
    } catch {
      return false;
    }
  };

  function nodePart(node) {
    const testAttr = TEST_ATTRS.find((a) => node.getAttribute(a));
    if (testAttr) return `[${testAttr}="${node.getAttribute(testAttr)}"]`;
    if (node.id && !looksGenerated(node.id)) return `#${cssEscape(node.id)}`;
    let part = node.tagName.toLowerCase();
    const label = node.getAttribute("aria-label");
    if (label && label.length < 60) part += `[aria-label="${label.replace(/"/g, '\\"')}"]`;
    const cls = [...node.classList].filter(isSemanticClass).slice(0, 2);
    if (cls.length) part += "." + cls.map(cssEscape).join(".");
    const parent = node.parentElement;
    if (parent) {
      const same = [...parent.children].filter((c) => c.tagName === node.tagName);
      if (same.length > 1) part += `:nth-of-type(${same.indexOf(node) + 1})`;
    }
    return part;
  }

  // Shortest ancestor path (joined with " > ") that matches exactly this element.
  function selectorFor(el) {
    if (!(el instanceof Element)) return null;
    const parts = [];
    let node = el;
    while (node && node.nodeType === 1 && parts.length < 8) {
      parts.unshift(nodePart(node));
      const sel = parts.join(" > ");
      if (isUnique(sel)) return sel;
      node = node.parentElement;
    }
    return parts.join(" > ");
  }

  // Production builds minify component names ("Qs", "i$e"); keep only readable ones.
  const isReadableName = (n) => /^[A-Z][A-Za-z0-9_.]{3,}$/.test(n);

  function componentChain(el) {
    const names = [];
    try {
      // React: walk the fiber tree upward collecting component names.
      const key = Object.keys(el).find((k) => k.startsWith("__reactFiber$") || k.startsWith("__reactInternalInstance$"));
      let fiber = key ? el[key] : null;
      for (let i = 0; fiber && names.length < 8 && i < 300; i++) {
        const t = fiber.type;
        const name = t && typeof t !== "string" ? t.displayName || t.name : null;
        if (name && isReadableName(name) && !names.includes(name)) names.push(name);
        fiber = fiber.return;
      }
      // Vue 3
      let vue = el.__vueParentComponent;
      while (vue && names.length < 8) {
        const name = vue.type && (vue.type.name || vue.type.__name);
        if (name && isReadableName(name) && !names.includes(name)) names.push(name);
        vue = vue.parent;
      }
    } catch {}
    return names.length ? names : undefined;
  }

  function describe(el) {
    if (!(el instanceof Element)) return null;
    // Prefer the nearest interactive ancestor: clicking an <svg> inside a <button> means the button.
    const target = el.closest("button, a, [role=button], [role=link], [role=menuitem], [role=tab], input, select, textarea, label, summary") || el;
    const r = target.getBoundingClientRect();
    const attrs = {};
    for (const a of ["id", "name", "type", "role", "aria-label", "title", "href", "placeholder", ...TEST_ATTRS]) {
      const v = target.getAttribute(a);
      if (v) attrs[a] = trunc(v, 200);
    }
    return {
      selector: selectorFor(target),
      tag: target.tagName.toLowerCase(),
      text: trunc((target.innerText || target.value || "").trim().replace(/\s+/g, " "), 120) || undefined,
      classes: target.classList.length ? trunc(target.className, 200) : undefined,
      attrs: Object.keys(attrs).length ? attrs : undefined,
      rect: { x: Math.round(r.x), y: Math.round(r.y), width: Math.round(r.width), height: Math.round(r.height) },
      components: componentChain(target),
      innerTarget: target !== el ? selectorFor(el) : undefined,
    };
  }

  // ---------- user actions ----------

  addEventListener("mouseover", (e) => (lastHover = e.target), { capture: true, passive: true });
  addEventListener(
    "click",
    (e) => record({ kind: "click", element: describe(e.target), x: e.clientX, y: e.clientY }),
    { capture: true, passive: true }
  );
  addEventListener(
    "change",
    (e) => {
      // Never record values, only which field changed.
      record({ kind: "input", element: describe(e.target) }, { stream: false });
    },
    { capture: true, passive: true }
  );

  // ---------- navigation ----------

  let lastUrl = location.href;
  const navCheck = (how) => {
    if (location.href === lastUrl) return;
    const from = lastUrl;
    lastUrl = location.href;
    record({ kind: "nav", how, from, title: document.title });
  };
  for (const fn of ["pushState", "replaceState"]) {
    const orig = history[fn];
    history[fn] = function (...args) {
      const result = orig.apply(this, args);
      navCheck(fn);
      return result;
    };
  }
  addEventListener("popstate", () => navCheck("popstate"));
  addEventListener("hashchange", () => navCheck("hashchange"));
  record({ kind: "nav", how: "load", from: document.referrer || null, title: document.title });

  // ---------- console + errors ----------

  const fmtArg = (a) => {
    if (a instanceof Error) return trunc(`${a.name}: ${a.message}\n${a.stack || ""}`, 1500);
    if (typeof a === "string") return trunc(a, 1000);
    try {
      return trunc(JSON.stringify(a), 1000);
    } catch {
      return trunc(String(a), 1000);
    }
  };
  for (const level of ["error", "warn"]) {
    const orig = console[level];
    console[level] = function (...args) {
      try {
        record({ kind: "console", level, message: args.map(fmtArg).join(" ") });
      } catch {}
      return orig.apply(this, args);
    };
  }
  addEventListener("error", (e) => {
    if (e.target && e.target !== window && e.target.tagName) {
      // resource failed to load (<img>, <script>, …)
      record({ kind: "error", type: "resource", source: e.target.src || e.target.href, tag: e.target.tagName.toLowerCase() });
    } else {
      record({ kind: "error", type: "exception", message: trunc(e.message, 1000), source: `${e.filename}:${e.lineno}:${e.colno}`, stack: e.error && trunc(e.error.stack, 1500) });
    }
  }, true);
  addEventListener("unhandledrejection", (e) => {
    record({ kind: "error", type: "unhandledrejection", message: fmtArg(e.reason) });
  });

  // ---------- network ----------
  // Every request goes into the ring; only failures and slow ones are streamed.

  function recordRequest(info) {
    const bad = info.error || info.status >= 400 || info.status === 0;
    const slow = info.ms >= SLOW_MS;
    record({ kind: "request", ...info, slow: slow || undefined }, { stream: bad || slow });
  }

  const origFetch = window.fetch;
  if (origFetch) {
    window.fetch = async function (input, init) {
      const start = performance.now();
      const method = (init && init.method) || (input && input.method) || "GET";
      const rawUrl = typeof input === "string" ? input : input && input.url ? input.url : String(input);
      const url = new URL(rawUrl, location.href).href;
      try {
        const res = await origFetch.apply(this, arguments);
        const info = { method: method.toUpperCase(), requestUrl: url, status: res.status, ms: Math.round(performance.now() - start) };
        if (!res.ok) {
          res.clone().text().then(
            (body) => recordRequest({ ...info, body: trunc(body, 800) }),
            () => recordRequest(info)
          );
        } else {
          recordRequest(info);
        }
        return res;
      } catch (err) {
        recordRequest({ method: method.toUpperCase(), requestUrl: url, status: 0, error: fmtArg(err), ms: Math.round(performance.now() - start) });
        throw err;
      }
    };
  }

  const XHR = XMLHttpRequest.prototype;
  const origOpen = XHR.open;
  const origSend = XHR.send;
  XHR.open = function (method, url) {
    this.__cr = { method: String(method).toUpperCase(), requestUrl: new URL(String(url), location.href).href };
    return origOpen.apply(this, arguments);
  };
  XHR.send = function () {
    const meta = this.__cr;
    if (meta) {
      const start = performance.now();
      this.addEventListener("loadend", () => {
        const info = { ...meta, status: this.status, ms: Math.round(performance.now() - start) };
        if (this.status >= 400) {
          try {
            info.body = trunc(this.responseType === "" || this.responseType === "text" ? this.responseText : "", 800);
          } catch {}
        }
        recordRequest(info);
      });
    }
    return origSend.apply(this, arguments);
  };

  // ---------- snapshot on demand ----------

  function snapshot() {
    const active = document.activeElement;
    const selection = String(getSelection() || "").trim();
    const hovered = describe(lastHover);
    const focused = active && active !== document.body ? describe(active) : null;
    return {
      url: location.href,
      title: document.title,
      viewport: { width: innerWidth, height: innerHeight, dpr: devicePixelRatio, scrollX: Math.round(scrollX), scrollY: Math.round(scrollY) },
      // Where the page sits on screen, so a screen-space region can be mapped back to page coordinates.
      window: { screenX, screenY, outerWidth, outerHeight },
      hovered,
      focused: focused && focused.selector !== (hovered && hovered.selector) ? focused : undefined,
      selection: selection ? trunc(selection, 500) : undefined,
      recent: ring.slice(-40),
    };
  }

  addEventListener("message", (e) => {
    if (e.source !== window || !e.data || e.data.source !== SRC_RELAY || e.data.type !== "snapshot") return;
    let data;
    try {
      data = snapshot();
    } catch (err) {
      data = { error: String(err) };
    }
    window.postMessage({ source: SRC_PAGE, type: "snapshot-result", id: e.data.id, data }, "*");
  });
})();
