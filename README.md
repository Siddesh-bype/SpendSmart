# SpendSmart

SpendSmart is a local-first Flutter expense tracker for Android. Financial data stays in Hive storage on the device unless the user explicitly exports or shares a report.

That local storage is not encrypted. The app has no password to derive a key from, so records are protected by Android's per-app sandbox only — a rooted device, a full-device backup, or physical access to an unlocked phone can read them.

## Features

- Add, edit, delete, search, filter, and categorize expenses.
- Track monthly and category budgets with configurable month start dates.
- Record income, recurring expenses, lending entries, and split-group expenses.
- Review spending charts, trends, goals, and local budget notifications.
- Optionally request an AI spending review through your own Cloudflare Worker and OpenRouter account. Only category totals, month progress, budget, and currency are sent, and only after you tap Analyze spending.
- Optionally ask the same Worker to suggest categories for pending transactions. Only merchant name strings are sent, and only after you tap Categorize with AI.
- Import text-based bank statement PDFs and compatible CSV files with a review step.
- Export expense reports as PDF or CSV and share them through Android apps.
- Light, dark, and system themes with reduced-motion support.

SpendSmart does not provide cloud synchronization, automatic SMS monitoring, or
cross-device backup. An account exists only to unlock the optional AI features;
it holds no financial data, and the app works fully offline without one.

## Optional AI Review

The Android app never contains an OpenRouter key. It ships with the public URL of
the Worker in `cloudflare/ai-analysis-worker`, which holds the key as a Cloudflare
secret. Sign in from Settings to unlock the AI features; the session token is kept
in the Android Keystore and is capped by a per-account daily quota.

Two actions can send data to it. Both are opt-in: each runs only when you tap it,
never automatically and never in the background. They send different data.

- **Analyze spending** (Insights) sends aggregate category totals, custom-month
  progress, the monthly budget, and the currency. It sends no merchant names, no
  transaction titles, notes, dates, or IDs, and no individual transactions. The
  forecast and the anomaly list are computed in the Worker; the model only
  explains them.
- **Categorize with AI** (Pending Categorization) sends merchant name strings and
  nothing else — at most 50 per request, each at most 64 characters. No amounts,
  dates, IDs, notes, or existing categories go with them. The Worker discards any
  suggestion whose merchant it did not send, whose category is not one of the
  app's categories, or whose confidence is not low, medium, or high.

## Requirements

- Flutter SDK compatible with Dart `3.10.7` or newer.
- Android SDK with API 36 installed.

## Development

```powershell
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat analyze
C:\flutter\bin\flutter.bat test
C:\flutter\bin\flutter.bat run
```

## Imports

CSV imports require date, title or merchant, and amount columns. Supported aliases are defined in `CsvImportService`. Invalid, oversized, or duplicate rows are skipped and reported before data is saved.

PDF import supports text-based statements containing explicit debit markers. Scanned-image statements require OCR and are not supported.

## Android Release

Create `android/key.properties` locally with `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`. Keep that file and the keystore private and backed up; neither is committed.

Build per-ABI release APKs with:

```powershell
C:\flutter\bin\flutter.bat build apk --release --split-per-abi --obfuscate --split-debug-info=build\symbols
```

Generated APKs are written to `build\app\outputs\flutter-apk`.
