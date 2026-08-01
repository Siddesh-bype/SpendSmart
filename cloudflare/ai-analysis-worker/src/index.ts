import {
  authConstants,
  authenticate,
  consumeQuota,
  createUser,
  isValidEmail,
  isValidPassword,
  resolveSession,
  revokeSession,
  usageToday,
  type AuthEnv,
  type SessionUser,
} from "./auth.ts";

interface Env extends AuthEnv {
  APP_PROXY_TOKEN: string;
  OPENROUTER_API_KEY: string;
  OPENROUTER_MODEL?: string;
}

type Totals = Record<string, number>;

interface MonthSummary {
  total: number;
  categories: Totals;
}

interface PeriodProgress {
  daysElapsed: number;
  daysRemaining: number;
  totalDays: number;
}

interface AnalysisRequest {
  currency: string;
  monthlyBudget: number;
  period: PeriodProgress;
  currentMonth: MonthSummary;
  history: MonthSummary[];
}

interface Forecast {
  projectedSpend: number | null;
  status: "withinBudget" | "atRisk" | "overBudget" | "unavailable";
  confidence: "low" | "medium" | "high" | "unavailable";
}

interface Anomaly {
  category: string;
  currentAmount: number;
  baselineAmount: number;
  severity: "warning" | "critical";
}

interface CategorizeRequest {
  merchants: string[];
}

interface CategoryResult {
  merchant: string;
  category: string;
  confidence: "low" | "medium" | "high";
}

const maxBodyBytes = 8 * 1024;
const maxAmount = 10_000_000;
const maxMerchants = 50;
const maxMerchantLength = 64;

/// Free models that support `response_format: json_object`, tried in order.
/// Verified against https://openrouter.ai/api/v1/models. Free tiers are
/// aggressively rate-limited, so a single model is not dependable -- the chain
/// is what keeps AI working rather than 502-ing on the first 429.
const fallbackModels = [
  "openrouter/free",
  "google/gemma-4-31b-it:free",
  "openai/gpt-oss-20b:free",
  "nvidia/nemotron-nano-9b-v2:free",
];

function modelChain(env: Env): string[] {
  const preferred = env.OPENROUTER_MODEL?.trim();
  if (!preferred) return fallbackModels;
  return [preferred, ...fallbackModels.filter((model) => model !== preferred)];
}
const confidenceLevels = ["low", "medium", "high"];
const allowedCategories = new Set([
  "Food",
  "Transport",
  "Shopping",
  "Health",
  "Entertainment",
  "Bills",
  "Other",
]);

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === "POST" && url.pathname === "/auth/signup") {
      return signup(request, env);
    }
    if (request.method === "POST" && url.pathname === "/auth/login") {
      return login(request, env);
    }
    if (request.method === "POST" && url.pathname === "/auth/logout") {
      return logout(request, env);
    }
    if (request.method === "GET" && url.pathname === "/auth/me") {
      return me(request, env);
    }
    if (request.method === "POST" && url.pathname === "/analyze-spending") {
      return analyzeSpending(request, env);
    }
    if (request.method === "POST" && url.pathname === "/categorize") {
      return categorizeMerchants(request, env);
    }
    return new Response("Not found", { status: 404 });
  },
};

async function signup(request: Request, env: Env): Promise<Response> {
  const body = await readJsonBody(request);
  if (body === null) return authError(400, "Malformed request.");

  const { email, password, displayName } = body as Record<string, unknown>;
  if (!isValidEmail(email)) {
    return authError(400, "Enter a valid email address.");
  }
  if (!isValidPassword(password)) {
    return authError(
      400,
      `Password must be at least ${authConstants.minPasswordLength} characters.`,
    );
  }
  const name =
    typeof displayName === "string" && displayName.trim().length > 0
      ? displayName.trim().slice(0, 64)
      : null;

  const session = await createUser(env, email, password, name);
  // A usable signup form has to say the address is taken -- the generic
  // credentials error reads as nonsense here, since nothing was "incorrect".
  // Enumeration protection stays on /auth/login, where it costs nothing.
  if (!session) {
    return authError(
      409,
      'An account with this email already exists. Sign in instead.',
    );
  }

  return Response.json(
    { ...session, email: email.trim().toLowerCase(), displayName: name },
    { headers: { "Cache-Control": "no-store" } },
  );
}

async function login(request: Request, env: Env): Promise<Response> {
  const body = await readJsonBody(request);
  if (body === null) return authError(400, "Malformed request.");

  const { email, password } = body as Record<string, unknown>;
  if (typeof email !== "string" || typeof password !== "string") {
    return authError(401, authConstants.credentialsError);
  }

  const session = await authenticate(env, email, password);
  if (!session) return authError(401, authConstants.credentialsError);

  return Response.json(
    { ...session, email: email.trim().toLowerCase() },
    { headers: { "Cache-Control": "no-store" } },
  );
}

