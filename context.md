# SpendSmart — Project Context

> Updated 2026-10-16 for v2.2.0+220 (custom categories, backup/restore, report center).
> Previous regen 2026-10-05 after full redesign. Source: `lib/`, `test/`, `pubspec.yaml`,
> `README.md`, `.opencode/plan/spendsmart-redesign-plan.md`.
> Gates at push: `flutter analyze` clean, `flutter test` 157/157 green, release APKs built
> (`--release --split-per-abi --obfuscate`).

## 1. What it is
Air-gapped, zero-telemetry personal expense engine. Flutter 3 + Dart 3 + Hive NoSQL,
Android-first. No HTTP/network deps, no Firebase/analytics. Hive files in
`/data/user/0/.../app_flutter/`; exports via cache + `FLAG_GRANT_READ_URI_PERMISSION`.

## 2. Theme system (new)
Three-layer tokens. Raw palette in `Scheme` (`lib/utils/constants.dart`), per-brightness
view `SchemeTheme.dark/.light/.of(context)` (`lib/utils/theme.dart`), focus/scrim in
`lib/utils/design.dart`. `AppTheme` now exposes these tokens through Material's
`ColorScheme`; legacy `AppColors` remains only for compatibility and persisted avatar values.
- **Dark:** bg `#00021A` · surface `#080F2E` · elevated `#172957` · ink `#E9EDF5`
  · muted `#9AA6C2` · border = ink @10% · CTA = ink fill + `#00021A` text.
- **Light:** bg `#F9F7F7` · surface `#FFFFFF` · tint `#DBE2EF` · ink `#112D4E` (13:1) ·
  muted `#5C6B80` (5.1:1) · primary `#3F72AF` (CTA white text 4.96:1).
- Semantic trio + 7 category hues defined PER theme (one hex can't pass 4.5:1 on both
  backgrounds — verified in comments). Scrim black 50%. Cream `#FCF1D0` rejected.
- Language: minimal solid surface + 1px border cards (16–18dp), CTA pills ≥48dp,
  inline errors, tabular numerals for all money. Exactly ONE glass hero (pulse card).
  Reduced-motion snaps all entrance tweens. No emojis as icons. Touch targets ≥44dp.

## 3. Entry, navigation & state
- Entry `lib/main.dart` → `SpendSmartApp` → `SplashScreen`; DI via ProviderScope overrides.
- Riverpod v3 only. Write-verify pattern (await box write → reload → assign), except
  `notificationProvider` (mutate-then-persist).
- **Dock = 5 equal tabs** (Home/Analytics/Budget/Groups/Settings), surface + hairline,
  active filled pill, labels always. Body is a swipeable `PageView` of `_KeepAliveTab`s
  (was `IndexedStack`); a tab tap animates to the page and ignores intermediate
  `onPageChanged` events via `_tapTarget` (no highlight flicker / extra haptics).
  Center quick-add FAB + chip overlay + 3 controllers
  DELETED. Each screen owns its contextual `+`; Home keeps the primary Add Expense CTA.
- Dead code purged: `lib/app.dart` stub, unused copyWiths/providers/getters
  (`addExpenseFromSMS`, group `updateExpense`, `deleteBudget`, `goalFor`/`clearGoal`,
  `addTip`, `save/deleteMerchant`, `memoryFor`, `getPendingExpenses`, `getBudget`,
  `getGroupExpenses`, `clearAll`→ replaced by `clearAllData`), dead tokens Durations/shadows.

## 4. Data layer
TypeIds 0–9 (0–3,5 codegen; 4,6,7,8,9 hand-written null-tolerant). Boxes: `expenses`,
`merchants`, `budgets`, `lendings`, `incomes`, `recurring_expenses`, `split_groups`,
`group_expenses`, `custom_categories`. Expenses may reference stable custom categories.
- **Custom categories (v2.2.0):** `CustomCategory` typeId 9 (`id`, `name`, `iconCodePoint`,
  `colorValue`, `archived`, `mergedIntoId`). Trailing nullable `customCategoryId` on
  `Expense` (field 9) and `Budget` (field 3) — 2.1.7 records load with null. Built-in
  `Category` stays the legacy-safe fallback on every expense. Icons come from the const
  `customCategoryIcons` list (lookup by code point, fallback `Icons.category`) so release
  icon tree-shaking works — never build `IconData` from a runtime int.
- **Category keys:** `ExpenseCategoryKey.builtIn(cat)` / `.custom(id)`; storage form
  `builtIn:<index>` / `custom:<id>`. Budget spending maps are keyed by `ExpenseCategoryKey`
  (`checkBudgets` also accepts legacy `Category`/id keys).
`SplitGroup.myParticipantId` = optional trailing Hive field 4
(null = legacy first-participant behavior, both directions safe).
`FinancialPeriod` half-open cycles, startDay clamp 1–28. Corruption → quarantine, never delete.
Notifications persist via explicit stable-id switch (ids 0/1/3, 2 vacant legacy→tip), plus
`isRead` and `categoryKey`. Budget alert dedupe matches `categoryKey`, or — for pre-2.2.0
notifications with null `categoryKey` — the `": <label>"` title suffix (no re-alert on upgrade).

## 5. Services & algos
- **CSV:** 5 MB guard, isolate decode, alias headers, strict dates, formula-injection
  round-trip; single shared `CategoryClassifier.exactCategory`; memory lookup forwarded.
