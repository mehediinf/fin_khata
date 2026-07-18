import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../services/backup_crypto_service.dart';
import '../../../../services/security_service.dart';
import '../../data/drift_finance_repository.dart';
import '../../domain/finance_models.dart';
import '../../domain/finance_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.open();
  ref.onDispose(database.close);
  return database;
});

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => DriftFinanceRepository(ref.watch(databaseProvider)),
);

final securityServiceProvider = Provider<SecurityService>(
  (ref) => SecurityService(),
);

final backupCryptoServiceProvider = Provider<BackupCryptoService>(
  (ref) => BackupCryptoService(),
);

final financeControllerProvider =
    NotifierProvider<FinanceController, FinanceState>(FinanceController.new);

class FinanceState {
  const FinanceState({
    this.loading = true,
    this.workspaces = const [],
    this.currentWorkspace,
    this.accounts = const [],
    this.categories = const [],
    this.transactions = const [],
    this.budgets = const [],
    this.contacts = const [],
    this.businessEntries = const [],
    this.pendingSync = 0,
    this.bangla = true,
    this.darkMode = false,
    this.error,
  });

  final bool loading;
  final List<Workspace> workspaces;
  final Workspace? currentWorkspace;
  final List<Account> accounts;
  final List<Category> categories;
  final List<FinanceTransaction> transactions;
  final List<Budget> budgets;
  final List<Contact> contacts;
  final List<BusinessEntry> businessEntries;
  final int pendingSync;
  final bool bangla;
  final bool darkMode;
  final String? error;

  bool get isBusiness => currentWorkspace?.type == WorkspaceType.business;

  FinanceSummary get summary {
    final now = DateTime.now();
    final monthly = transactions.where(
      (item) => item.date.year == now.year && item.date.month == now.month,
    );
    double income = 0;
    double expense = 0;
    for (final item in monthly) {
      if (item.type == TransactionType.income) income += item.amount;
      if (item.type == TransactionType.expense) expense += item.amount;
    }
    return FinanceSummary(
      balance: accounts
          .where((a) => a.isActive)
          .fold(0, (sum, a) => sum + a.currentBalance),
      income: income,
      expense: expense,
      sales: businessEntries
          .where((e) => e.type == BusinessEntryType.sale)
          .fold(0, (sum, e) => sum + e.total),
      purchases: businessEntries
          .where((e) => e.type == BusinessEntryType.purchase)
          .fold(0, (sum, e) => sum + e.total),
      customerDue: contacts
          .where((c) => c.type == ContactType.customer)
          .fold(0, (sum, c) => sum + c.balance),
      supplierPayable: contacts
          .where((c) => c.type == ContactType.supplier)
          .fold(0, (sum, c) => sum + c.balance),
    );
  }

  FinanceState copyWith({
    bool? loading,
    List<Workspace>? workspaces,
    Workspace? currentWorkspace,
    List<Account>? accounts,
    List<Category>? categories,
    List<FinanceTransaction>? transactions,
    List<Budget>? budgets,
    List<Contact>? contacts,
    List<BusinessEntry>? businessEntries,
    int? pendingSync,
    bool? bangla,
    bool? darkMode,
    String? error,
    bool clearError = false,
  }) => FinanceState(
    loading: loading ?? this.loading,
    workspaces: workspaces ?? this.workspaces,
    currentWorkspace: currentWorkspace ?? this.currentWorkspace,
    accounts: accounts ?? this.accounts,
    categories: categories ?? this.categories,
    transactions: transactions ?? this.transactions,
    budgets: budgets ?? this.budgets,
    contacts: contacts ?? this.contacts,
    businessEntries: businessEntries ?? this.businessEntries,
    pendingSync: pendingSync ?? this.pendingSync,
    bangla: bangla ?? this.bangla,
    darkMode: darkMode ?? this.darkMode,
    error: clearError ? null : error ?? this.error,
  );
}

class FinanceController extends Notifier<FinanceState> {
  static const _uuid = Uuid();
  late FinanceRepository _repository;
  late SecurityService _security;

  @override
  FinanceState build() {
    _repository = ref.watch(financeRepositoryProvider);
    _security = ref.watch(securityServiceProvider);
    Future.microtask(initialize);
    return const FinanceState();
  }

