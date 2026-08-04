-- SpendSmart AI access accounts.
--
-- This database exists only to decide who may call the AI routes. No expense
-- data is stored here: the app keeps that on-device, encrypted.
--
-- This migration reproduces the schema that is ALREADY live (it is the former
-- schema.sql verbatim). Every statement is IF NOT EXISTS, so applying it to
-- the deployed database is a no-op that only records the migration row.

CREATE TABLE IF NOT EXISTS users (
  id            TEXT PRIMARY KEY,
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,          -- PBKDF2-SHA256, base64
  password_salt TEXT NOT NULL,          -- base64
  display_name  TEXT,
  created_at    INTEGER NOT NULL,       -- epoch ms
  revoked       INTEGER NOT NULL DEFAULT 0
);

-- Only the SHA-256 of a bearer token is stored, so a dump of this table
-- yields nothing that can be replayed against the API.
CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expiry ON sessions(expires_at);

-- One row per user per UTC day. This is the spend ceiling: without it a
-- leaked credential could drain the OpenRouter quota unnoticed.
CREATE TABLE IF NOT EXISTS usage (
  user_id TEXT NOT NULL,
  day     TEXT NOT NULL,                -- 'YYYY-MM-DD' UTC
  calls   INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, day),
  FOREIGN KEY (user_id) REFERENCES users(id)
);
