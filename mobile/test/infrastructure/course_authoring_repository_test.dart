import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart' as api;
import 'package:kelimio_mobile/domain/course_authoring/course_authoring.dart';
import 'package:kelimio_mobile/domain/failures.dart';
import 'package:kelimio_mobile/infrastructure/network/failure_mapper.dart';
import 'package:kelimio_mobile/infrastructure/repositories/course_authoring_repository.dart';

void main() {
  test(
    'uploads exact checksum-bound bytes without bearer authorization',
    () async {
      final bytes = utf8.encode('small deterministic xlsx test bytes');
      final digest = sha256.convert(bytes);
      final sourceHex = digest.toString();
      final partBase64 = base64Encode(digest.bytes);
      final apiAdapter = _QueueAdapter([
        _ResponseSpec(
          201,
          jsonEncode({
            'created': true,
            'import': _statusJson(bytes.length, status: 'UPLOADING'),
            'upload': {
              'expiresAt': '2030-01-01T00:00:00.000Z',
              'parts': [
                {
                  'partNumber': 1,
                  'sizeBytes': bytes.length,
                  'url': 'https://upload.invalid/part?signature=not-logged',
                  'requiredHeaders': {
                    'contentLength': bytes.length.toString(),
                    'sha256': partBase64,
                  },
                },
              ],
            },
          }),
        ),
        _ResponseSpec(
          200,
          jsonEncode(_statusJson(bytes.length, status: 'QUEUED')),
        ),
      ]);
      final uploadAdapter = _UploadAdapter();
      final repository = _repository(apiAdapter, uploadAdapter);
      final progress = <(int, int)>[];

      final summary = await repository.uploadWorkbook(
        workbook: _workbook(bytes),
        createCommandId: '00000000-0000-4000-8000-000000000001',
        completeCommandId: '00000000-0000-4000-8000-000000000002',
        onProgress: (sent, total) => progress.add((sent, total)),
      );

      expect(summary.status, CourseImportStatus.queued);
      expect(uploadAdapter.uploadedBytes, bytes);
      expect(
        uploadAdapter.request!.headers['x-amz-checksum-sha256'],
        partBase64,
      );
      expect(
        uploadAdapter.request!.headers.keys.map((value) => value.toLowerCase()),
        isNot(contains('authorization')),
      );
      final createBody =
          jsonDecode(apiAdapter.sentBodies[0]) as Map<String, dynamic>;
      expect(createBody['sourceSha256'], sourceHex);
      expect(createBody['parts'], [
        {'partNumber': 1, 'sizeBytes': bytes.length, 'sha256': partBase64},
      ]);
      final completionBody =
          jsonDecode(apiAdapter.sentBodies[1]) as Map<String, dynamic>;
      expect(completionBody['parts'], [
        {'partNumber': 1, 'eTag': '"opaque-etag"', 'sha256': partBase64},
      ]);
      expect(progress.last, (bytes.length, bytes.length));
    },
  );

  test('rejects a server upload plan that differs from local bytes', () async {
    final bytes = utf8.encode('workbook bytes');
    final digest = sha256.convert(bytes);
    final apiAdapter = _QueueAdapter([
      _ResponseSpec(
        201,
        jsonEncode({
          'created': true,
          'import': _statusJson(bytes.length, status: 'UPLOADING'),
          'upload': {
            'expiresAt': '2030-01-01T00:00:00.000Z',
            'parts': [
              {
                'partNumber': 1,
                'sizeBytes': bytes.length,
                'url': 'https://upload.invalid/part',
                'requiredHeaders': {
                  'contentLength': bytes.length.toString(),
                  'sha256': base64Encode(List<int>.filled(32, 9)),
                },
              },
            ],
          },
        }),
      ),
    ]);
    final uploadAdapter = _UploadAdapter();
    final repository = _repository(apiAdapter, uploadAdapter);

    await expectLater(
      repository.uploadWorkbook(
        workbook: _workbook(bytes),
        createCommandId: '00000000-0000-4000-8000-000000000011',
        completeCommandId: '00000000-0000-4000-8000-000000000012',
        onProgress: (sent, total) {},
      ),
      throwsA(isA<ProtocolFailure>()),
    );
    expect(uploadAdapter.request, isNull);
    expect(digest.toString(), hasLength(64));

    final invalidUrlApi = _QueueAdapter([
      _ResponseSpec(
        201,
        jsonEncode({
          'created': true,
          'import': _statusJson(bytes.length, status: 'UPLOADING'),
          'upload': {
            'expiresAt': '2030-01-01T00:00:00.000Z',
            'parts': [
              {
                'partNumber': 1,
                'sizeBytes': bytes.length,
                'url': 'file:///private/workbook',
                'requiredHeaders': {
                  'contentLength': bytes.length.toString(),
                  'sha256': base64Encode(digest.bytes),
                },
              },
            ],
          },
        }),
      ),
    ]);
    final invalidUrlUpload = _UploadAdapter();
    await expectLater(
      _repository(invalidUrlApi, invalidUrlUpload).uploadWorkbook(
        workbook: _workbook(bytes),
        createCommandId: '00000000-0000-4000-8000-000000000013',
        completeCommandId: '00000000-0000-4000-8000-000000000014',
        onProgress: (sent, total) {},
      ),
      throwsA(isA<ProtocolFailure>()),
    );
    expect(invalidUrlUpload.request, isNull);
  });

  test(
    'redacts workbook command data and authorization on API failure',
    () async {
      final bytes = utf8.encode('private workbook bytes');
      final apiAdapter = _QueueAdapter(const [], failConnection: true);
      final uploadAdapter = _UploadAdapter();
      final repository = _repository(apiAdapter, uploadAdapter);

      Object? thrown;
      try {
        await repository.uploadWorkbook(
          workbook: _workbook(bytes, name: 'private-course-name.xlsx'),
          createCommandId: '00000000-0000-4000-8000-000000000021',
          completeCommandId: '00000000-0000-4000-8000-000000000022',
          onProgress: (sent, total) {},
        );
      } on Object catch (error) {
        thrown = error;
      }

      expect(thrown, isA<NetworkFailure>());
      final cause = (thrown! as NetworkFailure).cause! as DioException;
      expect(cause.requestOptions.data, isNull);
      expect(
        cause.requestOptions.headers.keys.map((value) => value.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(cause.toString(), isNot(contains('private-course-name')));
    },
  );

  test(
    'discovers owner imports through the authenticated API contract',
    () async {
      final apiAdapter = _QueueAdapter([
        _ResponseSpec(
          200,
          jsonEncode({
            'items': [
              _statusJson(128, status: 'COMMITTED')
                ..['commit'] = {
                  'courseId': '00000000-0000-4000-8000-000000000200',
                  'contentChangeSetId': '00000000-0000-4000-8000-000000000250',
                  'draftReleaseId': '00000000-0000-4000-8000-000000000300',
                  'sourceRowCount': 23,
                  'questionCount': 14,
                  'matchingQuestionCount': 3,
                  'requiredClientCapabilities': ['question.matching.v1'],
                  'committedAt': '2026-08-02T09:00:00.000Z',
                }
                ..['activation'] = {
                  'releaseId': '00000000-0000-4000-8000-000000000300',
                  'operation': 'INITIAL_PUBLICATION',
                  'activatedAt': '2026-08-02T09:01:00.000Z',
                  'reprojectionStatus': 'PENDING',
                },
            ],
            'nextCursor': 'opaque-owner-bound-cursor',
          }),
        ),
      ]);
      final repository = _repository(apiAdapter, _UploadAdapter());

      final page = await repository.listImports();

      expect(page.items, hasLength(1));
      expect(
        page.items.single.activation?.releaseId,
        '00000000-0000-4000-8000-000000000300',
      );
      expect(page.nextCursor, 'opaque-owner-bound-cursor');
      expect(apiAdapter.requests.single.path, '/v1/courses/imports');
      expect(apiAdapter.requests.single.queryParameters['limit'], 20);
    },
  );
}

GeneratedCourseAuthoringRepository _repository(
  _QueueAdapter apiAdapter,
  _UploadAdapter uploadAdapter,
) {
  final apiDio = Dio(BaseOptions(baseUrl: 'https://kelimio.invalid'));
  apiDio.httpClientAdapter = apiAdapter;
  final uploadDio = Dio();
  uploadDio.httpClientAdapter = uploadAdapter;
  return GeneratedCourseAuthoringRepository(
    api.CourseImportApi(apiDio),
    api.CourseReleaseApi(apiDio),
    api.DevelopmentApi(apiDio),
    const DioFailureMapper(),
    uploadClient: uploadDio,
  );
}

SelectedWorkbook _workbook(List<int> bytes, {String name = 'course.xlsx'}) =>
    SelectedWorkbook(
      displayName: name,
      sizeBytes: bytes.length,
      readRange: (start, endExclusive) =>
          Stream.value(bytes.sublist(start, endExclusive)),
    );

Map<String, Object?> _statusJson(int size, {required String status}) => {
  'id': '00000000-0000-4000-8000-000000000100',
  'status': status,
  'originalFileName': 'course.xlsx',
  'declaredMediaType': workbookMediaType,
  'fileSizeBytes': size,
  'rulesVersion': 'xlsx-v2',
  'processingAttempts': 0,
  'createdAt': '2026-01-01T00:00:00.000Z',
  'updatedAt': '2026-01-01T00:00:00.000Z',
  'uploadExpiresAt': '2030-01-01T00:00:00.000Z',
  'preview': null,
  'approvalBindingSha256': null,
  'approvedAt': null,
  'commit': null,
  'activation': null,
  'failureCode': null,
};

final class _ResponseSpec {
  const _ResponseSpec(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

final class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(List<_ResponseSpec> responses, {this.failConnection = false})
    : _responses = [...responses];

  final List<_ResponseSpec> _responses;
  final bool failConnection;
  final List<String> sentBodies = [];
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.data case final String body) {
      sentBodies.add(body);
    }
    if (failConnection) {
      options.headers['Authorization'] = 'Bearer must-be-redacted';
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
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

final class _UploadAdapter implements HttpClientAdapter {
  RequestOptions? request;
  List<int> uploadedBytes = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    final builder = BytesBuilder(copy: false);
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        builder.add(chunk);
      }
    }
    uploadedBytes = builder.takeBytes();
    return ResponseBody.fromString(
      '',
      200,
      headers: const {
        'etag': ['"opaque-etag"'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
