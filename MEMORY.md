# Memory — claude-code

> Generated: 2026-07-26 23:49:44  
> Total memories: **21**  
> Breakdown: fact: 2, decision: 13, context: 2, learning: 3, observation: 1

---

## Instructions

*Standing rules, constraints, and guidelines to always follow.*

*No memories of this type.*

---

## Facts

*Verified information, project status, and established truths.*

### Windows dev PC (siddesh): only 7.6GB usable RAM, 1...

Windows dev PC (siddesh): only 7.6GB usable RAM, 12 logical CPUs, commit charge runs 16/19.7GB so the machine pages hard. VS Code 1.129.1 with 44 extensions incl. 7 AI agent extensions. Projects live inside OneDrive (C:\Users\sidde\OneDrive\Desktop\...), so file watchers and OneDrive sync fight over the same trees. Treat this as a MEMORY-constrained machine: prefer removing resident processes over micro-tuning.

*Confidence: 0.95 | Status: active | Created: 2026-07-26T16:20:43*

### OneScan dev environment (2026-07-03): Python 3.12....

OneScan dev environment (2026-07-03): Python 3.12.12 and Ollama installed; Flutter SDK NOT installed/on PATH - M0 toolchain setup is the first blocker before any mobile work.

*Confidence: 0.95 | Status: active | Created: 2026-07-03T08:22:16*

---

## Decisions

*Architectural choices, approach selections, and their rationale.*

### Rewrote C:\Users\sidde\AppData\Roaming\Code\User\s...

