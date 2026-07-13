import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/finance_models.dart';
import '../domain/finance_repository.dart';

class DriftFinanceRepository implements FinanceRepository {
  DriftFinanceRepository(this.database);

  final AppDatabase database;
  static const _uuid = Uuid();

  int get _now => DateTime.now().millisecondsSinceEpoch;

  @override
  Future<void> initialize() => database.ensureSchema();

  @override
  Future<List<Workspace>> workspaces() async {
    final rows = await database
        .customSelect(
          'SELECT id, name, type, currency FROM workspaces '
          'WHERE deleted_at IS NULL ORDER BY created_at',
        )
        .get();
    return rows
        .map(
          (r) => Workspace(
            id: r.read<String>('id'),
            name: r.read<String>('name'),
            type: WorkspaceType.values.byName(r.read<String>('type')),
            currency: r.read<String>('currency'),
          ),
        )
        .toList();
  }

  @override
  Future<void> saveWorkspace(Workspace workspace) async {
    await database.transaction(() async {
      await database.customStatement(
        '''INSERT INTO workspaces
        (id, name, type, currency, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET name=excluded.name,
        currency=excluded.currency, updated_at=excluded.updated_at,
        version=workspaces.version+1, sync_status='pending' ''',
        [
          workspace.id,
          workspace.name,
          workspace.type.name,
          workspace.currency,
          _now,
          _now,
        ],
      );
      await _queue('workspace', workspace.id);
      await _audit(workspace.id, 'save', 'workspace', workspace.id);
    });
  }

  @override
  Future<List<Account>> accounts(String workspaceId) async {
    final rows = await _select(
      '''SELECT id, workspace_id, name, type, opening_balance,
      current_balance, is_active FROM accounts
      WHERE workspace_id=? AND deleted_at IS NULL ORDER BY created_at''',
      [workspaceId],
    );
    return rows
        .map(
          (r) => Account(
            id: r.read<String>('id'),
            workspaceId: r.read<String>('workspace_id'),
            name: r.read<String>('name'),
            type: r.read<String>('type'),
            openingBalance: r.read<double>('opening_balance'),
            currentBalance: r.read<double>('current_balance'),
            isActive: r.read<int>('is_active') == 1,
          ),
        )
        .toList();
  }

  @override
  Future<void> saveAccount(Account account) async {
    await database.transaction(() async {
      await database.customStatement(
        '''INSERT INTO accounts
        (id, workspace_id, name, type, opening_balance, current_balance,
        is_active, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET name=excluded.name, type=excluded.type,
        is_active=excluded.is_active, updated_at=excluded.updated_at,
        version=accounts.version+1, sync_status='pending' ''',
        [
          account.id,
          account.workspaceId,
          account.name,
          account.type,
          account.openingBalance,
          account.currentBalance,
          account.isActive ? 1 : 0,
          _now,
          _now,
        ],
      );
      await _queue('account', account.id);
      await _audit(account.workspaceId, 'save', 'account', account.id);
    });
  }

  @override
  Future<List<Category>> categories(String workspaceId) async {
    final rows = await _select(
      '''SELECT id, workspace_id, name, type FROM categories
      WHERE workspace_id=? AND deleted_at IS NULL ORDER BY name''',
      [workspaceId],
    );
    return rows
        .map(
          (r) => Category(
            id: r.read<String>('id'),
            workspaceId: r.read<String>('workspace_id'),
            name: r.read<String>('name'),
            type: TransactionType.values.byName(r.read<String>('type')),
          ),
        )
        .toList();
  }

  @override
  Future<void> saveCategory(Category category) async {
    await database.customStatement(
      '''INSERT INTO categories (id, workspace_id, name, type, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET name=excluded.name, updated_at=excluded.updated_at''',
      [
        category.id,
        category.workspaceId,
        category.name,
        category.type.name,
        _now,
        _now,
      ],
    );
    await _queue('category', category.id);
  }

  @override
  Future<List<FinanceTransaction>> transactions(String workspaceId) async {
    final rows = await _select(
      '''SELECT * FROM transactions WHERE workspace_id=? AND deleted_at IS NULL
      ORDER BY date DESC, created_at DESC''',
      [workspaceId],
    );
    return rows
        .map(
          (r) => FinanceTransaction(
            id: r.read<String>('id'),
            workspaceId: r.read<String>('workspace_id'),
            accountId: r.read<String>('account_id'),
            destinationAccountId: r.readNullable<String>(
              'destination_account_id',
            ),
            categoryId: r.readNullable<String>('category_id'),
            type: TransactionType.values.byName(r.read<String>('type')),
            amount: r.read<double>('amount'),
            date: DateTime.fromMillisecondsSinceEpoch(r.read<int>('date')),
            note: r.read<String>('note'),
            referenceNumber: r.readNullable<String>('reference_number'),
            contactId: r.readNullable<String>('contact_id'),
            attachmentId: r.readNullable<String>('attachment_id'),
            syncStatus: SyncStatus.values.byName(r.read<String>('sync_status')),
          ),
        )
        .toList();
  }

