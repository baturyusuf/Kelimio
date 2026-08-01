import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:kelimio_mobile/domain/auth/auth.dart';

final class LocalKeycloakPkceSession
    implements AuthRepository, AccessTokenProvider {
  LocalKeycloakPkceSession._(
    this._issuer,
    this._clientId,
    this._accessToken,
    this._refreshToken,
    this._idToken,
    this._expiresAt,
  );

  final Uri _issuer;
  final String _clientId;
  String? _accessToken;
  String? _refreshToken;
  String? _idToken;
  DateTime? _expiresAt;
  Future<String?>? _refreshInFlight;
  int _sessionGeneration = 0;
  bool _signedIn = false;

  static Future<LocalKeycloakPkceSession> registerAndAuthorize({
    required Uri issuer,
    required Uri mailpitBaseUri,
    required String clientId,
    required String redirectUri,
    required bool isolatedLocalMode,
  }) async {
    var stage = 'local configuration guard';
    _LocalKeycloakBrowser? browser;
    try {
      _requireIsolatedLocalConfiguration(
        issuer: issuer,
        mailpitBaseUri: mailpitBaseUri,
        clientId: clientId,
        redirectUri: redirectUri,
        isolatedLocalMode: isolatedLocalMode,
      );
      browser = _LocalKeycloakBrowser(issuer);

      final state = _randomBase64Url(24);
      final nonce = _randomBase64Url(24);
      final verifier = _randomBase64Url(32);
      final challenge = base64Url
          .encode(sha256.convert(ascii.encode(verifier)).bytes)
          .replaceAll('=', '');
      final email = 'kelimio-e2e-${_randomHex(10)}@example.invalid';
      final username = 'kelimio-e2e-${_randomHex(10)}';
      final password = 'K!${_randomBase64Url(24)}aA9';

      final authorizationUri = _endpoint(issuer, 'auth').replace(
        queryParameters: {
          'client_id': clientId,
          'redirect_uri': redirectUri,
          'response_type': 'code',
          'scope': 'openid profile email offline_access',
          'state': state,
          'nonce': nonce,
          'code_challenge': challenge,
          'code_challenge_method': 'S256',
        },
      );

      stage = 'authorization start';
      final login = await browser.getFollowing(authorizationUri);
      if (login.callbackUri != null) {
        throw const _SensitiveProtocolFailure();
      }
      final loginDocument = html_parser.parse(login.page.body);
      final registrationHref = loginDocument
          .querySelectorAll('a[href]')
          .map((element) => element.attributes['href'])
          .whereType<String>()
          .where((href) => href.contains('/login-actions/registration'))
          .toSet();
      if (registrationHref.length != 1) {
        throw const _SensitiveProtocolFailure();
      }

      stage = 'public registration form';
      final registration = await browser.getFollowing(
        login.page.uri.resolve(registrationHref.single),
      );
      if (registration.callbackUri != null) {
        throw const _SensitiveProtocolFailure();
      }
      final registrationDocument = html_parser.parse(registration.page.body);
      final registrationForm = registrationDocument.querySelector(
        'form#kc-register-form',
      );
      if (registrationForm == null) {
        throw const _SensitiveProtocolFailure();
      }
      final registrationAction = _formAction(
        registration.page.uri,
        registrationForm,
      );
      final registrationFields = _formFields(registrationForm)
        ..addAll({
          'username': username,
          'email': email,
          'firstName': 'Kelimio',
          'lastName': 'E2E',
          'password': password,
          'password-confirm': password,
        });

      stage = 'registration submission';
      final registered = await browser.postFormFollowing(
        registrationAction,
        registrationFields,
      );
      if (registered.callbackUri != null) {
        // Verification must happen before Keycloak issues an authorization code.
        throw const _SensitiveProtocolFailure();
      }

      stage = 'verification email';
      final verificationUri = await _MailpitClient(
        mailpitBaseUri,
      ).waitForVerificationLink(email: email, keycloakIssuer: issuer);

      stage = 'email verification callback';
      final verified = await browser.getFollowing(verificationUri);
      final callback = verified.callbackUri;
      final expectedCallback = Uri.parse(redirectUri);
      if (callback == null ||
          callback.scheme != expectedCallback.scheme ||
          callback.userInfo != expectedCallback.userInfo ||
          callback.host != expectedCallback.host ||
          callback.port != expectedCallback.port ||
          callback.path != expectedCallback.path ||
          callback.queryParameters['state'] != state ||
          callback.queryParameters.containsKey('error')) {
        throw const _SensitiveProtocolFailure();
      }
      final code = callback.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw const _SensitiveProtocolFailure();
      }

      stage = 'authorization code exchange';
      final tokenResponse = await _postFormJson(_endpoint(issuer, 'token'), {
        'grant_type': 'authorization_code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'code': code,
        'code_verifier': verifier,
      });
      final accessToken = _requiredString(tokenResponse, 'access_token');
      final refreshToken = _requiredString(tokenResponse, 'refresh_token');
      final idToken = _requiredString(tokenResponse, 'id_token');
      final expiresAt = _validateAccessToken(
        accessToken,
        issuer: issuer,
        clientId: clientId,
      );
      _validateIdToken(
        idToken,
        issuer: issuer,
        clientId: clientId,
        nonce: nonce,
      );

      browser.close();
      return LocalKeycloakPkceSession._(
        issuer,
        clientId,
        accessToken,
        refreshToken,
        idToken,
        expiresAt,
      );
    } on LocalOidcE2eFailure {
      browser?.close();
      rethrow;
    } on Object {
      browser?.close();
      throw LocalOidcE2eFailure(stage);
    }
  }

  @override
  Future<AuthSession?> restore() async {
    if (!_signedIn) {
      return null;
    }
    final token = await accessToken();
    final expiresAt = _expiresAt;
    if (token == null || expiresAt == null) {
      return null;
    }
    return AuthSession(expiresAt: expiresAt);
  }

  @override
  Future<AuthSession> signIn() async {
    _signedIn = true;
    final restored = await restore();
    if (restored == null) {
      _signedIn = false;
      throw const LocalOidcE2eFailure('in-memory session restore');
    }
    return restored;
  }

  @override
  Future<void> signOut() async {
    final refreshToken = _refreshToken;
    _signedIn = false;
    ++_sessionGeneration;
    _refreshInFlight = null;
    _clearTokens();
    try {
      if (refreshToken != null) {
        await _postForm(_endpoint(_issuer, 'logout'), {
          'client_id': _clientId,
          'refresh_token': refreshToken,
        });
      }
    } on Object {
      // Match production behavior: local private state is cleared even when
      // the identity provider cannot complete its logout request.
    }
  }

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async {
    if (!_signedIn) {
      return null;
    }
    final generation = _sessionGeneration;
    final token = _accessToken;
    final expiresAt = _expiresAt;
    if (!forceRefresh &&
        token != null &&
        expiresAt != null &&
        expiresAt.isAfter(
          DateTime.now().toUtc().add(const Duration(seconds: 30)),
        )) {
      return token;
    }
    final refreshToken = _refreshToken;
    if (refreshToken == null) {
      _clearTokens();
      return null;
    }
    final existing = _refreshInFlight;
    if (existing != null) {
      return existing;
    }
    final refresh = _refresh(refreshToken, generation);
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<String?> _refresh(String refreshToken, int generation) async {
    try {
      final response = await _postFormJson(_endpoint(_issuer, 'token'), {
        'grant_type': 'refresh_token',
        'client_id': _clientId,
        'refresh_token': refreshToken,
      });
      final accessToken = _requiredString(response, 'access_token');
      final expiresAt = _validateAccessToken(
        accessToken,
        issuer: _issuer,
        clientId: _clientId,
      );
      if (generation != _sessionGeneration) {
        return null;
      }
      _accessToken = accessToken;
      _refreshToken =
          _optionalString(response, 'refresh_token') ?? refreshToken;
      _idToken = _optionalString(response, 'id_token') ?? _idToken;
      _expiresAt = expiresAt;
      return generation == _sessionGeneration ? accessToken : null;
    } on Object {
      if (generation == _sessionGeneration) {
        _clearTokens();
      }
      return null;
    }
  }

  void _clearTokens() {
    _accessToken = null;
    _refreshToken = null;
    _idToken = null;
    _expiresAt = null;
  }
}

