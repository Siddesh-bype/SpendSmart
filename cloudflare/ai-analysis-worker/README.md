# SpendSmart AI Analysis Worker

This Worker keeps the OpenRouter API key out of the Android APK, and owns the
account system that gates AI access. It stores no expense data — the app keeps
that on-device and never uploads it. The only thing in D1 is who may call the
AI routes.

## Routes

| Route | Auth | Purpose |
|---|---|---|
| `POST /auth/signup` | none (throttled) | Create an account, return a session token |
| `POST /auth/login` | none (throttled) | Exchange credentials for a session token |
| `POST /auth/logout` | session token | Revoke the presented session |
| `GET /auth/me` | session token | Email, display name, calls today, daily limit |
| `POST /analyze-spending` | session token | AI review of the deterministic forecast |
| `POST /categorize` | session token | Classify merchant strings |

The app has the Worker base URL compiled in (`AppConfig.workerBaseUrl` in
`lib/utils/constants.dart`). Users do not paste a URL or a token into Settings;
they sign in with an email and password.

### Auth model

A session token is 32 random bytes; only its SHA-256 is persisted, so a dump of
the `sessions` table yields nothing replayable. Tokens last 90 days. Sending it
as `Authorization: Bearer <token>` is the normal path for both AI routes, and is
quota-limited to 50 calls per UTC day per account.

`APP_PROXY_TOKEN` is retained as an **admin bypass** for curl smoke tests and
for installs configured before accounts existed. It skips the quota entirely. It
fails safe: an unset or shorter-than-16-character secret authorizes nothing.

`/auth/login` uses one message for "no such account" and "wrong password", so it
cannot be used to enumerate registered addresses. `/auth/signup` deliberately
does say the address is taken — a signup form that refuses to is unusable.

### `/analyze-spending`

Accepts only aggregate category totals for the current custom month and the three
preceding ones, custom-month progress, a budget, and a currency. Any other
top-level field is rejected with 400, and category keys must be one of the seven
fixed category names. It does not accept titles, merchant names, notes, dates,
IDs, sources, or full transactions.

Forecasts and anomaly thresholds are calculated in the Worker. OpenRouter
receives only the currency, budget, month progress, and those deterministic
results — the projection, plus up to three flagged categories with their current
and baseline amounts — and only explains them. The full category totals and the
three-month history stay in the Worker and are not forwarded.

### `/categorize`

Accepts merchant name strings and nothing else. The body must have exactly one
key, `merchants`: an array of 1 to 50 strings, each non-blank and at most 64
characters after trimming. A body carrying amounts, dates, IDs, notes,
categories, or any other field is rejected with 400. Those merchant strings are
forwarded to OpenRouter to be classified into one of Food, Transport, Shopping,
Health, Entertainment, Bills, or Other.

This is the only route that sends merchant names off the device. Like the AI
review, it runs only when the user taps the action in the app; it is not
automatic and not a background job.

Replies from the model are filtered before they are returned:

- A result whose merchant string is not byte-for-byte one of the merchants in the
  request is dropped, so the model cannot invent or rename a merchant.
- A category outside the seven allowed names is dropped.
- A confidence outside `low`, `medium`, and `high` is dropped.
- Duplicate merchants are deduplicated, keeping the first valid result, and no
  more results are returned than distinct merchants were sent.

Bad entries are dropped individually, so a partly invalid reply still returns its
valid rows; a reply that is not an object with a `results` array fails with 502.

### Both AI routes

Both reject bodies larger than 8 KiB with 413, send `Cache-Control: no-store`,
and return a generic error body plus a `requestId` correlation id — never
upstream detail. Quote that `requestId` when reading logs.

Response contract: `401` no or bad credentials, `413` body too large, `400`
malformed or schema-invalid body, `429` daily quota spent, `502` no model
answered, `503` D1 unreachable.

### Model fallback

