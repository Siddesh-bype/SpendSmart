# SpendSmart - Expense Tracker

SpendSmart is a comprehensive personal finance management application built with Flutter. It helps users track their daily expenses, manage budgets, gain spending insights, and securely back up their financial data to the cloud.

## Features

### 📊 Expense Tracking
- **Add Expenses**: Quickly log expenses with amount, category, date, and notes.
- **Smart Categorization**: Automatically categorizes expenses (Food, Transport, Bills, etc.).
- **Edit & Delete**: Easily modify or remove any transaction.
- **Search & Filter**: Find transactions by name, category, or date range.
- **Sort**: Organize transactions by date or amount.

### 💰 Budget Management
- **Set Monthly Budget**: Define a total spending limit for the month, respecting custom starting days.
- **Category Budgets**: Set specific limits for each spending category.
- **Visual Progress**: Track spending progress with intuitive, smoothly animated progress bars.
- **Alerts**: Get notified when approaching or exceeding budget limits.

### 📈 Smart Insights
- **Spending Analysis**: Visual charts showing spending distribution across categories.
- **Trend Analysis**: Track spending habits over time.
- **Comparison**: Compare current spending with previous periods.
- **Smart Tips**: AI-powered suggestions to save money.

### ☁️ Cloud Sync & Security
- **Secure Authentication**: Login/Signup using email or Google.
- **Cloud Backup**: Automatically syncs all financial data to the cloud.
- **Offline Support**: Continue using the app even without internet.
- **Data Sync**: Sync data across multiple devices.

### 📄 PDF Bank Statement Import
- **Auto-Import**: Extract transactions directly from bank statement PDFs.
- **Smart Matching**: Matches imported transactions with existing records.
- **Review Required**: All imported transactions require user review before saving.

### 🔔 Notification Tracking
- **SMS Monitoring**: Automatically detects and parses transaction SMS messages.
- **Notification Access**: Reads notifications from other banking apps to track spending.
- **Privacy Focused**: Requires explicit permission and processes data locally.

### 📊 Reporting & Export
- **PDF Reports**: Generate professional, printable PDF expense reports with charts.
- **CSV Export**: Export all transaction data to CSV format for use in spreadsheets.
- **Share Reports**: Easily share reports via WhatsApp, email, or other apps.

### 🎨 Customization
- **Currency Support**: Supports multiple currencies (default: ₹).
- **Theme Options**: Light, Dark, and System default themes.
- **Starting Day**: Customize the start day of the month (1-31), affecting all Insights and Budget calculations.
- **Fluid UI**: Enjoy a polished, engaging interface with smooth implicit animations.

## Getting Started

### Prerequisites
- Flutter SDK (version 3.10.7 or higher)
- Android Studio or VS Code
- Firebase project (for cloud sync)

### Installation
1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd spendsmart
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Create a Firebase project at [https://firebase.google.com/](https://firebase.google.com/)
   - Add Android and iOS apps to your Firebase project
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place them in the `android/app/` and `ios/Runner/` directories respectively

4. Run the app:
   ```bash
   flutter run
   ```

## Usage

### Adding an Expense
1. Tap the '+' button on the Home screen
2. Enter the amount
3. Select a category
4. Add an optional note
5. Tap 'Save'

### Importing Bank Statements
1. Go to Settings > Import Bank Statement (PDF)
2. Select a PDF file from your device
3. The app will parse transactions and show them for review
4. Review each transaction and tap 'Save' to add them to your records

### Setting a Budget
1. Go to Home screen
2. Tap the 'Budget' card or go to Settings > Spending Goals
3. Set your total monthly budget
4. Optionally, set budgets for individual categories
5. Track your progress throughout the month

## Tech Stack

- **Framework**: Flutter (with implicit UI animations via TweenAnimationBuilder)
- **State Management**: Riverpod
- **Database**: SQLite (sqflite) for local storage
- **Cloud Sync**: Supabase (PostgreSQL)
- **PDF Processing**: Syncfusion_flutter_pdf
- **Notifications**: Telephony (Android), UserNotifications (iOS)
- **Charts**: fl_chart
- **Authentication**: Firebase Authentication / Supabase Auth

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
