import '../energy/energy.dart';

enum QuestionType { wordMultipleChoice }

enum ServerAttemptStatus {
  inProgress,
  completedPass,
  completedFail,
  interruptedEnergy,
}

final class AnswerOption {
  const AnswerOption({required this.id, required this.text});

  final String id;
  final String text;
}

final class Question {
  Question({
    required this.id,
    required this.revisionId,
    required this.type,
    required this.position,
    required this.prompt,
    required List<AnswerOption> options,
  }) : options = List.unmodifiable(options) {
    if (options.length != 4) {
      throw ArgumentError.value(
        options.length,
        'options',
        'Type-A requires four options',
      );
    }
  }

  final String id;
  final String revisionId;
  final QuestionType type;
  final int position;
  final String prompt;
  final List<AnswerOption> options;

  bool containsOption(String optionId) =>
      options.any((option) => option.id == optionId);
}

final class AttemptSession {
  AttemptSession({
    required this.id,
    required this.testId,
    required this.testRevisionId,
    required this.status,
    required List<Question> questions,
    required this.startedAt,
  }) : questions = List.unmodifiable(questions) {
    if (questions.isEmpty) {
      throw ArgumentError.value(
        questions,
        'questions',
        'Attempt requires questions',
      );
    }
  }

  final String id;
  final String testId;
  final String testRevisionId;
  final ServerAttemptStatus status;
  final List<Question> questions;
  final DateTime startedAt;
}

final class AnswerFeedback {
  const AnswerFeedback({
    required this.submissionId,
    required this.correct,
    required this.correctOptionId,
    required this.activeScoreDelta,
    required this.lifetimeScoreDelta,
    required this.activeQuestionScore,
    required this.lifetimeScore,
    required this.energy,
    required this.attemptStatus,
  });

  final String submissionId;
  final bool correct;
  final String correctOptionId;
  final int activeScoreDelta;
  final int lifetimeScoreDelta;
  final int activeQuestionScore;
  final int lifetimeScore;
  final Energy energy;
  final ServerAttemptStatus attemptStatus;
}

final class AttemptResult {
  const AttemptResult({
    required this.attemptId,
    required this.status,
    required this.correctCount,
    required this.questionCount,
    required this.correctRatio,
    required this.completedAt,
  });

  final String attemptId;
  final ServerAttemptStatus status;
  final int correctCount;
  final int questionCount;
  final double correctRatio;
  final DateTime completedAt;
}

abstract interface class LearningRepository {
  Future<AttemptSession> startAttempt({
    required String testId,
    required String commandId,
  });

  Future<AnswerFeedback> submitAnswer({
    required String attemptId,
    required String questionRevisionId,
    required String selectedOptionId,
    required String submissionId,
  });

  Future<AttemptResult> finishAttempt({
    required String attemptId,
    required String commandId,
  });
}

enum RecoveryPhase { starting, presenting, submitting, finishing }

final class AttemptRecoverySnapshot {
  const AttemptRecoverySnapshot({
    required this.testId,
    required this.startCommandId,
    required this.phase,
    required this.questionIndex,
    required this.updatedAt,
    this.attemptId,
    this.selectedOptionId,
    this.submissionId,
    this.finishCommandId,
  });

  final String testId;
  final String startCommandId;
  final RecoveryPhase phase;
  final String? attemptId;
  final int questionIndex;
  final String? selectedOptionId;
  final String? submissionId;
  final String? finishCommandId;
  final DateTime updatedAt;
}

abstract interface class AttemptRecoveryStore {
  Future<AttemptRecoverySnapshot?> read();

  Future<void> write(AttemptRecoverySnapshot snapshot);

  Future<void> clear();
}
