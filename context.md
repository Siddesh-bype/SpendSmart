# SpendSmart — Project Context

> Generated 2026-10-04 via parallel-agent exploration. Source: `lib/`, `test/`, `pubspec.yaml`, `README.md`, `MEMORY.md`.

## 1. What it is
Air-gapped, zero-telemetry personal expense engine. Flutter 3 + Dart 3 + Hive NoSQL, Android-first. `spendsmart 2.1.7+217`, SDK `^3.10.7` (`pubspec.yaml:1-7`). No HTTP/network deps, no Firebase/analytics. Privacy: Hive files in `/data/user/0/.../app_flutter/`, exports via cache + `FLAG_GRANT_READ_URI_PERMISSION`.

## 2. Entry & State
- Entry: `lib/main.dart:12-15` `WidgetsFlutterBinding.ensureInitialized()` + `SharedPreferences.getInstance()`; Hive boxes **not** opened here (avoid first-frame stall), deferred to `SplashScreen`/`OnboardingScreen.init()`.
- DI: `main.dart:20,24-27` injects `SharedPreferences` + uninitialized `StorageService()` via `ProviderScope(overrides:)`.
- Shell: `main.dart:33-52` `SpendSmartApp extends ConsumerWidget` watches `appSettingsProvider` for theme, `home: SplashScreen()`.
- Riverpod v3 only (`flutter_riverpod ^3.2.1`): 2x plain `Provider` (DI roots: `sharedPreferencesProvider`, `storageServiceProvider` — throws if pre-override) + 11x `NotifierProvider`. No legacy `StateProvider/StateNotifier`.
- Write-verify pattern: `await box.put/delete` → re-read full list → `state = ...` via `_load/_reload` helpers (`expense_provider.dart:17-24`, `budget_provider.dart:14-26`, `lending_provider.dart:14-34`, `group_provider.dart:16-18`, `income_provider.dart:18,23`). Exception: `notification_provider.dart:35-50` mutates `state` first, then `_persist()` (no reload).

| Provider | State | Backing |
|---|---|---|
| `appSettingsProvider` | `AppSettings` (currency, budget, theme, onboarding, startDay 1-28) | prefs keys |
| `expenseProvider` | `List<Expense>` | `expenses` box |
| `incomeProvider` | `List<Income>` desc by date | `incomes` box |
| `budgetProvider` | `List<Budget>` keyed by `category.index` | `budgets` box |
| `recurringExpenseProvider` | `List<RecurringExpense>` + `generateDueExpenses()` | `recurring_expenses` box |
| `lendingProvider` | `List<Lending>` + settle flag | `lendings` box |
| `splitGroupProvider` / `groupExpenseProvider` | groups + group expenses, cascade delete | `split_groups` / `group_expenses` |
| `merchantNotifierProvider` | `List<MerchantMemory>` learn→apply loop | `merchants` box |
| `spendingGoalProvider` / `dailyGoalProvider` | single goal / `Map<YYYY-MM-DD,double>` JSON blob | prefs |
| `notificationProvider` | `List<AppNotification>` JSON `app_notifications_v1` | prefs |

