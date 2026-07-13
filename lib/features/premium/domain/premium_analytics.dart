import '../../finance/domain/finance_models.dart';

class MonthlyCashFlow {
  const MonthlyCashFlow({
    required this.month,
    required this.income,
    required this.expense,
  });

  final DateTime month;
  final double income;
  final double expense;
  double get net => income - expense;
}

class CategoryInsight {
  const CategoryInsight({
    required this.name,
    required this.amount,
    required this.share,
  });

  final String name;
  final double amount;
  final double share;
}

enum InsightLevel { positive, attention, critical }

class SmartRecommendation {
  const SmartRecommendation({
    required this.title,
    required this.message,
    required this.level,
  });

  final String title;
  final String message;
  final InsightLevel level;
}

class PremiumInsights {
  const PremiumInsights({
    required this.healthScore,
    required this.savingsRate,
    required this.forecastNet,
    required this.monthlyCashFlow,
    required this.topCategories,
    required this.recommendations,
    required this.profitMargin,
    required this.collectionEfficiency,
    required this.dueExposure,
  });

  final int healthScore;
  final double savingsRate;
  final double forecastNet;
  final List<MonthlyCashFlow> monthlyCashFlow;
  final List<CategoryInsight> topCategories;
  final List<SmartRecommendation> recommendations;
  final double profitMargin;
  final double collectionEfficiency;
  final double dueExposure;
}

class PremiumAnalytics {
  const PremiumAnalytics._();

  static PremiumInsights calculate({
    required List<Account> accounts,
    required List<Category> categories,
    required List<FinanceTransaction> transactions,
    required List<Budget> budgets,
    required List<Contact> contacts,
    required List<BusinessEntry> businessEntries,
    required bool isBusiness,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final months = List.generate(6, (index) {
      final month = DateTime(current.year, current.month - (5 - index));
      final matching = transactions.where(
        (item) =>
            item.date.year == month.year && item.date.month == month.month,
      );
      return MonthlyCashFlow(
        month: month,
        income: matching
            .where((item) => item.type == TransactionType.income)
            .fold(0, (total, item) => total + item.amount),
        expense: matching
            .where((item) => item.type == TransactionType.expense)
            .fold(0, (total, item) => total + item.amount),
      );
    });

    final latest = months.last;
    final savingsRate = latest.income <= 0
        ? 0.0
        : ((latest.income - latest.expense) / latest.income).clamp(-1.0, 1.0);
    final balance = accounts
        .where((account) => account.isActive)
        .fold<double>(0, (total, account) => total + account.currentBalance);
    final reserveMonths = latest.expense <= 0
        ? (balance > 0 ? 6.0 : 0.0)
        : (balance / latest.expense).clamp(0.0, 6.0);
    final budgetLimit = budgets.fold<double>(
      0,
      (total, item) => total + item.limit,
    );
    final budgetScore = budgetLimit <= 0
        ? .65
        : (1 - (latest.expense / budgetLimit - .7).clamp(0.0, 1.0));

    final sales = businessEntries
        .where((item) => item.type == BusinessEntryType.sale)
        .fold<double>(0, (total, item) => total + item.total);
    final salesPaid = businessEntries
        .where((item) => item.type == BusinessEntryType.sale)
        .fold<double>(0, (total, item) => total + item.paid);
    final purchases = businessEntries
        .where((item) => item.type == BusinessEntryType.purchase)
        .fold<double>(0, (total, item) => total + item.total);
    final profit = sales - purchases - latest.expense;
    final profitMargin = sales <= 0 ? 0.0 : profit / sales;
    final collectionEfficiency = sales <= 0 ? 1.0 : salesPaid / sales;
    final dueExposure = contacts.fold<double>(
      0,
      (total, item) => total + item.balance,
    );

    final personalScore =
        ((savingsRate.clamp(0.0, .4) / .4) * 40) +
        ((reserveMonths / 6) * 35) +
        (budgetScore * 25);
    final businessScore =
        (profitMargin.clamp(0.0, .3) / .3 * 40) +
        (collectionEfficiency.clamp(0.0, 1.0) * 35) +
        (budgetScore * 25);
    final healthScore = (isBusiness ? businessScore : personalScore)
        .round()
        .clamp(0, 100);

    final recentForForecast = months.skip(3).toList();
    final forecastNet = recentForForecast.isEmpty
        ? 0.0
        : recentForForecast.fold<double>(0, (total, item) => total + item.net) /
              recentForForecast.length;

    final expenseTotal = transactions
        .where((item) => item.type == TransactionType.expense)
        .fold<double>(0, (total, item) => total + item.amount);
    final categoryTotals = <String?, double>{};
    for (final item in transactions.where(
      (item) => item.type == TransactionType.expense,
    )) {
      categoryTotals.update(
        item.categoryId,
        (value) => value + item.amount,
        ifAbsent: () => item.amount,
      );
    }
    final topCategories = categoryTotals.entries.map((entry) {
      final category = categories
          .where((item) => item.id == entry.key)
          .firstOrNull;
      return CategoryInsight(
        name: category?.name ?? 'Uncategorized',
        amount: entry.value,
        share: expenseTotal <= 0 ? 0 : entry.value / expenseTotal,
      );
    }).toList()..sort((a, b) => b.amount.compareTo(a.amount));

    final recommendations = <SmartRecommendation>[];
    if (isBusiness) {
      if (collectionEfficiency < .75) {
        recommendations.add(
          const SmartRecommendation(
            title: 'Improve due collection',
            message:
                'Less than 75% of sales have been collected. Follow up high-value dues first.',
            level: InsightLevel.critical,
          ),
        );
      }
      if (profitMargin < .1 && sales > 0) {
        recommendations.add(
          const SmartRecommendation(
            title: 'Review your margin',
            message:
                'Profit margin is below 10%. Review purchase costs and pricing.',
            level: InsightLevel.attention,
          ),
        );
      }
    } else {
      if (savingsRate < .1 && latest.income > 0) {
        recommendations.add(
          const SmartRecommendation(
            title: 'Increase monthly savings',
            message:
                'Savings are below 10% of income. Start with a realistic category limit.',
            level: InsightLevel.attention,
          ),
        );
      }
      if (reserveMonths < 1 && latest.expense > 0) {
        recommendations.add(
          const SmartRecommendation(
            title: 'Build an emergency reserve',
            message:
                'Available balance covers less than one month of current expenses.',
            level: InsightLevel.critical,
          ),
        );
      }
    }
    if (recommendations.isEmpty) {
      recommendations.add(
        const SmartRecommendation(
          title: 'Finances look healthy',
          message:
              'Keep recording transactions to make future forecasts more accurate.',
          level: InsightLevel.positive,
        ),
      );
    }

    return PremiumInsights(
      healthScore: healthScore,
      savingsRate: savingsRate,
      forecastNet: forecastNet,
      monthlyCashFlow: months,
      topCategories: topCategories.take(5).toList(),
      recommendations: recommendations,
      profitMargin: profitMargin,
      collectionEfficiency: collectionEfficiency,
      dueExposure: dueExposure,
    );
  }
}
