import type { OAuthHelpers } from "@cloudflare/workers-oauth-provider";
import type { AppEnv } from "./env";
import { HttpError, json, readJson, sha256Hex } from "./http";
import type { Identity } from "./identity";
import { assertSessionId, parseManifest, SHA256 } from "./manifest";
import { Store } from "./store";

/** /api/* routes (docs/cloud-sessions.md §2). Returns null when nothing matched. */
export async function handleApi(request: Request, env: AppEnv, identity: Identity, url: URL): Promise<Response | null> {
  const store = new Store(env);
  const parts = url.pathname.split("/").slice(2).map(decodeURIComponent); // after "/api"
  const method = request.method;

  if (parts[0] === "me" && parts.length === 1 && method === "GET") return json({ id: identity.id, via: identity.via });

  // Signed-in devices and agents (docs/cloud-sessions.md §6): one OAuth grant each.
  if (parts[0] === "grants") {
    const oauth = (env as AppEnv & { OAUTH_PROVIDER?: OAuthHelpers }).OAUTH_PROVIDER;
    if (!oauth) throw new HttpError(501, "sign-in is not available here");
    if (parts.length === 1 && method === "GET") return json(await listGrants(oauth, identity.id));
    if (parts.length === 3 && parts[2] === "revoke" && method === "POST") {
      await oauth.revokeGrant(parts[1]!, identity.id);
      return new Response(null, { status: 204 });
    }
  }

  if (parts[0] === "sessions") {
    if (parts.length === 1 && method === "GET") return json(await store.listSessions());
    const id = parts[1]!;
    assertSessionId(id);
    if (parts.length === 3 && parts[2] === "push" && method === "POST") {
      const { value } = await readJson(request);
      const manifest = parseManifest(value, id);
      return json({ missing: await store.missing(manifest.files.map((f) => f.sha256)) });
    }
    if (parts.length === 3 && parts[2] === "commit" && method === "POST") {
      const { text, value } = await readJson(request);
      const manifest = parseManifest(value, id);
      const manifestSha256 = await sha256Hex(text);
      // If-Match: "<manifestSha256>" commits only over that version (412 otherwise); absent, it always replaces.
      const ifMatch = request.headers.get("if-match")?.trim().replace(/^W\//, "").replace(/^"|"$/g, "");
      await store.commit(manifest, text, manifestSha256, identity.id, ifMatch || undefined);
      return json({ url: `${url.origin}/s/${encodeURIComponent(id)}/`, manifestSha256 });
    }
    if (parts.length === 2 && method === "GET") {
      const row = await store.getSession(id);
      if (!row) throw new HttpError(404, "no such session");
      const { manifestText, manifestSha256: _sha, ...rest } = row;
      return json({ ...rest, manifest: JSON.parse(manifestText) });
    }
    if (parts.length === 2 && method === "DELETE") {
      if (!(await store.deleteSession(id))) throw new HttpError(404, "no such session");
      return new Response(null, { status: 204 });
    }
  }

  if (parts[0] === "blobs" && parts[1] !== undefined) {
    const sha = parts[1];
    if (!SHA256.test(sha)) throw new HttpError(400, "invalid sha256");
    if (parts.length === 2 && method === "PUT") {
      await store.putBlob(sha, request);
      return new Response(null, { status: 204 });
    }
    if (parts.length === 3 && parts[2] === "uploads" && method === "POST") {
      return json({ uploadId: await store.createUpload(sha) });
    }
    const uploadId = parts[3];
    if (parts[2] === "uploads" && uploadId) {
      if (parts.length === 5 && parts[4] === "complete" && method === "POST") {
        const { value } = await readJson(request);
        const list = (value as { parts?: unknown })?.parts;
        if (!Array.isArray(list) || !list.length) throw new HttpError(400, "parts must be a non-empty array");
        const uploaded = list.map((p: { partNumber?: unknown; etag?: unknown }) => {
          if (!Number.isInteger(p?.partNumber) || typeof p?.etag !== "string") throw new HttpError(400, "each part needs partNumber and etag");
          return { partNumber: p.partNumber as number, etag: p.etag };
        });
        await store.completeUpload(sha, uploadId, uploaded);
        return new Response(null, { status: 204 });
      }
      if (parts.length === 5 && method === "PUT") {
        const partNumber = Number(parts[4]);
        if (!Number.isInteger(partNumber) || partNumber < 1 || partNumber > 10000) throw new HttpError(400, "invalid part number");
        return json({ etag: await store.uploadPart(sha, uploadId, partNumber, request) });
      }
    }
  }
  return null;
}

export interface GrantRow {
  id: string;
  clientId: string;
  name: string;
  createdAt: number;
}

export async function listGrants(oauth: OAuthHelpers, userId: string): Promise<GrantRow[]> {
  const rows: GrantRow[] = [];
  let cursor: string | undefined;
  do {
    const page = await oauth.listUserGrants(userId, { cursor });
    for (const g of page.items) rows.push({ id: g.id, clientId: g.clientId, name: g.metadata?.label || g.clientId, createdAt: g.createdAt });
    cursor = page.cursor;
  } while (cursor);
  return rows.sort((a, b) => b.createdAt - a.createdAt);
}