## 3. Data layer (`lib/models/`, `lib/services/storage_service.dart`, `lib/utils/financial_period.dart`)
TypeIds 0-8, no collisions (0-3,5 codegen `.g.dart`; 4,6,7,8 hand-written null-tolerant adapters):
- `Category` enum typeId 0: food, transport, shopping, health, entertainment, bills, other + `displayName/color/icon` ext.
- `Expense` typeId 1: id/title/amount/category/date/note?/isManual/isUncategorized(source mutable)/source + `copyWith`.
- `MerchantMemory` typeId 2: merchantName/category(mutable)/usageCount/lastUsed.
- `Budget` typeId 3: category/monthlyLimit(mutable)/alertAt default 0.8.
- `Income` typeId 4 manual; `Lending` typeId 5 (isSettled mutable); `RecurringExpense` typeId 6 manual (`computeNextDue`: daily+1d, weekly+7d, yearly+1y, monthly clamp via `DateTime(y,m+1,0).day`); `SplitGroup` typeId 7 manual (`Participant` plain, not Hive); `GroupExpense` typeId 8 manual (`ParticipantShare` plain).
- Plain-Dart (no box): `AppSettings`, `AppNotification`, `SpendingGoal` → SharedPreferences.
- Boxes (`storage_service.dart:17-24`): `expenses, merchants, budgets, lendings, incomes, recurring_expenses, split_groups, group_expenses`. Keying: id-keyed except `merchants` by normalized string (+legacy-lowercase fallback) and `budgets` by `category.index`.
- No atomic/multi-box transactions. `saveExpenses` uses single `putAll` (bulk-opt, not atomic). Merchant rekey = `delete`+`put` (non-atomic). `clearAll()` = 8 sequential `clear()`. `GroupExpense.groupId` has no FK; filtered linearly.
- `FinancialPeriod` (`utils/financial_period.dart`): half-open `[start, endExclusive)`, `clamp(startDay,1,28)`, `containing/shifted/previous/next/daysElapsed/daysRemaining/label`. Fixes calendar-month payday bug.
- Corruption: never-delete quarantine (`storage_service.dart:26-106`) — on `openBox` failure record `openFailures[name]`, move `.hive`+`.lock` to `<name>.corrupt-<ts>.hive`, reopen fresh. Unencrypted storage intentional.

## 4. Services (`lib/services/`)
- **CSV** (`csv_import_service.dart`): 5 MB guard, `compute(_decodeCsv)` isolate + sync fallback. Header `toLowerCase().trim()` alias match: id/date(`date,txn date...`)/title(`title,merchant,description,narration`)/amount(`amount,debit,withdrawal...`, credit-only rejected)/category/source/manual/note. Requires date+title+amount. Amount strips `rs/inr/₹/$/€/£/¥`. Dates: `yyyy-MM-dd HH:mm:ss, yyyy-MM-dd, dd/MM/yyyy, MM/dd/yyyy, dd-MM-yyyy` strict. Undoes `ExportService.sanitizeCell` `'<formula>` round-trip. Defaults `source=csv, isManual=true, id=uuid.v4()`. No SHA-256 — id-reuse else uuid.
- **PDF** (`pdf_import_service.dart`): `syncfusion_flutter_pdf` `PdfTextExtractor` in `compute`, 10 MB cap. 3 debit regexes (HDFC `dd/MM/yy + -amt + Dr?`, SBI `dd MMM yyyy + amt + Dr`, generic `date+amt+(D|Dr|Debit|DR)`). Skips headers (`opening/closing balance...`) and credits (`cr|credit|salary|refund...`). Dates `dd/MM/yyyy` (+2000 for 2-digit) / `dd MMM yyyy` with `_strictDate` round-trip. `_cleanDescription` preserves full merchant (UPI-Swiggy bug fixed; stripping in `normalizeMerchant`). Dedup `Set<lower|amt.2f|yyyy-m-d>`, sort desc.
- **Classifier** (`category_classifier.dart`): `normalizeMerchant` lower→strip `@handle`→seps to space→strip `\d{5,}`→strip leading rails (`upi,pos,atm,neft,imps,rtgs,ach,mandate,bil,ecom,vps`)→strip trailing refs (`ref,txn,rrn,utr,ord...`)→strip trailing corp suffixes (`ltd,pvt,inc,llp,llc,corp,plc`, keep last token). `classify`: exact displayName → longest-keyword-first (`wholeWord` via padded `' kw '` for eat/ola/bus/auto/jio/vi/rent + brand companions olacabs/redbus/jiofiber) → fallback `(other, unconfident)`. `educationKeywords` intentionally dead (no `Category.education`). Resolution: CSV `namedCategory > memory > classify(rawCategory) if confident > resolveImported(title)`; shared `resolveImportedCategory = memory > classify > (other, uncategorized=true)`. `MerchantCategoryLookup` typedef keeps importers Hive-free.
- **Anomaly** (`merchant_anomaly_service.dart:38-105`): 3-mo baseline, `expectedByNow=baseline*elapsed/total`, flag `>=1.5x && excess>=max(1,budget*0.05)` (floor 500 when budget<=0), critical `>=2x`, top-5 by excess. Engine (`financial_calculation_engine.dart:106-236`): `overBudget if spend>budget||burn>1.25`, `caution if burn>1.05`; health 40+25+20+15.
- **Export**: CSV `export_service.dart` header `ID,Date,Title,Amount,Category,Source,Is Manual,Is Uncategorized,Note` + `sanitizeCell` anti-formula-injection → `SpendSmart_Export_*.csv`. PDF `pdf_export_service.dart` indigo banner + top-6 bars + paginated history → `SpendSmart_Report_*.pdf`. Lending `lending_pdf_service.dart` active/settled splits + net-per-friend → `SpendSmart_Lending_*.pdf`.
- **AI advisor** (`ai_financial_advisor_service.dart`): fully on-device, no `http` import. `categorizePendingExpenses` (memory→classifier→pay/transfer fallback), `generateReview` (pacing + >35% dominant + >=90% budget + health recs), `answerSpendingQuery` keyword dispatch.

