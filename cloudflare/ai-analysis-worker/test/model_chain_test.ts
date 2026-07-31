import assert from "node:assert/strict";

import { models } from "../src/index.ts";

const { modelChain, fallbackModels } = models;

// --- default chain ---

assert.deepEqual(
  modelChain({} as never),
  fallbackModels,
  "no override yields the plain fallback chain",
);

assert.equal(fallbackModels[0], "openrouter/free", "primary is the free router alias");
assert.ok(fallbackModels.length >= 2, "a chain of one defeats the purpose");
assert.equal(
  new Set(fallbackModels).size,
  fallbackModels.length,
  "no duplicate models -- a repeat wastes an attempt on a model that just failed",
);

// --- OPENROUTER_MODEL override ---

const withOverride = modelChain({ OPENROUTER_MODEL: "custom/model" } as never);
assert.equal(withOverride[0], "custom/model", "override is tried first");
assert.deepEqual(
  withOverride.slice(1),
  fallbackModels,
  "override prepends, it does not replace the fallbacks",
);

// An override naming a model already in the chain must not appear twice, or
// that model gets two attempts while another gets none.
const overlapping = modelChain({ OPENROUTER_MODEL: fallbackModels[2] } as never);
assert.equal(overlapping[0], fallbackModels[2]);
assert.equal(
  overlapping.length,
  fallbackModels.length,
  "overlapping override does not grow the chain",
);
assert.equal(
  new Set(overlapping).size,
  overlapping.length,
  "overlapping override is deduped",
);

// Whitespace-only and empty overrides are treated as absent, not as a model
// name -- otherwise a stray env var would send an empty model to OpenRouter.
for (const blank of ["", "   ", "\n"]) {
  assert.deepEqual(
    modelChain({ OPENROUTER_MODEL: blank } as never),
    fallbackModels,
    `blank override (${JSON.stringify(blank)}) falls back to the default chain`,
  );
}

assert.deepEqual(
  modelChain({ OPENROUTER_MODEL: "  spaced/model  " } as never)[0],
  "spaced/model",
  "override is trimmed",
);

console.log("model_chain_test: ok");
