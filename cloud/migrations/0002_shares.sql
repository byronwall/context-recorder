-- Share links (docs/cloud-sessions.md §8): a random token that opens one session read-only, without sign-in.
CREATE TABLE shares (
  token TEXT PRIMARY KEY,
  session_id TEXT NOT NULL REFERENCES sessions (id) ON DELETE CASCADE,
  label TEXT,
  created_at TEXT NOT NULL,
  created_by TEXT NOT NULL,
  revoked_at TEXT
);
CREATE INDEX shares_session ON shares (session_id);
