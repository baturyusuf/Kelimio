import 'package:kelimio_mobile/domain/energy/energy.dart';
import 'package:kelimio_mobile/domain/learning/learning.dart';

const testId = '00000000-0000-4000-8000-000000000001';
const attemptId = '00000000-0000-4000-8000-000000000002';
const testRevisionId = '00000000-0000-4000-8000-000000000003';
const questionRevisionId = '00000000-0000-4000-8000-000000000004';
const submissionId = '00000000-0000-4000-8000-000000000005';

AttemptSession fixtureSession({Question? question}) {
  return AttemptSession(
    id: attemptId,
    testId: testId,
    testRevisionId: testRevisionId,
    status: ServerAttemptStatus.inProgress,
    questions: [
      question ??
          Question(
            id: '00000000-0000-4000-8000-000000000006',
            revisionId: questionRevisionId,
            type: QuestionType.wordMultipleChoice,
            position: 0,
            prompt: 'fixture prompt',
            options: const [
              AnswerOption(
                id: '00000000-0000-4000-8000-000000000010',
                text: 'option one',
              ),
              AnswerOption(
                id: '00000000-0000-4000-8000-000000000011',
                text: 'option two',
              ),
              AnswerOption(
                id: '00000000-0000-4000-8000-000000000012',
                text: 'option three',
              ),
              AnswerOption(
                id: '00000000-0000-4000-8000-000000000013',
                text: 'option four',
              ),
            ],
          ),
    ],
    startedAt: DateTime.utc(2026),
  );
}

Question fixtureClozeQuestion({
  String prompt = 'Ben her sabah çay ---.',
}) => Question(
  id: '00000000-0000-4000-8000-000000000106',
  revisionId: '00000000-0000-4000-8000-000000000104',
  type: QuestionType.multipleChoiceCloze,
  position: 1,
  prompt: prompt,
  options: const [
    AnswerOption(id: '00000000-0000-4000-8000-000000000110', text: 'içerim'),
    AnswerOption(id: '00000000-0000-4000-8000-000000000111', text: 'yerim'),
    AnswerOption(id: '00000000-0000-4000-8000-000000000112', text: 'koşarım'),
    AnswerOption(id: '00000000-0000-4000-8000-000000000113', text: 'yazarım'),
  ],
);

Question fixtureTypedClozeQuestion({
  String prompt = 'Ben her sabah çay ---.',
}) => Question(
  id: '00000000-0000-4000-8000-000000000206',
  revisionId: questionRevisionId,
  type: QuestionType.typedCloze,
  position: 1,
  prompt: prompt,
  options: const [],
);

AttemptSession fixtureTypedSession() =>
    fixtureSession(question: fixtureTypedClozeQuestion());

AnswerFeedback fixtureFeedback({String id = submissionId}) {
  return AnswerFeedback(
    submissionId: id,
    correct: true,
    correctOptionId: '00000000-0000-4000-8000-000000000010',
    activeScoreDelta: 10,
    lifetimeScoreDelta: 10,
    activeQuestionScore: 10,
    lifetimeScore: 10,
    energy: Energy(
      balance: 5,
      maximum: 5,
      unlimited: false,
      asOf: DateTime.utc(2026),
    ),
    attemptStatus: ServerAttemptStatus.inProgress,
  );
}

AnswerFeedback fixtureTypedFeedback({
  String id = submissionId,
  bool correct = true,
}) {
  return AnswerFeedback(
    submissionId: id,
    correct: correct,
    correctAnswerText: 'içerim',
    activeScoreDelta: correct ? 60 : 0,
    lifetimeScoreDelta: correct ? 60 : 0,
    activeQuestionScore: correct ? 60 : 0,
    lifetimeScore: correct ? 60 : 0,
    energy: Energy(
      balance: correct ? 5 : 4,
      maximum: 5,
      unlimited: false,
      asOf: DateTime.utc(2026),
    ),
    attemptStatus: ServerAttemptStatus.inProgress,
  );
}

AttemptRecoverySnapshot fixtureRecovery(
  RecoveryPhase phase, {
  AnswerKind? answerKind,
  String? selectedOptionId,
  String? recoveredSubmissionId,
}) {
  return AttemptRecoverySnapshot(
    testId: testId,
    startCommandId: '00000000-0000-4000-8000-000000000020',
    phase: phase,
    attemptId: attemptId,
    questionIndex: 0,
    answerKind: answerKind,
    selectedOptionId: selectedOptionId,
    submissionId: recoveredSubmissionId,
    updatedAt: DateTime.utc(2026),
  );
}
