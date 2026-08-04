/// Route-level tests for the Worker's `fetch` and `scheduled` handlers.
///
/// D1 is faked over `node:sqlite`, which ships with Node -- so the SQL, the
/// UNIQUE-constraint error text, `ON CONFLICT ... RETURNING`, and
/// `ON DELETE CASCADE` are all real, not stubbed. What that does NOT cover:
/// D1's own wire errors and result metadata beyond `meta.changes`, read
/// replication, and Miniflare's request lifecycle. Those need `wrangler dev`.

import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import { readFileSync } from "node:fs";

import worker, { limits } from "../src/index.ts";
import { authConstants, cleanupExpired, sha256 } from "../src/auth.ts";

const migrations = [
  "migrations/0001_init.sql",
  "migrations/0002_auth_attempts_and_cascade.sql",
];

/// Minimal stand-in for the D1 binding: prepare/bind/first/run/all + batch.
function makeDb() {
  const sqlite = new DatabaseSync(":memory:");
  sqlite.exec("PRAGMA foreign_keys = ON");
  for (const file of migrations) {
    sqlite.exec(readFileSync(new URL(`../${file}`, import.meta.url), "utf8"));
  }

  let broken: string | null = null;

  const statement = (sql: string, args: unknown[]) => ({
    async first() {
      if (broken) throw new Error(broken);
      return sqlite.prepare(sql).get(...(args as never[])) ?? null;
    },
    async run() {
      if (broken) throw new Error(broken);
      const result = sqlite.prepare(sql).run(...(args as never[]));
      return { success: true, meta: { changes: Number(result.changes) } };
    },
    async all() {
      if (broken) throw new Error(broken);
      return { results: sqlite.prepare(sql).all(...(args as never[])) };
    },
  });

  const db = {
    prepare(sql: string) {
      return {
        bind: (...args: unknown[]) => statement(sql, args),
        ...statement(sql, []),
      };
    },
    async batch(statements: Array<{ run(): Promise<unknown> }>) {
      const out = [];
      for (const one of statements) out.push(await one.run());
      return out;
    },
    /// Makes every subsequent query throw, to stand in for a D1 outage.
    breakWith(message: string) {
      broken = message;
    },
    heal() {
      broken = null;
    },
    raw: sqlite,
  };
  return db;
}

function makeEnv(overrides: Record<string, unknown> = {}) {
  return {
    DB: makeDb(),
    APP_PROXY_TOKEN: "a".repeat(40),
    OPENROUTER_API_KEY: "sk-test",
    ...overrides,
  } as never;
}

