import 'package:fin_khata/features/finance/domain/finance_models.dart';
import 'package:fin_khata/features/finance/presentation/providers/finance_controller.dart';
import 'package:fin_khata/features/finance/presentation/screens/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('workspace dialog scrolls when the keyboard is visible', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(1080, 1920);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeControllerProvider.overrideWith(_HomeFinanceController.new),
        ],
        child: const MaterialApp(home: HomeShell()),
      ),
    );

    await tester.tap(find.byTooltip('Workspace'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).first);
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    await tester.pump();

    expect(find.text('New workspace'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

class _HomeFinanceController extends FinanceController {
  @override
  FinanceState build() => const FinanceState(
    loading: false,
    bangla: false,
    workspaces: [
      Workspace(id: 'personal', name: 'Personal', type: WorkspaceType.personal),
    ],
    currentWorkspace: Workspace(
      id: 'personal',
      name: 'Personal',
      type: WorkspaceType.personal,
    ),
  );
}
