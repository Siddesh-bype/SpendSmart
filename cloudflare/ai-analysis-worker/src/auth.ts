/// Account handling for AI access.
///
/// This module decides *who* may call the AI routes. It stores no expense
/// data -- the app keeps that on-device, encrypted.

export interface AuthEnv {
  DB: D1Database;
}

export interface SessionUser {
  id: string;
  email: string;
  displayName: string | null;
}

const pbkdf2Iterations = 100_000;
const sessionDays = 90;
const defaultDailyLimit = 50;
const maxEmailLength = 254;
const minPasswordLength = 8;
const maxPasswordLength = 200;
/// Usage rows are kept long enough to answer "why was I charged" and to spot
/// abuse, then dropped. Nothing downstream reads a row older than today.
const usageRetentionDays = 90;
/// Throttle window for the unauthenticated auth routes. Short on purpose: it
/// blunts a flood without locking a real user out for long after a typo.
const authWindowSeconds = 60;
/// Per-window ceilings. The IP bound is looser because a household, an office,
/// or a carrier NAT shares one address; the email bound is what actually stops
/// a password-guessing run against a single account.
const authIpAttemptsPerWindow = 20;
const authEmailAttemptsPerWindow = 6;

/// Deliberately identical for "no such account" and "wrong password". A
/// distinct message would let anyone enumerate which emails are registered.
const credentialsError = "Incorrect email or password.";

export async function hashPassword(
  password: string,
  saltBase64: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const bits = await crypto.subtle.deriveBits(
    {
      name: "PBKDF2",
      salt: base64ToBytes(saltBase64),
      iterations: pbkdf2Iterations,
      hash: "SHA-256",
    },
    key,
    256,
  );
  return bytesToBase64(new Uint8Array(bits));
}

export function generateSalt(): string {
  return bytesToBase64(crypto.getRandomValues(new Uint8Array(16)));
}

/// 32 random bytes. Only its SHA-256 is persisted, so the raw value exists
/// solely in the response to the client.
export function generateSessionToken(): string {
  return bytesToBase64Url(crypto.getRandomValues(new Uint8Array(32)));
}

export async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return bytesToBase64(new Uint8Array(digest));
}

/// Rejects on length only. Anything that parses as an address is accepted --
/// over-strict patterns reject valid real-world addresses.
export function isValidEmail(value: unknown): value is string {
  if (typeof value !== "string") return false;
  const email = value.trim();
  if (email.length < 3 || email.length > maxEmailLength) return false;
  const at = email.indexOf("@");
  return at > 0 && at < email.length - 1 && !email.includes(" ");
}

export function isValidPassword(value: unknown): value is string {
  return (
    typeof value === "string" &&
    value.length >= minPasswordLength &&
    value.length <= maxPasswordLength
  );
}

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

/// True only for a real UNIQUE-constraint rejection. D1 surfaces the SQLite
/// message verbatim ("UNIQUE constraint failed: users.email"), sometimes
/// wrapped in "D1_ERROR: ...". Everything else -- missing table, unbound
/// binding, D1 outage -- must NOT be reported as a duplicate email.
function isUniqueViolation(exception: unknown): boolean {
  const message = exception instanceof Error ? exception.message : String(exception);
  return /UNIQUE constraint failed/i.test(message);
}

/// Thrown when the database itself is unreachable or broken, so the route can
/// answer 503 rather than inventing a reason the request failed.
export class StorageError extends Error {
  constructor(operation: string) {
    super(`storage unavailable: ${operation}`);
    this.name = "StorageError";
  }
}

/// Returns null only when the email is already registered. Any other database
/// failure throws StorageError.
export async function createUser(
  env: AuthEnv,
  email: string,
  password: string,
  displayName: string | null,
): Promise<{ token: string; expiresAt: number } | null> {
  const salt = generateSalt();
  const hash = await hashPassword(password, salt);
  const id = crypto.randomUUID();
  const now = Date.now();

  try {
    await env.DB.prepare(
      `INSERT INTO users (id, email, password_hash, password_salt, display_name, created_at, revoked)
       VALUES (?, ?, ?, ?, ?, ?, 0)`,
    )
      .bind(id, normalizeEmail(email), hash, salt, displayName, now)
      .run();
  } catch (exception) {
    if (isUniqueViolation(exception)) return null;
    // The signup route turns null into a specific "email already taken"
    // message -- deliberately, because a signup form that will not say the
    // address is taken is unusable. So every other failure has to be a
    // different signal, or an outage masquerades as a duplicate account.
    throw new StorageError("createUser");
  }

  return issueSession(env, id);
}

