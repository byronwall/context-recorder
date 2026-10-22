/** Bindings and vars from wrangler.jsonc, plus .dev.vars / secrets. */
export interface AppEnv {
  ASSETS: Fetcher;
  BUCKET: R2Bucket;
  DB: D1Database;
  /** Reserved for workers-oauth-provider (milestone 5). */
  OAUTH_KV: KVNamespace;
  ACCESS_TEAM_DOMAIN: string;
  ACCESS_AUD: string;
  FRAMES?: string;
  /** Local only. When set, it is the identity and no Access JWT is required. */
  DEV_IDENTITY?: string;
  /** HMAC key for /f/* signed URLs. Secret in production. */
  SIGNING_SECRET?: string;
}

declare global {
  namespace Cloudflare {
    interface Env extends AppEnv {
      /** Test-only: D1 migrations read by vitest.config.ts. */
      TEST_MIGRATIONS?: import("cloudflare:test").D1Migration[];
    }
  }
}
