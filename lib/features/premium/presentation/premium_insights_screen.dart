import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_currencies.dart';
import '../../finance/presentation/providers/finance_controller.dart';
import '../domain/premium_analytics.dart';

class PremiumInsightsScreen extends ConsumerWidget {
  const PremiumInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeControllerProvider);
    final currency = state.currentWorkspace?.currency ?? 'BDT';
    final insights = PremiumAnalytics.calculate(
      accounts: state.accounts,
      categories: state.categories,
      transactions: state.transactions,
      budgets: state.budgets,
      contacts: state.contacts,
      businessEntries: state.businessEntries,
      isBusiness: state.isBusiness,
    );
    String t(String english, String bangla) => state.bangla ? bangla : english;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('Premium Insights', 'প্রিমিয়াম ইনসাইটস')),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Chip(
              avatar: Icon(Icons.workspace_premium_rounded, size: 18),
              label: Text('PRO'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: ref.read(financeControllerProvider.notifier).refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _PremiumHero(
              score: insights.healthScore,
              isBusiness: state.isBusiness,
              bangla: state.bangla,
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final width = wide
                    ? (constraints.maxWidth - 24) / 3
                    : (constraints.maxWidth - 12) / 2;
                final metrics = state.isBusiness
                    ? [
                        (
                          t('Profit margin', 'লাভের হার'),
                          _percent(insights.profitMargin),
                          Icons.auto_graph_rounded,
                          Colors.indigo,
                        ),
                        (
                          t('Collection', 'আদায়ের হার'),
                          _percent(insights.collectionEfficiency),
                          Icons.payments_outlined,
                          Colors.teal,
                        ),
                        (
                          t('Due exposure', 'মোট বাকি'),
                          formatMoney(insights.dueExposure, currency),
                          Icons.warning_amber_rounded,
                          Colors.orange,
                        ),
                      ]
                    : [
                        (
                          t('Savings rate', 'সঞ্চয়ের হার'),
                          _percent(insights.savingsRate),
                          Icons.savings_outlined,
                          Colors.indigo,
                        ),
                        (
                          t('Next month forecast', 'আগামী মাসের পূর্বাভাস'),
                          formatMoney(insights.forecastNet, currency),
                          Icons.query_stats_rounded,
                          Colors.teal,
                        ),
                        (
                          t('Active balance', 'বর্তমান ব্যালেন্স'),
                          formatMoney(state.summary.balance, currency),
                          Icons.account_balance_wallet_outlined,
                          Colors.orange,
                        ),
                      ];
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: metrics
                      .map(
                        (metric) => SizedBox(
                          width: width,
                          child: _MetricCard(
                            label: metric.$1,
                            value: metric.$2,
                            icon: metric.$3,
                            color: metric.$4,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 22),
            _SectionTitle(
              title: t('6-month cash flow', '৬ মাসের ক্যাশ ফ্লো'),
              subtitle: t('Income and expense movement', 'আয় ও খরচের পরিবর্তন'),
            ),
            const SizedBox(height: 10),
            _CashFlowChart(
              items: insights.monthlyCashFlow,
              bangla: state.bangla,
            ),
            const SizedBox(height: 22),
            _SectionTitle(
              title: t('Smart recommendations', 'স্মার্ট পরামর্শ'),
              subtitle: t(
                'Calculated from your workspace data',
                'আপনার workspace-এর তথ্য থেকে হিসাব করা',
              ),
            ),
            const SizedBox(height: 10),
            ...insights.recommendations.map(
              (item) => _RecommendationCard(item: item, bangla: state.bangla),
            ),
            if (!state.isBusiness && insights.topCategories.isNotEmpty) ...[
              const SizedBox(height: 22),
              _SectionTitle(
                title: t('Expense concentration', 'খরচের ঘনত্ব'),
                subtitle: t(
                  'Your highest spending categories',
                  'যেসব ক্যাটাগরিতে সবচেয়ে বেশি খরচ',
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: insights.topCategories
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(item.name)),
                                    Text(
                                      formatMoney(item.amount, currency),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                LinearProgressIndicator(
                                  value: item.share.clamp(0, 1),
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            _SectionTitle(
              title: t('Global-ready workspace', 'Global-ready workspace'),
              subtitle: t(
                'Bangladesh-first, ready wherever you work',
                'বাংলাদেশকে প্রাধান্য দিয়ে, বিশ্বের যেকোনো জায়গার জন্য প্রস্তুত',
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.public)),
                    title: Text(t('Workspace currency', 'Workspace মুদ্রা')),
                    subtitle: Text(
                      '${AppCurrency.fromCode(currency).name} ($currency)',
                    ),
                    trailing: const Icon(
                      Icons.verified_rounded,
                      color: Colors.teal,
                    ),
                  ),
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.language)),
                    title: Text(t('Bangla + English', 'বাংলা + English')),
                    subtitle: Text(
                      t(
                        'Localized experience and global number format',
                        'স্থানীয় অভিজ্ঞতা ও global number format',
                      ),
                    ),
                    trailing: const Icon(
                      Icons.verified_rounded,
                      color: Colors.teal,
                    ),
                  ),
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.account_balance_outlined),
                    ),
                    title: Text(t('Bangladesh payments', 'বাংলাদেশি পেমেন্ট')),
                    subtitle: const Text(
                      'bKash • Nagad • Rocket • Bank • Cash',
                    ),
                    trailing: const Icon(
                      Icons.verified_rounded,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumHero extends StatelessWidget {
  const _PremiumHero({
    required this.score,
    required this.isBusiness,
    required this.bangla,
  });

  final int score;
  final bool isBusiness;
  final bool bangla;

  @override
  Widget build(BuildContext context) {
    final color = score >= 75
        ? Colors.green
        : score >= 50
        ? Colors.orange
        : Colors.red;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102A43), Color(0xFF0B6B53)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 94,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.square(
                  dimension: 88,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 9,
                    color: color,
                    backgroundColor: Colors.white24,
                  ),
                ),
                Text(
                  '$score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bangla ? 'Financial Health Score' : 'Financial Health Score',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  isBusiness
                      ? (bangla
                            ? 'ব্যবসার আর্থিক স্বাস্থ্য'
                            : 'Business financial health')
                      : (bangla
                            ? 'ব্যক্তিগত আর্থিক স্বাস্থ্য'
                            : 'Personal financial health'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  bangla
                      ? 'আরও তথ্য যোগ করলে score ও forecast আরও নির্ভুল হবে।'
                      : 'More recorded data makes the score and forecast smarter.',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 14),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(label, maxLines: 2),
        ],
      ),
    ),
  );
}

