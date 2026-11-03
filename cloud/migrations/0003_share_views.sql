-- One row per page load of a share link (docs/cloud-sessions.md §8). No IP address is kept.
CREATE TABLE share_views (
  token TEXT NOT NULL REFERENCES shares (token) ON DELETE CASCADE,
  viewed_at TEXT NOT NULL,
  viewer TEXT NOT NULL,
  country TEXT,
  region TEXT,
  city TEXT,
  referrer TEXT,
  device TEXT
);
CREATE INDEX share_views_token ON share_views (token, viewed_at DESC);
