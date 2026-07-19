import 'package:fin_khata/core/database/app_database.dart';
import 'package:fin_khata/features/finance/data/drift_finance_repository.dart';
import 'package:fin_khata/features/finance/domain/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftFinanceRepository repository;

  setUp(() async {
    database = AppDatabase.memory();
    repository = DriftFinanceRepository(database);
    await repository.initialize();
    await repository.saveWorkspace(
      const Workspace(
        id: 'workspace',
        name: 'Personal',
        type: WorkspaceType.personal,
      ),
    );
    await repository.saveAccount(
      const Account(
        id: 'cash',
        workspaceId: 'workspace',
        name: 'Cash',
        type: 'cash',
        openingBalance: 1000,
        currentBalance: 1000,
      ),
    );
    await repository.saveAccount(
      const Account(
        id: 'bank',
        workspaceId: 'workspace',
        name: 'Bank',
        type: 'bank',
        openingBalance: 0,
        currentBalance: 0,
      ),
    );
  });

  tearDown(() => repository.close());

  test('income increases and expense decreases account balance', () async {
    await repository.postTransaction(
      FinanceTransaction(
        id: 'income',
        workspaceId: 'workspace',
        accountId: 'cash',
        type: TransactionType.income,
        amount: 500,
        date: DateTime(2026, 7, 13),
      ),
    );
    await repository.postTransaction(
      FinanceTransaction(
        id: 'expense',
        workspaceId: 'workspace',
        accountId: 'cash',
        type: TransactionType.expense,
        amount: 200,
        date: DateTime(2026, 7, 13),
      ),
    );

    final accounts = await repository.accounts('workspace');
    expect(
      accounts.firstWhere((item) => item.id == 'cash').currentBalance,
      1300,
    );
  });

  test('transfer updates both accounts atomically', () async {
    await repository.postTransaction(
      FinanceTransaction(
        id: 'transfer',
        workspaceId: 'workspace',
        accountId: 'cash',
        destinationAccountId: 'bank',
        type: TransactionType.transfer,
        amount: 250,
        date: DateTime(2026, 7, 13),
      ),
    );

    final accounts = await repository.accounts('workspace');
    expect(
      accounts.firstWhere((item) => item.id == 'cash').currentBalance,
      750,
    );
    expect(
      accounts.firstWhere((item) => item.id == 'bank').currentBalance,
      250,
    );
  });

  test('same-account and non-positive transactions are rejected', () async {
    expect(
      () => repository.postTransaction(
        FinanceTransaction(
          id: 'invalid',
          workspaceId: 'workspace',
          accountId: 'cash',
          destinationAccountId: 'cash',
          type: TransactionType.transfer,
          amount: 10,
          date: DateTime(2026, 7, 13),
        ),
      ),
      throwsA(isA<FinanceValidationException>()),
    );
    expect(
      () => validatePositiveAmount(0),
      throwsA(isA<FinanceValidationException>()),
    );
  });

  test(
    'importWorkspace upserts an already-existing row instead of ignoring it',
    () async {
      final backup = await repository.exportWorkspace('workspace');
      final tables = Map<String, Object?>.from(
        backup['tables']! as Map,
      );
      final accounts = (tables['accounts'] as List)
          .cast<Map>()
          .map(Map<String, Object?>.from)
          .toList();
      final cashRow = accounts.firstWhere((row) => row['id'] == 'cash');
      // Simulate a remote edit: the same account id, renamed and with a
      // different balance — as if another device changed it before pushing.
      cashRow['name'] = 'Cash (renamed remotely)';
      cashRow['current_balance'] = 9999.0;
      tables['accounts'] = accounts;
      final modifiedBackup = {...backup, 'tables': tables};

      await repository.importWorkspace(modifiedBackup);

      final updated = await repository.accounts('workspace');
      final cash = updated.firstWhere((item) => item.id == 'cash');
      expect(cash.name, 'Cash (renamed remotely)');
      expect(cash.currentBalance, 9999.0);
    },
  );
}
