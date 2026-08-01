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
  int? _refreshGeneration;
  int _sessionGeneration = 0;
  bool _locallySignedOut = false;
  Future<void> _tokenStorageTail = Future<void>.value();

  static const _accessTokenKey = 'oidc.access_token';
  static const _refreshTokenKey = 'oidc.refresh_token';
  static const _idTokenKey = 'oidc.id_token';
  static const _expiresAtKey = 'oidc.expires_at';
  static const _signedOutKey = 'oidc.signed_out';
  static const _scopes = <String>[
    'openid',
    'profile',
    'email',
    'offline_access',
  ];

  @override
  Future<AuthSession?> restore() async {
    final generation = _sessionGeneration;
    final token = await accessToken();
    if (token == null || generation != _sessionGeneration) {
      return null;
    }
    final snapshot = await _readTokenSnapshot();
    return generation != _sessionGeneration || snapshot.expiresAt == null
        ? null
        : AuthSession(expiresAt: snapshot.expiresAt!);
  }

  @override
  Future<AuthSession> signIn() async {
    final generation = ++_sessionGeneration;
    _locallySignedOut = true;
    _refreshInFlight = null;
    _refreshGeneration = null;
    try {
      await _clearTokens(generation: generation);
      if (generation != _sessionGeneration) {
        throw const AuthenticationCancelledFailure();
      }
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
      final stored = await _writeTokens(
        generation: generation,
        accessToken: accessToken,
        refreshToken: response.refreshToken,
        idToken: response.idToken,
        expiresAt: expiresAt,
      );
      if (!stored || generation != _sessionGeneration) {
        throw const AuthenticationCancelledFailure();
      }
      _locallySignedOut = false;
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
    ++_sessionGeneration;
    _locallySignedOut = true;
    _refreshInFlight = null;
    _refreshGeneration = null;
    String? idToken;
    Object? localFailure;
    StackTrace? localFailureStackTrace;
    try {
      await _withTokenStorage(() async {
        Object? operationFailure;
        StackTrace? operationFailureStackTrace;
        try {
          idToken = await _storage.read(key: _idTokenKey);
        } on Object catch (error, stackTrace) {
          operationFailure = error;
          operationFailureStackTrace = stackTrace;
        }
        try {
          await _clearTokensUnlocked();
        } on Object catch (error, stackTrace) {
          operationFailure ??= error;
          operationFailureStackTrace ??= stackTrace;
        }
        if (operationFailure != null) {
          Error.throwWithStackTrace(
            operationFailure,
            operationFailureStackTrace ?? StackTrace.current,
          );
        }
      });
    } on Object catch (error, stackTrace) {
      localFailure = error;
      localFailureStackTrace = stackTrace;
    }
    final tokenForLogout = idToken;
    try {
      if (tokenForLogout != null) {
        await _appAuth.endSession(
          EndSessionRequest(
            idTokenHint: tokenForLogout,
            postLogoutRedirectUrl: _config.postLogoutRedirectUri,
            issuer: _config.oidcIssuer.toString(),
            allowInsecureConnections: !_config.isProduction,
          ),
        );
      }
    } on Object {
      // Local credentials are still removed when provider logout is unavailable.
    }
    if (localFailure != null) {
      Error.throwWithStackTrace(
        localFailure,
        localFailureStackTrace ?? StackTrace.current,
      );
    }
  }

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async {
    if (_locallySignedOut) {
      return null;
    }
    final generation = _sessionGeneration;
    final snapshot = await _readTokenSnapshot();
    if (generation != _sessionGeneration) {
      return null;
    }
    final accessToken = snapshot.accessToken;
    final expiresAt = snapshot.expiresAt;
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
    if (existingRefresh != null && _refreshGeneration == generation) {
      return existingRefresh;
    }
    final future = _refresh(generation);
    _refreshInFlight = future;
    _refreshGeneration = generation;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
        _refreshGeneration = null;
      }
    }
  }

  Future<String?> _refresh(int generation) async {
    final snapshot = await _readTokenSnapshot();
    if (generation != _sessionGeneration) {
      return null;
    }
    final refreshToken = snapshot.refreshToken;
    if (refreshToken == null) {
      await _clearTokens(generation: generation);
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
      if (generation != _sessionGeneration) {
        return null;
      }
      if (accessToken == null || expiresAt == null) {
        await _clearTokens(generation: generation);
        return null;
      }
      final stored = await _writeTokens(
        generation: generation,
        accessToken: accessToken,
        refreshToken: response.refreshToken ?? refreshToken,
        idToken: response.idToken ?? snapshot.idToken,
        expiresAt: expiresAt,
      );
      return stored && generation == _sessionGeneration ? accessToken : null;
    } on Object {
      if (generation == _sessionGeneration) {
        await _clearTokens(generation: generation);
      }
      return null;
    }
  }

  Future<_TokenSnapshot> _readTokenSnapshot() {
    return _withTokenStorage(() async {
      if (await _storage.read(key: _signedOutKey) == 'true') {
        return const _TokenSnapshot.empty();
      }
      final values = await Future.wait([
        _storage.read(key: _accessTokenKey),
        _storage.read(key: _refreshTokenKey),
        _storage.read(key: _idTokenKey),
        _storage.read(key: _expiresAtKey),
      ]);
      return _TokenSnapshot(
        accessToken: values[0],
        refreshToken: values[1],
        idToken: values[2],
        expiresAt: values[3] == null
            ? null
            : DateTime.tryParse(values[3]!)?.toUtc(),
      );
    });
  }

  Future<bool> _writeTokens({
    required int generation,
    required String accessToken,
    required String? refreshToken,
    required String? idToken,
    required DateTime expiresAt,
  }) {
    return _withTokenStorage(() async {
      if (generation != _sessionGeneration) {
        return false;
      }
      try {
        await _storage.write(key: _signedOutKey, value: 'true');
        await Future.wait([
          _storage.write(key: _accessTokenKey, value: accessToken),
          _storage.write(key: _refreshTokenKey, value: refreshToken),
          _storage.write(key: _idTokenKey, value: idToken),
          _storage.write(
            key: _expiresAtKey,
            value: expiresAt.toUtc().toIso8601String(),
          ),
        ]);
        await _storage.delete(key: _signedOutKey);
      } on Object {
        try {
          await _clearTokensUnlocked();
        } on Object {
          // Preserve the original persistence failure. The signed-out marker
          // is written before token mutation whenever secure storage permits.
        }
        rethrow;
      }
      return generation == _sessionGeneration;
    });
  }

  Future<void> _clearTokens({required int generation}) {
    if (generation == _sessionGeneration) {
      _locallySignedOut = true;
    }
    return _withTokenStorage(() async {
      if (generation == _sessionGeneration) {
        await _clearTokensUnlocked();
      }
    });
  }

  Future<void> _clearTokensUnlocked() async {
    Object? failure;
    StackTrace? failureStackTrace;
    try {
      await _storage.write(key: _signedOutKey, value: 'true');
    } on Object catch (error, stackTrace) {
      failure = error;
      failureStackTrace = stackTrace;
    }
    try {
      await Future.wait([
        _storage.delete(key: _accessTokenKey),
        _storage.delete(key: _refreshTokenKey),
        _storage.delete(key: _idTokenKey),
        _storage.delete(key: _expiresAtKey),
      ]);
    } on Object catch (error, stackTrace) {
      failure ??= error;
      failureStackTrace ??= stackTrace;
    }
    if (failure != null) {
      Error.throwWithStackTrace(
        failure,
        failureStackTrace ?? StackTrace.current,
      );
    }
  }

  Future<T> _withTokenStorage<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _tokenStorageTail = _tokenStorageTail.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

final class _TokenSnapshot {
  const _TokenSnapshot({
    required this.accessToken,
    required this.refreshToken,
    required this.idToken,
    required this.expiresAt,
  });

  const _TokenSnapshot.empty()
    : accessToken = null,
      refreshToken = null,
      idToken = null,
      expiresAt = null;

  final String? accessToken;
  final String? refreshToken;
  final String? idToken;
  final DateTime? expiresAt;
}