Rewrote C:\Users\sidde\AppData\Roaming\Code\User\settings.json for RAM/CPU on the 7.6GB machine (backup settings.json.bak). 68 keys, ALL verified against ground truth on disk (each extension's contributes.configuration package.json + 95 builtin manifests + workbench.desktop.main.js bundle) rather than from memory. Key caps: C_Cpp.intelliSenseCacheSize 5120->512, C_Cpp.intelliSenseMemoryLimit 4096->1024, typescript.tsserver.maxTsServerMemory 3072->2048, java.gradle.buildServer.enabled off, gradle.autoDetect off, jupyter.disableJupyterAutoStart true, python.analysis.languageServerMode light, eslint.run onSave, window.restoreWindows one. Deduped a duplicate git.autofetch key. Dropped as placebo (already optimal defaults): editor.smoothScrolling, workbench.list.smoothScrolling, editor.cursorSmoothCaretAnimation, python.analysis.diagnosticMode, terminal.integrated.scrollback.

*Confidence: 0.95 | Status: active | Created: 2026-07-26T16:21:26*

### SpendSmart: MerchantAnomalyService (lib/services/m...

SpendSmart: MerchantAnomalyService (lib/services/merchant_anomaly_service.dart) ports the Worker calculateAnomalies math to on-device merchant granularity: baseline = mean of 3 prior custom months, expectedByNow = baseline*daysElapsed/totalDays, flag at >=1.5x with excess >= max(1, budget*0.05), critical at >=2x, top 5 by excess. When monthlyBudget<=0 it uses an absolute 500 floor instead of the Worker's 1, because merchant baselines are much smaller than category baselines. 18 tests, full suite 64/64 green.

*Confidence: 0.95 | Status: active | Created: 2026-07-26T16:01:56*

### SpendSmart AiCategorizationService.buildBatches dr...

SpendSmart AiCategorizationService.buildBatches drops merchants >64 chars after trim instead of truncating, so every string sent to the Worker /categorize route is byte-for-byte a caller input and echoed results join back without a lookup table; merchants are pre-trimmed because the Worker keys replies by the exact string received.

*Confidence: 0.9 | Status: active | Created: 2026-07-26T16:11:06*

### spendsmart: created lib/services/category_classifi...

spendsmart: created lib/services/category_classifier.dart as the single source of truth for merchant normalization + keyword categorization. Merged 63 keyword rules from pdf_import_service._guessCategory and csv_import_service._parseCategory, deduped (electric covers electricity, shop covers shopping, pharma covers pharmacy). Matching is longest-keyword-first against normalized text, with a wholeWord flag on eat/auto/vi/rent to avoid theatre/autopay/parent false positives. Education keywords kept as a public educationKeywords const outside the ranked table because Category has no education value and the old pdf branch returning Category.other was dead code. ClassificationSource.merchantMemory is never returned by this class.

*Confidence: 0.95 | Status: active | Created: 2026-07-26T14:34:36*

### SpendSmart 2026-07-26 second feature batch: added ...

SpendSmart 2026-07-26 second feature batch: added (1) batch AI categorization and (2) on-device merchant-level anomaly detection. NEW Worker route POST /categorize in cloudflare/ai-analysis-worker/src/index.ts - accepts ONLY {merchants: string[]} (max 50, each max 64 chars, hasOnlyKeys enforced), sanitizeCategories drops any result whose merchant was not in the request (echo-back allowlist prevents hallucinated merchants), plus category/confidence allowlists and dedup; dispatch refactored into analyzeSpending/categorizeMerchants sharing authorizeAndReadBody + requestCompletion. NEW lib/services/ai_categorization_service.dart mirrors ai_spending_analysis_service patterns; categorizeEndpoint derives /categorize by replacing the last path segment of the stored /analyze-spending URL. NEW lib/services/merchant_anomaly_service.dart is pure Dart, ports the Worker's calculateAnomalies math to merchant granularity (1.5x flag, 2x critical, pro-rated expectedByNow, minimumImpact = max(1, budget*0.05) but floor 500 when budget<=0), surfaced in insights_screen as a Merchant Alerts section hidden when empty. PendingScreen got Categorize-with-AI behind a mandatory confirm-every-time consent dialog (deliberately NO persisted consent flag), auto-applies only high-confidence, fans one suggestion out to all expenses sharing that merchant, seeds MerchantMemory from every applied result. PRIVACY BOUNDARY CHANGED: /categorize sends merchant names, which the old README explicitly promised never happened - both READMEs rewritten per-route. normalizeMerchant now strips corporate suffixes (ltd/limited/pvt/private/inc/llp/llc/corp/plc) as trailing tokens. Verified: flutter test 94/94, flutter analyze clean, both worker tests pass via node (Node 26 strips TS, no package.json). NOT DEPLOYED - user runs wrangler deploy themselves.

*Confidence: 0.95 | Status: active | Created: 2026-07-26T16:22:09*

### Refactored OneScan backend chat.py: extracted inli...

Refactored OneScan backend chat.py: extracted inline message persistence and AI-request shaping (safety payload dict, save-message boilerplate) from api/routes/chat.py into new services/chat.py (send_message, _to_safety_payload, _save_message), matching the routes-delegate-to-services pattern used everywhere else in the codebase. Also removed unused Path import in knowledge/loader.py. Did not touch DI for load_knowledge_base in scan_log.py or add new tests for scan_log/chat/routes — flagged as untested but no bug forced it (YAGNI). 22 existing tests still pass.

*Confidence: 0.95 | Status: active | Created: 2026-07-09T03:44:41*

### SpendSmart worker: POST /categorize added to cloud...

SpendSmart worker: POST /categorize added to cloudflare/ai-analysis-worker/src/index.ts. Contract {merchants:string[]} (max 50, each <=64 chars) -> {results:[{merchant,category,confidence}]}. Privacy boundary: route deliberately accepts NO amounts/dates/IDs/notes. Sanitizer sanitizeCategories() drops results whose merchant is not an exact echo of a requested merchant, category not in the 7 allowed, or confidence not low/medium/high; dedupes first-valid-wins; empty array is a valid 200 (caller falls back to local rules), 502 only on upstream failure or unparseable content. Exported as 'categorization' alongside 'analysisMath' for tests.

*Confidence: 0.95 | Status: active | Created: 2026-07-26T15:59:34*

### SpendSmart Insights screen: added _MerchantAlertsS...

SpendSmart Insights screen: added _MerchantAlertsSection (StatefulWidget in lib/screens/insights_screen.dart) rendering MerchantAnomalyService.detect results; memoized with identical() on the raw expenseProvider list plus monthlyBudget/startingDayOfMonth, matching the _syncMerchantIndex pattern in add_expense_screen.dart. Renders SizedBox.shrink() when no anomalies.

*Confidence: 0.95 | Status: active | Created: 2026-07-26T16:07:30*

### OneScan: user chose full MVP scope (M1-M8) for the...

OneScan: user chose full MVP scope (M1-M8) for the implementation plan, demoing on a physical Android phone over LAN to the Windows dev PC. Plan written to docs/PLAN.md on 2026-07-03.

*Confidence: 1 | Status: active | Created: 2026-07-03T08:22:10*

### spendsmart CategoryClassifier keyword-collision fi...

spendsmart CategoryClassifier keyword-collision fix: made 'ola', 'bus', 'jio' wholeWord:true rules and added explicit single-token brand rules 'olacabs', 'redbus', 'jiofiber', 'jiomart' (shopping) to keep OLACABS/REDBUS/JIOFIBER working. Fixes false positives: 'coca cola'->transport, 'business'->transport, 'jiomart'->bills. Covered by test/category_classifier_test.dart (28 tests). Pattern: a wholeWord keyword loses single-token brand spellings, so always pair it with explicit brand rules.

*Confidence: 0.95 | Status: active | Created: 2026-07-26T14:41:58*

### Rewrote Zed global instructions at C:\Users\sidde\...

Rewrote Zed global instructions at C:\Users\sidde\AppData\Roaming\Zed\AGENTS.md (backup AGENTS.md.bak). Restructured around a LOCATE->READ->EDIT->VERIFY tool loop using verified Zed tool names (edit_file, write_file, grep, find_path, list_directory, diagnostics, terminal, spawn_agent, skill, fetch, search_web), added a thinking/effort ladder and a definition-of-done checklist, removed the stale Antigravity IDE section, kept Python/ML, Web, Flutter, PowerShell and security rules.

*Confidence: 0.95 | Status: active | Created: 2026-07-26T14:08:50*

### SpendSmart 2026-07-26: implemented unified Categor...

SpendSmart 2026-07-26: implemented unified CategoryClassifier + revived the dead MerchantMemory store, closing a learn->apply loop. NEW lib/services/category_classifier.dart is the single source of truth (~63 keyword rules merged from pdf_import_service._guessCategory and csv_import_service._parseCategory, both deleted = 112 lines of duplicated rules gone); it also owns normalizeMerchant (strips UPI-/POS/NEFT rails, UPI handles, ref numbers) and the MerchantCategoryLookup typedef + resolveImportedCategory. Resolution order on import: explicit CSV category column > learned merchant memory > keyword rules > fallback; isUncategorized is now true ONLY on total miss (was hardcoded true for all SMS, false for all CSV). MerchantMemory.category made non-final (safe - no Hive schema change, .g.dart untouched, repo has NO build_runner/hive_generator so codegen is impossible). StorageService.lookupMerchantCategory does normalized-exact then token-overlap ranked by usageCount. Teach sites: pending_screen, edit_expense_sheet (only when category actually changed), add_expense_screen. Read wired via ref.read(storageServiceProvider).lookupMerchantCategory tear-off in pdf_import_screen and settings_screen. Also fixed _cleanDescription truncating UPI-Swiggy to UPI, and 3 substring collisions (coca cola->transport via ola, jiomart->bills via jio, business->transport via bus) using wholeWord rules + explicit brand rules. Verified: flutter test 46/46 (was 18; +28 new classifier tests), flutter analyze clean project-wide. Flutter lives at C:\flutter\bin\flutter.bat, NOT on PATH.

*Confidence: 0.95 | Status: active | Created: 2026-07-26T15:52:03*

### Zed 1.12.0 on Windows. Optimized C:\Users\sidde\Ap...

Zed 1.12.0 on Windows. Optimized C:\Users\sidde\AppData\Roaming\Zed\settings.json for agent workflow (backup settings.json.bak): default_profile ask->write; agent.tool_permissions set to a 'balanced' policy (read/LSP/search auto-allow, edit_file+write_file allow with always_deny on .env|secrets/|*.pem|*.key|id_rsa|credentials.json, terminal confirm-by-default with allowlist for git status/diff/log, npm/pnpm build+test, pytest, cargo, flutter/dart, tsc, ls/dir and always_confirm on git push, reset --hard, rm -r, Remove-Item -Recurse); single_file_review true, expand_edit_card false, auto_compact 85%, use_modifier_to_send true, show_turn_stats true, play_sound_when_agent_done when_hidden, subagent_model sonnet-5 without thinking, Conventional Commits commit_message_instructions, and a custom read-only 'research' profile with all context servers. Zed 1.12 also ships LSP agent tools go_to_definition/find_references/rename_symbol/apply_code_action/get_code_actions that are absent from the public docs tools page.

*Confidence: 0.95 | Status: active | Created: 2026-07-26T14:15:06*

---

## Goals

*Objectives, targets, and milestones to track progress.*

*No memories of this type.*

---

## Commitments

*Promises, obligations, and TODOs that need follow-through.*

*No memories of this type.*

---

## Preferences

*User and entity preferences for personalization.*

*No memories of this type.*

---

## Relationships

*Entity connections, team context, and collaboration patterns.*

*No memories of this type.*

---

## Context

*Session summaries, status updates, and conversation state.*

### SpendSmart (Flutter/Hive local-first expense track...

SpendSmart (Flutter/Hive local-first expense tracker, v2.1.7, ~14.4k LOC lib/) AI architecture audit 2026-07-26: AI = one manual 'Analyze spending' button in insights_screen.dart:474 -> POSTs category totals to user-configured Cloudflare Worker (cloudflare/ai-analysis-worker/src/index.ts) -> OpenRouter. Worker computes forecast+anomalies DETERMINISTICALLY (calculateForecast:208, calculateAnomalies:231); the LLM only rewords them. Key dead code: MerchantMemory box+provider fully built but ZERO consumers (storage_service.dart:89, merchant_memory_provider.dart), SMS parser only referenced by tests, lib/widgets/charts.dart unused. Two divergent hardcoded keyword categorizers: pdf_import_service.dart:175-253 (~60 literals) and csv_import_service.dart:236-274 (~20). No compute()/Isolate anywhere; no derived Riverpod providers - all aggregation+sorting inline in build(). AI proxy token stored plaintext in SharedPreferences. Default worker model is cohere/north-mini-code:free (a CODE model for a finance task).

*Confidence: 0.95 | Status: active | Created: 2026-07-26T14:23:25*

### OneScan ponytail-review session 2026-07-08: review...

OneScan ponytail-review session 2026-07-08: reviewed ai_service/ (304 lines, 8 files) - found nothing to cut, verdict 'Lean already. Ship.' net 0 lines. Currently mid-review of mobile/lib/ (1599 lines, 23 Flutter/Dart files) via background Explore agent (agentId af514da9ecf3f95a6) scanning for unused abstractions, speculative config, dead code, hand-rolled logic vs stdlib/Flutter widgets. Findings pending.

*Confidence: 0.9 | Status: active | Created: 2026-07-09T03:49:09*

---

## Events

*Important conversations, milestones, and temporal occurrences.*

*No memories of this type.*

---

## Learnings

*Knowledge acquired from experience, corrections, and insights.*

### VS Code Python/Jupyter memory research (Windows, 7...

VS Code Python/Jupyter memory research (Windows, 7.6GB RAM machine, Pylance 2026.3.1 / python 2026.4.0 / jupyter 2025.9.1): python.analysis.memory.keepLibraryAst DOES NOT EXIST (0 occurrences in Pylance 2026.3.1 package.json) - it is a zombie key from old blog posts, must be dropped. python.analysis.languageServerMode='light' IS real (enum light/default/full) and is the single biggest lever: it sets exclude=['**'], indexing=false, useLibraryCodeForTypes=false, enablePytestSupport=false. python.analysis.diagnosticMode ALREADY defaults to openFilesOnly and autoImportCompletions ALREADY defaults to false - setting them is a no-op placebo. python.analysis.nodeArguments (default ['--max-old-space-size=8192']) only applies when nodeExecutable is set; old name nodeExecutableArgs is gone. Setting nodeExecutable to a real node RAISES memory (loses VS Code's pointer compression) - wrong direction. jupyter.disableJupyterAutoStart=true is the biggest Jupyter win. ms-toolsai.jupyter activates on onLanguage:python (not just notebooks), so VS Code Profiles split is the real structural fix.

*Confidence: 0.95 | Status: active | Created: 2026-07-26T15:05:54*

### SpendSmart limitation: CategoryClassifier.normaliz...

SpendSmart limitation: CategoryClassifier.normalizeMerchant does not strip corporate suffixes, so 'SWIGGY LTD' -> 'swiggy ltd' and does NOT collapse with 'swiggy'. Merchant grouping (anomalies, merchant memory) therefore splits those. Fix belongs in normalizeMerchant as a suffix strip (ltd/limited/pvt/inc).

*Confidence: 1 | Status: active | Created: 2026-07-26T16:01:59*

### VS Code perf: 'code --profile NAME --install-exten...

VS Code perf: 'code --profile NAME --install-extension X' FAILS with 'Profile not found', and 'code --profile NAME --new-window FOLDER' does NOT create the profile while VS Code is already running (CLI forwards to the running instance; globalStorage/storage.json only flushes on exit). Also '--disable-extension' is explicitly non-persistent. CONCLUSION: VS Code profile creation cannot be scripted on a running instance - it requires the UI. Verified on VS Code 1.129.1, 2026-07-26.

*Confidence: 0.95 | Status: active | Created: 2026-07-26T16:20:56*

---

## Observations

*Patterns noticed, behavioral notes, and recurring themes.*

### Claude Code on this machine routes through third-p...

Claude Code on this machine routes through third-party proxy ANTHROPIC_BASE_URL=https://cc.freemodel.dev with a non-Anthropic key format (fe_oa_, not sk-ant-). Measured 2026-07-26: proxy answers 20/20 requests but latency degrades 0.64s->2.99s under 12-way concurrency, while api.anthropic.com stays flat ~0.40s. A parallel 11-agent workflow lost 9 agents to ENOTFOUND / connection-closed. Proxy is the likely cause but this was NOT reproduced on demand - do not state it as proven. Switching off the proxy requires /login (the key is proxy-specific), not just a settings edit.

*Confidence: 0.85 | Status: active | Created: 2026-07-26T16:21:35*

---

## Artifacts

*Tool outputs, files, reports, and external references.*

*No memories of this type.*

---

## Errors

*Failure records, bugs, and lessons learned from mistakes.*

*No memories of this type.*

---

*End of memory export.*
