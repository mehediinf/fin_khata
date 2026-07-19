class AuthUser {
  const AuthUser({required this.id, required this.email});

  final String id;
  final String email;
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;

  bool get isExpired => DateTime.now().isAfter(accessExpiresAt);
}

class AuthResult {
  const AuthResult({required this.user, required this.tokens});

  final AuthUser user;
  final AuthTokens tokens;
}