  @override
  Future<void> postTransaction(FinanceTransaction transaction) async {
    validatePositiveAmount(transaction.amount);
    if (transaction.type == TransactionType.transfer) {
      final destination = transaction.destinationAccountId;
      if (destination == null) {
        throw const FinanceValidationException('Choose a destination account.');
      }
      validateTransfer(transaction.accountId, destination);
    }
    await database.transaction(() async {
      final sourceDelta = switch (transaction.type) {
        TransactionType.income => transaction.amount,
        TransactionType.expense ||
        TransactionType.transfer => -transaction.amount,
        TransactionType.adjustment => transaction.amount,
      };
      await _changeBalance(transaction.accountId, sourceDelta);
      if (transaction.type == TransactionType.transfer) {
        await _changeBalance(
          transaction.destinationAccountId!,
          transaction.amount,
        );
      }
      await database.customStatement(
        '''INSERT INTO transactions
        (id, workspace_id, account_id, destination_account_id, category_id,
        type, amount, date, note, reference_number, contact_id, attachment_id,
        created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          transaction.id,
          transaction.workspaceId,
          transaction.accountId,
          transaction.destinationAccountId,
          transaction.categoryId,
          transaction.type.name,
          transaction.amount,
          transaction.date.millisecondsSinceEpoch,
          transaction.note,
          transaction.referenceNumber,
          transaction.contactId,
          transaction.attachmentId,
          _now,
          _now,
        ],
      );
      await _writeLedgerLines(transaction);
      await _queue('transaction', transaction.id);
      await _audit(
        transaction.workspaceId,
        'create',
        'transaction',
        transaction.id,
      );
    });
  }

  Future<void> _writeLedgerLines(FinanceTransaction item) async {
    final debitId = _uuid.v4();
    final creditId = _uuid.v4();
    if (item.type == TransactionType.transfer) {
      await database.customStatement(
        '''INSERT INTO transaction_lines
        (id, transaction_id, ledger_account_id, debit_amount, credit_amount)
        VALUES (?, ?, ?, ?, 0), (?, ?, ?, 0, ?)''',
        [
          debitId,
          item.id,
          item.destinationAccountId,
          item.amount,
          creditId,
          item.id,
          item.accountId,
          item.amount,
        ],
      );
      return;
    }
    await database.customStatement(
      '''INSERT INTO transaction_lines
      (id, transaction_id, ledger_account_id, debit_amount, credit_amount)
      VALUES (?, ?, ?, ?, ?)''',
      [
        debitId,
        item.id,
        item.accountId,
        item.type == TransactionType.income ? item.amount : 0,
        item.type == TransactionType.expense ? item.amount : 0,
      ],
    );
  }

  @override
  Future<List<Budget>> budgets(String workspaceId) async {
    final rows = await _select(
      'SELECT * FROM budgets WHERE workspace_id=? ORDER BY month DESC',
      [workspaceId],
    );
    return rows
        .map(
          (r) => Budget(
            id: r.read<String>('id'),
            workspaceId: r.read<String>('workspace_id'),
            name: r.read<String>('name'),
            categoryId: r.readNullable<String>('category_id'),
            limit: r.read<double>('amount_limit'),
            month: DateTime.fromMillisecondsSinceEpoch(r.read<int>('month')),
          ),
        )
        .toList();
  }

  @override
  Future<void> saveBudget(Budget budget) async {
    validatePositiveAmount(budget.limit);
    await database.customStatement(
      '''INSERT INTO budgets
      (id, workspace_id, name, category_id, amount_limit, month, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET name=excluded.name,
      amount_limit=excluded.amount_limit, updated_at=excluded.updated_at''',
      [
        budget.id,
        budget.workspaceId,
        budget.name,
        budget.categoryId,
        budget.limit,
        budget.month.millisecondsSinceEpoch,
        _now,
        _now,
      ],
    );
    await _queue('budget', budget.id);
  }

  @override
  Future<List<Contact>> contacts(String workspaceId) async {
    final rows = await _select(
      '''SELECT * FROM contacts WHERE workspace_id=? AND deleted_at IS NULL
      ORDER BY name''',
      [workspaceId],
    );
    return rows
        .map(
          (r) => Contact(
            id: r.read<String>('id'),
            workspaceId: r.read<String>('workspace_id'),
            name: r.read<String>('name'),
            type: ContactType.values.byName(r.read<String>('type')),
            phone: r.readNullable<String>('phone') ?? '',
            email: r.readNullable<String>('email') ?? '',
            address: r.readNullable<String>('address') ?? '',
            balance: r.read<double>('balance'),
          ),
        )
        .toList();
  }

  @override
  Future<void> saveContact(Contact contact) async {
    await database.customStatement(
      '''INSERT INTO contacts
      (id, workspace_id, name, type, phone, email, address, balance, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET name=excluded.name, phone=excluded.phone,
      email=excluded.email, address=excluded.address, updated_at=excluded.updated_at,
      version=contacts.version+1, sync_status='pending' ''',
      [
        contact.id,
        contact.workspaceId,
        contact.name,
        contact.type.name,
        contact.phone,
        contact.email,
        contact.address,
        contact.balance,
        _now,
        _now,
      ],
    );
    await _queue('contact', contact.id);
  }

  @override
  Future<List<BusinessEntry>> businessEntries(String workspaceId) async {
    final rows = await _select(
      '''SELECT * FROM business_entries WHERE workspace_id=? AND deleted_at IS NULL
      ORDER BY date DESC''',
      [workspaceId],
    );
    return rows
        .map(
          (r) => BusinessEntry(
            id: r.read<String>('id'),
            workspaceId: r.read<String>('workspace_id'),
            type: BusinessEntryType.values.byName(r.read<String>('type')),
            contactId: r.readNullable<String>('contact_id'),
            accountId: r.readNullable<String>('account_id'),
            total: r.read<double>('total'),
            paid: r.read<double>('paid'),
            date: DateTime.fromMillisecondsSinceEpoch(r.read<int>('date')),
            note: r.read<String>('note'),
          ),
        )
        .toList();
  }

  @override
  Future<void> postBusinessEntry(BusinessEntry entry) async {
    validatePositiveAmount(entry.total);
    if (entry.paid < 0 || entry.paid > entry.total) {
      throw const FinanceValidationException(
        'Paid amount must be between zero and total.',
      );
    }
    await database.transaction(() async {
      if (entry.paid > 0) {
        if (entry.accountId == null) {
          throw const FinanceValidationException('Choose a payment account.');
        }
        await _changeBalance(
          entry.accountId!,
          entry.type == BusinessEntryType.sale ? entry.paid : -entry.paid,
        );
      }
      if (entry.contactId != null && entry.due > 0) {
        await _changeContactBalance(
          entry.contactId!,
          entry.type == BusinessEntryType.sale ? entry.due : entry.due,
        );
      }
      await database.customStatement(
        '''INSERT INTO business_entries
        (id, workspace_id, type, contact_id, account_id, total, paid, date,
        note, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          entry.id,
          entry.workspaceId,
          entry.type.name,
          entry.contactId,
          entry.accountId,
          entry.total,
          entry.paid,
          entry.date.millisecondsSinceEpoch,
          entry.note,
          _now,
          _now,
        ],
      );
      if (entry.type == BusinessEntryType.sale) {
        await database.customStatement(
          '''INSERT INTO invoices
          (id, workspace_id, sale_id, customer_id, invoice_number, total, paid,
          status, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            _uuid.v4(),
            entry.workspaceId,
            entry.id,
            entry.contactId,
            'INV-${_now.toString().substring(5)}',
            entry.total,
            entry.paid,
            entry.status.name,
            _now,
          ],
        );
      }
      await _queue(entry.type.name, entry.id);
      await _audit(entry.workspaceId, 'create', entry.type.name, entry.id);
    });
  }

  @override
  Future<void> receiveOrMakePayment({
    required String workspaceId,
    required String contactId,
    required String accountId,
    required double amount,
  }) async {
    validatePositiveAmount(amount);
    await database.transaction(() async {
      final row = await database
          .customSelect(
            'SELECT type, balance FROM contacts WHERE id=? AND workspace_id=?',
            variables: [
              Variable<String>(contactId),
              Variable<String>(workspaceId),
            ],
          )
          .getSingleOrNull();
      if (row == null) {
        throw const FinanceValidationException('Contact not found.');
      }
      final balance = row.read<double>('balance');
      if (amount > balance) {
        throw const FinanceValidationException(
          'Payment cannot exceed the current due.',
        );
      }
      final type = ContactType.values.byName(row.read<String>('type'));
      await _changeContactBalance(contactId, -amount);
      await _changeBalance(
        accountId,
        type == ContactType.customer ? amount : -amount,
      );
      final paymentId = _uuid.v4();
      await database.customStatement(
        '''INSERT INTO payments
        (id, workspace_id, contact_id, account_id, amount, direction, date, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          paymentId,
          workspaceId,
          contactId,
          accountId,
          amount,
          type == ContactType.customer ? 'received' : 'paid',
          _now,
          _now,
        ],
      );
      await _queue('payment', paymentId);
      await _audit(workspaceId, 'create', 'payment', paymentId);
    });
  }

  Future<void> _changeBalance(String accountId, double delta) async {
    final changed = await database.customUpdate(
      '''UPDATE accounts SET current_balance=current_balance+?, updated_at=?,
      version=version+1, sync_status='pending' WHERE id=? AND is_active=1''',
      variables: [
        Variable<double>(delta),
        Variable<int>(_now),
        Variable<String>(accountId),
      ],
    );
    if (changed != 1) {
      throw const FinanceValidationException('Active account not found.');
    }
  }

  Future<void> _changeContactBalance(
    String contactId,
    double delta,
  ) => database.customStatement(
    '''UPDATE contacts SET balance=balance+?, updated_at=?, version=version+1,
        sync_status='pending' WHERE id=?''',
    [delta, _now, contactId],
  );

  Future<List<QueryRow>> _select(String sql, List<Object?> values) => database
      .customSelect(sql, variables: values.map((e) => Variable(e)).toList())
      .get();

  Future<void> _queue(String entity, String id) => database.customStatement(
    '''INSERT OR IGNORE INTO sync_queue
    (entity_type, entity_id, operation, version, created_at)
    VALUES (?, ?, 'upsert', 1, ?)''',
    [entity, id, _now],
  );

  Future<void> _audit(
    String? workspaceId,
    String action,
    String entity,
    String id,
  ) => database.customStatement(
    '''INSERT INTO audit_logs
        (workspace_id, action, entity_type, entity_id, created_at)
        VALUES (?, ?, ?, ?, ?)''',
    [workspaceId, action, entity, id, _now],
  );

  @override
  Future<int> pendingSyncCount() async {
    final row = await database
        .customSelect(
          "SELECT COUNT(*) AS count FROM sync_queue WHERE status IN ('pending','failed')",
        )
        .getSingle();
    return row.read<int>('count');
  }

  @override
  Future<void> markPendingAsSynced() => database.customStatement(
    "UPDATE sync_queue SET status='synced' WHERE status IN ('pending','failed')",
  );

  @override
  Future<Map<String, Object?>> exportWorkspace(String workspaceId) async {
    final workspaceRows = await _rawRows('workspaces', 'id', workspaceId);
    if (workspaceRows.isEmpty) {
      throw const FinanceValidationException('Workspace not found.');
    }
    return {
      'schemaVersion': database.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'workspaceId': workspaceId,
      'tables': {
        'workspaces': workspaceRows,
        for (final table in [
          'accounts',
          'categories',
          'transactions',
          'contacts',
          'business_entries',
          'budgets',
          'payments',
          'invoices',
        ])
          table: await _rawRows(table, 'workspace_id', workspaceId),
      },
    };
  }

  Future<List<Map<String, Object?>>> _rawRows(
    String table,
    String column,
    String value,
  ) async {
    final rows = await database
        .customSelect(
          'SELECT * FROM $table WHERE $column=?',
          variables: [Variable<String>(value)],
        )
        .get();
    return rows.map((row) => Map<String, Object?>.from(row.data)).toList();
  }

  @override
  Future<void> importWorkspace(Map<String, Object?> backup) async {
    if (backup['schemaVersion'] != database.schemaVersion ||
        backup['tables'] is! Map) {
      throw const FinanceValidationException('Invalid or unsupported backup.');
    }
    final tables = Map<String, Object?>.from(backup['tables']! as Map);
    await database.transaction(() async {
      for (final entry in tables.entries) {
        final rows = (entry.value as List?)?.cast<Map>() ?? const [];
        for (final untyped in rows) {
          final row = Map<String, Object?>.from(untyped);
          final columns = row.keys.toList();
          final placeholders = List.filled(columns.length, '?').join(',');
          await database.customStatement(
            'INSERT OR IGNORE INTO ${entry.key} (${columns.join(',')}) VALUES ($placeholders)',
            columns.map((column) => row[column]).toList(),
          );
        }
      }
      await _audit(
        backup['workspaceId'] as String?,
        'import',
        'backup',
        jsonEncode(backup).hashCode.toString(),
      );
    });
  }

  @override
  Future<void> close() => database.close();
}
