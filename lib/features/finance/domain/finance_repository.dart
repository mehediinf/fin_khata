import 'finance_models.dart';

abstract interface class FinanceRepository {
  Future<void> initialize();
  Future<List<Workspace>> workspaces();
  Future<void> saveWorkspace(Workspace workspace);
  Future<List<Account>> accounts(String workspaceId);
  Future<void> saveAccount(Account account);
  Future<List<Category>> categories(String workspaceId);
  Future<void> saveCategory(Category category);
  Future<List<FinanceTransaction>> transactions(String workspaceId);
  Future<void> postTransaction(FinanceTransaction transaction);
  Future<List<Budget>> budgets(String workspaceId);
  Future<void> saveBudget(Budget budget);
  Future<List<Contact>> contacts(String workspaceId);
  Future<void> saveContact(Contact contact);
  Future<List<BusinessEntry>> businessEntries(String workspaceId);
  Future<void> postBusinessEntry(BusinessEntry entry);
  Future<void> receiveOrMakePayment({
    required String workspaceId,
    required String contactId,
    required String accountId,
    required double amount,
  });
  Future<Map<String, Object?>> exportWorkspace(String workspaceId);
  Future<void> importWorkspace(Map<String, Object?> backup);
  Future<int> pendingSyncCount();
  Future<void> markPendingAsSynced();
  Future<void> close();
}
