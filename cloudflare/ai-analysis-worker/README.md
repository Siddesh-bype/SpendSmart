# SpendSmart AI Analysis Worker

This Worker keeps the OpenRouter API key out of the Android APK. It exposes two
POST routes, each backing one explicit user action in the app. They send
different data off the device, so they are documented separately.

## `/analyze-spending`

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

## `/categorize`

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

## Both routes

Both require the same `APP_PROXY_TOKEN` bearer token, reject bodies larger than
8 KB with 413, and send `Cache-Control: no-store` on success. Failures return a
generic error body, never upstream detail.

## Deploy

Install Wrangler, sign in, then run these commands from this directory:

```powershell
npx wrangler login
npx wrangler secret put OPENROUTER_API_KEY
npx wrangler secret put APP_PROXY_TOKEN
npx wrangler deploy
```

Both routes ship in the same Worker script and are covered by the same two
secrets, so an existing deployment gains `/categorize` from `npx wrangler deploy`
alone. No `wrangler.jsonc` change and no new secret are required.

The Worker defaults to `cohere/north-mini-code:free`. Set `OPENROUTER_MODEL` as a
non-secret Worker variable only when you want to override that model. Add the
deployed endpoint ending in `/analyze-spending` and the `APP_PROXY_TOKEN` in
SpendSmart Settings; the app derives the `/categorize` URL from that same Worker
URL, so only the one URL is configured.

Use a unique random `APP_PROXY_TOKEN` of at least 32 characters. It protects the
Worker endpoints but is not an OpenRouter key; rotate it in Cloudflare and in the
app if the device is lost. Configure a Cloudflare WAF rate-limit rule for both
endpoints before distributing the APK beyond your own devices.
