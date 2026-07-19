import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  SecurityService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuthentication,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _localAuthentication = localAuthentication ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuthentication;

  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      throw const FormatException('PIN must contain 4 to 6 digits.');
    }
    final salt = DateTime.now().microsecondsSinceEpoch.toString();
    final digest = sha256.convert(utf8.encode('$salt:$pin')).toString();
    await _storage.write(key: 'pin_salt', value: salt);
    await _storage.write(key: 'pin_hash', value: digest);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: 'pin_salt');
    final expected = await _storage.read(key: 'pin_hash');
    if (salt == null || expected == null) return false;
    return sha256.convert(utf8.encode('$salt:$pin')).toString() == expected;
  }

  Future<bool> get hasPin async =>
      (await _storage.read(key: 'pin_hash')) != null;

  Future<void> removePin() async {
    await _storage.delete(key: 'pin_salt');
    await _storage.delete(key: 'pin_hash');
  }

  Future<bool> authenticateBiometric() async {
    try {
      if (!await _localAuthentication.isDeviceSupported()) return false;
      return _localAuthentication.authenticate(
        localizedReason: 'Unlock Smart Hisab',
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> get canUseBiometrics async {
    try {
      if (!await _localAuthentication.isDeviceSupported()) return false;
      final available = await _localAuthentication.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveSelectedWorkspace(String id) =>
      _storage.write(key: 'selected_workspace', value: id);

  Future<String?> selectedWorkspace() =>
      _storage.read(key: 'selected_workspace');

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime accessExpiresAt,
    required String email,
  }) async {
    await _storage.write(key: 'auth_access_token', value: accessToken);
    await _storage.write(key: 'auth_refresh_token', value: refreshToken);
    await _storage.write(
      key: 'auth_access_expires_at',
      value: accessExpiresAt.toIso8601String(),
    );
    await _storage.write(key: 'auth_email', value: email);
    await _storage.write(key: 'cloud_sync_enabled', value: 'true');
  }

  Future<String?> readAccessToken() => _storage.read(key: 'auth_access_token');

  Future<String?> readRefreshToken() =>
      _storage.read(key: 'auth_refresh_token');

  Future<DateTime?> readAccessExpiresAt() async {
    final value = await _storage.read(key: 'auth_access_expires_at');
    return value == null ? null : DateTime.tryParse(value);
  }

  Future<String?> readAuthEmail() => _storage.read(key: 'auth_email');

  Future<void> clearTokens() async {
    await _storage.delete(key: 'auth_access_token');
    await _storage.delete(key: 'auth_refresh_token');
    await _storage.delete(key: 'auth_access_expires_at');
    await _storage.delete(key: 'auth_email');
    await _storage.delete(key: 'cloud_sync_enabled');
  }

  Future<bool> get cloudSyncEnabled async =>
      (await _storage.read(key: 'cloud_sync_enabled')) == 'true';

  Future<void> saveSyncBaseVersion(String workspaceId, int version) =>
      _storage.write(
        key: 'sync_base_version_$workspaceId',
        value: version.toString(),
      );

  Future<int> syncBaseVersion(String workspaceId) async {
    final value = await _storage.read(key: 'sync_base_version_$workspaceId');
    return value == null ? 0 : int.tryParse(value) ?? 0;
  }
}
