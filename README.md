# FinKhata — Personal + Business Finance Manager

![FinKhata App Logo](assets/images/app_logo.png)

FinKhata একটি Bangladesh-first, global-ready personal ও small-business finance management application। App-এর in-app product identity **Smart Hisab**। একই user আলাদা Personal এবং Business workspace তৈরি করে প্রতিটির account, transaction, customer, supplier, budget ও report সম্পূর্ণ আলাদাভাবে পরিচালনা করতে পারে।

App-টি Flutter ও Dart দিয়ে তৈরি এবং local-first architecture অনুসরণ করে। অর্থাৎ financial data আগে device-এর Drift/SQLite database-এ সংরক্ষিত হয়; internet বা production backend ছাড়াও core হিসাব ব্যবহার করা যায়।

## বর্তমান Project Status

| বিষয় | অবস্থা |
|---|---|
| App version | `1.0.0+1` |
| Dart SDK | `^3.12.2` |
| Primary platform | Android ও iOS-ready Flutter project |
| Local database | Drift + SQLite, schema version `1` |
| State management | Riverpod |
| Navigation | GoRouter |
| Default language | বাংলা |
| Supported languages | বাংলা ও English |
| Default currency | BDT — Bangladeshi Taka |
| Architecture | Feature-based clean architecture |
| Test status | Finance, responsive UI ও premium analytics tests রয়েছে |

Documentation status legend:

- ✅ **Implemented:** UI থেকে ব্যবহার করা যায় এবং domain/data flow যুক্ত।
- 🧱 **Foundation:** schema/service/repository foundation আছে, কিন্তু সম্পূর্ণ user-facing flow নেই।
- ⏳ **Future:** production implementation এখনও করা হয়নি।

## প্রধান App Flow

```text
App Launch
   ↓
Animated Splash Screen
   ↓
Workspace আছে?
   ├── না → Language → Usage type → Workspace → Currency → Opening balance
   └── হ্যাঁ → Selected workspace restore
   ↓
Personal অথবা Business Dashboard
   ↓
Home / Transactions / Add / Reports / More
```

### Splash Screen ✅

- Smart Hisab branding
- Fade ও scale animation
- Light/dark theme-aware gradient
- বাংলা/English tagline
- Loading indicator
- প্রায় ২.২ সেকেন্ড পরে automatic navigation
- Existing user হলে Home এবং first-time user হলে Onboarding

### First-time Onboarding ✅

- বাংলা অথবা English নির্বাচন
- Personal অথবা Business workspace নির্বাচন
- Workspace name
- Workspace currency
- Cash opening balance
- BDT default currency
- Default Cash/Office Cash account তৈরি
- Workspace type অনুযায়ী default category তৈরি
- Keyboard-visible অবস্থায় scrollable ও overflow-safe layout

## Workspace System ✅

একজন user একাধিক isolated workspace তৈরি করতে পারে। যেমন:

```text
User
├── Personal
├── My Shop
├── Freelance Work
└── Second Business
```

Workspace rules:

- `Personal` এবং `Business`—দুই ধরনের workspace রয়েছে।
- প্রতিটি financial record-এ `workspaceId` থাকে।
- Account, category, transaction, budget, customer, supplier, sale ও purchase selected workspace অনুযায়ী filter হয়।
- এক workspace-এর data অন্য workspace-এর dashboard/report-এ mix হয় না।
- সর্বশেষ selected workspace secure storage-এ রাখা হয়।
- App পুনরায় চালু হলে selected workspace restore করার চেষ্টা করা হয়।
- নতুন workspace-এর জন্য আলাদা currency নির্বাচন করা যায়।

## Bangladesh-first এবং Global-ready Support ✅

### Supported Currencies

| Code | Currency | Symbol |
|---|---|---|
| BDT | Bangladeshi Taka | ৳ |
| USD | US Dollar | $ |
| EUR | Euro | € |
| GBP | British Pound | £ |
| INR | Indian Rupee | ₹ |
| AED | UAE Dirham | د.إ |
| SAR | Saudi Riyal | ر.س |
| MYR | Malaysian Ringgit | RM |
| SGD | Singapore Dollar | S$ |
| JPY | Japanese Yen | ¥ |
| CAD | Canadian Dollar | C$ |
| AUD | Australian Dollar | A$ |