final class LocalOidcE2eFailure implements Exception {
  const LocalOidcE2eFailure(this.stage);

  final String stage;

  @override
  String toString() =>
      'Local real-stack OIDC test failed during $stage; sensitive details were suppressed.';
}

final class _SensitiveProtocolFailure implements Exception {
  const _SensitiveProtocolFailure();
}

final class _LocalKeycloakBrowser {
  _LocalKeycloakBrowser(this.issuer) : _client = HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 10);
  }

  final Uri issuer;
  final HttpClient _client;
  final Map<String, Cookie> _cookies = {};

  Future<_Navigation> getFollowing(Uri uri) async {
    _assertAllowed(uri);
    return _follow(await _request(uri));
  }

  Future<_Navigation> postFormFollowing(
    Uri uri,
    Map<String, String> fields,
  ) async {
    _assertAllowed(uri);
    final response = await _request(uri, method: 'POST', fields: fields);
    if (response.statusCode == HttpStatus.temporaryRedirect ||
        response.statusCode == HttpStatus.permanentRedirect) {
      throw const _SensitiveProtocolFailure();
    }
    return _follow(response);
  }

  Future<_Navigation> _follow(_LocalResponse initial) async {
    var response = initial;
    for (var redirects = 0; redirects < 12; redirects += 1) {
      final location = response.location;
      if (!_isRedirect(response.statusCode) || location == null) {
        return _Navigation(page: response);
      }
      final next = response.uri.resolve(location);
      if (next.scheme != 'http' && next.scheme != 'https') {
        return _Navigation(page: response, callbackUri: next);
      }
      _assertAllowed(next);
      response = await _request(next);
    }
    throw const _SensitiveProtocolFailure();
  }

  Future<_LocalResponse> _request(
    Uri uri, {
    String method = 'GET',
    Map<String, String>? fields,
  }) async {
    _assertAllowed(uri);
    final request = method == 'POST'
        ? await _client.postUrl(uri)
        : await _client.getUrl(uri);
    request.followRedirects = false;
    request.headers.set(
      HttpHeaders.acceptHeader,
      'text/html,application/xhtml+xml,application/json',
    );
    for (final cookie in _cookies.values) {
      if (_cookieApplies(cookie, uri)) {
        // Keycloak 26 marks localhost development cookies Secure. Recreating
        // the outgoing cookie deliberately relaxes that flag only inside this
        // exact-host, explicit isolated test browser.
        request.cookies.add(Cookie(cookie.name, cookie.value));
      }
    }
    if (fields != null) {
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.write(_encodeForm(fields));
    }
    final response = await request.close().timeout(const Duration(seconds: 15));
    for (final cookie in response.cookies) {
      final key = '${cookie.name}|${cookie.path ?? ''}';
      final expired =
          cookie.maxAge == 0 ||
          (cookie.expires?.isBefore(DateTime.now()) ?? false);
      if (expired) {
        _cookies.remove(key);
      } else {
        _cookies[key] = cookie;
      }
    }
    final body = await response
        .transform(const Utf8Decoder(allowMalformed: true))
        .join();
    return _LocalResponse(
      uri: uri,
      statusCode: response.statusCode,
      body: body,
      location: response.headers.value(HttpHeaders.locationHeader),
    );
  }

  bool _cookieApplies(Cookie cookie, Uri uri) {
    final path = cookie.path;
    return uri.scheme == 'http' &&
        uri.host == 'localhost' &&
        uri.port == issuer.port &&
        (path == null || uri.path.startsWith(path));
  }

  void _assertAllowed(Uri uri) {
    final withinRealm =
        uri.path == issuer.path || uri.path.startsWith('${issuer.path}/');
    if (uri.scheme != 'http' ||
        uri.host != 'localhost' ||
        uri.port != issuer.port ||
        !withinRealm) {
      throw const _SensitiveProtocolFailure();
    }
  }

  void close() => _client.close(force: true);
}

