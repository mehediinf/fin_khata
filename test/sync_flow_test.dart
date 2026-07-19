import 'package:fin_khata/core/database/app_database.dart';
import 'package:fin_khata/features/auth/presentation/providers/auth_controller.dart';
import 'package:fin_khata/features/finance/data/drift_finance_repository.dart';
import 'package:fin_khata/features/finance/domain/finance_models.dart';
import 'package:fin_khata/features/finance/presentation/providers/finance_controller.dart';
import 'package:fin_khata/services/security_service.dart';
import 'package:fin_khata/services/sync_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase.memory();
    final repository = DriftFinanceRepository(database);
    await repository.initialize();
    await repository.saveWorkspace(
      const Workspace(id: 'ws1', name: 'Personal', type: WorkspaceType.personal),
    );
    await repository.saveAccount(
      const Account(
        id: 'cash',
        workspaceId: 'ws1',
        name: 'Cash',
        type: 'cash',
        openingBalance: 100,
        currentBalance: 100,
      ),
    );
  });

  ProviderContainer buildContainer(_FakeSyncApiClient syncApi) {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        securityServiceProvider.overrideWithValue(_FakeSecurityService()),
        authControllerProvider.overrideWith(_FakeLoggedInAuthController.new),
        syncApiClientProvider.overrideWithValue(syncApi),
      ],
    );
    return container;
  }

  test('syncNow exports, pushes, then pulls and imports — in that order', () async {
    final syncApi = _FakeSyncApiClient();
    final container = buildContainer(syncApi);
    addTearDown(container.dispose);
    container.read(financeControllerProvider);
    await pumpEventQueue();

    final conflict = await container
        .read(financeControllerProvider.notifier)
        .syncNow();

    expect(syncApi.calls, ['push', 'pull']);
    expect(syncApi.lastBaseVersion, 0);
    expect(syncApi.lastPushedSnapshot!['workspaceId'], 'ws1');
    expect(conflict, isFalse);
  });

  test('syncNow surfaces the conflict flag from a stale push', () async {
    final syncApi = _FakeSyncApiClient()..conflictToReturn = true;
    final container = buildContainer(syncApi);
    addTearDown(container.dispose);
    container.read(financeControllerProvider);
    await pumpEventQueue();

    final conflict = await container
        .read(financeControllerProvider.notifier)
        .syncNow();

    expect(conflict, isTrue);
  });

  test('syncNow applies the pulled snapshot to local data', () async {
    final syncApi = _FakeSyncApiClient();
    final container = buildContainer(syncApi);
    addTearDown(container.dispose);
    container.read(financeControllerProvider);
    await pumpEventQueue();

    // The "server" returns a snapshot where the cash account was renamed —
    // simulating a change made from another device.
    syncApi.pulledSnapshotOverride = () {
      final snapshot = Map<String, Object?>.from(syncApi.lastPushedSnapshot!);
      final tables = Map<String, Object?>.from(snapshot['tables']! as Map);
      final accounts = (tables['accounts'] as List)
          .cast<Map>()
          .map(Map<String, Object?>.from)
          .toList();
      accounts.first['name'] = 'Cash (from another device)';
      tables['accounts'] = accounts;
      snapshot['tables'] = tables;
      return snapshot;
    };

    await container.read(financeControllerProvider.notifier).syncNow();

    final state = container.read(financeControllerProvider);
    expect(
      state.accounts.firstWhere((a) => a.id == 'cash').name,
      'Cash (from another device)',
    );
  });

  test('syncNow throws when cloud sync is not logged in', () async {
    final syncApi = _FakeSyncApiClient();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        securityServiceProvider.overrideWithValue(_FakeSecurityService()),
        authControllerProvider.overrideWith(_FakeLoggedOutAuthController.new),
        syncApiClientProvider.overrideWithValue(syncApi),
      ],
    );
    addTearDown(container.dispose);
    container.read(financeControllerProvider);
    await pumpEventQueue();

    expect(
      () => container.read(financeControllerProvider.notifier).syncNow(),
      throwsA(isA<FinanceValidationException>()),
    );
    expect(syncApi.calls, isEmpty);
  });
}

class _FakeLoggedInAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    checking: false,
    loggedIn: true,
    cloudSyncEnabled: true,
    userEmail: 'test@example.com',
  );

  @override
  Future<String?> ensureValidAccessToken() async => 'fake-access-token';
}

class _FakeLoggedOutAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(checking: false);

  @override
  Future<String?> ensureValidAccessToken() async => null;
}

class _FakeSyncApiClient implements SyncApiClient {
  final List<String> calls = [];
  Map<String, Object?>? lastPushedSnapshot;
  int lastBaseVersion = -1;
  bool conflictToReturn = false;
  int versionCounterToReturn = 1;
  Map<String, Object?> Function()? pulledSnapshotOverride;

  @override
  Future<List<WorkspaceSummary>> listWorkspaces(String accessToken) async {
    calls.add('list');
    return const [];
  }

  @override
  Future<PushResult> push(
    String accessToken,
    String workspaceId, {
    required int baseVersion,
    required Map<String, Object?> snapshot,
  }) async {
    calls.add('push');
    lastPushedSnapshot = snapshot;
    lastBaseVersion = baseVersion;
    return PushResult(
      versionCounter: versionCounterToReturn,
      conflict: conflictToReturn,
    );
  }

  @override
  Future<WorkspaceSnapshotResult> pull(
    String accessToken,
    String workspaceId,
  ) async {
    calls.add('pull');
    return WorkspaceSnapshotResult(
      workspaceId: workspaceId,
      versionCounter: versionCounterToReturn,
      snapshot: pulledSnapshotOverride?.call() ?? lastPushedSnapshot!,
    );
  }
}

class _FakeSecurityService extends SecurityService {
  final Map<String, String> _store = {};

  @override
  Future<void> saveSyncBaseVersion(String workspaceId, int version) async {
    _store['sync_base_version_$workspaceId'] = version.toString();
  }

  @override
  Future<int> syncBaseVersion(String workspaceId) async {
    final value = _store['sync_base_version_$workspaceId'];
    return value == null ? 0 : int.tryParse(value) ?? 0;
  }

  @override
  Future<String?> selectedWorkspace() async => null;
}
