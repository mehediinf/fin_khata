import 'package:fin_khata/features/finance/presentation/providers/finance_controller.dart';
import 'package:fin_khata/features/security/presentation/providers/app_lock_controller.dart';
import 'package:fin_khata/features/security/presentation/screens/pin_lock_screen.dart';
import 'package:fin_khata/services/security_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stays unlocked when no PIN is set, and lockNow is a no-op', () async {
    final container = ProviderContainer(
      overrides: [
        securityServiceProvider.overrideWithValue(
          _FakeSecurityService(hasPinValue: false),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(appLockControllerProvider);
    await pumpEventQueue();

    final state = container.read(appLockControllerProvider);
    expect(state.checking, isFalse);
    expect(state.pinEnabled, isFalse);
    expect(state.locked, isFalse);

    container.read(appLockControllerProvider.notifier).lockNow();
    expect(container.read(appLockControllerProvider).locked, isFalse);
  });

  test('locks on launch when a PIN exists, and unlocks with the right PIN', () async {
    final container = ProviderContainer(
      overrides: [
        securityServiceProvider.overrideWithValue(
          _FakeSecurityService(hasPinValue: true, correctPin: '1234'),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(appLockControllerProvider);
    await pumpEventQueue();
    expect(container.read(appLockControllerProvider).locked, isTrue);

    final wrong = await container
        .read(appLockControllerProvider.notifier)
        .unlockWithPin('0000');
    expect(wrong, isFalse);
    expect(container.read(appLockControllerProvider).locked, isTrue);

    final right = await container
        .read(appLockControllerProvider.notifier)
        .unlockWithPin('1234');
    expect(right, isTrue);
    expect(container.read(appLockControllerProvider).locked, isFalse);

    // Backgrounding the app should lock it again.
    container.read(appLockControllerProvider.notifier).lockNow();
    expect(container.read(appLockControllerProvider).locked, isTrue);
  });

  testWidgets('PinLockScreen rejects a wrong PIN and accepts the right one', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeControllerProvider.overrideWith(_FakeFinanceController.new),
          securityServiceProvider.overrideWithValue(
            _FakeSecurityService(hasPinValue: true, correctPin: '1234'),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              final locked = ref.watch(
                appLockControllerProvider.select((s) => s.locked),
              );
              return locked
                  ? const PinLockScreen()
                  : const Scaffold(body: Text('Unlocked home'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('App is locked'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '0000');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong PIN, try again'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('Unlocked home'), findsOneWidget);
    expect(find.text('App is locked'), findsNothing);
  });
}

class _FakeSecurityService extends SecurityService {
  _FakeSecurityService({this.hasPinValue = true, this.correctPin = '1234'});

  final bool hasPinValue;
  final String correctPin;

  @override
  Future<bool> get hasPin async => hasPinValue;

  @override
  Future<bool> verifyPin(String pin) async => pin == correctPin;

  @override
  Future<bool> get canUseBiometrics async => false;

  @override
  Future<bool> authenticateBiometric() async => false;
}

class _FakeFinanceController extends FinanceController {
  @override
  FinanceState build() => const FinanceState(loading: false, bangla: false);
}
