import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/auth_api_client.dart';
import '../../../../services/security_service.dart';
import '../../../finance/presentation/providers/finance_controller.dart';
import '../../domain/auth_models.dart';

final authApiClientProvider = Provider<AuthApiClient>(
  (ref) => HttpAuthApiClient(),
);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthState {
  const AuthState({
    this.checking = true,
    this.loggedIn = false,
    this.userEmail,
    this.needsReauth = false,
    this.cloudSyncEnabled = false,
  });

  /// True while the initial secure-storage/session read is in flight.
  final bool checking;
  final bool loggedIn;
  final String? userEmail;

  /// True only for a user who previously enabled cloud sync and whose
  /// refresh token has since died (revoked/expired) — never true for a user
  /// who has never touched cloud sync.
  final bool needsReauth;
  final bool cloudSyncEnabled;

  AuthState copyWith({
    bool? checking,
    bool? loggedIn,
    String? userEmail,
    bool clearUserEmail = false,
    bool? needsReauth,
    bool? cloudSyncEnabled,
  }) => AuthState(
    checking: checking ?? this.checking,
    loggedIn: loggedIn ?? this.loggedIn,
    userEmail: clearUserEmail ? null : (userEmail ?? this.userEmail),
    needsReauth: needsReauth ?? this.needsReauth,
    cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
  );
}

class AuthController extends Notifier<AuthState> {
  late AuthApiClient _api;

  @override
  AuthState build() {
    _api = ref.watch(authApiClientProvider);
    Future.microtask(_restoreSession);
    return const AuthState();
  }

  SecurityService get _security => ref.read(securityServiceProvider);

  Future<void> _restoreSession() async {
    final enabled = await _security.cloudSyncEnabled;
    if (!enabled) {
      state = state.copyWith(checking: false, cloudSyncEnabled: false);
      return;
    }

    final email = await _security.readAuthEmail();
    final accessToken = await _security.readAccessToken();
    final expiresAt = await _security.readAccessExpiresAt();
    if (accessToken == null || email == null) {
      state = state.copyWith(
        checking: false,
        cloudSyncEnabled: true,
        needsReauth: true,
      );
      return;
    }

    if (expiresAt != null && DateTime.now().isBefore(expiresAt)) {
      state = state.copyWith(
        checking: false,
        loggedIn: true,
        cloudSyncEnabled: true,
        userEmail: email,
      );
      return;
    }

    final refreshed = await _tryRefresh();
    state = state.copyWith(
      checking: false,
      loggedIn: refreshed,
      cloudSyncEnabled: true,
      needsReauth: !refreshed,
      userEmail: refreshed ? email : null,
      clearUserEmail: !refreshed,
    );
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await _security.readRefreshToken();
    final email = await _security.readAuthEmail();
    if (refreshToken == null || email == null) return false;
    try {
      final tokens = await _api.refresh(refreshToken);
      await _security.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        accessExpiresAt: tokens.accessExpiresAt,
        email: email,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> register(String email, String password) async {
    final result = await _api.register(email, password);
    await _applyLogin(result);
  }

  Future<void> login(String email, String password) async {
    final result = await _api.login(email, password);
    await _applyLogin(result);
  }

  Future<void> _applyLogin(AuthResult result) async {
    await _security.saveTokens(
      accessToken: result.tokens.accessToken,
      refreshToken: result.tokens.refreshToken,
      accessExpiresAt: result.tokens.accessExpiresAt,
      email: result.user.email,
    );
    state = state.copyWith(
      checking: false,
      loggedIn: true,
      cloudSyncEnabled: true,
      needsReauth: false,
      userEmail: result.user.email,
    );
  }

  Future<void> logout() async {
    final refreshToken = await _security.readRefreshToken();
    if (refreshToken != null) {
      await _api.logout(refreshToken);
    }
    await _security.clearTokens();
    state = const AuthState(checking: false);
  }

  /// Returns a valid access token, transparently refreshing it if it's
  /// expired (or close to it). Returns null if cloud sync was never enabled,
  /// or if the refresh token has died — in the latter case [needsReauth] is
  /// set so the UI can prompt the user to log back in.
  Future<String?> ensureValidAccessToken() async {
    final enabled = await _security.cloudSyncEnabled;
    if (!enabled) return null;

    final accessToken = await _security.readAccessToken();
    final expiresAt = await _security.readAccessExpiresAt();
    final stillValid =
        accessToken != null &&
        expiresAt != null &&
        DateTime.now().isBefore(
          expiresAt.subtract(const Duration(seconds: 30)),
        );
    if (stillValid) return accessToken;

    final refreshed = await _tryRefresh();
    if (!refreshed) {
      state = state.copyWith(loggedIn: false, needsReauth: true);
      return null;
    }
    state = state.copyWith(loggedIn: true, needsReauth: false);
    return _security.readAccessToken();
  }
}