There is no single default model. The Worker walks a chain of free models that
support `response_format: json_object`, in order, until one answers:
`openrouter/free`, `google/gemma-4-31b-it:free`, `openai/gpt-oss-20b:free`,
`nvidia/nemotron-nano-9b-v2:free`. Free tiers are aggressively rate-limited, so
a single model is not dependable. A 429 or 5xx moves to the next model; a
400/401/403 stops the chain, because that is our request or our key and every
model would fail identically.

Each attempt has a 20 s timeout and the whole chain a 45 s deadline. Setting
`OPENROUTER_MODEL` (a plain var, not a secret) prepends one model to the chain
rather than replacing it.

### Quota accounting

A call is charged only when the request is actually sent upstream. Malformed
bodies, oversized bodies, and schema rejections are free. If no model answers,
the call is refunded — the user got nothing, so an OpenRouter outage must not eat
someone's daily allowance. The counter stops at the limit, so `/auth/me` never
reports more than 50.

## Required secrets and vars

| Name | Kind | Required | Notes |
|---|---|---|---|
| `OPENROUTER_API_KEY` | secret | **yes** | Without it every AI call 502s |
| `APP_PROXY_TOKEN` | secret | **yes** | Admin bypass. Unique random, at least 32 chars. Unset disables the bypass, which is safe but leaves you no smoke-test credential |
| `OPENROUTER_MODEL` | var | no | Prepends one model to the fallback chain |

Rotate `APP_PROXY_TOKEN` if a device holding it is lost. It is not an OpenRouter
key and grants no billing access, but it does bypass the per-account quota.

## Required Cloudflare rate-limit rules

**These are required infrastructure, not a hardening suggestion.** The Worker
throttles `/auth/signup` and `/auth/login` by client IP (20 per minute) and by
normalized email (6 per minute), because each runs a deliberately expensive
100k-iteration PBKDF2 and is therefore a CPU amplifier. That in-Worker throttle
is a floor, not a ceiling: it still costs an invocation and a D1 write per
attempt, and it fails open if its table is missing.

Add these in **Security → WAF → Rate limiting rules** on the zone or route
fronting the Worker, before distributing the APK beyond your own devices:

| Rule | Match | Limit | Action |
|---|---|---|---|
| Auth flood | `http.request.uri.path in {"/auth/login" "/auth/signup"}` | 10 requests / 1 min per IP | Block, 60 s |
| AI abuse | `http.request.uri.path in {"/analyze-spending" "/categorize"}` | 60 requests / 1 min per IP | Managed challenge |

The AI rule matters because the daily quota is refunded on upstream failure — a
client can retry a failing model without limit, and this rule is what bounds
that, not the quota.

## Retention and cleanup

A cron trigger (`17 3 * * *`, see `wrangler.jsonc`) runs the `scheduled` handler,
which deletes:

- sessions past `expires_at` (expiry is also enforced at read time, so this is
  storage hygiene, not a security boundary),
- `auth_attempts` rows whose throttle window has closed,
- `usage` rows older than **90 days** (`authConstants.usageRetentionDays`).

Nothing reads a `usage` row older than today; the 90 days exist only to answer
"why was I charged" and to spot abuse. Deleting a user cascades to their
sessions and usage (`ON DELETE CASCADE`, migration 0002).

## Schema

The schema lives in `migrations/` as numbered files and is applied with
`wrangler d1 migrations apply` — `wrangler deploy` does **not** apply it. The old
ad-hoc `schema.sql` is gone.

- `0001_init.sql` — reproduces what is already live, verbatim, all statements
  `IF NOT EXISTS`. Applying it to the deployed database is a no-op that only
  records the migration row.
- `0002_auth_attempts_and_cascade.sql` — adds `auth_attempts` and rebuilds
  `sessions` and `usage` with `ON DELETE CASCADE` (SQLite cannot `ALTER` a
  foreign key). **This one rewrites two tables** — see rollback below.

