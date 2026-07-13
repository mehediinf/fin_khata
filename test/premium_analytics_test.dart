import 'package:fin_khata/features/finance/domain/finance_models.dart';
import 'package:fin_khata/features/premium/domain/premium_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('personal insights calculate savings, forecast and top category', () {
    final insights = PremiumAnalytics.calculate(
      accounts: const [
        Account(
          id: 'cash',
          workspaceId: 'personal',
          name: 'Cash',
          type: 'cash',
          openingBalance: 0,
          currentBalance: 5000,
        ),
      ],
      categories: const [
        Category(
          id: 'food',
          workspaceId: 'personal',
          name: 'Food',
          type: TransactionType.expense,
        ),
      ],
      transactions: [
        FinanceTransaction(
          id: 'income',
          workspaceId: 'personal',
          accountId: 'cash',
          type: TransactionType.income,
          amount: 10000,
          date: DateTime(2026, 7, 3),
        ),
        FinanceTransaction(
          id: 'expense',
          workspaceId: 'personal',
          accountId: 'cash',
          categoryId: 'food',
          type: TransactionType.expense,
          amount: 4000,
          date: DateTime(2026, 7, 5),
        ),
      ],
      budgets: [
        Budget(
          id: 'budget',
          workspaceId: 'personal',
          name: 'Monthly',
          limit: 8000,
          month: DateTime(2026, 7),
        ),
      ],
      contacts: const [],
      businessEntries: const [],
      isBusiness: false,
      now: DateTime(2026, 7, 13),
    );

    expect(insights.savingsRate, .6);
    expect(insights.forecastNet, 2000);
    expect(insights.topCategories.single.name, 'Food');
    expect(insights.topCategories.single.share, 1);
    expect(insights.healthScore, inInclusiveRange(0, 100));
  });

  test('business insights flag low collection efficiency and due exposure', () {
    final insights = PremiumAnalytics.calculate(
      accounts: const [],
      categories: const [],
      transactions: [
        FinanceTransaction(
          id: 'expense',
          workspaceId: 'business',
          accountId: 'cash',
          type: TransactionType.expense,
          amount: 1000,
          date: DateTime(2026, 7, 5),
        ),
      ],
      budgets: const [],
      contacts: const [
        Contact(
          id: 'customer',
          workspaceId: 'business',
          name: 'Customer',
          type: ContactType.customer,
          balance: 4000,
        ),
      ],
      businessEntries: [
        BusinessEntry(
          id: 'sale',
          workspaceId: 'business',
          type: BusinessEntryType.sale,
          total: 10000,
          paid: 6000,
          date: DateTime(2026, 7, 2),
        ),
        BusinessEntry(
          id: 'purchase',
          workspaceId: 'business',
          type: BusinessEntryType.purchase,
          total: 5000,
          paid: 5000,
          date: DateTime(2026, 7, 2),
        ),
      ],
      isBusiness: true,
      now: DateTime(2026, 7, 13),
    );

    expect(insights.profitMargin, .4);
    expect(insights.collectionEfficiency, .6);
    expect(insights.dueExposure, 4000);
    expect(
      insights.recommendations.map((item) => item.title),
      contains('Improve due collection'),
    );
  });
}
