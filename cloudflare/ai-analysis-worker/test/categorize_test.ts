import assert from "node:assert/strict";

import { categorization } from "../src/index.ts";

const { isCategorizeRequest, sanitizeCategories } = categorization;

// --- request validation ---

assert.equal(isCategorizeRequest({ merchants: ["ZOMATO", "UBER TRIP"] }), true);
assert.equal(isCategorizeRequest({ merchants: [] }), false, "empty array rejected");
assert.equal(isCategorizeRequest({ merchants: "ZOMATO" }), false, "non-array rejected");
assert.equal(
  isCategorizeRequest({ merchants: Array.from({ length: 50 }, (_, index) => `M${index}`) }),
  true,
  "50 merchants allowed",
);
assert.equal(
  isCategorizeRequest({ merchants: Array.from({ length: 51 }, (_, index) => `M${index}`) }),
  false,
  "more than 50 merchants rejected",
);
assert.equal(isCategorizeRequest({ merchants: ["A".repeat(64)] }), true, "64 chars allowed");
assert.equal(isCategorizeRequest({ merchants: ["A".repeat(65)] }), false, "65 chars rejected");
assert.equal(isCategorizeRequest({ merchants: ["OK", "   "] }), false, "blank entry rejected");
assert.equal(isCategorizeRequest({ merchants: ["OK", 42] }), false, "non-string entry rejected");
assert.equal(
  isCategorizeRequest({ merchants: ["ZOMATO"], amount: 250 }),
  false,
  "extra top-level keys rejected",
);
assert.equal(isCategorizeRequest({}), false);
assert.equal(isCategorizeRequest(null), false);
assert.equal(isCategorizeRequest(["ZOMATO"]), false);

// --- output sanitizing ---

const requested = ["ZOMATO", "UBER TRIP", "APOLLO PHARMACY"];

assert.deepEqual(
  sanitizeCategories(
    {
      results: [
        { merchant: "ZOMATO", category: "Food", confidence: "high" },
        { merchant: "UBER TRIP", category: "Transport", confidence: "medium" },
        { merchant: "APOLLO PHARMACY", category: "Health", confidence: "low" },
      ],
    },
    requested,
  ),
  [
    { merchant: "ZOMATO", category: "Food", confidence: "high" },
    { merchant: "UBER TRIP", category: "Transport", confidence: "medium" },
    { merchant: "APOLLO PHARMACY", category: "Health", confidence: "low" },
  ],
  "valid results pass through unchanged",
);

assert.deepEqual(
  sanitizeCategories(
    {
      results: [
        { merchant: "ZOMATO", category: "Food", confidence: "high" },
        { merchant: "NETFLIX", category: "Entertainment", confidence: "high" },
        { merchant: "zomato", category: "Food", confidence: "high" },
      ],
    },
    requested,
  ),
  [{ merchant: "ZOMATO", category: "Food", confidence: "high" }],
  "hallucinated merchants not in the request are dropped, match is exact",
);

assert.deepEqual(
  sanitizeCategories(
    {
      results: [
        { merchant: "ZOMATO", category: "Groceries", confidence: "high" },
        { merchant: "UBER TRIP", category: "Transport", confidence: "high" },
      ],
    },
    requested,
  ),
  [{ merchant: "UBER TRIP", category: "Transport", confidence: "high" }],
  "bogus category dropped",
);

assert.deepEqual(
  sanitizeCategories(
    {
      results: [
        { merchant: "ZOMATO", category: "Food", confidence: "very high" },
        { merchant: "UBER TRIP", category: "Transport", confidence: 0.9 },
        { merchant: "APOLLO PHARMACY", category: "Health", confidence: "low" },
      ],
    },
    requested,
  ),
  [{ merchant: "APOLLO PHARMACY", category: "Health", confidence: "low" }],
  "bad confidence values dropped",
);

assert.deepEqual(
  sanitizeCategories(
    {
      results: [
        { merchant: "ZOMATO", category: "Food", confidence: "high" },
        { merchant: "ZOMATO", category: "Bills", confidence: "low" },
      ],
    },
    requested,
  ),
  [{ merchant: "ZOMATO", category: "Food", confidence: "high" }],
  "duplicate merchants deduped, first valid wins",
);

assert.deepEqual(
  sanitizeCategories(
    {
      results: [
        { merchant: "NETFLIX", category: "Entertainment", confidence: "high" },
        { merchant: "ZOMATO", category: "Groceries", confidence: "high" },
        { merchant: "ZOMATO", category: "Food", confidence: "certain" },
        "ZOMATO",
        null,
        {},
      ],
    },
    requested,
  ),
  [],
  "all-invalid results yield an empty array, not a throw",
);

assert.deepEqual(
  sanitizeCategories({ results: [] }, requested),
  [],
  "empty results array is valid",
);

assert.equal(
  sanitizeCategories(
    {
      results: Array.from({ length: 10 }, () => ({
        merchant: "ZOMATO",
        category: "Food",
        confidence: "high",
      })),
    },
    ["ZOMATO"],
  ).length,
  1,
  "never returns more results than were requested",
);

// Unparseable shapes throw so the route can answer 502.
assert.throws(() => sanitizeCategories({ results: "Food" }, requested), /invalid response/);
assert.throws(() => sanitizeCategories({}, requested), /invalid response/);
assert.throws(() => sanitizeCategories(null, requested), /invalid response/);

console.log("categorize_test: ok");
