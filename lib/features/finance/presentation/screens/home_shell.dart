import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_currencies.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../../auth/presentation/screens/auth_screen.dart';
import '../../../onboarding/presentation/onboarding_screen.dart';
import '../../../premium/domain/premium_analytics.dart';
import '../../../security/presentation/providers/app_lock_controller.dart';
import '../../../security/presentation/screens/pin_lock_screen.dart';
import '../../domain/finance_models.dart';
import '../providers/finance_controller.dart';

class HomeGate extends ConsumerWidget {
  const HomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockState = ref.watch(appLockControllerProvider);
    if (lockState.checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (lockState.locked) {
      return const PinLockScreen();
    }
    final authState = ref.watch(authControllerProvider);
    if (authState.checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (authState.needsReauth) {
      return const AuthScreen(forcedReauth: true);
    }
    final state = ref.watch(financeControllerProvider);
    if (state.loading && state.workspaces.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.error != null && state.workspaces.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(state.error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: ref
                      .read(financeControllerProvider.notifier)
                      .initialize,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (state.workspaces.isEmpty) return const OnboardingScreen();
    return const HomeShell();
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeControllerProvider);
    final strings = AppStrings.of(context);
    final workspace = state.currentWorkspace;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: workspace == null
            ? Text(strings.appName)
            : DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: workspace.id,
                  borderRadius: BorderRadius.circular(16),
                  items: state.workspaces
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id == null) return;
                    ref
                        .read(financeControllerProvider.notifier)
                        .switchWorkspace(
                          state.workspaces.firstWhere((item) => item.id == id),
                        );
                  },
                ),
              ),
        actions: [
          IconButton(
            tooltip: 'Workspace',
            onPressed: () => _showWorkspaceDialog(context, ref),
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _index > 1 ? _index - 1 : _index,
              children: const [
                DashboardPage(),
                TransactionsPage(),
                ReportsPage(),
                MorePage(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          if (value == 2) {
            _showAddMenu(context, ref, state);
          } else {
            setState(() => _index = value);
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: strings.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: strings.transactions,
          ),
          NavigationDestination(
            icon: const Icon(Icons.add_circle, size: 34),
            label: strings.add,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: strings.reports,
          ),
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view_rounded),
            label: strings.more,
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeControllerProvider);
    final summary = state.summary;
    final bangla = state.bangla;
    String t(String en, String bn) => bangla ? bn : en;
    final cards = state.isBusiness
        ? [
            (
              t('Sales', 'বিক্রি'),
              summary.sales,
              Icons.trending_up_rounded,
              Colors.teal,
            ),
            (
              t('Expenses', 'খরচ'),
              summary.expense + summary.purchases,
              Icons.trending_down_rounded,
              Colors.orange,
            ),
            (
              t('Profit', 'লাভ'),
              summary.profit,
              Icons.auto_graph_rounded,
              Colors.indigo,
            ),
            (
              t('Customer due', 'কাস্টমার বাকি'),
              summary.customerDue,
              Icons.people_outline,
              Colors.pink,
            ),
          ]
        : [
            (
              t('Total balance', 'মোট ব্যালেন্স'),
              summary.balance,
              Icons.account_balance_wallet_outlined,
              Colors.teal,
            ),
            (
              t('This month income', 'এই মাসের আয়'),
              summary.income,
              Icons.south_west_rounded,
              Colors.green,
            ),
            (
              t('This month expense', 'এই মাসের খরচ'),
              summary.expense,
              Icons.north_east_rounded,
              Colors.orange,
            ),
            (
              t('Savings', 'সঞ্চয়'),
              summary.savings,
              Icons.savings_outlined,
              Colors.indigo,
            ),
          ];
    return RefreshIndicator(
      onRefresh: ref.read(financeControllerProvider.notifier).refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            state.isBusiness
                ? t('Business overview', 'ব্যবসার সারসংক্ষেপ')
                : t('Money overview', 'টাকার সারসংক্ষেপ'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth > 700
                  ? (constraints.maxWidth - 36) / 4
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards
                    .map(
                      (item) => SizedBox(
                        width: width,
                        child: _SummaryCard(
                          label: item.$1,
                          value: item.$2,
                          icon: item.$3,
                          color: item.$4,
                          currency: state.currentWorkspace?.currency ?? 'BDT',
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 22),
          Text(
            t('Quick actions', 'দ্রুত কাজ'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _QuickActions(state: state),
          const SizedBox(height: 16),
          _DashboardPremiumBanner(state: state),
          if (!state.isBusiness) ...[
            const SizedBox(height: 22),
            _BudgetOverview(state: state),
          ],
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.isBusiness
                    ? t('Recent activity', 'সাম্প্রতিক কার্যক্রম')
                    : t('Recent transactions', 'সাম্প্রতিক লেনদেন'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: () {},
                child: Text(t('Latest 5', 'সর্বশেষ ৫টি')),
              ),
            ],
          ),
          if (state.isBusiness)
            ...state.businessEntries
                .take(5)
                .map((entry) => _BusinessEntryTile(entry: entry, state: state))
          else
            ...state.transactions
                .take(5)
                .map((item) => _TransactionTile(item: item, state: state)),
          if ((state.isBusiness ? state.businessEntries : state.transactions)
              .isEmpty)
            _EmptyCard(
              message: t(
                'No activity yet. Use a quick action to begin.',
                'এখনও কোনো হিসাব নেই। Quick action থেকে শুরু করুন।',
              ),
            ),
        ],
      ),
    );
  }
}

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeControllerProvider);
    String t(String en, String bn) => state.bangla ? bn : en;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          t('All transactions', 'সব লেনদেন'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          t(
            'Every record is isolated inside this workspace.',
            'প্রতিটি রেকর্ড শুধু এই workspace-এর মধ্যে রাখা হয়েছে।',
          ),
        ),
        const SizedBox(height: 16),
        if (state.transactions.isEmpty)
          _EmptyCard(
            message: t(
              'No income, expense or transfer yet.',
              'এখনও আয়, খরচ বা transfer নেই।',
            ),
          ),
        ...state.transactions.map(
          (item) => _TransactionTile(item: item, state: state),
        ),
        if (state.isBusiness && state.businessEntries.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            t('Sales & purchases', 'বিক্রি ও ক্রয়'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...state.businessEntries.map(
            (entry) => _BusinessEntryTile(entry: entry, state: state),
          ),
        ],
      ],
    );
  }
}

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeControllerProvider);
    final s = state.summary;
    final currency = state.currentWorkspace?.currency ?? 'BDT';
    String t(String en, String bn) => state.bangla ? bn : en;
    final rows = state.isBusiness
        ? [
            (t('Sales report', 'বিক্রি রিপোর্ট'), s.sales, Colors.green),
            (t('Purchase report', 'ক্রয় রিপোর্ট'), s.purchases, Colors.orange),
            (t('General expense', 'সাধারণ খরচ'), s.expense, Colors.red),
            (t('Profit summary', 'লাভের সারসংক্ষেপ'), s.profit, Colors.indigo),
            (t('Customer due', 'কাস্টমার বাকি'), s.customerDue, Colors.pink),
            (
              t('Supplier payable', 'সাপ্লায়ার পাওনা'),
              s.supplierPayable,
              Colors.deepOrange,
            ),
            (t('Cash flow', 'ক্যাশ ফ্লো'), s.income - s.expense, Colors.teal),
          ]
        : [
            (t('Income', 'আয়'), s.income, Colors.green),
            (t('Expense', 'খরচ'), s.expense, Colors.orange),
            (t('Savings', 'সঞ্চয়'), s.savings, Colors.indigo),
            (t('Account balance', 'Account ব্যালেন্স'), s.balance, Colors.teal),
          ];
    final max = rows.fold<double>(
      1,
      (value, row) => row.$2.abs() > value ? row.$2.abs() : value,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          t('Reports', 'রিপোর্ট'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(t('Current month • $currency', 'চলতি মাস • $currency')),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: rows
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(row.$1)),
                              Text(
                                _money(row.$2, currency),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          LinearProgressIndicator(
                            value: (row.$2.abs() / max).clamp(0, 1),
                            color: row.$3,
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
        const SizedBox(height: 18),
        Text(
          t('Account statement', 'Account statement'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...state.accounts.map(
          (account) => Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.account_balance_wallet_outlined),
              ),
              title: Text(account.name),
              subtitle: Text(account.type),
              trailing: Text(
                _money(account.currentBalance, currency),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeControllerProvider);
    final controller = ref.read(financeControllerProvider.notifier);
    String t(String en, String bn) => state.bangla ? bn : en;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          t('Manage', 'পরিচালনা'),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        _PremiumEntryCard(state: state),
        const SizedBox(height: 4),
        _SectionCard(
          title: t('Accounts', 'Accounts'),
          icon: Icons.account_balance_wallet_outlined,
          action: () => _showAccountDialog(context, ref),
          children: state.accounts
              .map(
                (account) => ListTile(
                  dense: true,
                  title: Text(account.name),
                  subtitle: Text(account.type),
                  trailing: Text(
                    _money(
                      account.currentBalance,
                      state.currentWorkspace?.currency ?? 'BDT',
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        _SectionCard(
          title: t('Categories', 'ক্যাটাগরি'),
          icon: Icons.category_outlined,
          action: () => _showCategoryDialog(context, ref),
          children: state.categories
              .map(
                (category) => ListTile(
                  dense: true,
                  title: Text(category.name),
                  trailing: Text(category.type.name),
                ),
              )
              .toList(),
        ),
        if (!state.isBusiness)
          _SectionCard(
            title: t('Monthly budgets', 'মাসিক বাজেট'),
            icon: Icons.pie_chart_outline,
            action: () => _showBudgetDialog(context, ref),
            children: state.budgets
                .map(
                  (budget) => ListTile(
                    dense: true,
                    title: Text(budget.name),
                    trailing: Text(
                      _money(
                        budget.limit,
                        state.currentWorkspace?.currency ?? 'BDT',
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        if (state.isBusiness)
          _SectionCard(
            title: t('Customers & suppliers', 'কাস্টমার ও সাপ্লায়ার'),
            icon: Icons.groups_outlined,
            action: () => _showContactDialog(context, ref),
            children: state.contacts
                .map(
                  (contact) => ListTile(
                    dense: true,
                    title: Text(contact.name),
                    subtitle: Text(contact.type.name),
                    trailing: Text(
                      _money(
                        contact.balance,
                        state.currentWorkspace?.currency ?? 'BDT',
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.translate),
                title: Text(t('Bangla language', 'বাংলা ভাষা')),
                value: state.bangla,
                onChanged: controller.setBangla,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: Text(t('Dark theme', 'ডার্ক থিম')),
                value: state.darkMode,
                onChanged: controller.setDarkMode,
              ),
              Builder(
                builder: (context) {
                  final pinEnabled = ref.watch(
                    appLockControllerProvider.select((s) => s.pinEnabled),
                  );
                  return ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(
                      t(
                        'PIN & biometric security',
                        'PIN ও biometric security',
                      ),
                    ),
                    subtitle: Text(
                      pinEnabled
                          ? t(
                              'App auto-locks in the background. Tap to change or remove PIN.',
                              'App background-এ গেলে auto-lock হয়। PIN বদলাতে/সরাতে tap করুন।',
                            )
                          : t(
                              'No app-lock PIN set yet',
                              'এখনো app-lock PIN সেট করা হয়নি',
                            ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        _showPinDialog(context, ref, pinEnabled: pinEnabled),
                  );
                },
              ),
              Builder(
                builder: (context) {
                  final authState = ref.watch(authControllerProvider);
                  return ListTile(
                    leading: const Icon(Icons.cloud_sync_outlined),
                    title: Text(t('Cloud sync', 'Cloud sync')),
                    subtitle: Text(
                      authState.loggedIn
                          ? '${authState.userEmail} • ${state.pendingSync} '
                                '${t('pending changes', 'টি pending change')}'
                          : t(
                              'Log in to sync this workspace across devices',
                              'Device-এর মধ্যে sync করতে login করুন',
                            ),
                    ),
                    trailing: authState.loggedIn
                        ? TextButton(
                            onPressed: () async {
                              try {
                                final conflict = await controller.syncNow();
                                if (!context.mounted) return;
                                _notice(
                                  context,
                                  conflict
                                      ? 'Synced — a newer copy from another '
                                            'device was found and applied.'
                                      : 'Synced successfully.',
                                );
                              } catch (error) {
                                if (context.mounted) _error(context, error);
                              }
                            },
                            child: Text(t('Sync', 'Sync')),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: authState.loggedIn
                        ? () => _showLogoutDialog(context, ref)
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AuthScreen(),
                            ),
                          ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: Text(t('Backup workspace', 'Workspace backup')),
                subtitle: Text(
                  t(
                    'Encrypted, passphrase-protected export',
                    'Encrypted, passphrase-protected export',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showBackup(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.restore_outlined),
                title: Text(t('Restore workspace', 'Workspace restore')),
                subtitle: Text(
                  t(
                    'Import an encrypted backup',
                    'Encrypted backup import করুন',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showRestoreDialog(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumEntryCard extends StatelessWidget {
  const _PremiumEntryCard({required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.push('/premium'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF102A43), Color(0xFF0B6B53)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 25,
              backgroundColor: Colors.white12,
              foregroundColor: Colors.amber,
              child: Icon(Icons.workspace_premium_rounded, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.bangla ? 'Premium Insights' : 'Premium Insights',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.bangla
                        ? 'Health score, forecast ও advanced analytics'
                        : 'Health score, forecast and advanced analytics',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    ),
  );
}

class _DashboardPremiumBanner extends StatelessWidget {
  const _DashboardPremiumBanner({required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    final score = PremiumAnalytics.calculate(
      accounts: state.accounts,
      categories: state.categories,
      transactions: state.transactions,
      budgets: state.budgets,
      contacts: state.contacts,
      businessEntries: state.businessEntries,
      isBusiness: state.isBusiness,
    ).healthScore;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/premium'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.square(
                    dimension: 54,
                    child: CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 6,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  Text(
                    '$score',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.bangla
                          ? 'আপনার Financial Health Score'
                          : 'Your Financial Health Score',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      state.bangla
                          ? 'Forecast ও smart recommendation দেখুন'
                          : 'View forecasts and smart recommendations',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.currency,
  });
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final String currency;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .12),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(height: 18),
          Text(
            _money(value, currency),
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

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.state});
  final FinanceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String en, String bn) => state.bangla ? bn : en;
    final actions = state.isBusiness
        ? [
            (
              t('New sale', 'নতুন বিক্রি'),
              Icons.point_of_sale_outlined,
              () => _showBusinessEntryDialog(
                context,
                ref,
                BusinessEntryType.sale,
              ),
            ),
            (
              t('Purchase', 'ক্রয়'),
              Icons.shopping_cart_outlined,
              () => _showBusinessEntryDialog(
                context,
                ref,
                BusinessEntryType.purchase,
              ),
            ),
            (
              t('Expense', 'খরচ'),
              Icons.payments_outlined,
              () =>
                  _showTransactionDialog(context, ref, TransactionType.expense),
            ),
            (
              t('Payment', 'পেমেন্ট'),
              Icons.handshake_outlined,
              () => _showPaymentDialog(context, ref),
            ),
          ]
        : [
            (
              t('Income', 'আয়'),
              Icons.south_west_rounded,
              () =>
                  _showTransactionDialog(context, ref, TransactionType.income),
            ),
            (
              t('Expense', 'খরচ'),
              Icons.north_east_rounded,
              () =>
                  _showTransactionDialog(context, ref, TransactionType.expense),
            ),
            (
              t('Transfer', 'ট্রান্সফার'),
              Icons.swap_horiz_rounded,
              () => _showTransactionDialog(
                context,
                ref,
                TransactionType.transfer,
              ),
            ),
            (
              t('Budget', 'বাজেট'),
              Icons.pie_chart_outline,
              () => _showBudgetDialog(context, ref),
            ),
          ];
    return Row(
      children: actions
          .map(
            (action) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: action.$3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        CircleAvatar(child: Icon(action.$2)),
                        const SizedBox(height: 7),
                        Text(
                          action.$1,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _BudgetOverview extends StatelessWidget {
  const _BudgetOverview({required this.state});
  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    if (state.budgets.isEmpty) return const SizedBox.shrink();
    final used = state.summary.expense;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.bangla ? 'বাজেট অগ্রগতি' : 'Budget progress',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...state.budgets.map((budget) {
          final progress = (used / budget.limit).clamp(0.0, 1.0);
          final color = progress <= .7
              ? Colors.green
              : progress <= .9
              ? Colors.orange
              : Colors.red;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          budget.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${_money(used, state.currentWorkspace?.currency ?? 'BDT')} / '
                        '${_money(budget.limit, state.currentWorkspace?.currency ?? 'BDT')}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: progress,
                    color: color,
                    minHeight: 9,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.item, required this.state});
  final FinanceTransaction item;
  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    final account = state.accounts
        .where((a) => a.id == item.accountId)
        .firstOrNull;
    final category = state.categories
        .where((c) => c.id == item.categoryId)
        .firstOrNull;
    final incoming =
        item.type == TransactionType.income ||
        item.type == TransactionType.adjustment;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            item.type == TransactionType.transfer
                ? Icons.swap_horiz
                : incoming
                ? Icons.south_west
                : Icons.north_east,
          ),
        ),
        title: Text(
          category?.name ?? _title(item.type),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${account?.name ?? 'Account'} • ${DateFormat.MMMd().format(item.date)}${item.note.isEmpty ? '' : '\n${item.note}'}',
        ),
        isThreeLine: item.note.isNotEmpty,
        trailing: Text(
          '${incoming ? '+' : '-'}${_money(item.amount, state.currentWorkspace?.currency ?? 'BDT')}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: incoming ? Colors.green : Colors.orange,
          ),
        ),
      ),
    );
  }
}

class _BusinessEntryTile extends StatelessWidget {
  const _BusinessEntryTile({required this.entry, required this.state});
  final BusinessEntry entry;
  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    final contact = state.contacts
        .where((c) => c.id == entry.contactId)
        .firstOrNull;
    final sale = entry.type == BusinessEntryType.sale;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            sale ? Icons.point_of_sale : Icons.shopping_cart_outlined,
          ),
        ),
        title: Text(
          sale ? 'Sale' : 'Purchase',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${contact?.name ?? 'Walk-in'} • ${entry.status.name}${entry.due > 0 ? ' • Due ${_money(entry.due, state.currentWorkspace?.currency ?? 'BDT')}' : ''}',
        ),
        trailing: Text(
          _money(entry.total, state.currentWorkspace?.currency ?? 'BDT'),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: sale ? Colors.green : Colors.orange,
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: Text(message, textAlign: TextAlign.center)),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.action,
    required this.children,
  });
  final String title;
  final IconData icon;
  final VoidCallback action;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: IconButton(
        onPressed: action,
        icon: const Icon(Icons.add_circle_outline),
      ),
      children: children.isEmpty
          ? [const ListTile(title: Text('No records yet'))]
          : children,
    ),
  );
}

class _DialogForm extends StatelessWidget {
  const _DialogForm({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: children);
}

Future<void> _showAddMenu(
  BuildContext context,
  WidgetRef ref,
  FinanceState state,
) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children:
              (state.isBusiness
                      ? const [
                          ('sale', 'New Sale', Icons.point_of_sale),
                          ('purchase', 'New Purchase', Icons.shopping_cart),
                          ('expense', 'Add Expense', Icons.payments),
                          (
                            'receive',
                            'Receive / Make Payment',
                            Icons.handshake,
                          ),
                        ]
                      : const [
                          ('income', 'Add Income', Icons.south_west),
                          ('expense', 'Add Expense', Icons.north_east),
                          ('transfer', 'Transfer', Icons.swap_horiz),
                        ])
                  .map(
                    (item) => ListTile(
                      leading: Icon(item.$3),
                      title: Text(item.$2),
                      onTap: () => Navigator.pop(context, item.$1),
                    ),
                  )
                  .toList(),
        ),
      ),
    ),
  );
  if (!context.mounted || choice == null) return;
  switch (choice) {
    case 'sale':
      await _showBusinessEntryDialog(context, ref, BusinessEntryType.sale);
    case 'purchase':
      await _showBusinessEntryDialog(context, ref, BusinessEntryType.purchase);
    case 'income':
      await _showTransactionDialog(context, ref, TransactionType.income);
    case 'expense':
      await _showTransactionDialog(context, ref, TransactionType.expense);
    case 'transfer':
      await _showTransactionDialog(context, ref, TransactionType.transfer);
    case 'receive':
      await _showPaymentDialog(context, ref);
  }
}

Future<void> _showTransactionDialog(
  BuildContext context,
  WidgetRef ref,
  TransactionType type,
) async {
  final state = ref.read(financeControllerProvider);
  if (state.accounts.isEmpty) {
    return _notice(context, 'Create an account first.');
  }
  String source = state.accounts.first.id;
  String? destination = state.accounts.length > 1 ? state.accounts[1].id : null;
  String? category;
  final available = state.categories.where((c) => c.type == type).toList();
  if (available.isNotEmpty) category = available.first.id;
  final amount = TextEditingController();
  final note = TextEditingController();
  await _showManagedDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(_title(type)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: source,
                decoration: const InputDecoration(labelText: 'Account'),
                items: state.accounts
                    .map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => source = v!),
              ),
              if (type == TransactionType.transfer) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: destination,
                  decoration: const InputDecoration(
                    labelText: 'Destination account',
                  ),
                  items: state.accounts
                      .map(
                        (a) =>
                            DropdownMenuItem(value: a.id, child: Text(a.name)),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => destination = v),
                ),
              ] else if (available.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: available
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (v) => category = v,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount (BDT)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(financeControllerProvider.notifier)
                    .addTransaction(
                      type: type,
                      accountId: source,
                      destinationAccountId: destination,
                      categoryId: category,
                      amount: double.tryParse(amount.text) ?? 0,
                      note: note.text,
                    );
                if (context.mounted) Navigator.pop(context);
              } catch (error) {
                if (context.mounted) _error(context, error);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  amount.dispose();
  note.dispose();
}

Future<void> _showBusinessEntryDialog(
  BuildContext context,
  WidgetRef ref,
  BusinessEntryType type,
) async {
  final state = ref.read(financeControllerProvider);
  if (state.accounts.isEmpty) {
    return _notice(context, 'Create an account first.');
  }
  final contactType = type == BusinessEntryType.sale
      ? ContactType.customer
      : ContactType.supplier;
  final contacts = state.contacts.where((c) => c.type == contactType).toList();
  String? contactId = contacts.firstOrNull?.id;
  String accountId = state.accounts.first.id;
  final total = TextEditingController();
  final paid = TextEditingController(text: '0');
  final note = TextEditingController();
  await _showManagedDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(
          type == BusinessEntryType.sale ? 'New sale' : 'New purchase',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String?>(
                initialValue: contactId,
                decoration: InputDecoration(
                  labelText: type == BusinessEntryType.sale
                      ? 'Customer'
                      : 'Supplier',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Walk-in / none'),
                  ),
                  ...contacts.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ),
                ],
                onChanged: (v) => setLocal(() => contactId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: total,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Total amount'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: paid,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Paid now (0 = fully due)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: accountId,
                decoration: const InputDecoration(
                  labelText: 'Cash / bank account',
                ),
                items: state.accounts
                    .map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                    )
                    .toList(),
                onChanged: (v) => accountId = v!,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Item / note'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(financeControllerProvider.notifier)
                    .addBusinessEntry(
                      type: type,
                      contactId: contactId,
                      accountId: accountId,
                      total: double.tryParse(total.text) ?? 0,
                      paid: double.tryParse(paid.text) ?? 0,
                      note: note.text,
                    );
                if (context.mounted) Navigator.pop(context);
              } catch (error) {
                if (context.mounted) _error(context, error);
              }
            },
            child: const Text('Save & create invoice'),
          ),
        ],
      ),
    ),
  );
  total.dispose();
  paid.dispose();
  note.dispose();
}

Future<void> _showPaymentDialog(BuildContext context, WidgetRef ref) async {
  final state = ref.read(financeControllerProvider);
  final dueContacts = state.contacts.where((c) => c.balance > 0).toList();
  if (dueContacts.isEmpty) {
    return _notice(context, 'No customer or supplier due found.');
  }
  if (state.accounts.isEmpty) {
    return _notice(context, 'Create an account first.');
  }
  String contactId = dueContacts.first.id;
  String accountId = state.accounts.first.id;
  final amount = TextEditingController();
  await _showManagedDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('Receive / make payment'),
      content: _DialogForm(
        children: [
          DropdownButtonFormField<String>(
            initialValue: contactId,
            decoration: const InputDecoration(labelText: 'Contact with due'),
            items: dueContacts
                .map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      '${c.name} • ${c.type.name} • ${_money(c.balance, state.currentWorkspace?.currency ?? 'BDT')}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => contactId = v!,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: accountId,
            decoration: const InputDecoration(labelText: 'Payment account'),
            items: state.accounts
                .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                .toList(),
            onChanged: (v) => accountId = v!,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await ref
                  .read(financeControllerProvider.notifier)
                  .payContact(
                    contactId,
                    accountId,
                    double.tryParse(amount.text) ?? 0,
                  );
              if (context.mounted) Navigator.pop(context);
            } catch (error) {
              if (context.mounted) _error(context, error);
            }
          },
          child: const Text('Save payment'),
        ),
      ],
    ),
  );
  amount.dispose();
}

Future<void> _showWorkspaceDialog(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final opening = TextEditingController(text: '0');
  WorkspaceType type = WorkspaceType.personal;
  String currencyCode = 'BDT';
  await _showManagedDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        scrollable: true,
        title: const Text('New workspace'),
        content: _DialogForm(
          children: [
            SegmentedButton<WorkspaceType>(
              segments: const [
                ButtonSegment(
                  value: WorkspaceType.personal,
                  label: Text('Personal'),
                ),
                ButtonSegment(
                  value: WorkspaceType.business,
                  label: Text('Business'),
                ),
              ],
              selected: {type},
              onSelectionChanged: (v) => setLocal(() => type = v.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: currencyCode,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Currency'),
              items: AppCurrency.supported
                  .map(
                    (currency) => DropdownMenuItem(
                      value: currency.code,
                      child: Text('${currency.symbol}  ${currency.code}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  setLocal(() => currencyCode = value ?? 'BDT'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: opening,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Opening cash ($currencyCode)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(financeControllerProvider.notifier)
                    .createWorkspace(
                      name: name.text,
                      type: type,
                      openingBalance: double.tryParse(opening.text) ?? 0,
                      currency: currencyCode,
                    );
                if (context.mounted) Navigator.pop(context);
              } catch (error) {
                if (context.mounted) _error(context, error);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  opening.dispose();
}

Future<void> _showAccountDialog(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final opening = TextEditingController(text: '0');
  String type = 'cash';
  await _showManagedDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        scrollable: true,
        title: const Text('Add account'),
        content: _DialogForm(
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Account name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                'cash',
                'bank',
                'card',
                'bKash',
                'Nagad',
                'Rocket',
                'mobile wallet',
                'PayPal',
                'Wise',
                'savings',
                'investment',
                'petty cash',
              ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => type = v!,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: opening,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Opening balance'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(financeControllerProvider.notifier)
                    .addAccount(
                      name.text,
                      type,
                      double.tryParse(opening.text) ?? 0,
                    );
                if (context.mounted) Navigator.pop(context);
              } catch (error) {
                if (context.mounted) _error(context, error);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  opening.dispose();
}

Future<void> _showCategoryDialog(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  TransactionType type = TransactionType.expense;
  await _showManagedDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        scrollable: true,
        title: const Text('Add category'),
        content: _DialogForm(
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Income'),
                ),
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Expense'),
                ),
              ],
              selected: {type},
              onSelectionChanged: (v) => setLocal(() => type = v.first),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(financeControllerProvider.notifier)
                    .addCategory(name.text, type);
                if (context.mounted) Navigator.pop(context);
              } catch (error) {
                if (context.mounted) _error(context, error);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
}

Future<void> _showBudgetDialog(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController(text: 'Monthly budget');
  final limit = TextEditingController();
  await _showManagedDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('Monthly budget'),
      content: _DialogForm(
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Budget name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: limit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Limit (BDT)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await ref
                  .read(financeControllerProvider.notifier)
                  .addBudget(name.text, double.tryParse(limit.text) ?? 0);
              if (context.mounted) Navigator.pop(context);
            } catch (error) {
              if (context.mounted) _error(context, error);
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  name.dispose();
  limit.dispose();
}

Future<void> _showContactDialog(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final phone = TextEditingController();
  ContactType type = ContactType.customer;
  await _showManagedDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        scrollable: true,
        title: const Text('Add customer / supplier'),
        content: _DialogForm(
          children: [
            SegmentedButton<ContactType>(
              segments: const [
                ButtonSegment(
                  value: ContactType.customer,
                  label: Text('Customer'),
                ),
                ButtonSegment(
                  value: ContactType.supplier,
                  label: Text('Supplier'),
                ),
              ],
              selected: {type},
              onSelectionChanged: (v) => setLocal(() => type = v.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await ref
                    .read(financeControllerProvider.notifier)
                    .addContact(name.text, type, phone: phone.text);
                if (context.mounted) Navigator.pop(context);
              } catch (error) {
                if (context.mounted) _error(context, error);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  phone.dispose();
}

Future<void> _showPinDialog(
  BuildContext context,
  WidgetRef ref, {
  required bool pinEnabled,
}) async {
  final pin = TextEditingController();
  await _showManagedDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(pinEnabled ? 'Change app PIN' : 'Set app PIN'),
      content: TextField(
        controller: pin,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(labelText: '4–6 digit PIN'),
      ),
      actions: [
        if (pinEnabled)
          TextButton(
            onPressed: () async {
              try {
                await ref.read(securityServiceProvider).removePin();
                await ref
                    .read(appLockControllerProvider.notifier)
                    .refreshPinStatus();
                if (context.mounted) {
                  Navigator.pop(context);
                  _notice(context, 'App-lock PIN removed.');
                }
              } catch (error) {
                if (context.mounted) _error(context, error);
              }
            },
            child: const Text('Remove PIN'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await ref.read(securityServiceProvider).setPin(pin.text);
              await ref
                  .read(appLockControllerProvider.notifier)
                  .refreshPinStatus();
              if (context.mounted) {
                Navigator.pop(context);
                _notice(context, 'PIN saved securely.');
              }
            } catch (error) {
              if (context.mounted) _error(context, error);
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  pin.dispose();
}

Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
  final confirmed = await _showManagedDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Log out of cloud sync?'),
      content: const Text(
        'This device will stop syncing until you log in again. Your local '
        'data is not affected.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) _notice(context, 'Logged out of cloud sync.');
  }
}

Future<void> _showBackup(BuildContext context, WidgetRef ref) async {
  final passController = TextEditingController();
  final confirmController = TextEditingController();
  var busy = false;
  String? errorText;

  final envelope = await _showManagedDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        scrollable: true,
        title: const Text('Encrypt backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a passphrase to encrypt this backup. If you lose it, '
              'the backup cannot be restored.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Passphrase (min 6 characters)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm passphrase',
              ),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    final pass = passController.text;
                    if (pass.length < 6) {
                      setState(
                        () => errorText =
                            'Passphrase must be at least 6 characters.',
                      );
                      return;
                    }
                    if (pass != confirmController.text) {
                      setState(() => errorText = 'Passphrases do not match.');
                      return;
                    }
                    setState(() {
                      busy = true;
                      errorText = null;
                    });
                    try {
                      final backup = await ref
                          .read(financeControllerProvider.notifier)
                          .exportCurrentWorkspace();
                      final encrypted = await ref
                          .read(backupCryptoServiceProvider)
                          .encryptJson(backup, pass);
                      if (context.mounted) Navigator.pop(context, encrypted);
                    } catch (error) {
                      setState(() {
                        busy = false;
                        errorText = error.toString();
                      });
                    }
                  },
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Text('Encrypt & Continue'),
          ),
        ],
      ),
    ),
  );
  passController.dispose();
  confirmController.dispose();
  if (envelope == null || !context.mounted) return;

  await _showManagedDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Encrypted workspace backup'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Save this somewhere safe. Without the passphrase, it cannot '
                'be restored.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.red),
              ),
              const SizedBox(height: 12),
              SelectableText(
                envelope,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: envelope));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Encrypted backup copied.')),
            );
          },
          child: const Text('Copy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

Future<void> _showRestoreDialog(BuildContext context, WidgetRef ref) async {
  final envelopeController = TextEditingController();
  final passController = TextEditingController();
  var busy = false;
  String? errorText;

  final imported = await _showManagedDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        scrollable: true,
        title: const Text('Restore workspace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: envelopeController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Encrypted backup text',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Passphrase'),
            ),
            if (errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    final envelopeText = envelopeController.text.trim();
                    if (envelopeText.isEmpty || passController.text.isEmpty) {
                      setState(
                        () => errorText =
                            'Paste the backup text and enter its passphrase.',
                      );
                      return;
                    }
                    setState(() {
                      busy = true;
                      errorText = null;
                    });
                    try {
                      final backup = await ref
                          .read(backupCryptoServiceProvider)
                          .decryptJson(envelopeText, passController.text);
                      await ref
                          .read(financeControllerProvider.notifier)
                          .importWorkspaceBackup(backup);
                      if (context.mounted) Navigator.pop(context, true);
                    } catch (error) {
                      setState(() {
                        busy = false;
                        errorText = error.toString();
                      });
                    }
                  },
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Text('Decrypt & Restore'),
          ),
        ],
      ),
    ),
  );
  envelopeController.dispose();
  passController.dispose();
  if (imported == true && context.mounted) {
    _notice(context, 'Workspace restored.');
  }
}

Future<T?> _showManagedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final route = DialogRoute<T>(context: context, builder: builder);
  final result = await Navigator.of(
    context,
    rootNavigator: true,
  ).push<T>(route);
  await route.completed;
  return result;
}

void _notice(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
void _error(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
String _money(double value, [String currency = 'BDT']) =>
    formatMoney(value, currency);
String _title(TransactionType type) => switch (type) {
  TransactionType.income => 'Income',
  TransactionType.expense => 'Expense',
  TransactionType.transfer => 'Transfer',
  TransactionType.adjustment => 'Adjustment',
};
