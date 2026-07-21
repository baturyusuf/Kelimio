import 'package:kelimio_api_client/kelimio_api_client.dart' as api;

import '../../domain/catalog/catalog.dart';
import '../../domain/energy/energy.dart';
import '../../domain/failures.dart';
import '../../domain/learning/learning.dart';

CourseSummary mapCourseSummary(api.CourseSummary value) {
  return CourseSummary(
    id: value.id,
    name: value.name,
    description: value.description,
    targetLanguage: value.targetLanguage,
    supportLanguages: value.supportLanguages.toList(growable: false),
    accessType: switch (value.accessType) {
      api.CourseSummaryAccessTypeEnum.FREE => CourseAccessType.free,
      api.CourseSummaryAccessTypeEnum.PAID => CourseAccessType.paid,
    },
    visibility: switch (value.visibility) {
      api.CourseSummaryVisibilityEnum.PUBLIC => CourseVisibility.public,
      api.CourseSummaryVisibilityEnum.PRIVATE => CourseVisibility.private,
    },
    enrolled: value.enrolled,
  );
}

CatalogPage mapCatalogPage(api.CoursePage value) {
  return CatalogPage(
    items: value.items.map(mapCourseSummary).toList(growable: false),
    nextCursor: value.nextCursor,
  );
}

CourseDetail mapCourseDetail(api.CourseDetail value) {
  final tests =
      value.tests
          .map(
            (test) => TestSummary(
              id: test.id,
              revisionId: test.revisionId,
              name: test.name,
              position: test.position,
              questionCount: test.questionCount,
            ),
          )
          .toList(growable: false)
        ..sort((left, right) => left.position.compareTo(right.position));
  final summary = CourseSummary(
    id: value.id,
    name: value.name,
    description: value.description,
    targetLanguage: value.targetLanguage,
    supportLanguages: value.supportLanguages.toList(growable: false),
    accessType: switch (value.accessType) {
      api.CourseDetailAccessTypeEnum.FREE => CourseAccessType.free,
      api.CourseDetailAccessTypeEnum.PAID => CourseAccessType.paid,
    },
    visibility: switch (value.visibility) {
      api.CourseDetailVisibilityEnum.PUBLIC => CourseVisibility.public,
      api.CourseDetailVisibilityEnum.PRIVATE => CourseVisibility.private,
    },
    enrolled: value.enrolled,
  );
  return CourseDetail(
    summary: summary,
    ownerDisplayName: value.ownerDisplayName,
    releaseId: value.releaseId,
    tests: tests,
  );
}

Enrollment mapEnrollment(api.EnrollmentResponse value) {
  return Enrollment(
    id: value.id,
    courseId: value.courseId,
    supportLanguage: value.supportLanguage,
    status: EnrollmentStatus.active,
    enrolledAt: value.enrolledAt.toUtc(),
  );
}

Energy mapEnergy(api.EnergyResponse value) {
  if (value.maximum != api.EnergyResponseMaximumEnum.number5) {
    throw const ProtocolFailure('Unsupported maximum energy value');
  }
  return Energy(
    balance: value.balance,
    maximum: 5,
    unlimited: value.unlimited,
    nextRegenerationAt: value.nextRegenerationAt?.toUtc(),
    asOf: value.asOf.toUtc(),
  );
}

AttemptSession mapAttempt(api.AttemptResponse value) {
  final questions =
      value.questions
          .map((question) {
            if (question.type !=
                api.QuestionPayloadTypeEnum.WORD_MULTIPLE_CHOICE) {
              throw ProtocolFailure(
                'Unsupported question type: ${question.type}',
              );
            }
            return Question(
              id: question.questionId,
              revisionId: question.questionRevisionId,
              type: QuestionType.wordMultipleChoice,
              position: question.position,
              prompt: question.prompt,
              options: question.options
                  .map(
                    (option) => AnswerOption(id: option.id, text: option.text),
                  )
                  .toList(growable: false),
            );
          })
          .toList(growable: false)
        ..sort((left, right) => left.position.compareTo(right.position));
  return AttemptSession(
    id: value.id,
    testId: value.testId,
    testRevisionId: value.testRevisionId,
    status: mapAttemptStatus(value.state),
    questions: questions,
    startedAt: value.startedAt.toUtc(),
  );
}

AnswerFeedback mapAnswerFeedback(api.AnswerRecordedResponse value) {
  return AnswerFeedback(
    submissionId: value.submissionId,
    correct: value.correct,
    correctOptionId: value.correctOptionId,
    activeScoreDelta: value.activeScoreDelta,
    lifetimeScoreDelta: value.lifetimeScoreDelta,
    activeQuestionScore: value.activeQuestionScore,
    lifetimeScore: value.lifetimeScore,
    energy: mapEnergy(value.energy),
    attemptStatus: mapAttemptStatus(value.attemptState),
  );
}

AttemptResult mapAttemptResult(api.FinishAttemptResponse value) {
  return AttemptResult(
    attemptId: value.attemptId,
    status: mapAttemptStatus(value.state),
    correctCount: value.correctCount,
    questionCount: value.questionCount,
    correctRatio: value.correctRatio.toDouble(),
    completedAt: value.completedAt.toUtc(),
  );
}

ServerAttemptStatus mapAttemptStatus(api.AttemptState value) => switch (value) {
  api.AttemptState.IN_PROGRESS => ServerAttemptStatus.inProgress,
  api.AttemptState.COMPLETED_PASS => ServerAttemptStatus.completedPass,
  api.AttemptState.COMPLETED_FAIL => ServerAttemptStatus.completedFail,
  api.AttemptState.INTERRUPTED_ENERGY => ServerAttemptStatus.interruptedEnergy,
};