export async function authenticate(
  env: AuthEnv,
  email: string,
  password: string,
): Promise<{ token: string; expiresAt: number } | null> {
  const row = await env.DB.prepare(
    `SELECT id, password_hash, password_salt, revoked FROM users WHERE email = ?`,
  )
    .bind(normalizeEmail(email))
    .first<{
      id: string;
      password_hash: string;
      password_salt: string;
      revoked: number;
    }>();

  // Hash even when the user is missing, so a nonexistent account does not
  // answer measurably faster than a wrong password.
  const salt = row?.password_salt ?? generateSalt();
  const attempt = await hashPassword(password, salt);
  if (!row || row.revoked === 1) return null;
  if (!constantTimeEquals(attempt, row.password_hash)) return null;

  return issueSession(env, row.id);
}

async function issueSession(
  env: AuthEnv,
  userId: string,
): Promise<{ token: string; expiresAt: number }> {
  const token = generateSessionToken();
  const now = Date.now();
  const expiresAt = now + sessionDays * 24 * 60 * 60 * 1000;

  await env.DB.prepare(
    `INSERT INTO sessions (token_hash, user_id, created_at, expires_at)
     VALUES (?, ?, ?, ?)`,
  )
    .bind(await sha256(token), userId, now, expiresAt)
    .run();

  return { token, expiresAt };
}

/// Resolves a bearer token to its user, or null when it is unknown, expired,
/// or belongs to a revoked account.
export async function resolveSession(
  env: AuthEnv,
  token: string,
): Promise<SessionUser | null> {
  const row = await env.DB.prepare(
    `SELECT u.id, u.email, u.display_name, s.expires_at, u.revoked
       FROM sessions s JOIN users u ON u.id = s.user_id
      WHERE s.token_hash = ?`,
  )
    .bind(await sha256(token))
    .first<{
      id: string;
      email: string;
      display_name: string | null;
      expires_at: number;
      revoked: number;
    }>();

  if (!row || row.revoked === 1) return null;
  if (row.expires_at < Date.now()) return null;
  return { id: row.id, email: row.email, displayName: row.display_name };
}

export async function revokeSession(env: AuthEnv, token: string): Promise<void> {
  await env.DB.prepare(`DELETE FROM sessions WHERE token_hash = ?`)
    .bind(await sha256(token))
    .run();
}

export function utcDay(now: number = Date.now()): string {
  return new Date(now).toISOString().slice(0, 10);
}

/// Increments today's counter and reports whether the call is allowed.
///
/// Increment-then-check, so a burst of concurrent requests cannot each read a
/// stale count and collectively overshoot the limit. The `WHERE calls < limit`
/// guard stops the counter at the ceiling, so a client that keeps hammering a
/// spent quota cannot push `/auth/me` above the limit it reports. `RETURNING`
/// gives the new value from the same statement; a follow-up SELECT would be a
/// second round trip that could read a value another request had moved.
export async function consumeQuota(
  env: AuthEnv,
  userId: string,
  limit: number = defaultDailyLimit,
): Promise<{ allowed: boolean; calls: number; limit: number }> {
  const row = await env.DB.prepare(
    `INSERT INTO usage (user_id, day, calls) VALUES (?, ?, 1)
     ON CONFLICT(user_id, day) DO UPDATE SET calls = calls + 1
       WHERE calls < ?
     RETURNING calls`,
  )
    .bind(userId, utcDay(), limit)
    .first<{ calls: number }>();

  // No row means the guard blocked the update: already at the ceiling.
  if (!row) return { allowed: false, calls: limit, limit };
  return { allowed: true, calls: row.calls, limit };
}

/// Gives a consumed call back.
///
/// Used when the upstream model never answered: the user got nothing, so
/// charging them for it would let an OpenRouter outage silently eat a day's
/// allowance. Clamped at zero -- a refund racing the midnight rollover must
/// not drive the new day negative and hand out free calls.
export async function releaseQuota(env: AuthEnv, userId: string): Promise<void> {
  await env.DB.prepare(
    `UPDATE usage SET calls = calls - 1
      WHERE user_id = ? AND day = ? AND calls > 0`,
  )
    .bind(userId, utcDay())
    .run();
}

