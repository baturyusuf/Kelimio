import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../../domain/auth/auth.dart';
import '../../domain/failures.dart';
import '../../domain/identifiers.dart';
import 'request_metadata.dart';

final class CorrelationInterceptor extends Interceptor {
  CorrelationInterceptor(this._identifiers);

  final IdentifierFactory _identifiers;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.putIfAbsent('X-Request-Id', _identifiers.create);
    handler.next(options);
  }
}

final class IdempotencyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final key = options.extra[RequestMetadata.idempotencyKey];
    if (key is String && key.isNotEmpty) {
      options.headers['Idempotency-Key'] = key;
    }
    handler.next(options);
  }
}

final class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._tokens);

  final Dio _dio;
  final AccessTokenProvider _tokens;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokens.accessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final alreadyRetried = request.extra[RequestMetadata.authRetried] == true;
    if (err.response?.statusCode != 401 || alreadyRetried) {
      handler.next(err);
      return;
    }

    try {
      final token = await _tokens.accessToken(forceRefresh: true);
      if (token == null) {
        handler.next(err);
        return;
      }
      request.extra[RequestMetadata.authRetried] = true;
      request.headers['Authorization'] = 'Bearer $token';
      final response = await _dio.fetch<Object?>(request);
      handler.resolve(response);
    } on Object {
      handler.next(err);
    }
  }
}

final class RedactedLogInterceptor extends Interceptor {
  RedactedLogInterceptor({required this.enabled});

  final bool enabled;
  static final _uuid = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}',
  );

  String _safePath(RequestOptions options) =>
      options.uri.path.replaceAll(_uuid, '{id}');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      developer.log(
        '${options.method} ${_safePath(options)}',
        name: 'kelimio.http',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    if (enabled) {
      final requestId = response.headers.value('x-request-id');
      developer.log(
        '${response.statusCode} ${_safePath(response.requestOptions)} '
        'requestId=${requestId ?? '-'}',
        name: 'kelimio.http',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      final requestId = err.response?.headers.value('x-request-id');
      developer.log(
        'error status=${err.response?.statusCode ?? '-'} '
        '${_safePath(err.requestOptions)} requestId=${requestId ?? '-'}',
        name: 'kelimio.http',
      );
    }
    handler.next(err);
  }
}

final class AnswerKeyLeakGuardInterceptor extends Interceptor {
  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final path = response.requestOptions.uri.path;
    if (isAnswerKeyGuardedAttemptStartPath(path) &&
        containsAnswerKeyLeak(response.data)) {
      handler.reject(
        DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.unknown,
          error: const ProtocolFailure('Attempt payload leaked an answer key'),
        ),
      );
      return;
    }
    handler.next(response);
  }
}

bool isAnswerKeyGuardedAttemptStartPath(String path) =>
    path.startsWith('/v1/tests/') && path.endsWith('/attempts');

bool containsAnswerKeyLeak(Object? data) {
  if (data is! Map<Object?, Object?>) {
    return false;
  }
  return _containsForbiddenAttemptAnswerMaterial(data);
}

bool _containsForbiddenAttemptAnswerMaterial(Object? value) {
  const forbidden = {
    'correct',
    'correctOptionId',
    'correct_option_id',
    'correctAnswer',
    'correct_answer',
    'correctAnswerText',
    'correct_answer_text',
    'answerKey',
    'answer_key',
    'isCorrect',
    'is_correct',
    'typedAnswer',
    'typed_answer',
    'correctMatches',
    'correct_matches',
    'matches',
    'matchingPairs',
    'matching_pairs',
    'pairId',
    'pair_id',
    'targetItemId',
    'target_item_id',
    'supportItemId',
    'support_item_id',
    'correctPairCount',
    'correct_pair_count',
    'matchingAnswerSalt',
    'matching_answer_salt',
    'matchingAnswerDigest',
    'matching_answer_digest',
  };
  final pending = <Object?>[value];
  while (pending.isNotEmpty) {
    final current = pending.removeLast();
    if (current is Map<Object?, Object?>) {
      if (current.keys.any(forbidden.contains)) {
        return true;
      }
      pending.addAll(current.values);
    } else if (current is List<Object?>) {
      pending.addAll(current);
    }
  }
  return false;
}