final class _MailpitClient {
  const _MailpitClient(this.baseUri);

  final Uri baseUri;

  Future<Uri> waitForVerificationLink({
    required String email,
    required Uri keycloakIssuer,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(deadline)) {
        final messages = await _getJson(
          client,
          baseUri.resolve('/api/v1/messages'),
        );
        final values = messages['messages'];
        if (values is List<Object?>) {
          for (final value in values) {
            if (value is! Map<String, Object?> ||
                !_hasRecipient(value, email)) {
              continue;
            }
            final id = value['ID'];
            if (id is! String || id.isEmpty) {
              throw const _SensitiveProtocolFailure();
            }
            final message = await _getJson(
              client,
              baseUri.resolve('/api/v1/message/${Uri.encodeComponent(id)}'),
            );
            final links = _verificationLinks(message);
            if (links.length != 1) {
              throw const _SensitiveProtocolFailure();
            }
            final link = Uri.parse(links.single);
            if (link.scheme != 'http' ||
                link.host != 'localhost' ||
                link.port != keycloakIssuer.port ||
                !link.path.contains('/login-actions/action-token')) {
              throw const _SensitiveProtocolFailure();
            }
            return link;
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      throw const _SensitiveProtocolFailure();
    } finally {
      client.close(force: true);
    }
  }

  bool _hasRecipient(Map<String, Object?> message, String email) {
    final recipients = message['To'];
    if (recipients is! List<Object?>) {
      return false;
    }
    return recipients.whereType<Map<String, Object?>>().any(
      (recipient) =>
          (recipient['Address'] as String?)?.toLowerCase() ==
          email.toLowerCase(),
    );
  }

  Set<String> _verificationLinks(Map<String, Object?> message) {
    final links = <String>{};
    final html = message['HTML'];
    if (html is String && html.isNotEmpty) {
      final document = html_parser.parse(html);
      for (final anchor in document.querySelectorAll('a[href]')) {
        final href = anchor.attributes['href'];
        if (href != null && href.contains('/login-actions/action-token')) {
          links.add(href);
        }
      }
    }
    final text = message['Text'];
    if (text is String && text.isNotEmpty) {
      final urlPattern = RegExp("https?://[^\\s<>\"']+");
      for (final match in urlPattern.allMatches(text)) {
        final value = match.group(0);
        if (value != null && value.contains('/login-actions/action-token')) {
          links.add(value);
        }
      }
    }
    return links;
  }

  Future<Map<String, Object?>> _getJson(HttpClient client, Uri uri) async {
    if (uri.scheme != 'http' ||
        uri.host != 'localhost' ||
        uri.port != baseUri.port) {
      throw const _SensitiveProtocolFailure();
    }
    final request = await client.getUrl(uri);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw const _SensitiveProtocolFailure();
    }
    final decoded = jsonDecode(
      await response.transform(const Utf8Decoder()).join(),
    );
    if (decoded is! Map<String, Object?>) {
      throw const _SensitiveProtocolFailure();
    }
    return decoded;
  }
}

final class _LocalResponse {
  const _LocalResponse({
    required this.uri,
    required this.statusCode,
    required this.body,
    required this.location,
  });

