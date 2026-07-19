import 'dart:convert';

import 'package:http/http.dart' as http;

import '../features/auth/domain/auth_models.dart';
import 'api_config.dart';
import 'api_exception.dart';

const _accessTokenLifetime = Duration(minutes: 15);

abstract class AuthApiClient {
  Future<AuthResult> register(String email, String password);
  Future<AuthResult> login(String email, String password);
  Future<AuthTokens> refresh(String refreshToken);
  Future<void> logout(String refreshToken);
}

class HttpAuthApiClient implements AuthApiClient {
  HttpAuthApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<AuthResult> register(String email, String password) =>
      _authRequest('/auth/register', email, password);

  @override
  Future<AuthResult> login(String email, String password) =>
      _authRequest('/auth/login', email, password);

  Future<AuthResult> _authRequest(
    String path,
    String email,
    String password,
  ) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = _decode(response);
    final user = body['user'] as Map<String, dynamic>;
    return AuthResult(
      user: AuthUser(id: user['id'] as String, email: user['email'] as String),
      tokens: AuthTokens(
        accessToken: body['accessToken'] as String,
        refreshToken: body['refreshToken'] as String,
        accessExpiresAt: DateTime.now().add(_accessTokenLifetime),
      ),
    );
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/auth/refresh'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    final body = _decode(response);
    return AuthTokens(
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
      accessExpiresAt: DateTime.now().add(_accessTokenLifetime),
    );
  }

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await _client.post(
        Uri.parse('$apiBaseUrl/auth/logout'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
    } catch (_) {
      // Best-effort: local tokens are cleared by the caller regardless.
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body = const {};
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        // fall through to the status-code-based error below
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    final message =
        body['error'] as String? ?? 'Request failed (${response.statusCode}).';
    throw ApiException(message, statusCode: response.statusCode);
  }
}