Currency behavior:

- BDT নতুন workspace-এর default।
- প্রতিটি workspace নিজস্ব currency রাখে।
- Dashboard, reports, account balances, budgets, dues এবং Premium Insights workspace currency অনুযায়ী format হয়।
- এই version-এ automatic exchange-rate conversion নেই; workspace currency display ও accounting base currency হিসেবে ব্যবহৃত হয়।

### Account Presets

Bangladesh-focused account:

- Cash
- Bank
- Card
- bKash
- Nagad
- Rocket
- Savings
- Investment
- Petty Cash

Global wallet preset:

- Mobile Wallet
- PayPal
- Wise

## Personal Finance Features

### Account Management ✅

- নতুন account তৈরি
- Account name ও type নির্বাচন
- Opening balance
- Current balance domain/repository flow থেকে update
- Active account validation
- Workspace-wise account statement
- Opening balance থেকে initial current balance তৈরি

### Default Personal Categories ✅

Income:

- Salary
- Freelance

Expense:

- Food
- Transport
- Rent
- Medical

User UI থেকে নতুন Income অথবা Expense category তৈরি করতে পারে।

### Transactions ✅

Supported transaction types:

- Income
- Expense
- Transfer
- Adjustment — domain/database supported; direct UI action বর্তমানে exposed নয়

Transaction data support:

- Source account
- Destination account
- Category
- Amount
- Date
- Note
- Reference number
- Contact reference
- Attachment reference
- Sync status

### Balance Rules

| Transaction | Source account | Destination account |
|---|---:|---:|
| Income | Amount যোগ হয় | প্রযোজ্য নয় |
| Expense | Amount বাদ হয় | প্রযোজ্য নয় |
| Transfer | Amount বাদ হয় | Amount যোগ হয় |
| Adjustment | Amount যোগ হয় | প্রযোজ্য নয় |

Transfer একটি atomic database transaction-এর মধ্যে হয়। Source update, destination update, transaction record ও ledger line—সব সফল হলে commit হয়; কোনো অংশ ব্যর্থ হলে সব rollback হয়।

### Monthly Budget ✅

- Monthly overall budget তৈরি
- Optional category reference domain/database-এ supported
- Current month expense বনাম budget limit
- Budget progress indicator
- Safe: `0–70%`
- Warning: `71–90%`
- Critical/Exceeded: `90%`-এর বেশি
- Budget limit অবশ্যই positive হতে হবে

### Personal Dashboard ✅

- Total balance
- Current month income
- Current month expense
- Current month savings
- Quick actions: Income, Expense, Transfer, Budget
- Budget progress
- Recent transactions
- Financial Health Score premium banner
- Pull-to-refresh

### Personal Reports ✅

- Income summary
- Expense summary
- Savings summary
- Account balances
- Visual comparison bars
- Workspace currency formatting

## Business Finance Features

### Default Business Categories ✅

Income:

- Product Sales
- Service Sales

Expense:

- Purchase
- Rent
- Salary
- Marketing

### Customers এবং Suppliers ✅

- Customer তৈরি
- Supplier তৈরি
- Name
- Phone
- Email, address ও notes-এর database/domain support
- Contact balance
- Customer due
- Supplier payable
- Workspace-wise contact isolation

### Sales ✅

- Customer অথবা walk-in sale
- Total amount
- Paid-now amount
- Cash/bank/payment account নির্বাচন
- Item/note
- Fully paid sale
- Partially paid sale
- Fully due sale
- Paid amount account balance-এ যোগ হয়
- Remaining amount customer due-তে যোগ হয়
- Sale save হলে basic invoice record স্বয়ংক্রিয়ভাবে তৈরি হয়
- Invoice number `INV-...` pattern-এ তৈরি হয়

### Purchases ✅

- Supplier অথবা no-contact purchase
- Total amount
- Paid-now amount
- Payment account
- Item/note
- Fully paid purchase
- Partially paid purchase
- Fully payable purchase
- Paid amount account balance থেকে বাদ হয়
- Remaining amount supplier payable-এ যোগ হয়

### Due এবং Payment Management ✅

Customer payment:

```text
Customer Due ↓
Selected Account Balance ↑
Payment History তৈরি
```

