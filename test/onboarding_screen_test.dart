import 'package:fin_khata/features/finance/presentation/providers/finance_controller.dart';
import 'package:fin_khata/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('onboarding remains scrollable when the keyboard is visible', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeControllerProvider.overrideWith(_TestFinanceController.new),
        ],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );

    await tester.tap(find.text('এগিয়ে যান'));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _TestFinanceController extends FinanceController {
  @override
  FinanceState build() => const FinanceState(loading: false, bangla: true);
}
