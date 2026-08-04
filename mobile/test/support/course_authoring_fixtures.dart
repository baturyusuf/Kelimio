import 'package:kelimio_mobile/domain/course_authoring/course_authoring.dart';
import 'package:kelimio_mobile/domain/failures.dart';

const courseImportId = '00000000-0000-4000-8000-000000000100';
const authoredCourseId = '00000000-0000-4000-8000-000000000200';
const draftReleaseId = '00000000-0000-4000-8000-000000000300';
const approvalBinding =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

final class StubWorkbookPicker implements WorkbookPicker {
  const StubWorkbookPicker();

  @override
  Future<SelectedWorkbook?> pickWorkbook() async => SelectedWorkbook(
    displayName: 'course.xlsx',
    sizeBytes: 1,
    readRange: (start, endExclusive) => Stream.value(const [1]),
  );
}

final class RecordingCourseAuthoringRepository
    implements CourseAuthoringRepository {
  RecordingCourseAuthoringRepository({
    this.failFirstUpload = false,
    this.failFirstEditorDraftWithConflict = false,
    this.importToGet,
    this.importsToDiscover = const [],
    List<LocalCourseEditorDocument>? editorDocuments,
  }) : editorDocuments = [...?editorDocuments];

  final bool failFirstUpload;
  final bool failFirstEditorDraftWithConflict;
  final CourseImportSummary? importToGet;
  final List<CourseImportSummary> importsToDiscover;
  final List<LocalCourseEditorDocument> editorDocuments;
  int uploadCalls = 0;
  int listCalls = 0;
  final List<(String, String)> uploadCommands = [];
  final List<String> approvalCommands = [];
  final List<String> commitCommands = [];
  final List<String> activationCommands = [];
  final List<String> editorDraftCommands = [];
  final List<String> editorPrompts = [];
  int editorDraftCalls = 0;
  int getEditorCalls = 0;

  @override
  Future<CourseImportSummary> uploadWorkbook({
    required SelectedWorkbook workbook,
    required String createCommandId,
    required String completeCommandId,
    required UploadProgress onProgress,
  }) async {
    uploadCalls += 1;
    uploadCommands.add((createCommandId, completeCommandId));
    if (failFirstUpload && uploadCalls == 1) {
      throw const NetworkFailure();
    }
    onProgress(1, 1);
    return courseImportSummary(CourseImportStatus.queued);
  }

  @override
  Future<CourseImportSummary> getImport(String importId) async =>
      importToGet ?? courseImportSummary(CourseImportStatus.previewReady);

  @override
  Future<CourseImportPage> listImports({String? cursor, int limit = 20}) async {
    listCalls += 1;
    return CourseImportPage(items: importsToDiscover);
  }

  @override
  Future<CourseImportPreviewPage> getPreview({
    required String importId,
    String? cursor,
    int limit = 20,
  }) async => const CourseImportPreviewPage(
    items: [
      CourseImportPreviewRow(
        ordinal: 1,
        questionOrdinal: 1,
        questionType: 'A',
        level: 'A1',
        unit: 'Home',
        topic: 'Objects',
        testNumber: 1,
        recordType: 'WORD',
        targetText: 'Pencere',
        translations: {'en': 'Window'},
        sentence: null,
        correctAnswer: 'Window',
        alternativeCorrectAnswer: 'A window',
        wrongAnswers: ['Door'],
        matchingGroup: null,
        hidden: false,
        note: null,
      ),
    ],
  );

  @override
  Future<CourseImportIssuePage> getIssues({
    required String importId,
    String? cursor,
    int limit = 20,
  }) async => const CourseImportIssuePage(items: []);

  @override
  Future<CourseImportSummary> approve({
    required String importId,
    required String approvalBindingSha256,
    required String commandId,
  }) async {
    approvalCommands.add(commandId);
    return courseImportSummary(CourseImportStatus.approved);
  }

  @override
  Future<CourseImportCommit> commit({
    required String importId,
    required String approvalBindingSha256,
    required String commandId,
  }) async {
    commitCommands.add(commandId);
    return authoredCommit;
  }

  @override
  Future<CourseReleaseImpact> getReleaseImpact({
    required String courseId,
    required String releaseId,
  }) async => releaseId == authoredEditorDraft.draftReleaseId
      ? authoredEditorImpact
      : authoredImpact;

  @override
  Future<CourseReleaseActivation> activateRelease({
    required CourseReleaseImpact impact,
    required String commandId,
  }) async {
    activationCommands.add(commandId);
    return CourseReleaseActivation(
      courseId: authoredCourseId,
      releaseId: impact.targetReleaseId,
      operation: impact.operation,
      releaseRevision: impact.releaseRevision,
      questionCount: 14,
      reprojectionStatus: 'PENDING',
    );
  }

  @override
  Future<LocalCourseEditorDocument> getEditor(String courseId) async {
    getEditorCalls += 1;
    if (editorDocuments.isNotEmpty) return editorDocuments.removeAt(0);
    return authoredEditorDocument;
  }

  @override
  Future<LocalCourseEditorDraftResult> createEditorDraft({
    required LocalCourseEditorDocument document,
    required String editedPrompt,
    required String commandId,
  }) async {
    editorDraftCalls += 1;
    editorDraftCommands.add(commandId);
    editorPrompts.add(editedPrompt);
    if (failFirstEditorDraftWithConflict && editorDraftCalls == 1) {
      throw const ConflictFailure(code: 'course-editor-version-conflict');
    }
    return authoredEditorDraft;
  }
}