Supplier payment:

```text
Supplier Payable ↓
Selected Account Balance ↓
Payment History তৈরি
```

Payment account, contact balance update এবং payment record একই atomic database transaction-এর মধ্যে পরিচালিত হয়।

### Business Dashboard ✅

- Sales
- Purchases ও general expense
- Profit summary
- Customer due
- Quick actions: New Sale, Purchase, Expense, Payment
- Recent sales/purchases
- Premium business health banner

### Business Reports ✅

- Sales report
- Purchase report
- General expense report
- Profit summary
- Customer due
- Supplier payable
- Cash flow
- Account statement

## Premium Insights ✅

Premium Insights বর্তমান workspace-এর বাস্তব local data থেকে calculate হয়; এটি static demo data ব্যবহার করে না। Dashboard অথবা More screen থেকে Premium hub খোলা যায়।

### Premium Personal Metrics

- Financial Health Score: `0–100`
- Savings rate
- Active account balance
- তিন মাসের average net cash flow থেকে next-month forecast
- ছয় মাসের income বনাম expense line chart
- Top five expense categories
- Category-wise expense concentration
- Emergency reserve signal
- Low-savings smart recommendation

### Premium Business Metrics

- Business Financial Health Score
- Profit margin
- Sales collection efficiency
- Total customer/supplier due exposure
- ছয় মাসের cash-flow chart
- Low collection warning
- Low profit-margin warning
- Smart recommendation cards

### Health Score Conditions

Personal score বিবেচনা করে:

- Savings rate — সর্বোচ্চ 40 points
- Expense cover করার reserve months — সর্বোচ্চ 35 points
- Budget performance — সর্বোচ্চ 25 points

Business score বিবেচনা করে:

- Profit margin — সর্বোচ্চ 40 points
- Collection efficiency — সর্বোচ্চ 35 points
- Budget performance — সর্বোচ্চ 25 points

Recommendation triggers:

- Personal savings rate `10%`-এর নিচে হলে savings recommendation
- Balance এক মাসের expense cover না করলে emergency reserve warning
- Business collection efficiency `75%`-এর নিচে হলে due collection warning
- Business profit margin `10%`-এর নিচে হলে pricing/cost review warning
- কোনো risk condition না থাকলে healthy-finance message

## Navigation এবং UI

### Routes

| Route | Screen |
|---|---|
| `/` | Animated Splash Screen |
| `/home` | HomeGate → Onboarding অথবা HomeShell |
| `/premium` | Premium Insights |

### Bottom Navigation ✅

- Home
- Transactions
- Add
- Reports
- More

Center Add menu workspace type অনুযায়ী পরিবর্তিত হয়।

Personal:

- Add Income
- Add Expense
- Transfer

Business:

- New Sale
- New Purchase
- Add Expense
- Receive/Make Payment

### Responsive ও Theme Support ✅

- Material 3 design
- Light theme
- Dark theme
- বাংলা ও English UI
- Phone ও wider layout-এর জন্য responsive card wrapping
- Keyboard-visible onboarding test
- Keyboard-safe scrollable dialogs
- Fractional device-pixel ratio regression test
- Android predictive-back callback enabled

## Financial এবং Validation Conditions

| Condition | Enforced behavior |
|---|---|
| Workspace name empty | Workspace তৈরি হয় না |
| Workspace selected নয় | Financial operation বন্ধ হয় |
| Amount `0`, negative অথবা non-finite | Transaction/payment/budget reject হয় |
| Transfer destination নেই | Transfer reject হয় |
| Source ও destination একই | Transfer reject হয় |
| Account inactive/not found | Balance update reject হয় |
| Business paid amount negative | Sale/purchase reject হয় |
| Paid amount total-এর বেশি | Sale/purchase reject হয় |
| Paid amount আছে কিন্তু payment account নেই | Sale/purchase reject হয় |
| Contact selected workspace-এ নেই | Payment reject হয় |
| Payment current due-এর বেশি | Payment reject হয় |
| Budget limit positive নয় | Budget reject হয় |
| PIN 4–6 digit নয় | PIN save হয় না |
| Backup schema version incompatible | Import reject হয় |
| Backup workspace পাওয়া যায় না | Export reject হয় |