async function logout(request: Request, env: Env): Promise<Response> {
  const token = bearerToken(request);
  if (token) await revokeSession(env, token);
  // Always 200: a caller discarding an already-invalid token is not an error.
  return Response.json({ ok: true }, { headers: { "Cache-Control": "no-store" } });
}

async function me(request: Request, env: Env): Promise<Response> {
  const token = bearerToken(request);
  const user = token ? await resolveSession(env, token) : null;
  if (!user) return authError(401, "Sign in to continue.");

  return Response.json(
    {
      email: user.email,
      displayName: user.displayName,
      callsToday: await usageToday(env, user.id),
      dailyLimit: authConstants.defaultDailyLimit,
    },
    { headers: { "Cache-Control": "no-store" } },
  );
}

function bearerToken(request: Request): string | null {
  const header = request.headers.get("authorization") ?? "";
  if (!/^Bearer\s+/i.test(header)) return null;
  const token = header.replace(/^Bearer\s+/i, "").trim();
  return token.length > 0 ? token : null;
}

/// Bounded read for the auth routes, which take small bodies.
async function readJsonBody(request: Request): Promise<unknown | null> {
  if (Number(request.headers.get("content-length")) > maxBodyBytes) return null;
  try {
    return await readBoundedJson(request);
  } catch {
    return null;
  }
}

function authError(status: number, message: string): Response {
  return Response.json({ error: message }, { status });
}

async function analyzeSpending(request: Request, env: Env): Promise<Response> {
  const gate = await authorizeAndReadBody(request, env);
  if ("response" in gate) return gate.response;
  const input = gate.body;
  if (!isAnalysisRequest(input)) return error(400);

  const forecast = calculateForecast(input);
  const anomalies = calculateAnomalies(input);

  try {
    const content = await requestCompletion(
      env,
      "SpendSmart AI Review",
      "You are a personal spending analyst. Explain only the deterministic forecast and category anomalies supplied by the system. Do not give financial, legal, or investment advice. Return JSON only: {summary:string, insights:[{title:string,detail:string,tone:'positive'|'neutral'|'warning'}]}. Give 1-4 practical observations. Never invent transactions, merchants, income, account details, forecasts, or anomalies.",
      {
        currency: input.currency,
        monthlyBudget: input.monthlyBudget,
        period: input.period,
        forecast,
        anomalies,
      },
    );
    if (content === null) return error(502);
    const analysis = sanitizeAssistantAnalysis(JSON.parse(content));
    return Response.json({ ...analysis, forecast, anomalies }, {
      headers: { "Cache-Control": "no-store" },
    });
  } catch {
    return error(502);
  }
}

async function categorizeMerchants(request: Request, env: Env): Promise<Response> {
  const gate = await authorizeAndReadBody(request, env);
  if ("response" in gate) return gate.response;
  const input = gate.body;
  if (!isCategorizeRequest(input)) return error(400);

  try {
    const content = await requestCompletion(
      env,
      "SpendSmart Merchant Categorizer",
      "You classify bank-statement merchant strings into exactly one category. The only allowed categories are: Food, Transport, Shopping, Health, Entertainment, Bills, Other. Return JSON only: {results:[{merchant:string,category:string,confidence:'low'|'medium'|'high'}]}. Echo each merchant string back byte-for-byte exactly as given; never invent, rename, split, merge, or add a merchant that is not in the input. Use 'low' confidence whenever you are genuinely unsure — an honest low rating is more useful than a confident guess. Use 'Other' when no category fits.",
      { merchants: input.merchants },
    );
    if (content === null) return error(502);
    const results = sanitizeCategories(JSON.parse(content), input.merchants);
    return Response.json({ results }, { headers: { "Cache-Control": "no-store" } });
  } catch {
    return error(502);
  }
}

/// Authorizes an AI request and reads its body.
///
/// Two credentials are accepted: a per-account session token, which is the
/// normal path and is quota-limited, and APP_PROXY_TOKEN, kept as an admin
/// bypass for curl checks and for installs configured before accounts existed.
async function authorizeAndReadBody(
  request: Request,
  env: Env,
): Promise<{ body: unknown } | { response: Response }> {
  const token = bearerToken(request);
  if (!token) return { response: error(401) };

  const isAdmin = hasValidToken(request, env.APP_PROXY_TOKEN);
  let user: SessionUser | null = null;

  if (!isAdmin) {
    user = await resolveSession(env, token);
    if (!user) return { response: error(401) };

    const quota = await consumeQuota(env, user.id);
    if (!quota.allowed) {
      return {
        response: Response.json(
          {
            error:
              `Daily AI limit reached (${quota.limit} requests). ` +
              "It resets at midnight UTC.",
          },
          { status: 429 },
        ),
      };
    }
  }

  if (Number(request.headers.get("content-length")) > maxBodyBytes) {
    return { response: error(413) };
  }
  try {
    return { body: await readBoundedJson(request) };
  } catch (exception) {
    return { response: error(exception instanceof RangeError ? 413 : 400) };
  }
}

