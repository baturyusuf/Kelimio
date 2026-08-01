import 'dart:async';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/core/config/app_config.dart';
import 'package:kelimio_mobile/domain/failures.dart';
import 'package:kelimio_mobile/infrastructure/auth/app_auth_gateway.dart';

void main() {
  test('stale refresh cannot resurrect or overwrite a newer session', () async {
    final storage = _ControlledTokenStorage({
      'oidc.access_token': 'old-access',
      'oidc.refresh_token': 'old-refresh',
      'oidc.id_token': 'old-id',
      'oidc.expires_at': DateTime.utc(2020).toIso8601String(),
    })..blockWrites();
    final appAuth = _ControlledAppAuth();
    final gateway = AppAuthGateway(
      config: _config,
      appAuth: appAuth,
      storage: storage,
    );

    final staleRefresh = gateway.accessToken(forceRefresh: true);
    await appAuth.refreshRequested.future;
    appAuth.refreshResponse.complete(
      TokenResponse(
        'stale-refreshed-access',
        'stale-refreshed-refresh',
        DateTime.utc(2031),
        'stale-refreshed-id',
        'Bearer',
        const ['openid'],
        null,
      ),
    );
    await storage.writesStarted.future;

    final signOut = gateway.signOut();
    final signIn = gateway.signIn();
    storage.releaseWrites();

    expect(await staleRefresh, isNull);
    await signOut;
    await signIn;
    expect(storage.values['oidc.access_token'], 'new-access');
    expect(storage.values['oidc.refresh_token'], 'new-refresh');
    expect(storage.values['oidc.id_token'], 'new-id');
    expect(
      storage.values['oidc.expires_at'],
      DateTime.utc(2032).toIso8601String(),
    );
  });

  test('failed token persistence clears every partial credential', () async {
    final storage = _ControlledTokenStorage({})
      ..failNextWriteFor('oidc.refresh_token');
    final gateway = AppAuthGateway(
      config: _config,
      appAuth: _ControlledAppAuth(),
      storage: storage,
    );

    await expectLater(gateway.signIn(), throwsA(isA<UnknownFailure>()));

    _expectSignedOutStorage(storage);
  });

  test('starting sign in clears any credential snapshot first', () async {
    final storage = _ControlledTokenStorage({
      'oidc.access_token': 'prior-access',
      'oidc.refresh_token': 'prior-refresh',
      'oidc.id_token': 'prior-id',
      'oidc.expires_at': DateTime.utc(2030).toIso8601String(),
    });
    final appAuth = _PendingAuthorizationAppAuth();
    final gateway = AppAuthGateway(
      config: _config,
      appAuth: appAuth,
      storage: storage,
    );

    final signIn = gateway.signIn();
    await appAuth.authorizationRequested.future;
    _expectSignedOutStorage(storage);
    appAuth.authorizationResponse.completeError(
      StateError('simulated cancelled authorization'),
    );

    await expectLater(signIn, throwsA(isA<UnknownFailure>()));
    expect(await gateway.restore(), isNull);
  });

  test('sign out still clears credentials when id-token read fails', () async {
    final storage = _ControlledTokenStorage({
      'oidc.access_token': 'prior-access',
      'oidc.refresh_token': 'prior-refresh',
      'oidc.id_token': 'prior-id',
      'oidc.expires_at': DateTime.utc(2030).toIso8601String(),
    })..failNextReadFor('oidc.id_token');
    final gateway = AppAuthGateway(
      config: _config,
      appAuth: _ControlledAppAuth(),
      storage: storage,
    );

    await expectLater(gateway.signOut(), throwsStateError);

    _expectSignedOutStorage(storage);
  });

  test('sign out reaches the provider when one token deletion fails', () async {
    final storage = _ControlledTokenStorage({
      'oidc.access_token': 'prior-access',
      'oidc.refresh_token': 'prior-refresh',
      'oidc.id_token': 'prior-id',
      'oidc.expires_at': DateTime.utc(2030).toIso8601String(),
    })..failNextDeleteFor('oidc.refresh_token');
    final appAuth = _ControlledAppAuth();
    final gateway = AppAuthGateway(
      config: _config,
      appAuth: appAuth,
      storage: storage,
    );

    await expectLater(gateway.signOut(), throwsStateError);

    expect(appAuth.endSessionCalls, 1);
    expect(storage.values['oidc.signed_out'], 'true');
    final restartedGateway = AppAuthGateway(
      config: _config,
      appAuth: _ControlledAppAuth(),
      storage: storage,
    );
    expect(await restartedGateway.restore(), isNull);
  });
}