## Accounting এবং Atomicity

- Financial write operation-এ Drift database transaction ব্যবহার করা হয়।
- Transfer source ও destination একই transaction-এর মধ্যে update হয়।
- Business entry payment, due, invoice, audit ও sync queue সম্পর্কিত write coordinatedভাবে করা হয়।
- Customer/supplier payment account এবং contact balance atomicভাবে update করে।
- Transaction-এর জন্য `transaction_lines` record তৈরি হয়।
- Transfer-এ debit ও credit—দুইটি ledger line তৈরি হয়।
- Business double-entry expansion-এর জন্য schema foundation রয়েছে।

## Local-first Data Architecture ✅

```text
User Action
   ↓
Validation
   ↓
Drift/SQLite atomic write
   ├── Main entity
   ├── Balance/Due update
   ├── Sync queue
   └── Audit log
   ↓
Riverpod state refresh
   ↓
UI updates
```

Sync metadata support:

- UUID string IDs
- `createdAt`
- `updatedAt`
- `deletedAt` soft-delete field
- Record version
- Sync status: `pending`, `syncing`, `synced`, `failed`
- Sync queue retry/status fields
- Duplicate queue protection through entity/version uniqueness

## Database Schema

Drift `GeneratedDatabase` ও custom SQL schema ব্যবহার করা হয়েছে। Database schema version বর্তমানে `1`।

### Implemented Data Flow-এ ব্যবহৃত Tables

- `workspaces`
- `accounts`
- `categories`
- `transactions`
- `transaction_lines`
- `contacts`
- `business_entries`
- `payments`
- `invoices`
- `budgets`
- `sync_queue`
- `audit_logs`

### Foundation/Future Expansion Tables 🧱

- `business_profiles`
- `sale_items`
- `purchase_items`
- `invoice_items`
- `loans`
- `recurring_transactions`
- `attachments`
- `reminders`
- `subscriptions`

Useful indexes:

- Workspace + active account
- Workspace + category type
- Workspace + transaction date
- Workspace + contact type

## Backup এবং Restore

### বর্তমানে যা আছে

- Workspace-specific JSON export ✅
- Database schema version export ✅
- Export timestamp ✅
- Workspace, accounts, categories, transactions, contacts, business entries, budgets, payments ও invoices export ✅
- Backup JSON clipboard-এ copy করা যায় ✅
- Repository-level import validation ও atomic import 🧱
- Duplicate record prevention-এ `INSERT OR IGNORE` 🧱

### বর্তমান সীমাবদ্ধতা

- Restore/import-এর পূর্ণ user-facing screen এখনও নেই।
- Backup file encryption এখনও production-ready নয়।
- File picker এবং import progress UI এখনও নেই।

## Security

### Implemented/Foundation

- PIN secure storage service ✅
- PIN raw text হিসেবে সংরক্ষণ করা হয় না ✅
- Per-PIN salt + SHA-256 hash ✅
- PIN length condition: 4–6 digits ✅
- PIN verify/remove service ✅
- Biometric authentication service ✅
- Android biometric permission ✅
- Android `FlutterFragmentActivity` biometric compatibility ✅
- iOS Face ID usage description ✅
- Selected workspace secure storage ✅

### Security Limitations

- PIN set করার UI আছে, তবে complete automatic app-lock/session-timeout gate এখনও যুক্ত নয়।
- Local SQLite database file-level encryption এখনও যুক্ত নয়।
- Screenshot blocking এখনও যুক্ত নয়।
- Production authentication token/backend flow এখনও নেই।

## Offline Sync

### Local Foundation 🧱

- প্রতিটি গুরুত্বপূর্ণ write sync queue-তে pending item যোগ করে।
- Entity type, entity ID, operation, version ও retry count রাখা হয়।
- UI pending sync count দেখায়।
- Local demo action pending item-কে synced হিসেবে mark করতে পারে।
- Audit log financial changes record করে।

### এখনও Production-ready নয় ⏳

- Node.js/PostgreSQL backend
- Authentication API
- Push/pull sync endpoint
- Real network retry
- Multi-device conflict resolution
- Server-side audit trail
- Realtime collaboration

`Sync` button বর্তমানে remote server-এ data upload করে না; এটি local sync-state foundation প্রদর্শন করে।

