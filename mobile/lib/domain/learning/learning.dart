import '../energy/energy.dart';

enum QuestionType { wordMultipleChoice, multipleChoiceCloze, typedCloze }

enum AnswerKind { option, typed }

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
    if (type != QuestionType.typedCloze && options.length != 4) {
      throw ArgumentError.value(
        options.length,
        'options',
        'Multiple-choice questions require four options',
      );
    }
    if (type == QuestionType.typedCloze && options.isNotEmpty) {
      throw ArgumentError.value(
        options.length,
        'options',
        'Typed cloze questions cannot contain options',
      );
    }
    if (isCloze && !_hasExactlyOneClozeMarker(prompt)) {
      throw ArgumentError(
        'Cloze questions require exactly one marker in the prompt',
      );
    }
  }

  final String id;
  final String revisionId;
  final QuestionType type;
  final int position;
  final String prompt;
  final List<AnswerOption> options;

  bool get isCloze =>
      type == QuestionType.multipleChoiceCloze ||
      type == QuestionType.typedCloze;

  AnswerKind get answerKind =>
      type == QuestionType.typedCloze ? AnswerKind.typed : AnswerKind.option;

  ClozePromptSegments get clozePromptSegments {
    if (!isCloze) {
      throw StateError('Only a cloze question has prompt segments');
    }
    final markerIndex = prompt.indexOf(_clozeMarker);
    return ClozePromptSegments(
      before: prompt.substring(0, markerIndex),
      after: prompt.substring(markerIndex + _clozeMarker.length),
    );
  }

  bool containsOption(String optionId) =>
      options.any((option) => option.id == optionId);
}

final class ClozePromptSegments {
  const ClozePromptSegments({required this.before, required this.after});

  final String before;
  final String after;
}

const _clozeMarker = '---';

bool _hasExactlyOneClozeMarker(String prompt) {
  final first = prompt.indexOf(_clozeMarker);
  if (first == -1) {
    return false;
  }
  return prompt.indexOf(_clozeMarker, first + 1) == -1;
}

sealed class AnswerInput {
  const AnswerInput();

  AnswerKind get kind;
}

final class OptionAnswerInput extends AnswerInput {
  OptionAnswerInput(this.selectedOptionId) {
    if (selectedOptionId.isEmpty) {
      throw ArgumentError('An option answer requires an option identifier');
    }
  }

  final String selectedOptionId;

  @override
  AnswerKind get kind => AnswerKind.option;

  @override
  String toString() => 'OptionAnswerInput(<redacted-id>)';
}

final class TypedAnswerInput extends AnswerInput {
  TypedAnswerInput(String value) : _value = value {
    if (!isValid(value)) {
      throw ArgumentError('A typed answer must contain 1 to 500 characters');
    }
  }

  static const int maxLength = 500;

  static int codePointLength(String value) => value.runes.length;

  static bool isValid(String value) {
    final length = codePointLength(value);
    return length >= 1 && length <= maxLength && value.trim().isNotEmpty;
  }

  final String _value;

  /// Exposed only so the repository can serialize the transient submission.
  String get rawValueForSubmission => _value;

  @override
  AnswerKind get kind => AnswerKind.typed;

  @override
  String toString() => 'TypedAnswerInput(<redacted>)';
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
  AnswerFeedback({
    required this.submissionId,
    required this.correct,
    this.correctOptionId,
    this.correctAnswerText,
    required this.activeScoreDelta,
    required this.lifetimeScoreDelta,
    required this.activeQuestionScore,
    required this.lifetimeScore,
    required this.energy,
    required this.attemptStatus,
  }) {
    final hasOption = correctOptionId != null;
    final hasText = correctAnswerText != null;
    if (hasOption == hasText) {
      throw ArgumentError(
        'Answer feedback requires exactly one authoritative answer value',
      );
    }
    final text = correctAnswerText;
    if (text != null && !TypedAnswerInput.isValid(text)) {
      throw ArgumentError('Invalid authoritative typed-answer feedback');
    }
  }

  final String submissionId;
  final bool correct;
  final String? correctOptionId;
  final String? correctAnswerText;
  final int activeScoreDelta;
  final int lifetimeScoreDelta;
  final int activeQuestionScore;
  final int lifetimeScore;
  final Energy energy;
  final ServerAttemptStatus attemptStatus;

  @override
  String toString() => 'AnswerFeedback(<redacted-authoritative-answer>)';
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
    required AnswerInput answer,
    required String submissionId,
  });

  Future<AnswerFeedback?> getRecordedAnswer({
    required String attemptId,
    required String submissionId,
  });

  Future<AttemptResult> finishAttempt({
    required String attemptId,
    required String commandId,
  });
}

enum RecoveryPhase { starting, presenting, submitting, feedback, finishing }

final class AttemptRecoverySnapshot {
  const AttemptRecoverySnapshot({
    required this.testId,
    required this.startCommandId,
    required this.phase,
    required this.questionIndex,
    required this.updatedAt,
    this.attemptId,
    this.answerKind,
    this.selectedOptionId,
    this.submissionId,
    this.finishCommandId,
  });

  final String testId;
  final String startCommandId;
  final RecoveryPhase phase;
  final String? attemptId;
  final int questionIndex;
  final AnswerKind? answerKind;
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
