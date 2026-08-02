import '../energy/energy.dart';

enum QuestionType {
  wordMultipleChoice,
  multipleChoiceCloze,
  typedCloze,
  matching,
}

enum AnswerKind { option, typed, matching }

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

final class MatchingItem {
  MatchingItem({required this.id, required this.text}) {
    if (id.isEmpty) {
      throw ArgumentError('A matching item requires an identifier');
    }
    if (text.trim().isEmpty) {
      throw ArgumentError('A matching item requires display text');
    }
  }

  final String id;
  final String text;
}

/// One learner-selected or authoritative matching relationship.
///
/// The relationship itself is answer material, so diagnostics deliberately do
/// not expose either opaque identifier.
final class MatchingPair {
  MatchingPair({required this.targetItemId, required this.supportItemId}) {
    if (targetItemId.isEmpty || supportItemId.isEmpty) {
      throw ArgumentError('A matching pair requires both item identifiers');
    }
    if (targetItemId == supportItemId) {
      throw ArgumentError('Matching-side identifiers must be unrelated');
    }
  }

  final String targetItemId;
  final String supportItemId;

  @override
  String toString() => 'MatchingPair(<redacted>)';
}

final class Question {
  Question({
    required this.id,
    required this.revisionId,
    required this.type,
    required this.position,
    required this.prompt,
    required List<AnswerOption> options,
    List<MatchingItem> targetItems = const [],
    List<MatchingItem> supportItems = const [],
  }) : options = List.unmodifiable(options),
       targetItems = List.unmodifiable(targetItems),
       supportItems = List.unmodifiable(supportItems) {
    switch (type) {
      case QuestionType.wordMultipleChoice:
      case QuestionType.multipleChoiceCloze:
        _requirePrompt();
        if (options.length != 4) {
          throw ArgumentError.value(
            options.length,
            'options',
            'Multiple-choice questions require four options',
          );
        }
        _requireNoMatchingItems();
        break;
      case QuestionType.typedCloze:
        _requirePrompt();
        if (options.isNotEmpty) {
          throw ArgumentError.value(
            options.length,
            'options',
            'Typed cloze questions cannot contain options',
          );
        }
        _requireNoMatchingItems();
        break;
      case QuestionType.matching:
        if (prompt != null) {
          throw ArgumentError('Matching questions require a null prompt');
        }
        if (options.isNotEmpty) {
          throw ArgumentError(
            'Matching questions cannot contain answer options',
          );
        }
        _validateMatchingItems();
        break;
    }
    final promptValue = prompt;
    if (isCloze &&
        (promptValue == null || !_hasExactlyOneClozeMarker(promptValue))) {
      throw ArgumentError(
        'Cloze questions require exactly one marker in the prompt',
      );
    }
  }

  final String id;
  final String revisionId;
  final QuestionType type;
  final int position;
  final String? prompt;
  final List<AnswerOption> options;
  final List<MatchingItem> targetItems;
  final List<MatchingItem> supportItems;

  bool get isCloze =>
      type == QuestionType.multipleChoiceCloze ||
      type == QuestionType.typedCloze;

  AnswerKind get answerKind => switch (type) {
    QuestionType.wordMultipleChoice ||
    QuestionType.multipleChoiceCloze => AnswerKind.option,
    QuestionType.typedCloze => AnswerKind.typed,
    QuestionType.matching => AnswerKind.matching,
  };

  ClozePromptSegments get clozePromptSegments {
    if (!isCloze) {
      throw StateError('Only a cloze question has prompt segments');
    }
    final promptValue = prompt!;
    final markerIndex = promptValue.indexOf(_clozeMarker);
    return ClozePromptSegments(
      before: promptValue.substring(0, markerIndex),
      after: promptValue.substring(markerIndex + _clozeMarker.length),
    );
  }

  bool containsOption(String optionId) =>
      options.any((option) => option.id == optionId);

  bool containsTargetItem(String itemId) =>
      targetItems.any((item) => item.id == itemId);

  bool containsSupportItem(String itemId) =>
      supportItems.any((item) => item.id == itemId);

  void _requirePrompt() {
    if (prompt == null || prompt!.trim().isEmpty) {
      throw ArgumentError('This question type requires a prompt');
    }
  }

  void _requireNoMatchingItems() {
    if (targetItems.isNotEmpty || supportItems.isNotEmpty) {
      throw ArgumentError('Only matching questions can contain matching items');
    }
  }