  final Uri uri;
  final int statusCode;
  final String body;
  final String? location;
}

final class _Navigation {
  const _Navigation({required this.page, this.callbackUri});

  final _LocalResponse page;
  final Uri? callbackUri;
}

void _requireIsolatedLocalConfiguration({
  required Uri issuer,
  required Uri mailpitBaseUri,
  required String clientId,
  required String redirectUri,
  required bool isolatedLocalMode,
}) {
  final callback = Uri.tryParse(redirectUri);
  if (!isolatedLocalMode ||
      issuer.scheme != 'http' ||
      issuer.host != 'localhost' ||
      issuer.path != '/realms/kelimio' ||
      mailpitBaseUri.scheme != 'http' ||
      mailpitBaseUri.host != 'localhost' ||
      clientId != 'kelimio-mobile' ||
      callback == null ||
      callback.scheme != 'com.kelimio.app.e2e' ||
      callback.path != '/oauthredirect') {
    throw const LocalOidcE2eFailure('local configuration guard');
  }
}

Uri _endpoint(Uri issuer, String endpoint) => issuer.replace(
  path: '${issuer.path}/protocol/openid-connect/$endpoint',
  query: null,
  fragment: null,
);

Uri _formAction(Uri pageUri, Element form) {
  if ((form.attributes['method'] ?? 'get').toLowerCase() != 'post') {
    throw const _SensitiveProtocolFailure();
  }
  final action = form.attributes['action'];
  if (action == null || action.isEmpty) {
    throw const _SensitiveProtocolFailure();
  }
  return pageUri.resolve(action);
}

Map<String, String> _formFields(Element form) {
  final fields = <String, String>{};
  for (final input in form.querySelectorAll('input[name]')) {
    if (input.attributes.containsKey('disabled')) {
      continue;
    }
    final name = input.attributes['name'];
    if (name == null || name.isEmpty) {
      continue;
    }
    final type = (input.attributes['type'] ?? 'text').toLowerCase();
    if (type == 'submit' || type == 'button' || type == 'file') {
      continue;
    }
    if ((type == 'checkbox' || type == 'radio') &&
        !input.attributes.containsKey('checked')) {
      continue;
    }
    fields[name] = input.attributes['value'] ?? '';
  }
  return fields;
}

Future<Map<String, Object?>> _postFormJson(
  Uri uri,
  Map<String, String> fields,
) async {
  final response = await _postForm(uri, fields);
  if (response.statusCode != HttpStatus.ok) {
    throw const _SensitiveProtocolFailure();
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, Object?>) {
    throw const _SensitiveProtocolFailure();
  }
  return decoded;
}

Future<_LocalResponse> _postForm(Uri uri, Map<String, String> fields) async {
  if (uri.scheme != 'http' || uri.host != 'localhost') {
    throw const _SensitiveProtocolFailure();
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client.postUrl(uri);
    request.followRedirects = false;
    request.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.write(_encodeForm(fields));
    final response = await request.close().timeout(const Duration(seconds: 15));
    final body = await response
        .transform(const Utf8Decoder(allowMalformed: true))
        .join();
    return _LocalResponse(
      uri: uri,
      statusCode: response.statusCode,
      body: body,
      location: response.headers.value(HttpHeaders.locationHeader),
    );
  } finally {
    client.close(force: true);
  }
}

String _encodeForm(Map<String, String> fields) => fields.entries
    .map(
      (entry) =>
          '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
    )
    .join('&');

String _requiredString(Map<String, Object?> values, String key) {
  final value = values[key];
  if (value is! String || value.isEmpty) {
    throw const _SensitiveProtocolFailure();
  }
  return value;
}

String? _optionalString(Map<String, Object?> values, String key) {
  final value = values[key];
  return value is String && value.isNotEmpty ? value : null;
}

DateTime _validateAccessToken(
  String token, {
  required Uri issuer,
  required String clientId,
}) {
  final claims = _jwtClaims(token);
  final audiences = _stringClaimValues(claims['aud']);
  final expiresAt = _expiry(claims);
  if (claims['iss'] != issuer.toString() ||
      !audiences.contains('kelimio-api') ||
      claims['azp'] != clientId ||
      claims['email_verified'] != true ||
      !expiresAt.isAfter(
        DateTime.now().toUtc().add(const Duration(seconds: 30)),
      )) {
    throw const _SensitiveProtocolFailure();
  }
  return expiresAt;
}

void _validateIdToken(
  String token, {
  required Uri issuer,
  required String clientId,
  required String nonce,
}) {
  final claims = _jwtClaims(token);
  final audiences = _stringClaimValues(claims['aud']);
  if (claims['iss'] != issuer.toString() ||
      !audiences.contains(clientId) ||
      claims['nonce'] != nonce ||
      !_expiry(claims).isAfter(DateTime.now().toUtc())) {
    throw const _SensitiveProtocolFailure();
  }
}

Map<String, Object?> _jwtClaims(String token) {
  final segments = token.split('.');
  if (segments.length != 3) {
    throw const _SensitiveProtocolFailure();
  }
  final normalized = base64Url.normalize(segments[1]);
  final decoded = jsonDecode(utf8.decode(base64Url.decode(normalized)));
  if (decoded is! Map<String, Object?>) {
    throw const _SensitiveProtocolFailure();
  }
  return decoded;
}

Set<String> _stringClaimValues(Object? claim) {
  if (claim is String) {
    return {claim};
  }
  if (claim is List<Object?>) {
    return claim.whereType<String>().toSet();
  }
  return const {};
}

DateTime _expiry(Map<String, Object?> claims) {
  final value = claims['exp'];
  if (value is! num) {
    throw const _SensitiveProtocolFailure();
  }
  return DateTime.fromMillisecondsSinceEpoch(
    value.toInt() * Duration.millisecondsPerSecond,
    isUtc: true,
  );
}

String _randomBase64Url(int byteCount) => base64Url
    .encode(List<int>.generate(byteCount, (_) => _secureRandom.nextInt(256)))
    .replaceAll('=', '');

String _randomHex(int byteCount) => List<int>.generate(
  byteCount,
  (_) => _secureRandom.nextInt(256),
).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

final Random _secureRandom = Random.secure();

bool _isRedirect(int statusCode) =>
    statusCode == HttpStatus.movedPermanently ||
    statusCode == HttpStatus.found ||
    statusCode == HttpStatus.seeOther ||
    statusCode == HttpStatus.temporaryRedirect ||
    statusCode == HttpStatus.permanentRedirect;
