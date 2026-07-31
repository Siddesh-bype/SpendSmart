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
  } catch {
    // UNIQUE violation: the address is taken. Reported to the caller as the
    // same generic failure as a bad password, so signup cannot be used to
    // discover which emails exist.
    return null;
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
/// stale count and collectively overshoot the limit.
export async function consumeQuota(
  env: AuthEnv,
  userId: string,
  limit: number = defaultDailyLimit,
): Promise<{ allowed: boolean; calls: number; limit: number }> {
  const day = utcDay();
  await env.DB.prepare(
    `INSERT INTO usage (user_id, day, calls) VALUES (?, ?, 1)
     ON CONFLICT(user_id, day) DO UPDATE SET calls = calls + 1`,
  )
    .bind(userId, day)
    .run();

  const row = await env.DB.prepare(
    `SELECT calls FROM usage WHERE user_id = ? AND day = ?`,
  )
    .bind(userId, day)
    .first<{ calls: number }>();

  const calls = row?.calls ?? 0;
  return { allowed: calls <= limit, calls, limit };
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
};
