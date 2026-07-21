final class AuthSession {
  const AuthSession({required this.expiresAt});

  final DateTime expiresAt;
}

abstract interface class AuthRepository {
  Future<AuthSession?> restore();

  Future<AuthSession> signIn();

  Future<void> signOut();
}

abstract interface class AccessTokenProvider {
  Future<String?> accessToken({bool forceRefresh = false});
}