## Architecture

```text
lib/
├── main.dart
├── bootstrap.dart
├── app/
│   ├── app.dart
│   ├── router/app_router.dart
│   └── theme/app_theme.dart
├── core/
│   ├── constants/app_currencies.dart
│   ├── database/app_database.dart
│   └── localization/app_strings.dart
├── features/
│   ├── finance/
│   │   ├── data/drift_finance_repository.dart
│   │   ├── domain/finance_models.dart
│   │   ├── domain/finance_repository.dart
│   │   └── presentation/
│   │       ├── providers/finance_controller.dart
│   │       └── screens/home_shell.dart
│   ├── onboarding/presentation/onboarding_screen.dart
│   ├── premium/
│   │   ├── domain/premium_analytics.dart
│   │   └── presentation/premium_insights_screen.dart
│   └── splash/presentation/splash_screen.dart
└── services/security_service.dart
```

Layer responsibilities:

- **Presentation:** Screens, widgets, dialogs, Riverpod state consumption
- **Application/Controller:** Workspace orchestration, refresh, user action coordination
- **Domain:** Entities, enums, validation, financial rules, premium calculations
- **Data:** Drift queries, atomic transactions, repository implementation
- **Core/Services:** Database, currency, theme, localization, security

## গুরুত্বপূর্ণ Dependencies

| Package | ব্যবহার |
|---|---|
| `flutter_riverpod` | State management ও dependency injection |
| `go_router` | Declarative navigation |
| `drift` | Local relational database |
| `path_provider` + `path` | SQLite file location |
| `uuid` | Entity IDs |
| `intl` | Currency/date formatting |
| `fl_chart` | Premium cash-flow chart |
| `flutter_secure_storage` | PIN metadata ও selected workspace |
| `local_auth` | Biometric authentication |
| `crypto` | Salted PIN hash |
| `flutter_launcher_icons` | Android/iOS launcher icon generation |

## Project চালানোর নিয়ম

### Requirements

- Flutter SDK
- Dart SDK compatible with `^3.12.2`
- Android Studio/Android SDK অথবা Xcode

### Setup

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

### Android Debug APK

```bash
flutter build apk --debug
```

Build output:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

### Launcher Icon পুনরায় Generate

```bash
dart run flutter_launcher_icons
```

## Tests

| Test file | Coverage |
|---|---|
| `finance_repository_test.dart` | Income, expense, atomic transfer, invalid amount, same-account transfer |
| `onboarding_screen_test.dart` | Small screen + visible keyboard overflow regression |
| `home_shell_dialog_test.dart` | Workspace dialog, fractional pixel ratio ও keyboard regression |
| `premium_analytics_test.dart` | Personal savings/forecast/category এবং business margin/collection/due calculations |

Run all tests:

```bash
flutter test
```

## বর্তমানে সম্পূর্ণ নয় এমন Feature

নিচের feature-গুলোর কিছু database foundation থাকলেও পূর্ণ production flow নেই:

- User authentication, Google/Apple sign-in ও guest-to-cloud migration
- Real cloud sync
- Encrypted backup file
- Restore/import screen
- Automatic PIN/biometric lock gate
- Full invoice PDF generation ও sharing
- Invoice branding/template editor
- Product inventory
- Employee/team management
- Loan UI ও repayment schedule
- Recurring transaction scheduler
- Notification/reminder execution
- Full double-entry general ledger UI
- Balance sheet, trial balance ও tax/VAT report
- Live foreign exchange conversion
- Subscription purchase/payment gateway
- Server-backed premium entitlement
- App Store/Play Store production release configuration

## Suggested Next Development Order

1. Automatic PIN/biometric lock gate
2. Encrypted backup + restore UI
3. PDF invoice generation ও sharing
4. Loan ও recurring transaction module
5. Production Node.js/PostgreSQL API
6. Conflict-safe cloud sync
7. Premium subscription entitlement
8. Bangladesh tax/VAT ও business report expansion
9. Inventory/POS optional module
10. Store release, privacy policy ও production monitoring

---

**Product message:** ব্যক্তিগত এবং ছোট ব্যবসার সব হিসাব—একটি নিরাপদ, সহজ ও local-first app-এ।