class _CashFlowChart extends StatelessWidget {
  const _CashFlowChart({required this.items, required this.bangla});

  final List<MonthlyCashFlow> items;
  final bool bangla;

  @override
  Widget build(BuildContext context) {
    final largest = items.fold<double>(1, (current, item) {
      final value = item.income > item.expense ? item.income : item.expense;
      return value > current ? value : current;
    });
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 22, 18, 14),
        child: Column(
          children: [
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (items.length - 1).toDouble(),
                  minY: 0,
                  maxY: largest * 1.18,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: .25),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= items.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat.MMM().format(items[index].month),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    _line(
                      items.indexed
                          .map(
                            (entry) =>
                                FlSpot(entry.$1.toDouble(), entry.$2.income),
                          )
                          .toList(),
                      Colors.green,
                    ),
                    _line(
                      items.indexed
                          .map(
                            (entry) =>
                                FlSpot(entry.$1.toDouble(), entry.$2.expense),
                          )
                          .toList(),
                      Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legend(color: Colors.green, label: bangla ? 'আয়' : 'Income'),
                const SizedBox(width: 22),
                _Legend(
                  color: Colors.orange,
                  label: bangla ? 'খরচ' : 'Expense',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) => LineChartBarData(
    spots: spots,
    color: color,
    barWidth: 3,
    isCurved: true,
    dotData: const FlDotData(show: false),
    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: .08)),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 7),
      Text(label),
    ],
  );
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.item, required this.bangla});
  final SmartRecommendation item;
  final bool bangla;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (item.level) {
      InsightLevel.positive => (Icons.check_circle_outline, Colors.green),
      InsightLevel.attention => (Icons.lightbulb_outline, Colors.orange),
      InsightLevel.critical => (Icons.warning_amber_rounded, Colors.red),
    };
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          foregroundColor: color,
          child: Icon(icon),
        ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(item.message),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 3),
      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

String _percent(double value) => '${(value * 100).toStringAsFixed(1)}%';