function post(path: string, body: unknown, headers: Record<string, string> = {}) {
  return new Request(`https://worker.test${path}`, {
    method: "POST",
    headers: { "CF-Connecting-IP": "203.0.113.1", ...headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

function get(path: string, headers: Record<string, string> = {}) {
  return new Request(`https://worker.test${path}`, { headers });
}

const call = (request: Request, env: unknown) =>
  worker.fetch(request, env as never);

const goodSignup = { email: "User@Example.com", password: "correct-horse", displayName: " Sid " };

// --- signup ---
{
  const env = makeEnv();
  const response = await call(post("/auth/signup", goodSignup), env);
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.email, "user@example.com", "email is normalized in the reply");
  assert.equal(body.displayName, "Sid", "display name is trimmed");
  assert.ok(body.token.length >= 40);
  assert.ok(body.expiresAt > Date.now());
  assert.equal(response.headers.get("Cache-Control"), "no-store");
  assert.equal(Object.hasOwn(body, "password"), false, "never echo the password");

  // Duplicate signup is a specific 409, not a generic credentials error.
  const duplicate = await call(post("/auth/signup", goodSignup), env);
  assert.equal(duplicate.status, 409);
  assert.match((await duplicate.json()).error, /already exists/);
}

// A real D1 failure must NOT be reported as a taken email -- finding 3.
{
  const env = makeEnv();
  env.DB.breakWith("D1_ERROR: no such table: users");
  const response = await call(post("/auth/signup", goodSignup), env);
  assert.equal(response.status, 503, "a missing table is an outage, not a conflict");
  const body = await response.json();
  assert.doesNotMatch(body.error, /already exists/);
  assert.doesNotMatch(body.error, /table|SQL|D1/i, "error body is sanitized");
}

// --- signup validation ---
{
  const env = makeEnv();
  for (const [payload, status] of [
    [{ email: "nope", password: "correct-horse" }, 400],
    [{ email: "a@b.co", password: "short" }, 400],
    [{ email: "a@b.co", password: "a".repeat(201) }, 400],
  ] as const) {
    assert.equal((await call(post("/auth/signup", payload), env)).status, status);
  }
  assert.equal(
    (await call(post("/auth/signup", "{not json"), env)).status,
    400,
    "malformed JSON is a 400, not a crash",
  );
}

// --- login ---
{
  const env = makeEnv();
  await call(post("/auth/signup", goodSignup), env);

  const ok = await call(
    post("/auth/login", { email: "  USER@example.com ", password: "correct-horse" }),
    env,
  );
  assert.equal(ok.status, 200, "login is case- and space-insensitive on email");
  assert.ok((await ok.json()).token);

  const wrong = await call(
    post("/auth/login", { email: "user@example.com", password: "wrong-horse" }),
    env,
  );
  assert.equal(wrong.status, 401);
  const wrongBody = await wrong.json();
  assert.equal(wrongBody.error, authConstants.credentialsError);

  // Unknown account, over-long password, and non-string password must all give
  // byte-identical replies to a wrong password -- finding 2.
  for (const payload of [
    { email: "nobody@example.com", password: "correct-horse" },
    { email: "user@example.com", password: "a".repeat(5000) },
    { email: "user@example.com", password: "short" },
    { email: "user@example.com", password: 12345 },
    { email: 42, password: "correct-horse" },
    { email: "no-at-sign", password: "correct-horse" },
  ]) {
    const response = await call(post("/auth/login", payload), env);
    assert.equal(response.status, 401, `${JSON.stringify(payload)} should be 401`);
    assert.deepEqual(
      await response.json(),
      wrongBody,
      "every login rejection has the identical body -- no enumeration signal",
    );
  }
}

// --- logout and session revocation ---
{
  const env = makeEnv();
  const { token } = await (await call(post("/auth/signup", goodSignup), env)).json();

  const before = await call(get("/auth/me", { authorization: `Bearer ${token}` }), env);
  assert.equal(before.status, 200);
  const me = await before.json();
  assert.equal(me.email, "user@example.com");
  assert.equal(me.callsToday, 0);
  assert.equal(me.dailyLimit, authConstants.defaultDailyLimit);

  assert.equal((await call(post("/auth/logout", {}, { authorization: `Bearer ${token}` }), env)).status, 200);
  assert.equal(
    (await call(get("/auth/me", { authorization: `Bearer ${token}` }), env)).status,
    401,
    "a revoked session no longer resolves",
  );
  // Logging out twice, or with no token at all, is still 200.
  assert.equal((await call(post("/auth/logout", {}), env)).status, 200);
}

// --- session expiry ---
{
  const env = makeEnv();
  const { token } = await (await call(post("/auth/signup", goodSignup), env)).json();
  env.DB.raw
    .prepare("UPDATE sessions SET expires_at = ?")
    .run(Date.now() - 1000);
  assert.equal(
    (await call(get("/auth/me", { authorization: `Bearer ${token}` }), env)).status,
    401,
    "an expired session is rejected at read time",
  );
}

// --- /auth/me unauthenticated and broken storage ---
{
  const env = makeEnv();
  assert.equal((await call(get("/auth/me"), env)).status, 401);
  assert.equal((await call(get("/auth/me", { authorization: "Bearer nope" }), env)).status, 401);
  assert.equal(
    (await call(get("/auth/me", { authorization: "Basic nope" }), env)).status,
    401,
    "a non-Bearer scheme is not a token",
  );
  env.DB.breakWith("D1_ERROR: network");
  assert.equal(
    (await call(get("/auth/me", { authorization: "Bearer nope" }), env)).status,
    503,
    "a D1 outage on /auth/me is a 503, not a bogus 401",
  );
}

// --- throttling (finding 1) ---
{
  const env = makeEnv();
  let throttled: Response | null = null;
  // The email bound is the tighter of the two, so it trips first.
  for (let attempt = 0; attempt <= authConstants.authEmailAttemptsPerWindow; attempt++) {
    const response = await call(
      post("/auth/login", { email: "victim@example.com", password: "guess-guess" }),
      env,
    );
    if (response.status === 429) {
      throttled = response;
      break;
    }
  }
  assert.ok(throttled, "repeated login attempts on one email must be throttled");
  assert.equal(throttled.status, 429);
  const retryAfter = Number(throttled.headers.get("Retry-After"));
  assert.ok(
    retryAfter >= 1 && retryAfter <= authConstants.authWindowSeconds,
    `Retry-After should be within the window, got ${retryAfter}`,
  );

  // A different email from the same IP still gets through until the looser IP
  // bound trips, so one attacker cannot lock out every account from one probe.
  assert.notEqual(
    (await call(post("/auth/login", { email: "other@example.com", password: "correct-horse" }), env)).status,
    429,
  );

  // Throttling happens before any PBKDF2, so it must not need a valid body.
  const flood = makeEnv();
  let ipThrottled = false;
  for (let attempt = 0; attempt < authConstants.authIpAttemptsPerWindow + 2; attempt++) {
    const response = await call(
      post("/auth/signup", { email: `burner${attempt}@example.com`, password: "correct-horse" }),
      flood,
    );
    if (response.status === 429) ipThrottled = true;
  }
  assert.ok(ipThrottled, "a single IP cycling fresh emails must still be bounded");
}

// A missing auth_attempts table must fail open, not break login.
{
  const env = makeEnv();
  await call(post("/auth/signup", goodSignup), env);
  env.DB.raw.exec("DROP TABLE auth_attempts");
  const response = await call(
    post("/auth/login", { email: "user@example.com", password: "correct-horse" }),
    env,
  );
  assert.equal(response.status, 200, "the throttle fails open rather than 500-ing login");
}

// --- AI routes: auth contract ---

const analysisBody = {
  currency: "Rs",
  monthlyBudget: 1000,
  period: { daysElapsed: 15, daysRemaining: 15, totalDays: 30 },
  currentMonth: { total: 550, categories: { Food: 300, Transport: 250 } },
  history: [
    { total: 200, categories: { Food: 100, Transport: 100 } },
    { total: 220, categories: { Food: 110, Transport: 110 } },
    { total: 180, categories: { Food: 90, Transport: 90 } },
  ],
};

const realFetch = globalThis.fetch;

/// Replaces global fetch with a scripted sequence of OpenRouter replies.
/// Each entry is a status, or a content string for a 200.
function mockUpstream(script: Array<number | string | "hang">) {
  const seen: Array<{ model: string; authorization: string | null }> = [];
  let index = 0;
  globalThis.fetch = (async (url: string | URL | Request, init?: RequestInit) => {
    const body = JSON.parse(String(init?.body));
    seen.push({
      model: body.model,
      authorization: new Headers(init?.headers).get("authorization"),
    });
    const step = script[index++] ?? 500;
    if (step === "hang") {
      // Resolves only when the caller's AbortSignal fires, so the per-attempt
      // timeout is what ends this, not the test.
      return new Promise((_resolve, reject) => {
        init?.signal?.addEventListener("abort", () =>
          reject(new DOMException("timed out", "TimeoutError")),
        );
      });
    }
    if (typeof step === "number") {
      return new Response(JSON.stringify({ error: "upstream" }), { status: step });
    }
    return Response.json({ choices: [{ message: { content: step } }] });
  }) as typeof fetch;
  return seen;
}

const analysisContent = JSON.stringify({
  summary: "You are tracking above budget.",
  insights: [{ title: "Food is up", detail: "Food is well above its baseline.", tone: "warning" }],
});

{
  const env = makeEnv();
  mockUpstream([analysisContent]);
  try {
    assert.equal(
      (await call(post("/analyze-spending", analysisBody), env)).status,
      401,
      "no bearer token is a 401",
    );
    assert.equal(
      (await call(post("/analyze-spending", analysisBody, { authorization: "Bearer bogus-token" }), env)).status,
      401,
    );

    // APP_PROXY_TOKEN still works as the admin bypass, with no quota row.
    const admin = await call(
      post("/analyze-spending", analysisBody, { authorization: `Bearer ${"a".repeat(40)}` }),
      env,
    );
    assert.equal(admin.status, 200, "APP_PROXY_TOKEN is retained as an admin bypass");
    const adminBody = await admin.json();
    assert.equal(adminBody.summary, "You are tracking above budget.");
    assert.ok(adminBody.requestId, "the correlation id is returned to the caller");
    assert.deepEqual(adminBody.forecast, {
      projectedSpend: 1100,
      status: "overBudget",
      confidence: "high",
    });
    assert.equal(
      env.DB.raw.prepare("SELECT COUNT(*) AS n FROM usage").get().n,
      0,
      "the admin bypass consumes no per-user quota",
    );
  } finally {
    globalThis.fetch = realFetch;
  }
}

// A short or absent APP_PROXY_TOKEN must never authorize anything.
{
  for (const secret of [undefined, "", "tooshort"]) {
    const env = makeEnv({ APP_PROXY_TOKEN: secret });
    const response = await call(
      post("/analyze-spending", analysisBody, { authorization: `Bearer ${secret ?? "x"}` }),
      env,
    );
    assert.equal(response.status, 401, `APP_PROXY_TOKEN=${JSON.stringify(secret)} must not authorize`);
  }
}

// --- quota is charged only for requests that actually go upstream (finding 4) ---
{
  const env = makeEnv();
  const { token } = await (await call(post("/auth/signup", goodSignup), env)).json();
  const auth = { authorization: `Bearer ${token}` };
  const callsToday = () =>
    env.DB.raw.prepare("SELECT COALESCE(SUM(calls), 0) AS n FROM usage").get().n;

  mockUpstream([]);
  try {
    // Malformed JSON: rejected before the model, so it must be free.
    assert.equal((await call(post("/analyze-spending", "{oops", auth), env)).status, 400);
    // Schema rejection: also free.
    assert.equal(
      (await call(post("/analyze-spending", { currency: "Rs" }, auth), env)).status,
      400,
    );
    // Oversized body: free, and a 413.
    const huge = await call(
      post("/categorize", { merchants: ["x".repeat(200)], pad: "y".repeat(limits.maxBodyBytes) }, auth),
      env,
    );
    assert.equal(huge.status, 413);
    assert.equal(callsToday(), 0, "rejected requests must not burn quota");

    // An upstream failure refunds: the user got nothing.
    globalThis.fetch = realFetch;
    mockUpstream([500, 500, 500, 500]);
    const failed = await call(post("/analyze-spending", analysisBody, auth), env);
    assert.equal(failed.status, 502);
    assert.ok((await failed.json()).requestId, "even a 502 carries a correlation id");
    assert.equal(callsToday(), 0, "an upstream failure is not charged");

    // A model reply the sanitizer rejects is also a 502, and also refunded.
    globalThis.fetch = realFetch;
    mockUpstream([JSON.stringify({ summary: "ok", insights: [] })]);
    assert.equal((await call(post("/analyze-spending", analysisBody, auth), env)).status, 502);
    assert.equal(callsToday(), 0, "an unusable model reply is not charged");

    // A success is charged exactly once.
    globalThis.fetch = realFetch;
    mockUpstream([analysisContent]);
    assert.equal((await call(post("/analyze-spending", analysisBody, auth), env)).status, 200);
    assert.equal(callsToday(), 1);
  } finally {
    globalThis.fetch = realFetch;
  }
}

// --- quota at exactly the limit boundary ---
{
  const env = makeEnv();
  const { token } = await (await call(post("/auth/signup", goodSignup), env)).json();
  const auth = { authorization: `Bearer ${token}` };
  const userId = env.DB.raw.prepare("SELECT id FROM users").get().id;
  const limit = authConstants.defaultDailyLimit;

  // Pre-charge to one below the limit; the next call must be the last allowed.
  env.DB.raw
    .prepare("INSERT INTO usage (user_id, day, calls) VALUES (?, ?, ?)")
    .run(userId, new Date().toISOString().slice(0, 10), limit - 1);

  mockUpstream(Array.from({ length: 4 }, () => analysisContent));
  try {
    const last = await call(post("/analyze-spending", analysisBody, auth), env);
    assert.equal(last.status, 200, `call ${limit} of ${limit} is allowed`);

    const over = await call(post("/analyze-spending", analysisBody, auth), env);
    assert.equal(over.status, 429, `call ${limit + 1} is refused`);
    const overBody = await over.json();
    assert.match(overBody.error, new RegExp(`${limit} requests`));
    assert.match(overBody.error, /midnight UTC/);

    // Hammering a spent quota must not push the reported count past the limit.
    for (let attempt = 0; attempt < 5; attempt++) {
      await call(post("/analyze-spending", analysisBody, auth), env);
    }
    const me = await (await call(get("/auth/me", auth), env)).json();
    assert.equal(me.callsToday, limit, "/auth/me never reports more than the limit");
  } finally {
    globalThis.fetch = realFetch;
  }
}

// --- model retry chain and upstream deadlines (finding 5) ---
{
  const env = makeEnv();
  const adminAuth = { authorization: `Bearer ${"a".repeat(40)}` };

  // 429 then 500 then success: the chain walks forward.
  let seen = mockUpstream([429, 500, analysisContent]);
  try {
    assert.equal((await call(post("/analyze-spending", analysisBody, adminAuth), env)).status, 200);
    assert.equal(seen.length, 3, "the chain retried past 429 and 500");
    assert.deepEqual(
      seen.map((attempt) => attempt.model),
      ["openrouter/free", "google/gemma-4-31b-it:free", "openai/gpt-oss-20b:free"],
      "models are tried in chain order, no repeats",
    );
    assert.equal(seen[0].authorization, "Bearer sk-test");
  } finally {
    globalThis.fetch = realFetch;
  }

  // A 401 is our key: every model would fail identically, so stop at one.
  seen = mockUpstream([401, analysisContent]);
  try {
    assert.equal((await call(post("/analyze-spending", analysisBody, adminAuth), env)).status, 502);
    assert.equal(seen.length, 1, "a 4xx that is not 429 stops the chain immediately");
  } finally {
    globalThis.fetch = realFetch;
  }

  // A hung model is aborted by its own timeout and the chain continues.
  seen = mockUpstream(["hang", analysisContent]);
  const signals: AbortSignal[] = [];
  const timedOutFetch = globalThis.fetch;
  globalThis.fetch = ((url: never, init?: RequestInit) => {
    if (init?.signal) signals.push(init.signal);
    return timedOutFetch(url, init);
  }) as typeof fetch;
  try {
    const started = Date.now();
    const pending = call(post("/analyze-spending", analysisBody, adminAuth), env);
    // Do not wait out the real 20s timeout -- fire the signal the Worker built.
    await new Promise((resolve) => setTimeout(resolve, 10));
    assert.equal(signals.length, 1, "each attempt carries an AbortSignal");
    signals[0].dispatchEvent(new Event("abort"));
    const response = await pending;
    assert.equal(response.status, 200, "the chain recovers after an aborted attempt");
    assert.equal(seen.length, 2, "the hung model was abandoned, the next one answered");
    assert.ok(Date.now() - started < limits.upstreamAttemptTimeoutMs);
  } finally {
    globalThis.fetch = realFetch;
  }

  assert.ok(
    limits.upstreamAttemptTimeoutMs < limits.upstreamTotalDeadlineMs,
    "a per-attempt timeout longer than the total deadline would be pointless",
  );
}

// --- /categorize contract ---
{
  const env = makeEnv();
  const adminAuth = { authorization: `Bearer ${"a".repeat(40)}` };
  mockUpstream([
    JSON.stringify({
      results: [
        { merchant: "ZOMATO", category: "Food", confidence: "high" },
        { merchant: "INVENTED", category: "Food", confidence: "high" },
      ],
    }),
  ]);
  try {
    const response = await call(
      post("/categorize", { merchants: ["ZOMATO", "UBER TRIP"] }, adminAuth),
      env,
    );
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.deepEqual(
      body.results,
      [{ merchant: "ZOMATO", category: "Food", confidence: "high" }],
      "the sanitizer still gates the model reply on the real route",
    );
    assert.ok(body.requestId);
  } finally {
    globalThis.fetch = realFetch;
  }

  assert.equal(
    (await call(post("/categorize", { merchants: [], extra: 1 }, adminAuth), env)).status,
    400,
  );
}

// --- routing ---
{
  const env = makeEnv();
  assert.equal((await call(get("/nope"), env)).status, 404);
  assert.equal((await call(get("/auth/signup"), env)).status, 404, "GET on a POST route is 404");
  assert.equal((await call(post("/auth/me", {}), env)).status, 404);
}

// --- cleanup and cascade (finding 6) ---
{
  const env = makeEnv();
  const { token } = await (await call(post("/auth/signup", goodSignup), env)).json();
  const userId = env.DB.raw.prepare("SELECT id FROM users").get().id;
  const day = new Date().toISOString().slice(0, 10);

  env.DB.raw
    .prepare("INSERT INTO sessions (token_hash, user_id, created_at, expires_at) VALUES (?, ?, 0, ?)")
    .run("expired-hash", userId, Date.now() - 1);
  env.DB.raw.prepare("INSERT INTO usage (user_id, day, calls) VALUES (?, ?, 3)").run(userId, "2020-01-01");
  env.DB.raw
    .prepare("INSERT INTO auth_attempts (identifier, window_start, attempts) VALUES (?, ?, 9)")
    .run("ip:198.51.100.7", Date.now() - 10 * 60 * 1000);

  const deleted = await cleanupExpired(env);
  assert.equal(deleted.sessions, 1, "the expired session was deleted");
  assert.equal(deleted.usage, 1, "usage past retention was deleted");
  assert.equal(deleted.attempts, 1, "the spent throttle window was deleted");

  // The live session survives.
  assert.equal(
    env.DB.raw.prepare("SELECT COUNT(*) AS n FROM sessions WHERE token_hash = ?").get(await sha256(token)).n,
    1,
    "cleanup must not touch an unexpired session",
  );

  // Deleting the user cascades to both child tables.
  env.DB.raw.prepare("INSERT INTO usage (user_id, day, calls) VALUES (?, ?, 1)").run(userId, day);
  env.DB.raw.prepare("DELETE FROM users WHERE id = ?").run(userId);
  assert.equal(env.DB.raw.prepare("SELECT COUNT(*) AS n FROM sessions").get().n, 0, "sessions cascade");
  assert.equal(env.DB.raw.prepare("SELECT COUNT(*) AS n FROM usage").get().n, 0, "usage cascades");

  assert.ok(authConstants.usageRetentionDays > 0, "retention must be documented as a number");
}

// The scheduled handler must swallow a broken database rather than throw.
{
  const env = makeEnv();
  env.DB.breakWith("D1_ERROR: gone");
  await worker.scheduled({} as never, env);
  env.DB.heal();
  await worker.scheduled({} as never, env);
}

console.log("routes_test: ok");