async function requestCompletion(
  env: Env,
  title: string,
  system: string,
  user: unknown,
): Promise<string | null> {
  const messages = [
    { role: "system", content: system },
    { role: "user", content: JSON.stringify(user) },
  ];

  for (const model of modelChain(env)) {
    const upstream = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
        "Content-Type": "application/json",
        "X-OpenRouter-Title": title,
      },
      body: JSON.stringify({
        model,
        temperature: 0.2,
        response_format: { type: "json_object" },
        messages,
      }),
    });
    if (upstream.ok) {
      const payload = (await upstream.json()) as {
        choices?: Array<{ message?: { content?: string } }>;
      };
      const content = payload.choices?.[0]?.message?.content;
      if (typeof content === "string") return content;
      // Reachable model, unusable answer. Try the next one.
      continue;
    }
    // 429 = rate limited, 5xx = upstream trouble; both may succeed elsewhere.
    // A 400/401/403 is our request or our key, so every model would fail the
    // same way -- stop rather than burn the whole chain.
    if (upstream.status !== 429 && upstream.status < 500) return null;
  }
  return null;
}

function hasValidToken(request: Request, expected: string | undefined): boolean {
  // An unset APP_PROXY_TOKEN must never authorize anything, or removing the
  // secret would silently open the admin bypass to everyone.
  if (!expected || expected.length < 16) return false;
  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/, "") || "";
  if (token.length !== expected.length || token.length < 16) return false;
  let difference = 0;
  for (let index = 0; index < token.length; index++) {
    difference |= token.charCodeAt(index) ^ expected.charCodeAt(index);
  }
  return difference === 0;
}

async function readBoundedJson(request: Request): Promise<unknown> {
  const reader = request.body?.getReader();
  if (!reader) throw new SyntaxError("missing body");
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > maxBodyBytes) {
        await reader.cancel();
        throw new RangeError("request too large");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return JSON.parse(new TextDecoder().decode(bytes));
}

function isAnalysisRequest(value: unknown): value is AnalysisRequest {
  if (!value || typeof value !== "object") return false;
  const input = value as AnalysisRequest;
  return (
    hasOnlyKeys(input, ["currency", "monthlyBudget", "period", "currentMonth", "history"]) &&
    typeof input.currency === "string" &&
    input.currency.length > 0 &&
    input.currency.length <= 8 &&
    isAmount(input.monthlyBudget) &&
    isPeriod(input.period) &&
    isMonthSummary(input.currentMonth) &&
    Array.isArray(input.history) &&
    input.history.length === 3 &&
    input.history.every(isMonthSummary)
  );
}

function isCategorizeRequest(value: unknown): value is CategorizeRequest {
  if (!value || typeof value !== "object" || !hasOnlyKeys(value, ["merchants"])) return false;
  const merchants = (value as CategorizeRequest).merchants;
  return (
    Array.isArray(merchants) &&
    merchants.length > 0 &&
    merchants.length <= maxMerchants &&
    merchants.every((merchant) => safeText(merchant, maxMerchantLength) !== null)
  );
}

function hasOnlyKeys(value: object, keys: string[]): boolean {
  return Object.keys(value).every((key) => keys.includes(key));
}

function isPeriod(value: unknown): value is PeriodProgress {
  if (!value || typeof value !== "object" || !hasOnlyKeys(value, ["daysElapsed", "daysRemaining", "totalDays"])) return false;
  const period = value as PeriodProgress;
  return [period.daysElapsed, period.daysRemaining, period.totalDays].every(
    (day) => Number.isInteger(day) && day >= 0 && day <= 31,
  ) && period.daysElapsed > 0 && period.totalDays > 0 && period.daysElapsed + period.daysRemaining === period.totalDays;
}

function isMonthSummary(value: unknown): value is MonthSummary {
  if (!value || typeof value !== "object" || !hasOnlyKeys(value, ["total", "categories"])) return false;
  const summary = value as MonthSummary;
  if (!isAmount(summary.total) || !isTotals(summary.categories)) return false;
  const categoryTotal = Object.values(summary.categories).reduce((total, amount) => total + amount, 0);
  return Math.abs(summary.total - categoryTotal) < 0.01;
}

function isTotals(value: unknown): value is Totals {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const entries = Object.entries(value);
  return entries.length <= allowedCategories.size && entries.every(
    ([category, amount]) => allowedCategories.has(category) && isAmount(amount),
  );
}

