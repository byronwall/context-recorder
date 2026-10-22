/**
 * Mark Markdown for MCP, ported from markdownFor() in scripts/viewer.html (cloud mode). Keep the two
 * in sync: get_session/get_mark must return the same text as the viewer's Copy as Markdown at /s/:id/.
 * Links are absolute `<origin>/s/<id>/<path>` URLs, as the viewer builds with new URL(path, location.href).
 */
import type { Manifest } from "./manifest";

export interface Mark {
  index: number;
  offsetSeconds: number;
  kind?: string;
  image?: string;
  frame?: string;
  screenshot?: string;
  narration?: string;
  context?: { appName?: string; bundleID?: string; windowTitle?: string; browserURL?: string; browserTitle?: string };
  browser?: any;
  [key: string]: unknown;
}

export interface SessionJson {
  name?: string;
  duration?: number;
  marks?: Mark[];
  [key: string]: unknown;
}

export const fmt = (s: number | undefined): string => {
  const t = Math.max(0, Math.floor(s || 0));
  return `${Math.floor(t / 60)}:${String(t % 60).padStart(2, "0")}`;
};

const isProblem = (e: any) =>
  e.kind === "console" || e.kind === "error" || (e.kind === "request" && (e.error || e.status >= 400 || e.status === 0 || e.slow));

const pageEventText = (e: any): string => {
  if (e.kind === "click") return `click ${e.element?.selector || ""}${e.element?.text ? ` “${e.element.text}”` : ""}`;
  if (e.kind === "nav") return `${e.how} → ${e.url}`;
  if (e.kind === "console") return `console.${e.level}: ${e.message}`;
  if (e.kind === "error") return `${e.type}: ${e.message || e.source}`;
  if (e.kind === "request")
    return `${e.method} ${e.requestUrl} → ${e.status} (${e.ms} ms)${e.error ? " " + e.error : ""}${e.body ? " — " + e.body : ""}`;
  return JSON.stringify(e);
};

const sourceText = (src: any): string =>
  src && src.file
    ? `${src.file}${src.line ? ":" + src.line : ""}${src.column ? ":" + src.column : ""}${src.via === "react-debugStack" ? " (post-transform line)" : ""}`
    : "";

export const titleOf = (m: Mark): string => {
  const said = (m.narration || "").split("⚑")[0]!.trim();
  const last = said.split(/(?<=[.!?])\s+/).filter(Boolean).pop();
  return last || m.context?.browserTitle || m.context?.windowTitle || m.context?.appName || `Mark ${m.index}`;
};

export interface MarkdownContext {
  /** `<origin>/s/<id>/` — the viewer page URL that relative paths resolve against. */
  base: string;
  manifest: Manifest;
}

export const cloudURL = (ctx: MarkdownContext, path: string): string => new URL(path, ctx.base).href;

export function markdownFor(m: Mark, ctx: MarkdownContext): string {
  const c = m.context || {};
  const videoPath = ctx.manifest.video?.path || "recording.mp4";
  const skipped = new Set((ctx.manifest.skippedPages || []).map((p) => p.path));
  return [
    `## ${String(m.index).padStart(3, "0")} · ${fmt(m.offsetSeconds)} · ${titleOf(m)}`,
    "",
    `![mark ${m.index}](${m.image ? cloudURL(ctx, m.image) : ""})`,
    "",
    m.narration ? `> ${m.narration}\n` : "",
    c.appName && `- **App:** ${c.appName} (\`${c.bundleID}\`)`,
    c.windowTitle && `- **Window:** ${c.windowTitle}`,
    c.browserURL && `- **URL:** ${c.browserURL}`,
    c.browserTitle && `- **Page title:** ${c.browserTitle}`,
    `- **Video:** \`${cloudURL(ctx, videoPath)}\` @ ${m.offsetSeconds.toFixed(1)}s`,
    m.browser?.hovered &&
      `- **Under mouse:** \`${m.browser.hovered.selector}\`${m.browser.hovered.text ? ` “${m.browser.hovered.text}”` : ""}${m.browser.hovered.components ? ` in ${[...m.browser.hovered.components].slice(0, 5).reverse().join(" › ")}` : ""}`,
    m.browser?.hovered?.source && `- **Source:** \`${sourceText(m.browser.hovered.source)}\``,
    m.browser?.focused && `- **Focused:** \`${m.browser.focused.selector}\``,
    ...(m.browser?.region?.elements || [])
      .slice(0, 15)
      .map(
        (el: any) =>
          `- In region: \`${el.selector}\`${el.text ? ` “${el.text.slice(0, 80)}”` : ""}${el.source ? ` · ${sourceText(el.source)}` : ""}`,
      ),
    m.browser?.pageFile &&
      (skipped.has(m.browser.pageFile)
        ? `- **Saved page:** not uploaded (\`${m.browser.pageFile}\` is only in the local session)`
        : `- **Saved page:** \`${cloudURL(ctx, m.browser.pageFile)}\``),
    ...(m.browser?.recent || []).filter(isProblem).slice(-8).map((e: any) => `- ⚠ ${pageEventText(e)}`),
  ]
    .filter((x) => x !== undefined && x !== null && x !== false)
    .join("\n");
}

/** The viewer's "Copy all as Markdown" text. */
export function sessionMarkdown(session: SessionJson, ctx: MarkdownContext): string {
  const heading = ctx.manifest.title ? ctx.manifest.title : `Session ${session.name}`;
  return `# ${heading}\n\n` + (session.marks || []).map((m) => markdownFor(m, ctx)).join("\n\n");
}
