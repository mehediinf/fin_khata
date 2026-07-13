enum WorkspaceType { personal, business }

enum TransactionType { income, expense, transfer, adjustment }

enum ContactType { customer, supplier }

enum BusinessEntryType { sale, purchase }

enum PaymentStatus { paid, partial, due }

enum SyncStatus { pending, syncing, synced, failed }

class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.type,
    this.currency = 'BDT',
  });

  final String id;
  final String name;
  final WorkspaceType type;
  final String currency;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'currency': currency,
  };

  factory Workspace.fromJson(Map<String, Object?> json) => Workspace(
    id: json['id']! as String,
    name: json['name']! as String,
    type: WorkspaceType.values.byName(json['type']! as String),
    currency: (json['currency'] as String?) ?? 'BDT',
  );
}

class Account {
  const Account({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.currentBalance,
    this.isActive = true,
  });

  final String id;
  final String workspaceId;
  final String name;
  final String type;
  final double openingBalance;
  final double currentBalance;
  final bool isActive;

  Account copyWith({double? currentBalance, bool? isActive}) => Account(
    id: id,
    workspaceId: workspaceId,
    name: name,
    type: type,
    openingBalance: openingBalance,
    currentBalance: currentBalance ?? this.currentBalance,
    isActive: isActive ?? this.isActive,
  );
}

class Category {
  const Category({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.type,
  });

  final String id;
  final String workspaceId;
  final String name;
  final TransactionType type;
}

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.workspaceId,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.date,
    this.destinationAccountId,
    this.categoryId,
    this.note = '',
    this.referenceNumber,
    this.contactId,
    this.attachmentId,
    this.syncStatus = SyncStatus.pending,
  });

  final String id;
  final String workspaceId;
  final String accountId;
  final String? destinationAccountId;
  final String? categoryId;
  final TransactionType type;
  final double amount;
  final DateTime date;
  final String note;
  final String? referenceNumber;
  final String? contactId;
  final String? attachmentId;
  final SyncStatus syncStatus;
}

class Budget {
  const Budget({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.limit,
    required this.month,
    this.categoryId,
  });

  final String id;
  final String workspaceId;
  final String name;
  final String? categoryId;
  final double limit;
  final DateTime month;
}

class Contact {
  const Contact({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.type,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.balance = 0,
  });

  final String id;
  final String workspaceId;
  final String name;
  final ContactType type;
  final String phone;
  final String email;
  final String address;
  final double balance;
}

class BusinessEntry {
  const BusinessEntry({
    required this.id,
    required this.workspaceId,
    required this.type,
    required this.total,
    required this.paid,
    required this.date,
    this.contactId,
    this.accountId,
    this.note = '',
  });

  final String id;
  final String workspaceId;
  final BusinessEntryType type;
  final String? contactId;
  final String? accountId;
  final double total;
  final double paid;
  final DateTime date;
  final String note;
  double get due => total - paid;
  PaymentStatus get status => paid == 0
      ? PaymentStatus.due
      : paid >= total
      ? PaymentStatus.paid
      : PaymentStatus.partial;
}

class FinanceSummary {
  const FinanceSummary({
    this.balance = 0,
    this.income = 0,
    this.expense = 0,
    this.sales = 0,
    this.purchases = 0,
    this.customerDue = 0,
    this.supplierPayable = 0,
  });

  final double balance;
  final double income;
  final double expense;
  final double sales;
  final double purchases;
  final double customerDue;
  final double supplierPayable;
  double get savings => income - expense;
  double get profit => sales - purchases - expense;
}

class FinanceValidationException implements Exception {
  const FinanceValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

void validatePositiveAmount(double amount) {
  if (!amount.isFinite || amount <= 0) {
    throw const FinanceValidationException('Amount must be greater than zero.');
  }
}

void validateTransfer(String sourceAccountId, String destinationAccountId) {
  if (sourceAccountId == destinationAccountId) {
    throw const FinanceValidationException(
      'Source and destination accounts must be different.',
    );
  }
}
