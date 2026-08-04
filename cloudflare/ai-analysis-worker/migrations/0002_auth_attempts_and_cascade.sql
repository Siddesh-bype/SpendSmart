-- Auth-route throttling, and ON DELETE CASCADE on the child tables.
--
-- 1. auth_attempts backs the in-Worker throttle on /auth/signup and
--    /auth/login (see src/auth.ts throttle). One row per (identifier, window)
--    rather than per attempt, so the throttle costs one upsert.
-- 2. sessions.user_id and usage.user_id gained ON DELETE CASCADE. SQLite
--    cannot ALTER a foreign key, so both tables are rebuilt. Neither is
--    referenced by anything else, so nothing points at the copies.

CREATE TABLE IF NOT EXISTS auth_attempts (
  identifier   TEXT NOT NULL,            -- 'ip:<addr>' or 'email:<normalized>'
  window_start INTEGER NOT NULL,         -- epoch ms, floored to the window
  attempts     INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (identifier, window_start)
);

-- Lets the cron sweep spent windows without a full scan.
CREATE INDEX IF NOT EXISTS idx_auth_attempts_window
  ON auth_attempts(window_start);

CREATE TABLE sessions_new (
  token_hash TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
INSERT INTO sessions_new (token_hash, user_id, created_at, expires_at)
  SELECT token_hash, user_id, created_at, expires_at FROM sessions;
DROP TABLE sessions;
ALTER TABLE sessions_new RENAME TO sessions;
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expiry ON sessions(expires_at);

CREATE TABLE usage_new (
  user_id TEXT NOT NULL,
  day     TEXT NOT NULL,
  calls   INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, day),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
INSERT INTO usage_new (user_id, day, calls)
  SELECT user_id, day, calls FROM usage;
DROP TABLE usage;
ALTER TABLE usage_new RENAME TO usage;

-- The cron deletes usage older than the retention period (90 days, see
-- authConstants.usageRetentionDays) by day string.
CREATE INDEX IF NOT EXISTS idx_usage_day ON usage(day);
