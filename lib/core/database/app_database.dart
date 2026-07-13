import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppDatabase extends GeneratedDatabase {
  AppDatabase._(super.executor);

  factory AppDatabase.open() => AppDatabase._(
    LazyDatabase(() async {
      final directory = await getApplicationDocumentsDirectory();
      return NativeDatabase.createInBackground(
        File(p.join(directory.path, 'smart_hisab.sqlite')),
      );
    }),
  );

  factory AppDatabase.memory() => AppDatabase._(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  List<TableInfo> get allTables => const [];

  Future<void> ensureSchema() async {
    for (final statement in _schemaStatements) {
      await customStatement(statement);
    }
  }

  static const _schemaStatements = <String>[
    '''CREATE TABLE IF NOT EXISTS workspaces (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, type TEXT NOT NULL,
      currency TEXT NOT NULL DEFAULT 'BDT', created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL, deleted_at INTEGER, version INTEGER NOT NULL DEFAULT 1,
      sync_status TEXT NOT NULL DEFAULT 'pending', device_id TEXT)''',
    '''CREATE TABLE IF NOT EXISTS business_profiles (
      workspace_id TEXT PRIMARY KEY REFERENCES workspaces(id), business_type TEXT,
      address TEXT, phone TEXT, logo TEXT, financial_year TEXT, tax_info TEXT,
      invoice_settings TEXT)''',
    '''CREATE TABLE IF NOT EXISTS accounts (
      id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL REFERENCES workspaces(id),
      name TEXT NOT NULL, type TEXT NOT NULL, opening_balance REAL NOT NULL,
      current_balance REAL NOT NULL, currency TEXT NOT NULL DEFAULT 'BDT',
      icon TEXT, color INTEGER, is_active INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER,
      version INTEGER NOT NULL DEFAULT 1, sync_status TEXT NOT NULL DEFAULT 'pending')''',
    'CREATE INDEX IF NOT EXISTS idx_accounts_workspace ON accounts(workspace_id, is_active)',
    '''CREATE TABLE IF NOT EXISTS categories (
      id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL REFERENCES workspaces(id),
      name TEXT NOT NULL, type TEXT NOT NULL, created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL, deleted_at INTEGER)''',
    'CREATE INDEX IF NOT EXISTS idx_categories_workspace ON categories(workspace_id, type)',
    '''CREATE TABLE IF NOT EXISTS transactions (
      id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL REFERENCES workspaces(id),
      account_id TEXT NOT NULL REFERENCES accounts(id), destination_account_id TEXT,
      category_id TEXT, type TEXT NOT NULL, amount REAL NOT NULL CHECK(amount > 0),
      date INTEGER NOT NULL, note TEXT NOT NULL DEFAULT '', reference_number TEXT,
      contact_id TEXT, attachment_id TEXT, created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL, deleted_at INTEGER, version INTEGER NOT NULL DEFAULT 1,
      sync_status TEXT NOT NULL DEFAULT 'pending')''',
    'CREATE INDEX IF NOT EXISTS idx_transactions_workspace_date ON transactions(workspace_id, date)',
    '''CREATE TABLE IF NOT EXISTS transaction_lines (
      id TEXT PRIMARY KEY, transaction_id TEXT NOT NULL REFERENCES transactions(id),
      ledger_account_id TEXT NOT NULL, debit_amount REAL NOT NULL DEFAULT 0,
      credit_amount REAL NOT NULL DEFAULT 0)''',
    '''CREATE TABLE IF NOT EXISTS contacts (
      id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL REFERENCES workspaces(id),
      name TEXT NOT NULL, type TEXT NOT NULL, phone TEXT, email TEXT, address TEXT,
      balance REAL NOT NULL DEFAULT 0, credit_limit REAL, notes TEXT,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER,
      version INTEGER NOT NULL DEFAULT 1, sync_status TEXT NOT NULL DEFAULT 'pending')''',
    'CREATE INDEX IF NOT EXISTS idx_contacts_workspace ON contacts(workspace_id, type)',
    '''CREATE TABLE IF NOT EXISTS business_entries (
      id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL REFERENCES workspaces(id),
      type TEXT NOT NULL, contact_id TEXT, account_id TEXT, total REAL NOT NULL,
      paid REAL NOT NULL, date INTEGER NOT NULL, note TEXT NOT NULL DEFAULT '',
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER,
      version INTEGER NOT NULL DEFAULT 1, sync_status TEXT NOT NULL DEFAULT 'pending')''',
    '''CREATE TABLE IF NOT EXISTS sale_items (
      id TEXT PRIMARY KEY, sale_id TEXT NOT NULL REFERENCES business_entries(id),
      description TEXT NOT NULL, quantity REAL NOT NULL, unit_price REAL NOT NULL,
      discount REAL NOT NULL DEFAULT 0, tax REAL NOT NULL DEFAULT 0)''',
    '''CREATE TABLE IF NOT EXISTS purchase_items (
      id TEXT PRIMARY KEY, purchase_id TEXT NOT NULL REFERENCES business_entries(id),
      description TEXT NOT NULL, quantity REAL NOT NULL, unit_price REAL NOT NULL)''',
    '''CREATE TABLE IF NOT EXISTS payments (
      id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL, contact_id TEXT NOT NULL,
      account_id TEXT NOT NULL, amount REAL NOT NULL, direction TEXT NOT NULL,
      date INTEGER NOT NULL, created_at INTEGER NOT NULL)''',
    '''CREATE TABLE IF NOT EXISTS invoices (
      id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL, sale_id TEXT,
      customer_id TEXT, invoice_number TEXT NOT NULL, total REAL NOT NULL,
      paid REAL NOT NULL, due_date INTEGER, status TEXT NOT NULL, created_at INTEGER NOT NULL)''',
    '''CREATE TABLE IF NOT EXISTS invoice_items (
      id TEXT PRIMARY KEY, invoice_id TEXT NOT NULL REFERENCES invoices(id),
      description TEXT NOT NULL, quantity REAL NOT NULL, unit_price REAL NOT NULL)''',
    '''CREATE TABLE IF NOT EXISTS budgets (
      id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL REFERENCES workspaces(id),
      name TEXT NOT NULL, category_id TEXT, amount_limit REAL NOT NULL,
      month INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)''',
    '''CREATE TABLE IF NOT EXISTS loans (
      id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL, type TEXT NOT NULL,
      person TEXT NOT NULL, principal REAL NOT NULL, interest REAL,
      start_date INTEGER NOT NULL, due_date INTEGER, installment REAL,
      paid REAL NOT NULL DEFAULT 0, reminder INTEGER)''',
    '''CREATE TABLE IF NOT EXISTS recurring_transactions (
      id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL, template TEXT NOT NULL,
      frequency TEXT NOT NULL, next_run INTEGER NOT NULL, is_active INTEGER NOT NULL)''',
    '''CREATE TABLE IF NOT EXISTS attachments (
      id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL, file_name TEXT NOT NULL,
      local_path TEXT, remote_url TEXT, mime_type TEXT, created_at INTEGER NOT NULL)''',
    '''CREATE TABLE IF NOT EXISTS reminders (
      id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL, title TEXT NOT NULL,
      scheduled_at INTEGER NOT NULL, is_completed INTEGER NOT NULL DEFAULT 0)''',
    '''CREATE TABLE IF NOT EXISTS sync_queue (
      id INTEGER PRIMARY KEY AUTOINCREMENT, entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL, operation TEXT NOT NULL, version INTEGER NOT NULL,
      created_at INTEGER NOT NULL, retry_count INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'pending', UNIQUE(entity_type, entity_id, version))''',
    '''CREATE TABLE IF NOT EXISTS audit_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT, workspace_id TEXT, action TEXT NOT NULL,
      entity_type TEXT NOT NULL, entity_id TEXT, metadata TEXT,
      created_at INTEGER NOT NULL)''',
    '''CREATE TABLE IF NOT EXISTS subscriptions (
      id TEXT PRIMARY KEY, workspace_id TEXT, plan TEXT NOT NULL,
      status TEXT NOT NULL, starts_at INTEGER, ends_at INTEGER)''',
  ];
}