  void _validateMatchingItems() {
    if (targetItems.length < MatchingAnswerInput.minPairs ||
        targetItems.length > MatchingAnswerInput.maxPairs ||
        targetItems.length != supportItems.length) {
      throw ArgumentError(
        'Matching questions require two to six items on each side',
      );
    }
    final targetIds = targetItems.map((item) => item.id).toSet();
    final supportIds = supportItems.map((item) => item.id).toSet();
    final targetLabels = targetItems.map((item) => item.text).toSet();
    final supportLabels = supportItems.map((item) => item.text).toSet();
    if (targetIds.length != targetItems.length ||
        supportIds.length != supportItems.length ||
        targetLabels.length != targetItems.length ||
        supportLabels.length != supportItems.length ||
        targetIds.any(supportIds.contains)) {
      throw ArgumentError(
        'Matching item identifiers and labels must be unique and unlinked',
      );
    }
  }
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

final class MatchingAnswerInput extends AnswerInput {
  MatchingAnswerInput(Iterable<MatchingPair> pairs)
    : pairs = List.unmodifiable(pairs) {
    if (this.pairs.length < minPairs || this.pairs.length > maxPairs) {
      throw ArgumentError('A matching answer requires two to six pairs');
    }
    final targetIds = this.pairs.map((pair) => pair.targetItemId).toSet();
    final supportIds = this.pairs.map((pair) => pair.supportItemId).toSet();
    if (targetIds.length != this.pairs.length ||
        supportIds.length != this.pairs.length) {
      throw ArgumentError(
        'A matching answer cannot repeat a target or support item',
      );
    }
  }

  static const int minPairs = 2;
  static const int maxPairs = 6;

  final List<MatchingPair> pairs;

  @override
  AnswerKind get kind => AnswerKind.matching;

  bool hasExactCoverageOf(Question question) {
    if (question.type != QuestionType.matching ||
        pairs.length != question.targetItems.length) {
      return false;
    }
    final targetIds = pairs.map((pair) => pair.targetItemId).toSet();
    final supportIds = pairs.map((pair) => pair.supportItemId).toSet();
    return _sameValues(
          targetIds,
          question.targetItems.map((item) => item.id),
        ) &&
        _sameValues(supportIds, question.supportItems.map((item) => item.id));
  }

  bool hasSameMappingAs(Iterable<MatchingPair> otherPairs) {
    final other = <String, String>{
      for (final pair in otherPairs) pair.targetItemId: pair.supportItemId,
    };
    if (other.length != pairs.length) {
      return false;
    }
    return pairs.every(
      (pair) => other[pair.targetItemId] == pair.supportItemId,
    );
  }

  @override
  String toString() => 'MatchingAnswerInput(<redacted>)';
}

bool _sameValues(Set<String> left, Iterable<String> rightValues) {
  final right = rightValues.toSet();
  return left.length == right.length && left.containsAll(right);
}

final class AttemptSession {
  AttemptSession({
    required this.id,
    required this.testId,
    required this.testRevisionId,
    required this.supportLanguage,
    required this.status,
    required List<Question> questions,
    required this.startedAt,
  }) : questions = List.unmodifiable(questions) {
    if (supportLanguage.trim().isEmpty) {
      throw ArgumentError('Attempt requires a pinned support language');
    }
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
  final String supportLanguage;
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
    List<MatchingPair>? correctMatches,
    required this.activeScoreDelta,
    required this.lifetimeScoreDelta,
    required this.activeQuestionScore,
    required this.lifetimeScore,
    required this.energy,
    required this.attemptStatus,
  }) : correctMatches = correctMatches == null
           ? null
           : List.unmodifiable(correctMatches) {
    final hasOption = correctOptionId != null;
    final hasText = correctAnswerText != null;
    final hasMatches = this.correctMatches != null;
    if ([hasOption, hasText, hasMatches].where((present) => present).length !=
        1) {
      throw ArgumentError(
        'Answer feedback requires exactly one authoritative answer value',
      );
    }
    final text = correctAnswerText;
    if (text != null && !TypedAnswerInput.isValid(text)) {
      throw ArgumentError('Invalid authoritative typed-answer feedback');
    }
    final matches = this.correctMatches;
    if (matches != null) {
      MatchingAnswerInput(matches);
    }
  }

  final String submissionId;
  final bool correct;
  final String? correctOptionId;
  final String? correctAnswerText;
  final List<MatchingPair>? correctMatches;
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