function isAmount(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 && value <= maxAmount;
}

function calculateForecast(input: AnalysisRequest): Forecast {
  if (input.period.daysElapsed < 3 || input.currentMonth.total <= 0) {
    return { projectedSpend: null, status: "unavailable", confidence: "unavailable" };
  }
  const projectedSpend = roundAmount(
    input.currentMonth.total / input.period.daysElapsed * input.period.totalDays,
  );
  const confidence = input.period.daysElapsed < 7
    ? "low"
    : input.period.daysElapsed < 14
      ? "medium"
      : "high";
  if (input.monthlyBudget <= 0) {
    return { projectedSpend, status: "unavailable", confidence };
  }
  const ratio = projectedSpend / input.monthlyBudget;
  return {
    projectedSpend,
    status: ratio > 1 ? "overBudget" : ratio >= 0.9 ? "atRisk" : "withinBudget",
    confidence,
  };
}

function calculateAnomalies(input: AnalysisRequest): Anomaly[] {
  if (input.history.some((month) => month.total <= 0)) return [];
  const minimumImpact = Math.max(1, input.monthlyBudget * 0.05);
  return Object.entries(input.currentMonth.categories).flatMap(([category, currentAmount]) => {
    const historicalAverage = input.history.reduce(
      (total, month) => total + (month.categories[category] || 0),
      0,
    ) / input.history.length;
    const expectedByNow = historicalAverage * input.period.daysElapsed / input.period.totalDays;
    const excess = currentAmount - expectedByNow;
    if (expectedByNow <= 0 || currentAmount < expectedByNow * 1.5 || excess < minimumImpact) return [];
    return [{
      category,
      currentAmount: roundAmount(currentAmount),
      baselineAmount: roundAmount(expectedByNow),
      severity: currentAmount >= expectedByNow * 2 ? "critical" : "warning",
    }];
  }).sort((a, b) => b.currentAmount - b.baselineAmount - (a.currentAmount - a.baselineAmount)).slice(0, 3);
}

function roundAmount(value: number): number {
  return Math.round(value * 100) / 100;
}

function sanitizeAssistantAnalysis(value: unknown) {
  if (!value || typeof value !== "object") throw new Error("invalid response");
  const input = value as { summary?: unknown; insights?: unknown };
  const summary = safeText(input.summary, 600);
  if (!summary || !Array.isArray(input.insights)) throw new Error("invalid response");

  const insights = input.insights.slice(0, 4).flatMap((item) => {
    if (!item || typeof item !== "object") return [];
    const insight = item as { title?: unknown; detail?: unknown; tone?: unknown };
    const title = safeText(insight.title, 80);
    const detail = safeText(insight.detail, 260);
    const tone = insight.tone;
    return title && detail && ["positive", "neutral", "warning"].includes(String(tone))
      ? [{ title, detail, tone }]
      : [];
  });
  if (!insights.length) throw new Error("invalid response");
  return { summary, insights };
}

// ponytail: merchants are echoed back byte-for-byte, never normalized. The caller keys results
// by the exact string it sent, so an untrimmed input the model trims simply gets dropped here
// and falls back to local rules — safer than returning a merchant the caller never asked for.
function sanitizeCategories(value: unknown, requested: string[]): CategoryResult[] {
  if (!value || typeof value !== "object") throw new Error("invalid response");
  const results = (value as { results?: unknown }).results;
  if (!Array.isArray(results)) throw new Error("invalid response");

  const requestedMerchants = new Set(requested);
  const sanitized: CategoryResult[] = [];
  const seen = new Set<string>();
  for (const item of results) {
    if (sanitized.length >= requestedMerchants.size) break;
    if (!item || typeof item !== "object") continue;
    const result = item as { merchant?: unknown; category?: unknown; confidence?: unknown };
    const { merchant, category, confidence } = result;
    if (typeof merchant !== "string" || !requestedMerchants.has(merchant) || seen.has(merchant)) continue;
    if (typeof category !== "string" || !allowedCategories.has(category)) continue;
    if (typeof confidence !== "string" || !confidenceLevels.includes(confidence)) continue;
    seen.add(merchant);
    sanitized.push({ merchant, category, confidence: confidence as CategoryResult["confidence"] });
  }
  return sanitized;
}

function safeText(value: unknown, maxLength: number): string | null {
  if (typeof value !== "string") return null;
  const text = value.trim();
  return text.length > 0 && text.length <= maxLength ? text : null;
}

function error(status: number): Response {
  return Response.json({ error: "AI analysis is unavailable." }, { status });
}

export const analysisMath = { calculateForecast, calculateAnomalies };
export const categorization = { isCategorizeRequest, sanitizeCategories };
export const models = { modelChain, fallbackModels };