export async function usageToday(
  env: AuthEnv,
  userId: string,
): Promise<number> {
  const row = await env.DB.prepare(
    `SELECT calls FROM usage WHERE user_id = ? AND day = ?`,
  )
    .bind(userId, utcDay())
    .first<{ calls: number }>();
  return row?.calls ?? 0;
}

/// Throttles the unauthenticated auth routes.
///
/// /auth/signup and /auth/login each run a 100k-iteration PBKDF2, which is
/// expensive on purpose -- that makes them a CPU amplifier for anyone who can
/// call them in a loop. A Cloudflare rate-limit rule is the real defence (see
/// README) but it lives in the dashboard, outside this repo, so it is not a
/// deployment guarantee. This is the in-Worker floor underneath it.
///
/// ponytail: one D1 row per (identifier, window) rather than per attempt, so
/// the throttle is a single upsert, not an append. That write is far cheaper
/// than the PBKDF2 it guards, and it runs BEFORE the hash, so the flood it is
/// meant to stop never reaches the expensive part. If D1 write volume ever
/// becomes the bottleneck, swap the body of this function for a Workers
/// Rate Limiting binding (`ratelimits` in wrangler.jsonc) -- same signature.
export async function throttle(
  env: AuthEnv,
  identifier: string,
  limit: number,
  now: number = Date.now(),
): Promise<{ allowed: boolean; retryAfterSeconds: number }> {
  const windowMs = authWindowSeconds * 1000;
  const windowStart = Math.floor(now / windowMs) * windowMs;
  const retryAfterSeconds = Math.max(
    1,
    Math.ceil((windowStart + windowMs - now) / 1000),
  );

  let row: { attempts: number } | null = null;
  try {
    row = await env.DB.prepare(
      `INSERT INTO auth_attempts (identifier, window_start, attempts) VALUES (?, ?, 1)
       ON CONFLICT(identifier, window_start) DO UPDATE SET attempts = attempts + 1
         WHERE attempts < ?
       RETURNING attempts`,
    )
      .bind(identifier, windowStart, limit)
      .first<{ attempts: number }>();
  } catch {
    // Fail open. A throttle that 500s when its own table is missing would
    // take down login entirely; the dashboard rule still covers the flood.
    return { allowed: true, retryAfterSeconds };
  }

  return { allowed: row !== null, retryAfterSeconds };
}

/// Deletes rows nothing will read again: expired sessions, spent throttle
/// windows, and usage older than the retention period. Called from the cron
/// handler -- see wrangler.jsonc `triggers.crons`.
export async function cleanupExpired(
  env: AuthEnv,
  now: number = Date.now(),
): Promise<{ sessions: number; attempts: number; usage: number }> {
  const cutoffDay = utcDay(now - usageRetentionDays * 24 * 60 * 60 * 1000);
  const [sessions, attempts, usage] = await env.DB.batch([
    env.DB.prepare(`DELETE FROM sessions WHERE expires_at < ?`).bind(now),
    env.DB.prepare(`DELETE FROM auth_attempts WHERE window_start < ?`).bind(
      now - authWindowSeconds * 1000,
    ),
    env.DB.prepare(`DELETE FROM usage WHERE day < ?`).bind(cutoffDay),
  ]);
  const changes = (result: D1Result) => result.meta?.changes ?? 0;
  return {
    sessions: changes(sessions),
    attempts: changes(attempts),
    usage: changes(usage),
  };
}

export function constantTimeEquals(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let index = 0; index < a.length; index++) {
    difference |= a.charCodeAt(index) ^ b.charCodeAt(index);
  }
  return difference === 0;
}

function bytesToBase64(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes));
}

function bytesToBase64Url(bytes: Uint8Array): string {
  return bytesToBase64(bytes)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function base64ToBytes(value: string): Uint8Array {
  const binary = atob(value);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

export const authConstants = {
  credentialsError,
  defaultDailyLimit,
  minPasswordLength,
  maxPasswordLength,
  sessionDays,
  usageRetentionDays,
  authWindowSeconds,
  authIpAttemptsPerWindow,
  authEmailAttemptsPerWindow,
};
