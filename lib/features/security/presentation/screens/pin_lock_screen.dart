import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../finance/presentation/providers/finance_controller.dart';
import '../providers/app_lock_controller.dart';

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  final _pin = TextEditingController();
  String? _errorText;
  bool _verifyingPin = false;
  bool _biometricBusy = false;
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareBiometrics());
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _prepareBiometrics() async {
    final canUse = await ref.read(securityServiceProvider).canUseBiometrics;
    if (!mounted) return;
    setState(() => _canUseBiometrics = canUse);
    if (canUse) await _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    if (_biometricBusy) return;
    setState(() => _biometricBusy = true);
    await ref.read(appLockControllerProvider.notifier).unlockWithBiometric();
    if (!mounted) return;
    setState(() => _biometricBusy = false);
  }

  Future<void> _submitPin() async {
    if (_verifyingPin) return;
    final pin = _pin.text.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      setState(
        () => _errorText = _t('PIN must be 4–6 digits', 'PIN ৪–৬ ডিজিট হতে হবে'),
      );
      return;
    }
    setState(() {
      _verifyingPin = true;
      _errorText = null;
    });
    final ok = await ref
        .read(appLockControllerProvider.notifier)
        .unlockWithPin(pin);
    if (!mounted) return;
    setState(() {
      _verifyingPin = false;
      if (!ok) {
        _errorText = _t('Wrong PIN, try again', 'ভুল PIN, আবার চেষ্টা করুন');
        _pin.clear();
      }
    });
  }

  bool _bangla = false;
  String _t(String en, String bn) => _bangla ? bn : en;

  @override
  Widget build(BuildContext context) {
    _bangla = ref.watch(financeControllerProvider.select((s) => s.bangla));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final topColor = isDark ? const Color(0xFF071A14) : const Color(0xFFE7F5EF);
    final bottomColor = isDark
        ? const Color(0xFF0B6B53)
        : const Color(0xFFBCE6D7);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [topColor, bottomColor],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: .28),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 46,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _t('App is locked', 'অ্যাপ লক করা আছে'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        'Enter your PIN to continue',
                        'চালিয়ে যেতে আপনার PIN দিন',
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .68),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _pin,
                        autofocus: true,
                        obscureText: true,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: Theme.of(context).textTheme.headlineSmall,
                        decoration: InputDecoration(
                          counterText: '',
                          errorText: _errorText,
                        ),
                        onChanged: (_) {
                          if (_errorText != null) {
                            setState(() => _errorText = null);
                          }
                        },
                        onSubmitted: (_) => _submitPin(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 220,
                      child: FilledButton(
                        onPressed: _verifyingPin ? null : _submitPin,
                        child: _verifyingPin
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_t('Unlock', 'Unlock')),
                      ),
                    ),
                    if (_canUseBiometrics) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _biometricBusy ? null : _tryBiometric,
                        icon: const Icon(Icons.fingerprint),
                        label: Text(
                          _t(
                            'Use biometric unlock',
                            'Biometric দিয়ে unlock করুন',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
