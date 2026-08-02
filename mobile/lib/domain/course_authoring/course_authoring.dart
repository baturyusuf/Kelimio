import 'dart:async';

import '../failures.dart';

const workbookMediaType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
const maximumWorkbookBytes = 25 * 1024 * 1024;

final class SelectedWorkbook {
  const SelectedWorkbook({
    required this.displayName,
    required this.sizeBytes,
    required this.readRange,
  });

  final String displayName;
  final int sizeBytes;
  final Stream<List<int>> Function(int start, int endExclusive) readRange;

  Stream<List<int>> openRead(int start, int endExclusive) {
    if (start < 0 || endExclusive <= start || endExclusive > sizeBytes) {
      throw const ValidationFailure(code: 'invalid-workbook-byte-range');
    }
    return readRange(start, endExclusive);
  }
}

abstract interface class WorkbookPicker {
  Future<SelectedWorkbook?> pickWorkbook();
}

enum CourseImportStatus {
  uploading,
  queued,
  processing,
  previewReady,
  validationFailed,
  malwareRejected,
  processingFailed,
  expired,
  approved,
  committed,
}

final class CourseImportPreviewSummary {
  const CourseImportPreviewSummary({
    required this.valid,
    required this.sourceRowCount,
    required this.questionCount,
    required this.matchingQuestionCount,
    required this.warningCount,
    required this.errorCount,
    required this.courseName,
    required this.targetLanguage,
    required this.supportLanguages,
    required this.requiredClientCapabilities,
  });

  final bool valid;
  final int sourceRowCount;
  final int? questionCount;
  final int? matchingQuestionCount;
  final int warningCount;
  final int errorCount;
  final String? courseName;
  final String? targetLanguage;
  final List<String> supportLanguages;
  final List<String> requiredClientCapabilities;
}

final class CourseImportCommit {
  const CourseImportCommit({
    required this.courseId,
    required this.contentChangeSetId,
    required this.draftReleaseId,
    required this.sourceRowCount,
    required this.questionCount,
    required this.matchingQuestionCount,
    required this.requiredClientCapabilities,
  });

  final String courseId;
  final String contentChangeSetId;
  final String draftReleaseId;
  final int sourceRowCount;
  final int questionCount;
  final int matchingQuestionCount;
  final List<String> requiredClientCapabilities;
}

final class CourseImportActivationSummary {
  const CourseImportActivationSummary({
    required this.releaseId,
    required this.operation,
    required this.activatedAt,
    required this.reprojectionStatus,
  });

  final String releaseId;
  final CourseReleaseOperation operation;
  final DateTime activatedAt;
  final String reprojectionStatus;
}

final class CourseImportSummary {
  const CourseImportSummary({
    required this.id,
    required this.status,
    required this.fileName,
    required this.fileSizeBytes,
    required this.preview,
    required this.approvalBindingSha256,
    required this.commit,
    required this.activation,
    required this.failureCode,
  });

  final String id;
  final CourseImportStatus status;
  final String fileName;
  final int fileSizeBytes;
  final CourseImportPreviewSummary? preview;
  final String? approvalBindingSha256;
  final CourseImportCommit? commit;
  final CourseImportActivationSummary? activation;
  final String? failureCode;

  bool get processing =>
      status == CourseImportStatus.queued ||
      status == CourseImportStatus.processing;
}

final class CourseImportPage {
  const CourseImportPage({required this.items, this.nextCursor});

  final List<CourseImportSummary> items;
  final String? nextCursor;
}

final class CourseImportPreviewRow {
  const CourseImportPreviewRow({
    required this.ordinal,
    required this.questionOrdinal,
    required this.questionType,
    required this.level,
    required this.unit,
    required this.topic,
    required this.testNumber,
    required this.recordType,
    required this.targetText,
    required this.translations,
    required this.sentence,
    required this.correctAnswer,
    required this.alternativeCorrectAnswer,
    required this.wrongAnswers,
    required this.matchingGroup,
    required this.hidden,
    required this.note,
  });

  final int ordinal;
  final int? questionOrdinal;
  final String? questionType;
  final String level;
  final String unit;
  final String topic;
  final int testNumber;
  final String recordType;
  final String targetText;
  final Map<String, String> translations;
  final String? sentence;
  final String? correctAnswer;
  final String? alternativeCorrectAnswer;
  final List<String> wrongAnswers;
  final String? matchingGroup;
  final bool hidden;
  final String? note;
}

final class CourseImportPreviewPage {
  const CourseImportPreviewPage({required this.items, this.nextCursor});

  final List<CourseImportPreviewRow> items;
  final String? nextCursor;
}

final class CourseImportIssue {
  const CourseImportIssue({
    required this.ordinal,
    required this.severity,
    required this.code,
    required this.message,
  });

  final int ordinal;
  final String severity;
  final String code;
  final String message;
}

final class CourseImportIssuePage {
  const CourseImportIssuePage({required this.items, this.nextCursor});

  final List<CourseImportIssue> items;
  final String? nextCursor;
}

enum CourseReleaseOperation { initialPublication, publication, rollback }

final class CourseReleaseImpact {
  const CourseReleaseImpact({
    required this.courseId,
    required this.targetReleaseId,
    required this.expectedActiveReleaseId,
    required this.operation,
    required this.releaseRevision,
    required this.targetQuestionCount,
    required this.unchangedQuestionCount,
    required this.changedQuestionCount,
    required this.addedQuestionCount,
    required this.removedQuestionCount,
    required this.affectedEnrollmentCount,
    required this.requiredClientCapabilities,
    required this.impactBindingSha256,
  });

  final String courseId;
  final String targetReleaseId;
  final String? expectedActiveReleaseId;
  final CourseReleaseOperation operation;
  final int releaseRevision;
  final int targetQuestionCount;
  final int unchangedQuestionCount;
  final int changedQuestionCount;
  final int addedQuestionCount;
  final int removedQuestionCount;
  final int affectedEnrollmentCount;
  final List<String> requiredClientCapabilities;
  final String impactBindingSha256;
}

final class CourseReleaseActivation {
  const CourseReleaseActivation({
    required this.courseId,
    required this.releaseId,
    required this.operation,
    required this.releaseRevision,
    required this.questionCount,
    required this.reprojectionStatus,
  });

  final String courseId;
  final String releaseId;
  final CourseReleaseOperation operation;
  final int releaseRevision;
  final int questionCount;
  final String reprojectionStatus;
}

typedef UploadProgress = void Function(int sentBytes, int totalBytes);

abstract interface class CourseAuthoringRepository {
  Future<CourseImportSummary> uploadWorkbook({
    required SelectedWorkbook workbook,
    required String createCommandId,
    required String completeCommandId,
    required UploadProgress onProgress,
  });

  Future<CourseImportSummary> getImport(String importId);

  Future<CourseImportPage> listImports({String? cursor, int limit = 20});

  Future<CourseImportPreviewPage> getPreview({
    required String importId,
    String? cursor,
    int limit = 20,
  });

  Future<CourseImportIssuePage> getIssues({
    required String importId,
    String? cursor,
    int limit = 20,
  });

  Future<CourseImportSummary> approve({
    required String importId,
    required String approvalBindingSha256,
    required String commandId,
  });

  Future<CourseImportCommit> commit({
    required String importId,
    required String approvalBindingSha256,
    required String commandId,
  });

  Future<CourseReleaseImpact> getReleaseImpact({
    required String courseId,
    required String releaseId,
  });

  Future<CourseReleaseActivation> activateRelease({
    required CourseReleaseImpact impact,
    required String commandId,
  });
}
