import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_currencies.dart';
import '../../finance/domain/finance_models.dart';
import '../../finance/presentation/providers/finance_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  WorkspaceType _type = WorkspaceType.personal;
  String _currency = 'BDT';
  final _name = TextEditingController(text: 'Personal');
  final _opening = TextEditingController(text: '0');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bangla = ref.watch(financeControllerProvider).bangla;
    String t(String en, String bn) => bangla ? bn : en;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 620,
                  minHeight: constraints.maxHeight > 48
                      ? constraints.maxHeight - 48
                      : 0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: constraints.maxHeight > 700 ? 56 : 8),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      t(
                        'Your money. One clear place.',
                        'আপনার সব হিসাব, এক জায়গায়।',
                      ),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t(
                        'Manage personal money and small business accounts securely—even when offline.',
                        'ইন্টারনেট ছাড়াও ব্যক্তিগত ও ছোট ব্যবসার হিসাব নিরাপদে পরিচালনা করুন।',
                      ),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 36),
                    if (_step == 0) ...[
                      Text(
                        t('Choose language', 'ভাষা নির্বাচন করুন'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('বাংলা')),
                          ButtonSegment(value: false, label: Text('English')),
                        ],
                        selected: {bangla},
                        onSelectionChanged: (value) => ref
                            .read(financeControllerProvider.notifier)
                            .setBangla(value.first),
                      ),
                    ] else ...[
                      Text(
                        t(
                          'Create your first workspace',
                          'প্রথম workspace তৈরি করুন',
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<WorkspaceType>(
                        segments: [
                          ButtonSegment(
                            value: WorkspaceType.personal,
                            icon: const Icon(Icons.person_outline),
                            label: Text(t('Personal', 'ব্যক্তিগত')),
                          ),
                          ButtonSegment(
                            value: WorkspaceType.business,
                            icon: const Icon(Icons.storefront_outlined),
                            label: Text(t('Business', 'ব্যবসা')),
                          ),
                        ],
                        selected: {_type},
                        onSelectionChanged: (value) => setState(() {
                          _type = value.first;
                          _name.text = _type == WorkspaceType.personal
                              ? 'Personal'
                              : 'My Business';
                        }),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _name,
                        decoration: InputDecoration(
                          labelText: t('Workspace name', 'Workspace-এর নাম'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _currency,
                        decoration: InputDecoration(
                          labelText: t('Currency', 'মুদ্রা'),
                        ),
                        items: AppCurrency.supported
                            .map(
                              (currency) => DropdownMenuItem(
                                value: currency.code,
                                child: Text(
                                  '${currency.symbol}  ${currency.code} — ${currency.name}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _currency = value ?? 'BDT'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _opening,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: t(
                            'Cash opening balance ($_currency)',
                            'Cash-এর প্রারম্ভিক ব্যালেন্স ($_currency)',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        t(
                          'Default account: Cash • Currency: $_currency',
                          'ডিফল্ট account: Cash • মুদ্রা: $_currency',
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : () => _next(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: _saving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _step == 0
                                    ? t('Continue', 'এগিয়ে যান')
                                    : t(
                                        'Start Smart Hisab',
                                        'স্মার্ট হিসাব শুরু করুন',
                                      ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      t(
                        'Local-first • Private • Built for BDT',
                        'Local-first • ব্যক্তিগত • BDT-এর জন্য তৈরি',
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _next(BuildContext context) async {
    if (_step == 0) {
      setState(() => _step = 1);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(financeControllerProvider.notifier)
          .createWorkspace(
            name: _name.text,
            type: _type,
            openingBalance: double.tryParse(_opening.text) ?? 0,
            currency: _currency,
          );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
