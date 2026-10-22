-- Sessions: one row per pushed session, holding its current manifest exactly as the Mac sent it.
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  recorded_at TEXT NOT NULL,
  duration REAL NOT NULL,
  mark_count INTEGER NOT NULL,
  size INTEGER NOT NULL,
  poster TEXT,
  manifest TEXT NOT NULL,
  manifest_sha256 TEXT NOT NULL,
  pushed_at TEXT NOT NULL,
  pushed_by TEXT NOT NULL
);
CREATE INDEX sessions_recorded_at ON sessions (recorded_at DESC);

-- The manifest's `files`, one row per path, so /s/:id/<path> is one indexed lookup and blob GC is a query.
CREATE TABLE session_files (
  session_id TEXT NOT NULL REFERENCES sessions (id) ON DELETE CASCADE,
  path TEXT NOT NULL,
  sha256 TEXT NOT NULL,
  size INTEGER NOT NULL,
  type TEXT NOT NULL,
  PRIMARY KEY (session_id, path)
);
CREATE INDEX session_files_sha256 ON session_files (sha256);

-- Index of verified blobs in R2 (key blobs/<sha256>). Written only after the hash checks out.
CREATE TABLE blobs (
  sha256 TEXT PRIMARY KEY,
  size INTEGER NOT NULL,
  created_at TEXT NOT NULL
);
