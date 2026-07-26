# Memory — claude-code

> Generated: 2026-07-26 19:46:17  
> Total memories: **6**  
> Breakdown: fact: 1, decision: 4, context: 1

---

## Instructions

*Standing rules, constraints, and guidelines to always follow.*

*No memories of this type.*

---

## Facts

*Verified information, project status, and established truths.*

### OneScan dev environment (2026-07-03): Python 3.12....

OneScan dev environment (2026-07-03): Python 3.12.12 and Ollama installed; Flutter SDK NOT installed/on PATH - M0 toolchain setup is the first blocker before any mobile work.

*Confidence: 0.95 | Status: active | Created: 2026-07-03T08:22:16*

---

## Decisions

*Architectural choices, approach selections, and their rationale.*

### Refactored OneScan backend chat.py: extracted inli...

Refactored OneScan backend chat.py: extracted inline message persistence and AI-request shaping (safety payload dict, save-message boilerplate) from api/routes/chat.py into new services/chat.py (send_message, _to_safety_payload, _save_message), matching the routes-delegate-to-services pattern used everywhere else in the codebase. Also removed unused Path import in knowledge/loader.py. Did not touch DI for load_knowledge_base in scan_log.py or add new tests for scan_log/chat/routes — flagged as untested but no bug forced it (YAGNI). 22 existing tests still pass.

*Confidence: 0.95 | Status: active | Created: 2026-07-09T03:44:41*

### OneScan: user chose full MVP scope (M1-M8) for the...

OneScan: user chose full MVP scope (M1-M8) for the implementation plan, demoing on a physical Android phone over LAN to the Windows dev PC. Plan written to docs/PLAN.md on 2026-07-03.

*Confidence: 1 | Status: active | Created: 2026-07-03T08:22:10*

### Rewrote Zed global instructions at C:\Users\sidde\...

Rewrote Zed global instructions at C:\Users\sidde\AppData\Roaming\Zed\AGENTS.md (backup AGENTS.md.bak). Restructured around a LOCATE->READ->EDIT->VERIFY tool loop using verified Zed tool names (edit_file, write_file, grep, find_path, list_directory, diagnostics, terminal, spawn_agent, skill, fetch, search_web), added a thinking/effort ladder and a definition-of-done checklist, removed the stale Antigravity IDE section, kept Python/ML, Web, Flutter, PowerShell and security rules.

*Confidence: 0.95 | Status: active | Created: 2026-07-26T14:08:50*

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

*No memories of this type.*

---

## Observations

*Patterns noticed, behavioral notes, and recurring themes.*

*No memories of this type.*

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
