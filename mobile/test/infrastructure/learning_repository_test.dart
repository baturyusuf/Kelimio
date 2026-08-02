import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart' as api;
import 'package:kelimio_mobile/domain/failures.dart';
import 'package:kelimio_mobile/domain/learning/learning.dart';
import 'package:kelimio_mobile/infrastructure/network/failure_mapper.dart';
import 'package:kelimio_mobile/infrastructure/repositories/dio_repositories.dart';

import '../support/fixtures.dart';

void main() {
  test('typed submit sends typedAnswer and never selectedOptionId', () async {
    final adapter = _RecordingAdapter([
      _ResponseSpec(200, _answerJson(correctAnswerText: 'server answer')),
    ]);
    final repository = _repository(adapter);

    final feedback = await repository.submitAnswer(
      attemptId: attemptId,
      questionRevisionId: questionRevisionId,
      answer: TypedAnswerInput('private typed answer'),
      submissionId: submissionId,
    );

    final body = jsonDecode(adapter.sentBodies.single) as Map<String, Object?>;
    expect(body['typedAnswer'], 'private typed answer');
    expect(body.containsKey('selectedOptionId'), isFalse);
    expect(body['submissionId'], submissionId);
    expect(body['questionRevisionId'], questionRevisionId);
    expect(feedback.correctAnswerText, 'server answer');
  });

  test('option submit sends selectedOptionId and never typedAnswer', () async {
    final adapter = _RecordingAdapter([
      _ResponseSpec(200, _answerJson(correctOptionId: 'option')),
    ]);
    final repository = _repository(adapter);

    await repository.submitAnswer(
      attemptId: attemptId,
      questionRevisionId: questionRevisionId,
      answer: OptionAnswerInput('option'),
      submissionId: submissionId,
    );

    final body = jsonDecode(adapter.sentBodies.single) as Map<String, Object?>;
    expect(body['selectedOptionId'], 'option');
    expect(body.containsKey('typedAnswer'), isFalse);
  });

  test(
    'typed request body is removed before a network failure escapes',
    () async {
      const raw = 'must not survive in the exception';
      final adapter = _RecordingAdapter(const [], failConnection: true);
      final repository = _repository(adapter);

      Object? thrown;
      try {
        await repository.submitAnswer(
          attemptId: attemptId,
          questionRevisionId: questionRevisionId,
          answer: TypedAnswerInput(raw),
          submissionId: submissionId,
        );
      } on Object catch (error) {
        thrown = error;
      }

      expect(thrown, isA<NetworkFailure>());
      final failure = thrown! as NetworkFailure;
      final dioError = failure.cause! as DioException;
      expect(dioError.requestOptions.data, isNull);
      expect(dioError.response?.requestOptions.data, isNull);
      expect(failure.toString(), isNot(contains(raw)));
    },
  );

  test('typed answer is removed from an echoed provider error', () async {
    const raw = 'provider must not echo this into an exception';
    final adapter = _RecordingAdapter([
      _ResponseSpec(422, jsonEncode({'code': 'INVALID_ANSWER', 'detail': raw})),
    ]);
    final repository = _repository(adapter);

    Object? thrown;
    try {
      await repository.submitAnswer(
        attemptId: attemptId,
        questionRevisionId: questionRevisionId,
        answer: TypedAnswerInput(raw),
        submissionId: submissionId,
      );
    } on Object catch (error) {
      thrown = error;
    }

    expect(thrown, isA<ValidationFailure>());
    final failure = thrown! as ValidationFailure;
    expect(failure.detail, isNull);
    final dioError = failure.cause! as DioException;
    expect(dioError.requestOptions.data, isNull);
    expect(dioError.response?.data, isNull);
    expect(dioError.toString(), isNot(contains(raw)));
  });

  test('HTTP 413 answer rejection maps to validation', () async {
    final adapter = _RecordingAdapter([
      const _ResponseSpec(413, '{"code":"PAYLOAD_TOO_LARGE"}'),
    ]);
    final repository = _repository(adapter);

    await expectLater(
      repository.submitAnswer(
        attemptId: attemptId,
        questionRevisionId: questionRevisionId,
        answer: TypedAnswerInput('private typed answer'),
        submissionId: submissionId,
      ),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('recorded-answer 404 maps to nullable absence', () async {
    final adapter = _RecordingAdapter([
      const _ResponseSpec(404, '{"code":"NOT_FOUND"}'),
    ]);
    final repository = _repository(adapter);

    final feedback = await repository.getRecordedAnswer(
      attemptId: attemptId,
      submissionId: submissionId,
    );

    expect(feedback, isNull);
    expect(adapter.paths, ['/v1/attempts/$attemptId/answers/$submissionId']);
  });
}

GeneratedLearningRepository _repository(_RecordingAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://kelimio.invalid'));
  dio.httpClientAdapter = adapter;
  return GeneratedLearningRepository(
    api.LearningApi(dio),
    const DioFailureMapper(),
  );
}

String _answerJson({String? correctOptionId, String? correctAnswerText}) =>
    jsonEncode({
      'submissionId': submissionId,
      'correct': true,
      'correctOptionId': ?correctOptionId,
      'correctAnswerText': ?correctAnswerText,
      'activeScoreDelta': 60,
      'lifetimeScoreDelta': 60,
      'activeQuestionScore': 60,
      'lifetimeScore': 60,
      'energy': {
        'balance': 5,
        'maximum': 5,
        'unlimited': false,
        'asOf': '2026-01-01T00:00:00.000Z',
      },
      'attemptState': 'IN_PROGRESS',
    });

final class _ResponseSpec {
  const _ResponseSpec(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

final class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(
    List<_ResponseSpec> responses, {
    this.failConnection = false,
  }) : _responses = [...responses];

  final List<_ResponseSpec> _responses;
  final bool failConnection;
  final List<String> sentBodies = [];
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    final data = options.data;
    if (data != null) {
      sentBodies.add(data as String);
    }
    if (failConnection) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'simulated connection failure',
      );
    }
    final response = _responses.removeAt(0);
    return ResponseBody.fromString(
      response.body,
      response.statusCode,
      headers: const {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
