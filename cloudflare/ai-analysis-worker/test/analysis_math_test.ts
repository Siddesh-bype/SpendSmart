import assert from "node:assert/strict";

import { analysisMath } from "../src/index.ts";

const input = {
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

const forecast = analysisMath.calculateForecast(input);
assert.deepEqual(forecast, {
  projectedSpend: 1100,
  status: "overBudget",
  confidence: "high",
});

const anomalies = analysisMath.calculateAnomalies(input);
assert.deepEqual(anomalies, [
  {
    category: "Food",
    currentAmount: 300,
    baselineAmount: 50,
    severity: "critical",
  },
  {
    category: "Transport",
    currentAmount: 250,
    baselineAmount: 50,
    severity: "critical",
  },
]);

assert.deepEqual(
  analysisMath.calculateAnomalies({ ...input, history: [input.history[0], input.history[1], { total: 0, categories: {} }] }),
  [],
);

console.log("analysis_math_test: ok");