## Deploy

From this directory:

```powershell
npx wrangler login
npx wrangler secret put OPENROUTER_API_KEY
npx wrangler secret put APP_PROXY_TOKEN

# Migrate first: 0002 adds a table the Worker's throttle reads.
npx wrangler d1 migrations list spendsmart-auth --remote
npx wrangler d1 migrations apply spendsmart-auth --remote
npx wrangler deploy
```

Order matters in one direction only. Migrating before deploying is safe: the
current Worker ignores the new table. Deploying first is also survivable — the
throttle fails open — but it leaves the auth routes unthrottled until you
migrate, so do not stop there.

### Rollback

Code: `npx wrangler rollback` (or `npx wrangler deployments list` then
`npx wrangler rollback <id>`).

Schema: there is no down-migration. `0001` is idempotent and safe to re-run.
`0002` drops and recreates `sessions` and `usage`, so take a backup before
applying it and restore from that if it goes wrong:

```powershell
npx wrangler d1 export spendsmart-auth --remote --output backup.sql
```

Worst case, `sessions` and `usage` are both rebuildable state — losing them logs
everyone out and resets today's counters. `users` is the only table that matters.

## Smoke test

Replace `$BASE` and `$ADMIN` with your Worker URL and `APP_PROXY_TOKEN`.

```powershell
# 1. Signup returns a token. A second, identical call must be 409, not 503.
curl -sS -X POST "$BASE/auth/signup" -H "content-type: application/json" `
  -d '{"email":"smoke@example.com","password":"correct-horse-battery"}'

# 2. Login, then read the quota.
$T = (curl -sS -X POST "$BASE/auth/login" -H "content-type: application/json" `
  -d '{"email":"smoke@example.com","password":"correct-horse-battery"}' | ConvertFrom-Json).token
curl -sS "$BASE/auth/me" -H "authorization: Bearer $T"   # callsToday:0, dailyLimit:50

# 3. Wrong password must be 401 with the generic message, and must not be 503.
curl -sS -o - -w " %{http_code}" -X POST "$BASE/auth/login" `
  -H "content-type: application/json" -d '{"email":"smoke@example.com","password":"nope"}'

# 4. Admin bypass reaches the model chain. Expect 200 and a requestId.
curl -sS -X POST "$BASE/categorize" -H "authorization: Bearer $ADMIN" `
  -H "content-type: application/json" -d '{"merchants":["ZOMATO"]}'

# 5. No token is 401; a junk body on a valid token is 400.
curl -sS -o /dev/null -w "%{http_code}" -X POST "$BASE/categorize" -d '{}'
curl -sS -o /dev/null -w "%{http_code}" -X POST "$BASE/categorize" `
  -H "authorization: Bearer $T" -H "content-type: application/json" -d '{"nope":1}'

# 6. Throttle: seven rapid logins on one email. The last must be 429 + Retry-After.
1..7 | % { curl -sS -o /dev/null -D - -X POST "$BASE/auth/login" `
  -H "content-type: application/json" `
  -d '{"email":"smoke@example.com","password":"nope"}' | Select-String "HTTP/|Retry-After" }

# 7. Cron handler, locally.
npx wrangler dev --test-scheduled
curl "http://localhost:8787/cdn-cgi/handler/scheduled"
```

Then check `npx wrangler tail` for the JSON log lines. They carry only
`requestId`, route, model, status, and timing — never merchant strings, amounts,
emails, passwords, or tokens.

## Tests

Plain Node scripts, no package.json and no dependencies — Node 26 strips
TypeScript natively:

```powershell
Get-ChildItem test/*.ts | % { node $_.FullName }
```

`routes_test.ts` drives the real `fetch` and `scheduled` handlers against a D1
fake backed by `node:sqlite`, so the SQL, the UNIQUE-constraint error text,
`ON CONFLICT ... RETURNING`, and `ON DELETE CASCADE` are all exercised for real.