  Future<void> initialize() async {
    try {
      await _repository.initialize();
      final spaces = await _repository.workspaces();
      final selectedId = await _security.selectedWorkspace();
      Workspace? selected;
      if (spaces.isNotEmpty) {
        selected =
            spaces.where((w) => w.id == selectedId).firstOrNull ?? spaces.first;
      }
      state = state.copyWith(
        loading: false,
        workspaces: spaces,
        currentWorkspace: selected,
        clearError: true,
      );
      if (selected != null) await _loadWorkspace(selected);
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> createWorkspace({
    required String name,
    required WorkspaceType type,
    double openingBalance = 0,
    String currency = 'BDT',
  }) async {
    if (name.trim().isEmpty) {
      throw const FinanceValidationException('Workspace name is required.');
    }
    final workspace = Workspace(
      id: _uuid.v4(),
      name: name.trim(),
      type: type,
      currency: currency,
    );
    await _repository.saveWorkspace(workspace);
    final cash = Account(
      id: _uuid.v4(),
      workspaceId: workspace.id,
      name: type == WorkspaceType.personal ? 'Cash' : 'Office Cash',
      type: 'cash',
      openingBalance: openingBalance,
      currentBalance: openingBalance,
    );
    await _repository.saveAccount(cash);
    for (final entry in _defaultCategories(type)) {
      await _repository.saveCategory(
        Category(
          id: _uuid.v4(),
          workspaceId: workspace.id,
          name: entry.$1,
          type: entry.$2,
        ),
      );
    }
    await initialize();
    await switchWorkspace(workspace);
  }

  List<(String, TransactionType)> _defaultCategories(WorkspaceType type) =>
      type == WorkspaceType.personal
      ? const [
          ('Salary', TransactionType.income),
          ('Freelance', TransactionType.income),
          ('Food', TransactionType.expense),
          ('Transport', TransactionType.expense),
          ('Rent', TransactionType.expense),
          ('Medical', TransactionType.expense),
        ]
      : const [
          ('Product Sales', TransactionType.income),
          ('Service Sales', TransactionType.income),
          ('Purchase', TransactionType.expense),
          ('Rent', TransactionType.expense),
          ('Salary', TransactionType.expense),
          ('Marketing', TransactionType.expense),
        ];

  Future<void> switchWorkspace(Workspace workspace) async {
    await _security.saveSelectedWorkspace(workspace.id);
    state = state.copyWith(currentWorkspace: workspace, loading: true);
    await _loadWorkspace(workspace);
  }

  Future<void> _loadWorkspace(Workspace workspace) async {
    final values = await Future.wait([
      _repository.accounts(workspace.id),
      _repository.categories(workspace.id),
      _repository.transactions(workspace.id),
      _repository.budgets(workspace.id),
      _repository.contacts(workspace.id),
      _repository.businessEntries(workspace.id),
      _repository.pendingSyncCount(),
    ]);
    state = state.copyWith(
      loading: false,
      currentWorkspace: workspace,
      accounts: values[0] as List<Account>,
      categories: values[1] as List<Category>,
      transactions: values[2] as List<FinanceTransaction>,
      budgets: values[3] as List<Budget>,
      contacts: values[4] as List<Contact>,
      businessEntries: values[5] as List<BusinessEntry>,
      pendingSync: values[6] as int,
      clearError: true,
    );
  }

  Future<void> refresh() async {
    final workspace = state.currentWorkspace;
    if (workspace != null) await _loadWorkspace(workspace);
  }

  Future<void> addAccount(
    String name,
    String type,
    double openingBalance,
  ) async {
    final workspace = _requireWorkspace();
    await _repository.saveAccount(
      Account(
        id: _uuid.v4(),
        workspaceId: workspace.id,
        name: name.trim(),
        type: type,
        openingBalance: openingBalance,
        currentBalance: openingBalance,
      ),
    );
    await refresh();
  }

  Future<void> addCategory(String name, TransactionType type) async {
    final workspace = _requireWorkspace();
    await _repository.saveCategory(
      Category(
        id: _uuid.v4(),
        workspaceId: workspace.id,
        name: name.trim(),
        type: type,
      ),
    );
    await refresh();
  }

  Future<void> addTransaction({
    required TransactionType type,
    required String accountId,
    String? destinationAccountId,
    String? categoryId,
    required double amount,
    String note = '',
  }) async {
    final workspace = _requireWorkspace();
    await _repository.postTransaction(
      FinanceTransaction(
        id: _uuid.v4(),
        workspaceId: workspace.id,
        accountId: accountId,
        destinationAccountId: destinationAccountId,
        categoryId: categoryId,
        type: type,
        amount: amount,
        date: DateTime.now(),
        note: note,
      ),
    );
    await refresh();
  }

  Future<void> addBudget(
    String name,
    double limit, {
    String? categoryId,
  }) async {
    final workspace = _requireWorkspace();
    final now = DateTime.now();
    await _repository.saveBudget(
      Budget(
        id: _uuid.v4(),
        workspaceId: workspace.id,
        name: name.trim(),
        limit: limit,
        categoryId: categoryId,
        month: DateTime(now.year, now.month),
      ),
    );
    await refresh();
  }

  Future<void> addContact(
    String name,
    ContactType type, {
    String phone = '',
  }) async {
    final workspace = _requireWorkspace();
    await _repository.saveContact(
      Contact(
        id: _uuid.v4(),
        workspaceId: workspace.id,
        name: name.trim(),
        type: type,
        phone: phone,
      ),
    );
    await refresh();
  }

  Future<void> addBusinessEntry({
    required BusinessEntryType type,
    String? contactId,
    String? accountId,
    required double total,
    required double paid,
    String note = '',
  }) async {
    final workspace = _requireWorkspace();
    await _repository.postBusinessEntry(
      BusinessEntry(
        id: _uuid.v4(),
        workspaceId: workspace.id,
        type: type,
        contactId: contactId,
        accountId: accountId,
        total: total,
        paid: paid,
        date: DateTime.now(),
        note: note,
      ),
    );
    await refresh();
  }

  Future<void> payContact(
    String contactId,
    String accountId,
    double amount,
  ) async {
    final workspace = _requireWorkspace();
    await _repository.receiveOrMakePayment(
      workspaceId: workspace.id,
      contactId: contactId,
      accountId: accountId,
      amount: amount,
    );
    await refresh();
  }

  Future<Map<String, Object?>> exportCurrentWorkspace() =>
      _repository.exportWorkspace(_requireWorkspace().id);

  Future<void> importWorkspaceBackup(Map<String, Object?> backup) async {
    await _repository.importWorkspace(backup);
    await initialize();
  }

  Future<void> syncNow() async {
    await _repository.markPendingAsSynced();
    await refresh();
  }

  void setBangla(bool value) => state = state.copyWith(bangla: value);
  void setDarkMode(bool value) => state = state.copyWith(darkMode: value);

  Workspace _requireWorkspace() {
    final workspace = state.currentWorkspace;
    if (workspace == null) {
      throw const FinanceValidationException('Create a workspace first.');
    }
    return workspace;
  }
}
