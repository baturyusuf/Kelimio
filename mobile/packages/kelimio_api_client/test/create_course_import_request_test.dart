import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

// tests for CreateCourseImportRequest
void main() {
  final CreateCourseImportRequest?
  instance = /* CreateCourseImportRequest(...) */ null;
  // TODO add properties to the entity

  group(CreateCourseImportRequest, () {
    // String originalFileName
    test('to test the property `originalFileName`', () async {
      // TODO
    });

    // String declaredMediaType
    test('to test the property `declaredMediaType`', () async {
      // TODO
    });

    // int fileSizeBytes
    test('to test the property `fileSizeBytes`', () async {
      // TODO
    });

    // String sourceSha256
    test('to test the property `sourceSha256`', () async {
      // TODO
    });

    // List<CourseImportPartDeclaration> parts
    test('to test the property `parts`', () async {
      // TODO
    });

    test(
      'redacts import artifacts, content, cursors, and provenance from toString',
      () {
        const partSha = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
        const sourceSha =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        const approvalSha =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        const reportSha =
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
        const uploadUrl =
            'http://storage.invalid/private-upload?secret=never-log';
        const cursor = 'owner-import-preview-position.secret-signature';
        final source = {
          'sheetOrdinal': 0,
          'sheetName': 'SECRET_SHEET',
          'rowNumber': 2,
          'columnNumber': 1,
          'reference': 'SECRET_REF',
        };
        final settings = {
          'courseName': 'SECRET_COURSE',
          'targetLanguageCode': 'tr',
          'targetLanguageName': 'SECRET_LANGUAGE',
          'supportLanguageCodes': ['en', 'ar', 'fr'],
          'defaultSupportLanguageCode': 'en',
          'defaultTestMode': 'MIXED',
          'visibility': 'PRIVATE',
          'targetTestSize': 20,
          'minimumLastAutomaticTestSize': 10,
          'fillFixedTests': true,
          'completionThresholdPercent': 50,
          'pricingSource': 'APPLICATION',
          'maximumTypedAlternativeAnswers': 1,
          'offlineMode': 'SCORELESS_PRACTICE',
        };
        final summary = {
          'isValid': true,
          'rowCount': 1,
          'questionCount': 1,
          'matchingQuestionCount': 0,
          'requiredClientCapabilities': <String>[],
          'levelCount': 1,
          'unitCount': 1,
          'topicCount': 1,
          'testCount': 1,
          'warningCount': 0,
          'errorCount': 0,
          'validationReportSha256': reportSha,
          'allocationSha256': sourceSha,
          'previewSha256': approvalSha,
          'settings': settings,
        };
        final row = {
          'ordinal': 1,
          'questionOrdinal': 1,
          'projectedQuestionType': 'A',
          'compositionKind': 'ROW',
          'groupPosition': null,
          'source': source,
          'level': 'SECRET_LEVEL',
          'unit': 'SECRET_UNIT',
          'topic': 'SECRET_TOPIC',
          'testNumber': 1,
          'allocationKind': 'FIXED',
          'allocationReason': 'FIXED_DECLARATION',
          'resolvedMode': 'WORD',
          'recordType': 'WORD',
          'targetText': 'SECRET_TARGET',
          'translations': {'tr': 'SECRET_TRANSLATION'},
          'sentence': 'SECRET_SENTENCE',
          'correctAnswer': 'SECRET_CORRECT',
          'alternativeCorrectAnswer': 'SECRET_ALTERNATIVE',
          'wrongAnswers': ['SECRET_WRONG'],
          'matchingGroup': 'SECRET_GROUP',
          'hidden': false,
          'note': 'SECRET_NOTE',
        };
        final status = {
          'id': '00000000-0000-4000-8000-000000000101',
          'status': 'PREVIEW_READY',
          'originalFileName': 'SECRET_FILE.xlsx',
          'declaredMediaType':
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'fileSizeBytes': 1,
          'rulesVersion': 'xlsx-v1',
          'processingAttempts': 1,
          'createdAt': '2026-08-02T00:00:00Z',
          'updatedAt': '2026-08-02T00:00:01Z',
          'uploadExpiresAt': '2026-08-02T00:15:00Z',
          'preview': summary,
          'approvalBindingSha256': approvalSha,
          'approvedAt': null,
          'commit': null,
          'failureCode': null,
        };
        final part = {'partNumber': 1, 'sizeBytes': 1, 'sha256': partSha};
        final completedPart = {
          'partNumber': 1,
          'eTag': 'SECRET_ETAG',
          'sha256': partSha,
        };
        final headers = {'contentLength': '1', 'sha256': partSha};
        final uploadPart = {
          'partNumber': 1,
          'sizeBytes': 1,
          'url': uploadUrl,
          'requiredHeaders': headers,
        };
        final upload = {
          'expiresAt': '2026-08-02T00:15:00Z',
          'parts': [uploadPart],
        };

        final values = <Object>[
          CourseImportPartDeclaration.fromJson(part),
          CourseImportPartHeaders.fromJson(headers),
          CourseImportPresignedPart.fromJson(uploadPart),
          CourseImportUploadInstructions.fromJson(upload),
          CreateCourseImportRequest.fromJson({
            'originalFileName': 'SECRET_FILE.xlsx',
            'declaredMediaType':
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'fileSizeBytes': 1,
            'sourceSha256': sourceSha,
            'parts': [part],
          }),
          CompletedCourseImportPart.fromJson(completedPart),
          CompleteCourseImportUploadRequest.fromJson({
            'sourceSha256': sourceSha,
            'parts': [completedPart],
          }),
          CourseImportPreviewSummary.fromJson(summary),
          CourseImportPreviewSettings.fromJson(settings),
          CourseImportSource.fromJson(source),
          CourseImportPreviewRow.fromJson(row),
          CourseImportPreviewPage.fromJson({
            'items': [row],
            'nextCursor': cursor,
          }),
          CourseImportValidationIssue.fromJson({
            'ordinal': 1,
            'severity': 'ERROR',
            'code': 'INVALID_CELL',
            'source': source,
            'message': 'SECRET_ISSUE',
          }),
          CourseImportIssuePage.fromJson({
            'items': [
              {
                'ordinal': 1,
                'severity': 'ERROR',
                'code': 'INVALID_CELL',
                'source': source,
                'message': 'SECRET_ISSUE',
              },
            ],
            'nextCursor': cursor,
          }),
          CourseImportStatusResponse.fromJson(status),
          CourseImportUploadSessionResponse.fromJson({
            'created': true,
            'import': status,
            'upload': upload,
          }),
          ApproveCourseImportRequest.fromJson({
            'approvalBindingSha256': approvalSha,
          }),
          CourseImportApprovalResponse.fromJson({
            'importId': '00000000-0000-4000-8000-000000000101',
            'status': 'APPROVED',
            'approvalBindingSha256': approvalSha,
            'approvedAt': '2026-08-02T00:01:00Z',
            'created': true,
          }),
          CommitCourseImportRequest.fromJson({
            'approvalBindingSha256': approvalSha,
          }),
        ];
        const secrets = [
          partSha,
          sourceSha,
          approvalSha,
          reportSha,
          uploadUrl,
          cursor,
          'SECRET_FILE.xlsx',
          'SECRET_SHEET',
          'SECRET_REF',
          'SECRET_TARGET',
          'SECRET_ISSUE',
          'SECRET_COURSE',
          'SECRET_LANGUAGE',
        ];
        for (final value in values) {
          final diagnostic = value.toString();
          expect(diagnostic, contains('[REDACTED]'));
          for (final secret in secrets) {
            expect(diagnostic, isNot(contains(secret)));
          }
        }
        final create = values[4] as CreateCourseImportRequest;
        final presignedPart = values[2] as CourseImportPresignedPart;
        expect(create.toJson()['sourceSha256'], sourceSha);
        expect(presignedPart.toJson()['url'], uploadUrl);
      },
    );
  });
}
