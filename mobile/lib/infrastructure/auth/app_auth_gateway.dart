import 'dart:async';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/config/app_config.dart';
import '../../domain/auth/auth.dart';
import '../../domain/failures.dart';

final class AppAuthGateway implements AuthRepository, AccessTokenProvider {
  AppAuthGateway({
    required AppConfig config,
    FlutterAppAuth? appAuth,
    FlutterSecureStorage? storage,
  }) : // The public constructor keeps `config` as its stable API name.
       // ignore: prefer_initializing_formals
       _config = config,
       _appAuth = appAuth ?? const FlutterAppAuth(),
       _storage = storage ?? const FlutterSecureStorage();

  final AppConfig _config;
  final FlutterAppAuth _appAuth;
  final FlutterSecureStorage _storage;
  Future<String?>? _refreshInFlight;

  static const _accessTokenKey = 'oidc.access_token';
  static const _refreshTokenKey = 'oidc.refresh_token';
  static const _idTokenKey = 'oidc.id_token';
  static const _expiresAtKey = 'oidc.expires_at';
  static const _scopes = <String>[
    'openid',
    'profile',
    'email',
    'offline_access',
  ];

  @override
  Future<AuthSession?> restore() async {
    final token = await accessToken();
    if (token == null) {
      return null;
    }
    final expiresAt = await _readExpiry();
    return expiresAt == null ? null : AuthSession(expiresAt: expiresAt);
  }

  @override
  Future<AuthSession> signIn() async {
    try {
      final response = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _config.oidcClientId,
          _config.redirectUri,
          issuer: _config.oidcIssuer.toString(),
          scopes: _scopes,
          allowInsecureConnections: !_config.isProduction,
        ),
      );
      final accessToken = response.accessToken;
      final expiresAt = response.accessTokenExpirationDateTime;
      if (accessToken == null || expiresAt == null) {
        throw const ProtocolFailure(
          'OIDC response did not include an access token',
        );
      }
      await _writeTokens(
        accessToken: accessToken,
        refreshToken: response.refreshToken,
        idToken: response.idToken,
        expiresAt: expiresAt,
      );
      return AuthSession(expiresAt: expiresAt);
    } on FlutterAppAuthUserCancelledException catch (error) {
      throw AuthenticationCancelledFailure(cause: error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw UnknownFailure(cause: error);
    }
  }

  @override
  Future<void> signOut() async {
    final idToken = await _storage.read(key: _idTokenKey);
    try {
      if (idToken != null) {
        await _appAuth.endSession(
          EndSessionRequest(
            idTokenHint: idToken,
            postLogoutRedirectUrl: _config.postLogoutRedirectUri,
            issuer: _config.oidcIssuer.toString(),
            allowInsecureConnections: !_config.isProduction,
          ),
        );
      }
    } on Object {
      // Local credentials are still removed when provider logout is unavailable.
    } finally {
      await _clearTokens();
    }
  }

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final expiresAt = await _readExpiry();
    final isUsable =
        accessToken != null &&
        expiresAt != null &&
        expiresAt.isAfter(
          DateTime.now().toUtc().add(const Duration(seconds: 30)),
        );
    if (!forceRefresh && isUsable) {
      return accessToken;
    }

    final existingRefresh = _refreshInFlight;
    if (existingRefresh != null) {
      return existingRefresh;
    }
    final future = _refresh();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<String?> _refresh() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) {
      await _clearTokens();
      return null;
    }
    try {
      final response = await _appAuth.token(
        TokenRequest(
          _config.oidcClientId,
          _config.redirectUri,
          issuer: _config.oidcIssuer.toString(),
          refreshToken: refreshToken,
          scopes: _scopes,
          allowInsecureConnections: !_config.isProduction,
        ),
      );
      final accessToken = response.accessToken;
      final expiresAt = response.accessTokenExpirationDateTime;
      if (accessToken == null || expiresAt == null) {
        await _clearTokens();
        return null;
      }
      await _writeTokens(
        accessToken: accessToken,
        refreshToken: response.refreshToken ?? refreshToken,
        idToken: response.idToken ?? await _storage.read(key: _idTokenKey),
        expiresAt: expiresAt,
      );
      return accessToken;
    } on Object {
      await _clearTokens();
      return null;
    }
  }

  Future<DateTime?> _readExpiry() async {
    final value = await _storage.read(key: _expiresAtKey);
    return value == null ? null : DateTime.tryParse(value)?.toUtc();
  }

  Future<void> _writeTokens({
    required String accessToken,
    required String? refreshToken,
    required String? idToken,
    required DateTime expiresAt,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
      _storage.write(key: _idTokenKey, value: idToken),
      _storage.write(
        key: _expiresAtKey,
        value: expiresAt.toUtc().toIso8601String(),
      ),
    ]);
  }

  Future<void> _clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _idTokenKey),
      _storage.delete(key: _expiresAtKey),
    ]);
  }
}
