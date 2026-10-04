# SpendSmart — Project Context

> Regenerated 2026-10-05 after full redesign (was 2026-10-04). Source: `lib/`, `test/`,
> `pubspec.yaml`, `README.md`, `.opencode/plan/spendsmart-redesign-plan.md`.
> Gates at push: `flutter analyze` clean, `flutter test` 122/122 green, release APKs built
> (`--release --split-per-abi --obfuscate`).

## 1. What it is
Air-gapped, zero-telemetry personal expense engine. Flutter 3 + Dart 3 + Hive NoSQL,
Android-first. No HTTP/network deps, no Firebase/analytics. Hive files in
`/data/user/0/.../app_flutter/`; exports via cache + `FLAG_GRANT_READ_URI_PERMISSION`.

## 2. Theme system (new)
Three-layer tokens. Raw palette in `Scheme` (`lib/utils/constants.dart`), per-brightness
view `SchemeTheme.dark/.light/.of(context)` (`lib/utils/theme.dart`), focus/scrim in
`lib/utils/design.dart`. Legacy `AppColors`/`AppTheme` retained untouched underneath.
- **Dark:** bg `#010736` · surface `#0D1C42` · elevated `#22396F` · ink `#E9EDF5`
  (16.5:1) · muted `#9AA6C2` (7.9:1) · border = ink @10% · CTA = ink fill + `#010736` text.
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
  active filled pill, labels always. Center quick-add FAB + chip overlay + 3 controllers
  DELETED. Each screen owns its contextual `+`; Home keeps the primary Add Expense CTA.
- Dead code purged: `lib/app.dart` stub, unused copyWiths/providers/getters
  (`addExpenseFromSMS`, group `updateExpense`, `deleteBudget`, `goalFor`/`clearGoal`,
  `addTip`, `save/deleteMerchant`, `memoryFor`, `getPendingExpenses`, `getBudget`,
  `getGroupExpenses`, `clearAll`→ replaced by `clearAllData`), dead tokens Durations/shadows.

## 4. Data layer
TypeIds 0–8 (0–3,5 codegen; 4,6,7,8 hand-written null-tolerant). Boxes: `expenses`,
`merchants`, `budgets`, `lendings`, `incomes`, `recurring_expenses`, `split_groups`,
`group_expenses`. `SplitGroup.myParticipantId` = optional trailing Hive field 4
(null = legacy first-participant behavior, both directions safe).
`FinancialPeriod` half-open cycles, startDay clamp 1–28. Corruption → quarantine, never delete.
Notifications persist via explicit stable-id switch (ids 0/1/3, 2 vacant legacy→tip).

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
explicit-accept row; never auto-overrides user pick.

## 7. Tests & tooling (122/122)
`test/` 15 files: period math, classifier, anomaly (+divisor/exclusion), pulse projection
(+split/cold-start), engine (+fixed detection), CSV (+precedence), wipe, provider behavior
(+identity, +legacy notification index), visibility (compact-phone both themes, no-SMS copy).
`analysis_options.yaml` = flutter_lints only. Flutter at `C:\flutter\bin\flutter.bat` (NOT on PATH).
Release: `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build\symbols`
→ arm64-v8a 19.8 MB, armeabi-v7a 17.6 MB, x86_64 21.4 MB (in Downloads).

## 8. Known follow-ups (not done)
- Hardcoded colors in untouched `category_grid.dart`, `edit_expense_sheet.dart`.
- Per-category anomaly baselines; mid-month coincidence blind spot (accepted per spec).
- `context.md` at repo root = agent doc; keep or gitignore at next commit.
