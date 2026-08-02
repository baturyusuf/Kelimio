import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart' as api;

import '../../domain/course_authoring/course_authoring.dart';
import '../../domain/failures.dart';
import '../network/failure_mapper.dart';
import '../network/request_metadata.dart';

final class GeneratedCourseAuthoringRepository
    implements CourseAuthoringRepository {
  GeneratedCourseAuthoringRepository(
    this._imports,
    this._releases,
    this._failures, {
    Dio? uploadClient,
  }) : _uploadClient = uploadClient ?? createPresignedUploadClient();

  final api.CourseImportApi _imports;
  final api.CourseReleaseApi _releases;
  final DioFailureMapper _failures;
  final Dio _uploadClient;

  static const _partSize = 5 * 1024 * 1024;

  static Dio createPresignedUploadClient() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(minutes: 2),
      receiveTimeout: const Duration(seconds: 30),
      responseType: ResponseType.plain,
      followRedirects: false,
      receiveDataWhenStatusError: false,
    ),
  );

  @override
  Future<CourseImportSummary> uploadWorkbook({
    required SelectedWorkbook workbook,
    required String createCommandId,
    required String completeCommandId,
    required UploadProgress onProgress,
  }) => _guard(() async {
    _validateWorkbook(workbook);
    final digestPlan = await _digest(workbook);
    final sessionResponse = await _imports.createCourseImport(
      idempotencyKey: createCommandId,
      createCourseImportRequest: api.CreateCourseImportRequest(
        originalFileName: workbook.displayName,
        declaredMediaType: api
            .CreateCourseImportRequestDeclaredMediaTypeEnum
            .applicationSlashVndPeriodOpenxmlformatsOfficedocumentPeriodSpreadsheetmlPeriodSheet,
        fileSizeBytes: workbook.sizeBytes,
        sourceSha256: digestPlan.sourceSha256Hex,
        parts: digestPlan.parts
            .map(
              (part) => api.CourseImportPartDeclaration(
                partNumber: part.partNumber,
                sizeBytes: part.sizeBytes,
                sha256: part.sha256Base64,
              ),
            )
            .toList(growable: false),
      ),
      extra: {RequestMetadata.idempotencyKey: createCommandId},
    );
    final session = sessionResponse.data;
    if (session == null) {
      throw const ProtocolFailure('Import session response body was empty');
    }
    final upload = session.upload;
    if (upload == null) {
      final summary = _mapSummary(session.import_);
      if (summary.status == CourseImportStatus.uploading) {
        throw const ProtocolFailure('Import upload instructions were absent');
      }
      return summary;
    }
    _validateUploadInstructions(upload, digestPlan);

    final completed = <api.CompletedCourseImportPart>[];
    var completedBytes = 0;
    for (final instruction in upload.parts) {
      final local = digestPlan.parts[instruction.partNumber - 1];
      final eTag = await _uploadPart(
        workbook: workbook,
        local: local,
        instruction: instruction,
        onProgress: (sent) => onProgress(
          math.min(completedBytes + sent, workbook.sizeBytes),
          workbook.sizeBytes,
        ),
      );
      completed.add(
        api.CompletedCourseImportPart(
          partNumber: local.partNumber,
          eTag: eTag,
          sha256: local.sha256Base64,
        ),
      );
      completedBytes += local.sizeBytes;
      onProgress(completedBytes, workbook.sizeBytes);
    }

    final completionResponse = await _imports.completeCourseImportUpload(
      importId: session.import_.id,
      idempotencyKey: completeCommandId,
      completeCourseImportUploadRequest: api.CompleteCourseImportUploadRequest(
        sourceSha256: digestPlan.sourceSha256Hex,
        parts: completed,
      ),
      extra: {RequestMetadata.idempotencyKey: completeCommandId},
    );
    final completedImport = completionResponse.data;
    if (completedImport == null) {
      throw const ProtocolFailure('Import completion response body was empty');
    }
    return _mapSummary(completedImport);
  });

  @override
  Future<CourseImportSummary> getImport(String importId) => _guard(() async {
    final response = await _imports.getCourseImport(importId: importId);
    final data = response.data;
    if (data == null) {
      throw const ProtocolFailure('Import status response body was empty');
    }
    return _mapSummary(data);
  });

  @override
  Future<CourseImportPreviewPage> getPreview({
    required String importId,
    String? cursor,
    int limit = 20,
  }) => _guard(() async {
    final response = await _imports.listCourseImportPreviewRows(
      importId: importId,
      cursor: cursor,
      limit: limit,
    );
    final data = response.data;
    if (data == null) {
      throw const ProtocolFailure('Import preview response body was empty');
    }
    return CourseImportPreviewPage(
      items: data.items
          .map(
            (row) => CourseImportPreviewRow(
              ordinal: row.ordinal,
              questionOrdinal: row.questionOrdinal,
              questionType: row.projectedQuestionType?.value,
              level: row.level,
              unit: row.unit,
              topic: row.topic,
              testNumber: row.testNumber,
              recordType: row.recordType.value,
              targetText: row.targetText,
              translations: Map.unmodifiable(row.translations),
              sentence: row.sentence,
              correctAnswer: row.correctAnswer,
              alternativeCorrectAnswer: row.alternativeCorrectAnswer,
              wrongAnswers: List.unmodifiable(row.wrongAnswers),
              matchingGroup: row.matchingGroup,
              hidden: row.hidden,
              note: row.note,
            ),
          )
          .toList(growable: false),
      nextCursor: data.nextCursor,
    );
  });

  @override
  Future<CourseImportIssuePage> getIssues({
    required String importId,
    String? cursor,
    int limit = 20,
  }) => _guard(() async {
    final response = await _imports.listCourseImportValidationIssues(
      importId: importId,
      cursor: cursor,
      limit: limit,
    );
    final data = response.data;
    if (data == null) {
      throw const ProtocolFailure('Import issues response body was empty');
    }
    return CourseImportIssuePage(
      items: data.items
          .map(
            (issue) => CourseImportIssue(
              ordinal: issue.ordinal,
              severity: issue.severity.value,
              code: issue.code,
              message: issue.message,
            ),
          )
          .toList(growable: false),
      nextCursor: data.nextCursor,
    );
  });

  @override
  Future<CourseImportSummary> approve({
    required String importId,
    required String approvalBindingSha256,
    required String commandId,
  }) => _guard(() async {
    await _imports.approveCourseImport(
      importId: importId,
      idempotencyKey: commandId,
      approveCourseImportRequest: api.ApproveCourseImportRequest(
        approvalBindingSha256: approvalBindingSha256,
      ),
      extra: {RequestMetadata.idempotencyKey: commandId},
    );
    return getImport(importId);
  });

  @override
  Future<CourseImportCommit> commit({
    required String importId,
    required String approvalBindingSha256,
    required String commandId,
  }) => _guard(() async {
    final response = await _imports.commitCourseImport(
      importId: importId,
      idempotencyKey: commandId,
      commitCourseImportRequest: api.CommitCourseImportRequest(
        approvalBindingSha256: approvalBindingSha256,
      ),
      extra: {RequestMetadata.idempotencyKey: commandId},
    );
    final data = response.data;
    if (data == null) {
      throw const ProtocolFailure('Import commit response body was empty');
    }
    return _mapCommitResponse(data);
  });

  @override
  Future<CourseReleaseImpact> getReleaseImpact({
    required String courseId,
    required String releaseId,
  }) => _guard(() async {
    final response = await _releases.getCourseReleaseImpact(
      courseId: courseId,
      releaseId: releaseId,
    );
    final data = response.data;
    if (data == null) {
      throw const ProtocolFailure('Release impact response body was empty');
    }
    return _mapImpact(data);
  });

  @override
  Future<CourseReleaseActivation> activateRelease({
    required CourseReleaseImpact impact,
    required String commandId,
  }) => _guard(() async {
    final response = await _releases.activateCourseRelease(
      courseId: impact.courseId,
      releaseId: impact.targetReleaseId,
      idempotencyKey: commandId,
      activateCourseReleaseRequest: api.ActivateCourseReleaseRequest(
        expectedActiveReleaseId: impact.expectedActiveReleaseId,
        impactBindingSha256: impact.impactBindingSha256,
      ),
      extra: {RequestMetadata.idempotencyKey: commandId},
    );
    final data = response.data;
    if (data == null) {
      throw const ProtocolFailure('Release activation response body was empty');
    }
    return CourseReleaseActivation(
      courseId: data.courseId,
      releaseId: data.releaseId,
      operation: _mapOperation(data.operation),
      releaseRevision: data.releaseRevision,
      questionCount: data.questionCount,
      reprojectionStatus: data.reprojectionStatus.value,
    );
  });

  Future<_WorkbookDigestPlan> _digest(SelectedWorkbook workbook) async {
    final sourceDigest = await sha256
        .bind(workbook.openRead(0, workbook.sizeBytes))
        .first;
    final parts = <_WorkbookPartDigest>[];
    for (var start = 0, number = 1; start < workbook.sizeBytes; number++) {
      final end = math.min(start + _partSize, workbook.sizeBytes);
      final digest = await sha256.bind(workbook.openRead(start, end)).first;
      parts.add(
        _WorkbookPartDigest(
          partNumber: number,
          start: start,
          endExclusive: end,
          sha256Base64: base64Encode(digest.bytes),
        ),
      );
      start = end;
    }
    return _WorkbookDigestPlan(
      sourceSha256Hex: sourceDigest.toString(),
      parts: List.unmodifiable(parts),
    );
  }

  Future<String> _uploadPart({
    required SelectedWorkbook workbook,
    required _WorkbookPartDigest local,
    required api.CourseImportPresignedPart instruction,
    required void Function(int sentBytes) onProgress,
  }) async {
    final uri = _validatedUploadUri(instruction.url);
    try {
      final response = await _uploadClient.putUri<Object?>(
        uri,
        data: workbook.openRead(local.start, local.endExclusive),
        options: Options(
          headers: {
            Headers.contentLengthHeader: local.sizeBytes.toString(),
            'x-amz-checksum-sha256': local.sha256Base64,
          },
          followRedirects: false,
          responseType: ResponseType.plain,
          receiveDataWhenStatusError: false,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
        onSendProgress: (sent, total) => onProgress(sent),
      );
      final eTag = response.headers.value('etag');
      if (eTag == null ||
          eTag.isEmpty ||
          eTag.length > 256 ||
          eTag.codeUnits.any((value) => value < 33 || value > 126)) {
        throw const ProtocolFailure('Import upload ETag was invalid');
      }
      return eTag;
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.transformTimeout) {
        throw const TimeoutFailure();
      }
      if (error.type == DioExceptionType.connectionError) {
        throw const NetworkFailure();
      }
      throw ServerFailure(status: error.response?.statusCode ?? 502);
    }
  }

  void _validateWorkbook(SelectedWorkbook workbook) {
    if (workbook.sizeBytes < 1 || workbook.sizeBytes > maximumWorkbookBytes) {
      throw const ValidationFailure(code: 'invalid-workbook-size');
    }
    if (!workbook.displayName.toLowerCase().endsWith('.xlsx')) {
      throw const ValidationFailure(code: 'invalid-workbook-name');
    }
  }

  void _validateUploadInstructions(
    api.CourseImportUploadInstructions upload,
    _WorkbookDigestPlan digestPlan,
  ) {
    if (upload.parts.length != digestPlan.parts.length ||
        !upload.expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const ProtocolFailure('Import upload plan did not match the file');
    }
    for (var index = 0; index < digestPlan.parts.length; index++) {
      final expected = digestPlan.parts[index];
      final actual = upload.parts[index];
      if (actual.partNumber != expected.partNumber ||
          actual.sizeBytes != expected.sizeBytes ||
          actual.requiredHeaders.contentLength !=
              expected.sizeBytes.toString() ||
          actual.requiredHeaders.sha256 != expected.sha256Base64) {
        throw const ProtocolFailure(
          'Import upload part did not match the file',
        );
      }
      _validatedUploadUri(actual.url);
    }
  }

  Uri _validatedUploadUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasScheme ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const ProtocolFailure('Import upload URL was invalid');
    }
    return uri;
  }

  CourseImportSummary _mapSummary(api.CourseImportStatusResponse value) {
    final preview = value.preview;
    final settings = preview?.settings;
    final commit = value.commit;
    return CourseImportSummary(
      id: value.id,
      status: _mapStatus(value.status),
      fileName: value.originalFileName,
      fileSizeBytes: value.fileSizeBytes,
      preview: preview == null
          ? null
          : CourseImportPreviewSummary(
              valid: preview.isValid,
              sourceRowCount: preview.rowCount,
              questionCount: preview.questionCount,
              matchingQuestionCount: preview.matchingQuestionCount,
              warningCount: preview.warningCount,
              errorCount: preview.errorCount,
              courseName: settings?.courseName,
              targetLanguage: settings?.targetLanguageCode,
              supportLanguages: settings == null
                  ? const []
                  : (settings.supportLanguageCodes.toList(growable: false)
                      ..sort()),
              requiredClientCapabilities:
                  preview.requiredClientCapabilities == null
                  ? const []
                  : (preview.requiredClientCapabilities!.toList(growable: false)
                      ..sort()),
            ),
      approvalBindingSha256: value.approvalBindingSha256,
      commit: commit == null
          ? null
          : CourseImportCommit(
              courseId: commit.courseId,
              contentChangeSetId: commit.contentChangeSetId,
              draftReleaseId: commit.draftReleaseId,
              sourceRowCount: commit.sourceRowCount,
              questionCount: commit.questionCount,
              matchingQuestionCount: commit.matchingQuestionCount,
              requiredClientCapabilities:
                  commit.requiredClientCapabilities.toList(growable: false)
                    ..sort(),
            ),
      failureCode: value.failureCode,
    );
  }

  CourseImportCommit _mapCommitResponse(api.CourseImportCommitResponse value) =>
      CourseImportCommit(
        courseId: value.courseId,
        contentChangeSetId: value.contentChangeSetId,
        draftReleaseId: value.draftReleaseId,
        sourceRowCount: value.sourceRowCount,
        questionCount: value.questionCount,
        matchingQuestionCount: value.matchingQuestionCount,
        requiredClientCapabilities: value.requiredClientCapabilities.toList(
          growable: false,
        )..sort(),
      );

  CourseReleaseImpact _mapImpact(api.CourseReleaseImpactResponse value) =>
      CourseReleaseImpact(
        courseId: value.courseId,
        targetReleaseId: value.targetReleaseId,
        expectedActiveReleaseId: value.expectedActiveReleaseId,
        operation: _mapOperation(value.operation),
        releaseRevision: value.releaseRevision,
        targetQuestionCount: value.targetQuestionCount,
        unchangedQuestionCount: value.unchangedQuestionCount,
        changedQuestionCount: value.changedQuestionCount,
        addedQuestionCount: value.addedQuestionCount,
        removedQuestionCount: value.removedQuestionCount,
        affectedEnrollmentCount: value.affectedEnrollmentCount,
        requiredClientCapabilities: value.requiredClientCapabilities.toList(
          growable: false,
        )..sort(),
        impactBindingSha256: value.impactBindingSha256,
      );

  CourseImportStatus _mapStatus(api.CourseImportStatus value) =>
      switch (value) {
        api.CourseImportStatus.UPLOADING => CourseImportStatus.uploading,
        api.CourseImportStatus.QUEUED => CourseImportStatus.queued,
        api.CourseImportStatus.PROCESSING => CourseImportStatus.processing,
        api.CourseImportStatus.PREVIEW_READY => CourseImportStatus.previewReady,
        api.CourseImportStatus.VALIDATION_FAILED =>
          CourseImportStatus.validationFailed,
        api.CourseImportStatus.MALWARE_REJECTED =>
          CourseImportStatus.malwareRejected,
        api.CourseImportStatus.PROCESSING_FAILED =>
          CourseImportStatus.processingFailed,
        api.CourseImportStatus.EXPIRED => CourseImportStatus.expired,
        api.CourseImportStatus.APPROVED => CourseImportStatus.approved,
        api.CourseImportStatus.COMMITTED => CourseImportStatus.committed,
      };

  CourseReleaseOperation _mapOperation(api.CourseReleaseOperation value) =>
      switch (value) {
        api.CourseReleaseOperation.INITIAL_PUBLICATION =>
          CourseReleaseOperation.initialPublication,
        api.CourseReleaseOperation.PUBLICATION =>
          CourseReleaseOperation.publication,
        api.CourseReleaseOperation.ROLLBACK => CourseReleaseOperation.rollback,
      };

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      final failure = _failures.map(error);
      _redactRequest(error.requestOptions);
      final response = error.response;
      if (response != null) {
        response.data = null;
        if (!identical(response.requestOptions, error.requestOptions)) {
          _redactRequest(response.requestOptions);
        }
      }
      throw failure;
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw UnknownFailure(cause: error);
    }
  }

  void _redactRequest(RequestOptions options) {
    options.data = null;
    options.headers.removeWhere(
      (name, value) => name.toLowerCase() == 'authorization',
    );
  }
}

final class _WorkbookDigestPlan {
  const _WorkbookDigestPlan({
    required this.sourceSha256Hex,
    required this.parts,
  });

  final String sourceSha256Hex;
  final List<_WorkbookPartDigest> parts;
}

final class _WorkbookPartDigest {
  const _WorkbookPartDigest({
    required this.partNumber,
    required this.start,
    required this.endExclusive,
    required this.sha256Base64,
  });

  final int partNumber;
  final int start;
  final int endExclusive;
  final String sha256Base64;

  int get sizeBytes => endExclusive - start;
}
