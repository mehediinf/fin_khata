import 'package:fin_khata/features/auth/presentation/providers/auth_controller.dart';
import 'package:fin_khata/features/auth/presentation/screens/auth_screen.dart';
import 'package:fin_khata/features/finance/domain/finance_models.dart';
import 'package:fin_khata/features/finance/presentation/providers/finance_controller.dart';
import 'package:fin_khata/features/finance/presentation/screens/home_shell.dart';
import 'package:fin_khata/features/security/presentation/providers/app_lock_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HomeGate shows AuthScreen only when a cloud-sync session needs reauth', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLockControllerProvider.overrideWith(_UnlockedAppLockController.new),
          authControllerProvider.overrideWith(_NeedsReauthAuthController.new),
          financeControllerProvider.overrideWith(_FakeFinanceController.new),
        ],
        child: const MaterialApp(home: HomeGate()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Sign in again to continue syncing'), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
  });

  testWidgets(
    'HomeGate shows the normal flow unchanged when cloud sync was never enabled',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appLockControllerProvider.overrideWith(
              _UnlockedAppLockController.new,
            ),
            authControllerProvider.overrideWith(_NeverEnabledAuthController.new),
            financeControllerProvider.overrideWith(_FakeFinanceController.new),
          ],
          child: const MaterialApp(home: HomeGate()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsNothing);
      expect(find.byType(HomeShell), findsOneWidget);
    },
  );
}

class _UnlockedAppLockController extends AppLockController {
  @override
  AppLockState build() => const AppLockState(checking: false, locked: false);
}

class _NeedsReauthAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    checking: false,
    needsReauth: true,
    cloudSyncEnabled: true,
  );
}

class _NeverEnabledAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(checking: false);
}

class _FakeFinanceController extends FinanceController {
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