CourseImportSummary courseImportSummary(
  CourseImportStatus status, {
  CourseImportActivationSummary? activation,
}) => CourseImportSummary(
  id: courseImportId,
  status: status,
  fileName: 'course.xlsx',
  fileSizeBytes: 128,
  preview: const CourseImportPreviewSummary(
    valid: true,
    sourceRowCount: 23,
    questionCount: 14,
    matchingQuestionCount: 3,
    warningCount: 0,
    errorCount: 0,
    courseName: 'Kelimio test course',
    targetLanguage: 'tr',
    supportLanguages: ['en'],
    requiredClientCapabilities: ['question.matching.v1'],
  ),
  approvalBindingSha256: approvalBinding,
  commit: status == CourseImportStatus.committed ? authoredCommit : null,
  activation: activation,
  failureCode: null,
);

const authoredCommit = CourseImportCommit(
  courseId: authoredCourseId,
  contentChangeSetId: '00000000-0000-4000-8000-000000000250',
  draftReleaseId: draftReleaseId,
  sourceRowCount: 23,
  questionCount: 14,
  matchingQuestionCount: 3,
  requiredClientCapabilities: ['question.matching.v1'],
);

const authoredImpact = CourseReleaseImpact(
  courseId: authoredCourseId,
  targetReleaseId: draftReleaseId,
  expectedActiveReleaseId: null,
  operation: CourseReleaseOperation.initialPublication,
  releaseRevision: 1,
  targetQuestionCount: 14,
  unchangedQuestionCount: 0,
  changedQuestionCount: 0,
  addedQuestionCount: 14,
  removedQuestionCount: 0,
  affectedEnrollmentCount: 0,
  requiredClientCapabilities: ['question.matching.v1'],
  impactBindingSha256: approvalBinding,
);

const authoredEditorDocument = LocalCourseEditorDocument(
  courseId: authoredCourseId,
  courseName: 'Kelimio test course',
  activeReleaseId: draftReleaseId,
  releaseRevision: 1,
  levelTitle: 'A1',
  unitTitle: 'Home',
  topicTitle: 'Daily routines',
  testId: '00000000-0000-4000-8000-000000000410',
  testTitle: 'Test 1',
  questionId: '00000000-0000-4000-8000-000000000420',
  questionRevisionId: '00000000-0000-4000-8000-000000000430',
  questionRevision: 1,
  prompt: 'Ben her gun ---.',
  entityTag:
      '"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"',
);

const latestAuthoredEditorDocument = LocalCourseEditorDocument(
  courseId: authoredCourseId,
  courseName: 'Kelimio test course',
  activeReleaseId: '00000000-0000-4000-8000-000000000301',
  releaseRevision: 2,
  levelTitle: 'A1',
  unitTitle: 'Home',
  topicTitle: 'Daily routines',
  testId: '00000000-0000-4000-8000-000000000410',
  testTitle: 'Test 1',
  questionId: '00000000-0000-4000-8000-000000000420',
  questionRevisionId: '00000000-0000-4000-8000-000000000431',
  questionRevision: 2,
  prompt: 'Ben her aksam ---.',
  entityTag:
      '"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"',
);

const authoredEditorDraft = LocalCourseEditorDraftResult(
  courseId: authoredCourseId,
  baseReleaseId: draftReleaseId,
  draftReleaseId: '00000000-0000-4000-8000-000000000302',
  releaseRevision: 2,
  questionRevisionId: '00000000-0000-4000-8000-000000000431',
  created: true,
);

const authoredEditorImpact = CourseReleaseImpact(
  courseId: authoredCourseId,
  targetReleaseId: '00000000-0000-4000-8000-000000000302',
  expectedActiveReleaseId: draftReleaseId,
  operation: CourseReleaseOperation.publication,
  releaseRevision: 2,
  targetQuestionCount: 14,
  unchangedQuestionCount: 13,
  changedQuestionCount: 1,
  addedQuestionCount: 0,
  removedQuestionCount: 0,
  affectedEnrollmentCount: 0,
  requiredClientCapabilities: ['question.matching.v1'],
  impactBindingSha256: approvalBinding,
);
