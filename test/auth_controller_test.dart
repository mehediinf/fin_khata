import 'package:fin_khata/features/auth/domain/auth_models.dart';
import 'package:fin_khata/features/auth/presentation/providers/auth_controller.dart';
import 'package:fin_khata/features/finance/presentation/providers/finance_controller.dart';
import 'package:fin_khata/services/api_exception.dart';
import 'package:fin_khata/services/auth_api_client.dart';
import 'package:fin_khata/services/security_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stays logged out when cloud sync was never enabled', () async {
    final container = ProviderContainer(
      overrides: [
        securityServiceProvider.overrideWithValue(_FakeSecurityService()),
        authApiClientProvider.overrideWithValue(_FakeAuthApiClient()),
      ],
    );
    addTearDown(container.dispose);

    container.read(authControllerProvider);
    await pumpEventQueue();

    final state = container.read(authControllerProvider);
    expect(state.checking, isFalse);
    expect(state.loggedIn, isFalse);
    expect(state.needsReauth, isFalse);
    expect(state.cloudSyncEnabled, isFalse);
  });

  test('register logs the user in and persists tokens', () async {
    final security = _FakeSecurityService();
    final container = ProviderContainer(
      overrides: [
        securityServiceProvider.overrideWithValue(security),
        authApiClientProvider.overrideWithValue(_FakeAuthApiClient()),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await pumpEventQueue();

    await container
        .read(authControllerProvider.notifier)
        .register('new@example.com', 'password123');

    final state = container.read(authControllerProvider);
    expect(state.loggedIn, isTrue);
    expect(state.userEmail, 'new@example.com');
    expect(await security.cloudSyncEnabled, isTrue);
    expect(await security.readAccessToken(), isNotNull);
  });

  test('restores an already-logged-in session on next launch', () async {
    final security = _FakeSecurityService();
    await security.saveTokens(
      accessToken: 'stored-access',
      refreshToken: 'stored-refresh',
      accessExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
      email: 'restored@example.com',
    );

    final container = ProviderContainer(
      overrides: [
        securityServiceProvider.overrideWithValue(security),
        authApiClientProvider.overrideWithValue(_FakeAuthApiClient()),
      ],
    );
    addTearDown(container.dispose);

    container.read(authControllerProvider);
    await pumpEventQueue();

    final state = container.read(authControllerProvider);
    expect(state.checking, isFalse);
    expect(state.loggedIn, isTrue);
    expect(state.userEmail, 'restored@example.com');
    expect(state.needsReauth, isFalse);
  });

  test(
    'flags needsReauth when the stored refresh token is dead',
    () async {
      final security = _FakeSecurityService();
      await security.saveTokens(
        accessToken: 'expired-access',
        refreshToken: 'dead-refresh',
        accessExpiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        email: 'stale@example.com',
      );

      final container = ProviderContainer(
        overrides: [
          securityServiceProvider.overrideWithValue(security),
          authApiClientProvider.overrideWithValue(
            _FakeAuthApiClient(rejectRefresh: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(authControllerProvider);
      await pumpEventQueue();

      final state = container.read(authControllerProvider);
      expect(state.checking, isFalse);
      expect(state.loggedIn, isFalse);
      expect(state.needsReauth, isTrue);
      expect(state.cloudSyncEnabled, isTrue);
    },
  );

  test('logout clears session state', () async {
    final security = _FakeSecurityService();
    final container = ProviderContainer(
      overrides: [
        securityServiceProvider.overrideWithValue(security),
        authApiClientProvider.overrideWithValue(_FakeAuthApiClient()),
      ],
    );
    addTearDown(container.dispose);
    container.read(authControllerProvider);
    await pumpEventQueue();

    await container
        .read(authControllerProvider.notifier)
        .login('someone@example.com', 'whatever-password');
    expect(container.read(authControllerProvider).loggedIn, isTrue);

    await container.read(authControllerProvider.notifier).logout();

    final state = container.read(authControllerProvider);
    expect(state.loggedIn, isFalse);
    expect(state.cloudSyncEnabled, isFalse);
    expect(await security.readAccessToken(), isNull);
  });

  test(
    'ensureValidAccessToken transparently refreshes an expiring token',
    () async {
      final security = _FakeSecurityService();
      await security.saveTokens(
        accessToken: 'about-to-expire',
        refreshToken: 'good-refresh',
        accessExpiresAt: DateTime.now().add(const Duration(seconds: 5)),
        email: 'refresh-me@example.com',
      );

      final container = ProviderContainer(
        overrides: [
          securityServiceProvider.overrideWithValue(security),
          authApiClientProvider.overrideWithValue(_FakeAuthApiClient()),
        ],
      );
      addTearDown(container.dispose);
      container.read(authControllerProvider);
      await pumpEventQueue();

      final token = await container
          .read(authControllerProvider.notifier)
          .ensureValidAccessToken();

      expect(token, isNotNull);
      expect(token, isNot('about-to-expire'));
      expect(container.read(authControllerProvider).needsReauth, isFalse);
    },
  );
}

class _FakeAuthApiClient implements AuthApiClient {
  _FakeAuthApiClient({this.rejectRefresh = false});

  final bool rejectRefresh;
  final Map<String, String> _passwords = {};
  int _tokenCounter = 0;

  AuthResult _issue(String email) {
    _tokenCounter++;
    return AuthResult(
      user: AuthUser(id: 'user-$email', email: email),
      tokens: AuthTokens(
        accessToken: 'access-$_tokenCounter',
        refreshToken: 'refresh-$_tokenCounter',
        accessExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
      ),
    );
  }

  @override
  Future<AuthResult> register(String email, String password) async {
    if (_passwords.containsKey(email)) {
      throw const ApiException(
        'An account with this email already exists.',
        statusCode: 409,
      );
    }
    _passwords[email] = password;
    return _issue(email);
  }

  @override
  Future<AuthResult> login(String email, String password) async {
    _passwords.putIfAbsent(email, () => password);
    if (_passwords[email] != password) {
      throw const ApiException('Invalid email or password.', statusCode: 401);
    }
    return _issue(email);
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    if (rejectRefresh) {
      throw const ApiException(
        'Refresh token has expired. Please log in again.',
        statusCode: 401,
      );
    }
    _tokenCounter++;
    return AuthTokens(
      accessToken: 'refreshed-access-$_tokenCounter',
      refreshToken: 'refreshed-refresh-$_tokenCounter',
      accessExpiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );
  }

  @override
  Future<void> logout(String refreshToken) async {}
}

class _FakeSecurityService extends SecurityService {
  final Map<String, String> _store = {};

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime accessExpiresAt,
    required String email,
  }) async {
    _store['auth_access_token'] = accessToken;
    _store['auth_refresh_token'] = refreshToken;
    _store['auth_access_expires_at'] = accessExpiresAt.toIso8601String();
    _store['auth_email'] = email;
    _store['cloud_sync_enabled'] = 'true';
  }

  @override
  Future<String?> readAccessToken() async => _store['auth_access_token'];

  @override
  Future<String?> readRefreshToken() async => _store['auth_refresh_token'];

  @override
  Future<DateTime?> readAccessExpiresAt() async {
    final value = _store['auth_access_expires_at'];
    return value == null ? null : DateTime.tryParse(value);
  }

  @override
  Future<String?> readAuthEmail() async => _store['auth_email'];

  @override
  Future<void> clearTokens() async {
    _store.remove('auth_access_token');
    _store.remove('auth_refresh_token');
    _store.remove('auth_access_expires_at');
    _store.remove('auth_email');
    _store.remove('cloud_sync_enabled');
  }

  @override
  Future<bool> get cloudSyncEnabled async =>
      _store['cloud_sync_enabled'] == 'true';

  @override
  Future<void> saveSyncBaseVersion(String workspaceId, int version) async {
    _store['sync_base_version_$workspaceId'] = version.toString();
  }

  @override
  Future<int> syncBaseVersion(String workspaceId) async {
    final value = _store['sync_base_version_$workspaceId'];
    return value == null ? 0 : int.tryParse(value) ?? 0;
  }
}
