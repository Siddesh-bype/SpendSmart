import assert from "node:assert/strict";

import {
  authConstants,
  constantTimeEquals,
  generateSalt,
  generateSessionToken,
  hashPassword,
  isValidEmail,
  isValidPassword,
  normalizeEmail,
  sha256,
  utcDay,
} from "../src/auth.ts";

// --- password hashing ---

const salt = generateSalt();
const hash = await hashPassword("correct-horse", salt);

assert.equal(
  await hashPassword("correct-horse", salt),
  hash,
  "same password and salt is deterministic",
);
assert.notEqual(
  await hashPassword("wrong-horse", salt),
  hash,
  "a different password yields a different digest",
);
assert.notEqual(
  await hashPassword("correct-horse", generateSalt()),
  hash,
  "a different salt yields a different digest -- no shared rainbow table",
);
assert.ok(!hash.includes("correct-horse"), "digest does not embed the password");

// Unicode must survive the UTF-8 round-trip, or those users cannot log back in.
const unicodeSalt = generateSalt();
assert.equal(
  await hashPassword("pässwörd-日本語-🔐", unicodeSalt),
  await hashPassword("pässwörd-日本語-🔐", unicodeSalt),
);

// --- salts and tokens ---

const salts = new Set(Array.from({ length: 50 }, () => generateSalt()));
assert.equal(salts.size, 50, "salt generator repeated");

const tokens = new Set(Array.from({ length: 50 }, () => generateSessionToken()));
assert.equal(tokens.size, 50, "session token generator repeated");

for (const token of tokens) {
  assert.ok(
    /^[A-Za-z0-9_-]+$/.test(token),
    `token must be URL-safe, got ${token}`,
  );
  assert.ok(token.length >= 40, "token is shorter than 32 bytes of entropy");
}

// The stored value must not be the token itself.
const token = generateSessionToken();
const digest = await sha256(token);
assert.notEqual(digest, token, "sessions must store a hash, not the token");
assert.equal(await sha256(token), digest, "hashing is deterministic");

// --- email validation ---

for (const good of [
  "a@b.co",
  "user@example.com",
  "first.last+tag@sub.domain.org",
]) {
  assert.equal(isValidEmail(good), true, `${good} should be valid`);
}
for (const bad of [
  "",
  "no-at-sign",
  "@leading.com",
  "trailing@",
  "has space@x.com",
  null,
  42,
  `${"a".repeat(250)}@example.com`,
]) {
  assert.equal(isValidEmail(bad), false, `${String(bad)} should be rejected`);
}

assert.equal(normalizeEmail("  User@Example.COM  "), "user@example.com");

// --- password rules ---

assert.equal(isValidPassword("a".repeat(authConstants.minPasswordLength)), true);
assert.equal(
  isValidPassword("a".repeat(authConstants.minPasswordLength - 1)),
  false,
  "below the minimum length is rejected",
);
assert.equal(
  isValidPassword("a".repeat(authConstants.maxPasswordLength + 1)),
  false,
  "an unbounded password would let a client burn CPU on PBKDF2",
);
assert.equal(isValidPassword(null), false);

// --- constant-time comparison ---

assert.equal(constantTimeEquals("abc", "abc"), true);
assert.equal(constantTimeEquals("abc", "abd"), false);
assert.equal(constantTimeEquals("abc", "ab"), false);
assert.equal(constantTimeEquals("", ""), true);

// --- quota day bucketing ---

assert.equal(utcDay(Date.UTC(2026, 7, 1, 12, 0, 0)), "2026-08-01");
assert.equal(
  utcDay(Date.UTC(2026, 7, 1, 23, 59, 59)),
  "2026-08-01",
  "the last second of a UTC day stays in that day",
);
assert.equal(
  utcDay(Date.UTC(2026, 7, 2, 0, 0, 0)),
  "2026-08-02",
  "midnight UTC starts a new quota day",
);

// Login uses one message for "no such account" and "wrong password", so it
// cannot be used to discover which addresses are registered. Signup is exempt:
// it has to tell the user the address is taken or the form is unusable.
assert.equal(authConstants.credentialsError, "Incorrect email or password.");

console.log("auth_test: ok");
