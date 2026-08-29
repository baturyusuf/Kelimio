import 'package:dio/dio.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart' as api;

import '../../domain/failures.dart';
import '../../domain/teacher/teacher_course.dart';
import '../network/failure_mapper.dart';
import '../network/request_metadata.dart';

final class GeneratedTeacherCourseRepository
    implements TeacherCourseRepository {
  const GeneratedTeacherCourseRepository(this._api, this._failures);

  final api.TeacherApi _api;
  final DioFailureMapper _failures;

  @override
  Future<TeacherCoursePage> listCourses({String? cursor, int limit = 20}) =>
      _guard(() async {
        final response = await _api.listTeacherCourses(
          cursor: cursor,
          limit: limit,
        );
        final data = response.data;
        if (data == null) {
          throw const ProtocolFailure('Teacher course response body was empty');
        }
        return TeacherCoursePage(
          items: data.items.map(_mapSummary).toList(growable: false),
          nextCursor: data.nextCursor,
        );
      });

  @override
  Future<TeacherCourseAnalytics> getAnalytics(String courseId) => _guard(
    () async {
      final response = await _api.getTeacherCourseAnalytics(courseId: courseId);
      final data = response.data;
      if (data == null || data.courseId != courseId) {
        throw const ProtocolFailure(
          'Teacher course analytics response was absent or mismatched',
        );
      }
      final metrics = data.metrics;
      if (data.updating == (metrics != null)) {
        throw const ProtocolFailure(
          'Teacher course analytics freshness state was inconsistent',
        );
      }
      if (metrics != null &&
          metrics.performance != null &&
          metrics.learnersWithRecordedActivity < 3) {
        throw const ProtocolFailure(
          'Teacher course analytics exposed small-cohort performance',
        );
      }
      final performance = metrics?.performance;
      if (performance != null &&
          (performance.correctAnswers > performance.answeredQuestions ||
              performance.passedAttempts > performance.completedAttempts)) {
        throw const ProtocolFailure(
          'Teacher course analytics aggregate ranges were invalid',
        );
      }
      return TeacherCourseAnalytics(
        courseId: data.courseId,
        courseReleaseId: data.courseReleaseId,
        updating: data.updating,
        metrics: metrics == null
            ? null
            : TeacherCourseAnalyticsMetrics(
                learnersWithRecordedActivity:
                    metrics.learnersWithRecordedActivity,
                performance: performance == null
                    ? null
                    : TeacherCoursePerformance(
                        answeredQuestions: performance.answeredQuestions,
                        correctAnswers: performance.correctAnswers,
                        completedAttempts: performance.completedAttempts,
                        passedAttempts: performance.passedAttempts,
                      ),
              ),
        updatedAt: data.updatedAt,
      );
    },
  );

  @override
  Future<FullCourseEditorDocument> getEditor(String courseId) =>
      _guard(() async {
        final response = await _api.getFullCourseEditor(courseId: courseId);
        final data = response.data;
        final entityTag = response.headers.value('etag');
        if (data == null || entityTag == null || entityTag.isEmpty) {
          throw const ProtocolFailure('Course editor body or ETag was absent');
        }
        return _mapDocument(data, entityTag);
      });

  @override
  Future<FullCourseDraft> saveDraft({
    required FullCourseEditorDocument document,
    required String commandId,
  }) => _guard(() async {
    final response = await _api.createFullCourseEditorDraft(
      courseId: document.courseId,
      idempotencyKey: commandId,
      ifMatch: document.entityTag,
      saveFullCourseEditorDraftRequest: _mapSave(document),
      extra: {RequestMetadata.idempotencyKey: commandId},
    );
    final data = response.data;
    if (data == null) {
      throw const ProtocolFailure('Course draft response body was empty');
    }
    return FullCourseDraft(
      courseId: data.courseId,
      baseReleaseId: data.baseReleaseId,
      draftReleaseId: data.draftReleaseId,
      releaseRevision: data.releaseRevision,
      questionCount: data.questionCount,
    );
  });

  @override
  Future<String> createInvitation(String courseId) => _guard(() async {
    final response = await _api.createCourseInvitation(
      courseId: courseId,
      createCourseInvitationRequest: api.CreateCourseInvitationRequest(
        maxUses: 1,
        expiresInHours: 168,
      ),
    );
    final data = response.data;
    if (data == null) {
      throw const ProtocolFailure('Invitation response was empty');
    }
    return data.token;
  });

  TeacherCourseSummary _mapSummary(api.TeacherCourseSummary value) =>
      TeacherCourseSummary(
        id: value.id,
        name: value.name,
        description: value.description,
        targetLanguage: value.targetLanguage,
        defaultSupportLanguage: value.defaultSupportLanguage,
        visibility: value.visibility.value == 'PUBLIC'
            ? TeacherCourseVisibility.public
            : TeacherCourseVisibility.private,
        publicationStatus: value.publicationStatus.value,
        activeReleaseId: value.activeReleaseId,
        activeReleaseRevision: value.activeReleaseRevision,
        hasOpenDraft: value.hasOpenDraft,
        openDraftReleaseId: value.openDraftReleaseId,
        createdAt: value.createdAt,
      );

  FullCourseEditorDocument _mapDocument(
    api.FullCourseEditorDocument value,
    String entityTag,
  ) => FullCourseEditorDocument(
    courseId: value.courseId,
    activeReleaseId: value.activeReleaseId,
    releaseRevision: value.releaseRevision,
    name: value.name,
    description: value.description,
    visibility: value.visibility.value == 'PUBLIC'
        ? TeacherCourseVisibility.public
        : TeacherCourseVisibility.private,
    targetLanguage: value.targetLanguage,
    defaultSupportLanguage: value.defaultSupportLanguage,
    supportLanguages: value.supportLanguages.toList(growable: false),
    levels: value.levels.map(_mapLevel).toList(growable: false),
    entityTag: entityTag,
  );

  EditorLevel _mapLevel(api.CourseEditorLevel value) => EditorLevel(
    id: value.id,
    title: value.title,
    units: value.units.map(_mapUnit).toList(growable: false),
  );

  EditorUnit _mapUnit(api.CourseEditorUnit value) => EditorUnit(
    id: value.id,
    title: value.title,
    topics: value.topics.map(_mapTopic).toList(growable: false),
  );

  EditorTopic _mapTopic(api.CourseEditorTopic value) => EditorTopic(
    id: value.id,
    title: value.title,
    tests: value.tests.map(_mapTest).toList(growable: false),
  );

  EditorTest _mapTest(api.CourseEditorTest value) => EditorTest(
    id: value.id,
    title: value.title,
    passThreshold: value.passThreshold.toDouble(),
    questions: value.questions.map(_mapQuestion).toList(growable: false),
  );

  EditorQuestion _mapQuestion(api.CourseEditorQuestion value) => EditorQuestion(
    id: value.id,
    type: switch (value.type.value) {
      'WORD_MULTIPLE_CHOICE' => EditorQuestionType.wordMultipleChoice,
      'MULTIPLE_CHOICE_CLOZE' => EditorQuestionType.multipleChoiceCloze,
      'TYPED_CLOZE' => EditorQuestionType.typedCloze,
      'MATCHING' => EditorQuestionType.matching,
      _ => throw const ProtocolFailure('Unsupported editor question type'),
    },
    prompt: value.prompt,
    correctAnswer: value.correctAnswer,
    alternativeCorrectAnswer: value.alternativeCorrectAnswer,
    translations: value.translations,
    options: value.options
        .map(
          (option) => EditorOption(
            text: option.text,
            correct: option.correct,
            translations: option.translations,
          ),
        )
        .toList(growable: false),
    matchingPairs: value.matchingPairs
        .map(
          (pair) => EditorMatchingPair(
            targetText: pair.targetText,
            translations: pair.translations,
          ),
        )
        .toList(growable: false),
  );

  api.SaveFullCourseEditorDraftRequest _mapSave(
    FullCourseEditorDocument value,
  ) => api.SaveFullCourseEditorDraftRequest(
    baseReleaseId: value.activeReleaseId,
    name: value.name,
    description: value.description,
    visibility: value.visibility == TeacherCourseVisibility.public
        ? api.SaveFullCourseEditorDraftRequestVisibilityEnum.PUBLIC
        : api.SaveFullCourseEditorDraftRequestVisibilityEnum.PRIVATE,
    levels: value.levels.map(_mapSaveLevel).toList(growable: false),
  );

  api.CourseEditorLevel _mapSaveLevel(EditorLevel value) =>
      api.CourseEditorLevel(
        id: value.id,
        title: value.title,
        units: value.units.map(_mapSaveUnit).toList(growable: false),
      );

  api.CourseEditorUnit _mapSaveUnit(EditorUnit value) => api.CourseEditorUnit(
    id: value.id,
    title: value.title,
    topics: value.topics.map(_mapSaveTopic).toList(growable: false),
  );

  api.CourseEditorTopic _mapSaveTopic(EditorTopic value) =>
      api.CourseEditorTopic(
        id: value.id,
        title: value.title,
        tests: value.tests.map(_mapSaveTest).toList(growable: false),
      );

  api.CourseEditorTest _mapSaveTest(EditorTest value) => api.CourseEditorTest(
    id: value.id,
    title: value.title,
    passThreshold: value.passThreshold,
    questions: value.questions.map(_mapSaveQuestion).toList(growable: false),
  );

  api.CourseEditorQuestion _mapSaveQuestion(EditorQuestion value) =>
      api.CourseEditorQuestion(
        id: value.id,
        type: switch (value.type) {
          EditorQuestionType.wordMultipleChoice =>
            api.CourseEditorQuestionTypeEnum.WORD_MULTIPLE_CHOICE,
          EditorQuestionType.multipleChoiceCloze =>
            api.CourseEditorQuestionTypeEnum.MULTIPLE_CHOICE_CLOZE,
          EditorQuestionType.typedCloze =>
            api.CourseEditorQuestionTypeEnum.TYPED_CLOZE,
          EditorQuestionType.matching =>
            api.CourseEditorQuestionTypeEnum.MATCHING,
        },
        prompt: value.prompt,
        correctAnswer: value.correctAnswer,
        alternativeCorrectAnswer: value.alternativeCorrectAnswer,
        translations: value.translations,
        options: value.options
            .map(
              (option) => api.CourseEditorOption(
                text: option.text,
                correct: option.correct,
                translations: option.translations,
              ),
            )
            .toList(growable: false),
        matchingPairs: value.matchingPairs
            .map(
              (pair) => api.CourseEditorMatchingPair(
                targetText: pair.targetText,
                translations: pair.translations,
              ),
            )
            .toList(growable: false),
      );

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw _failures.map(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw UnknownFailure(cause: error);
    }
  }
}