- **PDF:** syncfusion extractor in isolate, 10 MB cap, 3 debit regexes, header/credit skips.
- **Classifier:** normalizeMerchant (rails/handles/ref-nos/corp suffixes), longest-keyword-first
  with wholeWord guards; resolution explicit > memory > confident-keyword > fallback.
- **Forecast (new):** `FixedObligationService.detect()` — same normalized merchant in ≥2
  consecutive prior periods with spread/mean <15% → fixed. Forecast = fixed 1:1 +
  variable burn-rate pace (`projectMonthEndDetailed`), cold-start `isEarlyEstimate` flag
  rendered in UI. Baselines divide by months-with-data.
- **Anomaly:** fixed-within-commitment excluded; guard relaxed to ≥2-of-3 months;
  1.5x flag / 2x critical + min-impact kept.
- **AI advisor:** fully on-device (memory → classifier → fallback; review + keyword Q&A).
- **Export:** CSV (sanitized) / PDF report / lending PDF via share sheet.
- **Category catalog (new):** `ExpenseCategoryCatalog` in
  `lib/services/expense_category_resolver.dart` (via `expense_category_provider.dart`) is
  the single resolver for calculations, reports, CSV/PDF export, notifications and the AI
  advisor. Merged categories follow `mergedIntoId` (cycle-safe); a custom label that
  collides with a built-in one renders as `"<label> (custom)"`.
- **Backup (new):** `BackupService` — JSON `format: spendsmart-backup`, `version: 1`, all
  Hive boxes + used prefs (incl. `daily_goals`, `app_notifications_v1`). Full strict schema
  validation before any write; restore is insert-only (never overwrites/wipes).
  `createSnapshot()` re-parses its own output, so the validator must accept everything the
  app writes (notifications: required id/title/body/time/type, optional isRead/categoryKey;
  group expenses only need an existing group — payer/share membership is NOT enforced
  because editing a group can remove a participant who still has expenses).
- **Reports (new):** `ReportService` + `report_models.dart` — presets (current/previous
  financial period, last 7/30/90 days, custom), inclusive date-only ranges, built-in /
  custom / uncategorized filters, 4 sort orders, sanitized CSV.

## 6. Screens (all retokened, §3.1–3.7 + secondaries)
Home (hero + CTA + pulse hero + compact linked rows + top-4 cats + recents) →
Transactions (sticky fixed-height filter bar, range = removable chip, `+ Expense`) →
Analytics (compact 140px donut, full calendar, Trends MoM row, per-slice label contrast) →
Budget (active-first list + expander, remaining lines, displayName dropdown) →
Groups (AppBar `+ New Group`, tappable me-chips with ME badge, settle sheets) →
Settings ("Settings"; Preferences → Appearance → Planning → Data & Import → Export →
Danger Zone with confirm-gated erase-all) → Income / Lending (WIRED via Settings Planning,
was test-only) / Recurring / Goals / Insights / Pending / Import / Notifications / Onboarding.
AddExpense: merchant autocomplete + removable `[icon Name ×]` type pill + "Use X instead?"
explicit-accept row; never auto-overrides user pick. Custom categories pickable (forces
built-in `other` as fallback); link to the category manager.
New in v2.2.0 (Settings → Data): **Backup & Restore** (share / pick / preview / confirm
restore; invalidates every data provider through a container captured before the await,
so leaving mid-restore still refreshes state), **Manage Categories** (add / rename / merge /
archive), **Report Center** (preset + custom ranges, category filter, sort, CSV share).

## 7. Tests & tooling (157/157)
`test/` 18 files: period math, classifier, anomaly (+divisor/exclusion), pulse projection
(+split/cold-start), engine (+fixed detection), CSV (+precedence), wipe, provider behavior
(+identity, +legacy notification index, +built-in budget alerts on `ExpenseCategoryKey`
spending, +pre-2.2.0 alert dedupe), visibility (compact-phone both themes, no-SMS copy),
and new in v2.2.0: backup (schema rejection, round-trip, real notification shape),
custom-category provider, category resolver, lending provider, report service.
`analysis_options.yaml` = flutter_lints only. Flutter at `C:\flutter\bin\flutter.bat` (NOT on PATH).
Build/test from a copy in `%LOCALAPPDATA%\Temp\opencode\spendsmart` (OneDrive locks/stalls;
robocopy with `/R:1 /W:1` — default retries hang on `.plugin_symlinks`).
Release: `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build\symbols`
→ v2.2.0 (versionCode 220 + per-ABI offset, e.g. arm64 = 2220), release-key signed:
arm64-v8a 20.3 MB, armeabi-v7a 18.1 MB, x86_64 21.8 MB → `Downloads\SpendSmart-v2.2.0-<abi>.apk`.

## 8. Known follow-ups (not done)
- Per-category anomaly baselines; mid-month coincidence blind spot (accepted per spec).
- Device-level verification of nested swipe gestures and native Android launch resources.
- No UI to un-archive a custom category (`CustomCategoryNotifier.unarchive` exists).
- Report totals: a custom category literally named "Uncategorized" is overwritten by the
  real uncategorized bucket (`report_models.dart` `categoryTotals`).
- Transactions built-in filter excludes expenses whose `customCategoryId` points to a
  missing custom category (only reachable via backup import); Analytics counts them.
- `CustomCategoryNotifier.delete()` only checks expenses, not budgets / merged refs (no UI
  caller yet — fix before wiring it up).
- `context.md` at repo root = agent doc; keep or gitignore at next commit.