void _expectSignedOutStorage(_ControlledTokenStorage storage) {
  expect(storage.values['oidc.access_token'], isNull);
  expect(storage.values['oidc.refresh_token'], isNull);
  expect(storage.values['oidc.id_token'], isNull);
  expect(storage.values['oidc.expires_at'], isNull);
  expect(storage.values['oidc.signed_out'], 'true');
}

final _config = AppConfig(
  apiBaseUri: Uri.parse('http://localhost:8080'),
  oidcIssuer: Uri.parse('http://localhost:8081/realms/kelimio'),
  oidcClientId: 'kelimio-mobile',
  redirectUri: 'com.kelimio.app:/oauthredirect',
  postLogoutRedirectUri: 'com.kelimio.app:/logout',
  isProduction: false,
  localDevelopmentToolsEnabled: false,
);

final class _ControlledAppAuth extends FlutterAppAuth {
  final refreshRequested = Completer<void>();
  final refreshResponse = Completer<TokenResponse>();
  int endSessionCalls = 0;

  @override
  Future<AuthorizationTokenResponse> authorizeAndExchangeCode(
    AuthorizationTokenRequest request,
  ) async {
    return AuthorizationTokenResponse(
      'new-access',
      'new-refresh',
      DateTime.utc(2032),
      'new-id',
      'Bearer',
      const ['openid'],
      null,
      null,
    );
  }

  @override
  Future<TokenResponse> token(TokenRequest request) {
    if (!refreshRequested.isCompleted) {
      refreshRequested.complete();
    }
    return refreshResponse.future;
  }

  @override
  Future<EndSessionResponse> endSession(EndSessionRequest request) async {
    endSessionCalls += 1;
    return EndSessionResponse(null);
  }
}

final class _PendingAuthorizationAppAuth extends FlutterAppAuth {
  final authorizationRequested = Completer<void>();
  final authorizationResponse = Completer<AuthorizationTokenResponse>();

  @override
  Future<AuthorizationTokenResponse> authorizeAndExchangeCode(
    AuthorizationTokenRequest request,
  ) {
    authorizationRequested.complete();
    return authorizationResponse.future;
  }
}

final class _ControlledTokenStorage extends FlutterSecureStorage {
  _ControlledTokenStorage(Map<String, String> initial) : values = {...initial};

  final Map<String, String> values;
  final Completer<void> writesStarted = Completer<void>();
  Completer<void>? _writeGate;
  String? _failingWriteKey;
  String? _failingReadKey;
  String? _failingDeleteKey;

  void blockWrites() => _writeGate = Completer<void>();

  void releaseWrites() => _writeGate?.complete();

  void failNextWriteFor(String key) => _failingWriteKey = key;

  void failNextReadFor(String key) => _failingReadKey = key;

  void failNextDeleteFor(String key) => _failingDeleteKey = key;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (_failingReadKey == key) {
      _failingReadKey = null;
      throw StateError('simulated secure-storage read failure');
    }
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (!writesStarted.isCompleted) {
      writesStarted.complete();
    }
    await _writeGate?.future;
    if (_failingWriteKey == key) {
      _failingWriteKey = null;
      throw StateError('simulated secure-storage write failure');
    }
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (_failingDeleteKey == key) {
      _failingDeleteKey = null;
      throw StateError('simulated secure-storage delete failure');
    }
    values.remove(key);
  }
}