## 5. UI (`lib/screens/` 22 files, `lib/widgets/` 10 files, `lib/utils/theme|design|constants`)
All screens `Consumer*` except plain `SplashScreen`. Shell `MainScaffold` (bottom nav). Flows: Home(dashboard+pulse+alerts) → Transactions(search/filter ledger) → Analytics(`fl_chart`+`SpendingCalendar` by `FinancialPeriod`) → Budget(per-category vs actuals) → Income/Lending/Groups(+detail/add/settle sheets) → Goals/Recurring → Insights(AI review+Q&A+merchant alerts) → Pending(uncategorized review + AI batch) → PdfImport(CSV+PDF) → Notifications → Settings(currency/startDay/theme).
Widgets: `GlassContainer` (blur card), `MoneyText` (tabular figures), `SectionHeader`, `ExpenseTile` (slidable edit/delete), `CategoryGrid`, `EmptyState`, `EditExpenseSheet`, `DayDetailSheet`, `SpendingCalendar` (heatmap), `SpendingPulseCard` (pro-rated projection, null if <3d/no-spend).
Tokens (`design.dart` canonical, no literals): spacing 4/8/12/16/24/32, radii 8/14/24/28, durations 150/250/400ms, type 32/22/17/15/13/11/10. Material3, light/dark themes (`theme.dart`). Palette (`constants.dart`): primary `123B5D`, accent `16A6C7`, category colors food `E07B6A` … other `90A4AE`.

## 6. Tests & Tooling
- `test/` 12 files ~95+ cases: `financial_period` ~17, `category_classifier` ~30+, `merchant_anomaly` ~15+, `financial_calculation_engine` 6, `provider_behavior` 5, `spending_pulse` 6, `csv` 4, `date_extension`/`validation`/`analytics_daily`/`pdf_import` 1-4 each, `screen_visibility` 2 widget (compact-phone light+dark fit, onboarding no-SMS-copy). Gaps: only 2 widget tests, no goldens, no per-screen interaction.
- `analysis_options.yaml`: `include: package:flutter_lints/flutter.yaml` only.
- Commands (from repo root): `C:\flutter\bin\flutter.bat pub get | analyze | test [--reporter=expanded] | run | build apk --release --split-per-abi --obfuscate` (Flutter NOT on PATH per MEMORY.md).
- Key deps: `hive/hive_flutter, flutter_riverpod, fl_chart, syncfusion_flutter_pdf, csv, file_picker, share_plus, package_info_plus, intl, uuid, flutter_slidable, open_filex, path_provider, shared_preferences`.

## 7. Known constraints (from MEMORY.md)
- Dev PC 7.6 GB RAM + OneDrive-hosted tree → prefer Temp copy for builds, kill stray `node/bun/flutter`.
- No `build_runner/hive_generator` in repo → cannot regen `.g.dart`; keep `MerchantMemory.category` non-final pattern for schema-safe edits.
- `normalizeMerchant` corp-suffix strip already landed (was a known split bug).
