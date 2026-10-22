export class HttpError extends Error {
  constructor(
    readonly status: number,
    message: string,
    readonly extra?: Record<string, unknown>,
  ) {
    super(message);
  }
}

export const json = (body: unknown, init: ResponseInit = {}): Response =>
  new Response(JSON.stringify(body), {
    ...init,
    headers: { "content-type": "application/json; charset=utf-8", ...(init.headers as Record<string, string>) },
  });

export const errorResponse = (e: unknown): Response => {
  if (e instanceof HttpError) return json({ error: e.message, ...e.extra }, { status: e.status });
  console.error(e);
  return json({ error: "internal error" }, { status: 500 });
};

/**
 * CORS-"simple" content types can be sent cross-site without a preflight, so a page elsewhere could
 * otherwise POST to the API with the user's Access cookie. JSON (or no type) is required instead.
 */
export function assertNotSimpleForm(request: Request): void {
  const type = (request.headers.get("content-type") || "").split(";")[0]!.trim().toLowerCase();
  if (type === "text/plain" || type === "application/x-www-form-urlencoded" || type === "multipart/form-data") {
    throw new HttpError(415, "send JSON with content-type: application/json");
  }
}

export async function readJson(request: Request): Promise<{ text: string; value: unknown }> {
  assertNotSimpleForm(request);
  const text = await request.text();
  try {
    return { text, value: JSON.parse(text) };
  } catch {
    throw new HttpError(400, "body is not valid JSON");
  }
}

export const toHex = (buf: ArrayBuffer): string =>
  [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");

export async function sha256Hex(text: string | ArrayBuffer | Uint8Array): Promise<string> {
  const data = typeof text === "string" ? new TextEncoder().encode(text) : text;
  return toHex(await crypto.subtle.digest("SHA-256", data));
}

export const escapeHtml = (s: unknown): string =>
  String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
