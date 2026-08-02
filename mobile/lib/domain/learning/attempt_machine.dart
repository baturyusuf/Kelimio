import '../energy/energy.dart';
import '../failures.dart';
import 'learning.dart';

final class ActiveAttempt {
  const ActiveAttempt({required this.session, required this.startCommandId});

  final AttemptSession session;
  final String startCommandId;
}

final class PendingAnswer {
  PendingAnswer({
    required this.submissionId,
    required this.questionRevisionId,
    required this.input,
    this.matchingResendUsed = false,
  }) {
    if (matchingResendUsed && input.kind != AnswerKind.matching) {
      throw ArgumentError('Only a matching answer can use the resend marker');
    }
  }

  final String submissionId;
  final String questionRevisionId;
  final AnswerInput input;
  final bool matchingResendUsed;

  AnswerKind get kind => input.kind;

  PendingAnswer markMatchingResendUsed() {
    if (kind != AnswerKind.matching || matchingResendUsed) {
      throw StateError('Matching resend is not available');
    }
    return PendingAnswer(
      submissionId: submissionId,
      questionRevisionId: questionRevisionId,
      input: input,
      matchingResendUsed: true,
    );
  }
}

/// Ephemeral learner work for a matching question.
///
/// The selected relationships are intentionally absent from
/// [AttemptRecoverySnapshot]. They may live only for the current process and
/// are redacted from diagnostics.
final class MatchingDraft {
  const MatchingDraft.empty() : activeTargetItemId = null, pairs = const [];

  MatchingDraft._({
    this.activeTargetItemId,
    required Iterable<MatchingPair> pairs,
  }) : pairs = List.unmodifiable(pairs);

  final String? activeTargetItemId;
  final List<MatchingPair> pairs;

  bool isCompleteFor(Question question) {
    if (activeTargetItemId != null ||
        question.answerKind != AnswerKind.matching ||
        pairs.length != question.targetItems.length) {
      return false;
    }
    return MatchingAnswerInput(pairs).hasExactCoverageOf(question);
  }

  MatchingDraft selectTarget(Question question, String targetItemId) {
    _requireMatchingQuestion(question);
    if (!question.containsTargetItem(targetItemId) ||
        pairs.any((pair) => pair.targetItemId == targetItemId)) {
      throw ArgumentError('Target item cannot be selected');
    }
    return MatchingDraft._(
      activeTargetItemId: activeTargetItemId == targetItemId
          ? null
          : targetItemId,
      pairs: pairs,
    );
  }

  MatchingDraft selectSupport(Question question, String supportItemId) {
    _requireMatchingQuestion(question);
    final targetItemId = activeTargetItemId;
    if (targetItemId == null ||
        !question.containsSupportItem(supportItemId) ||
        pairs.any((pair) => pair.supportItemId == supportItemId)) {
      throw ArgumentError('Support item cannot be selected');
    }
    return MatchingDraft._(
      pairs: [
        ...pairs,
        MatchingPair(targetItemId: targetItemId, supportItemId: supportItemId),
      ],
    );
  }

  MatchingDraft removePair(Question question, String targetItemId) {
    _requireMatchingQuestion(question);
    if (!pairs.any((pair) => pair.targetItemId == targetItemId)) {
      throw ArgumentError('Matching pair does not exist');
    }
    return MatchingDraft._(
      pairs: pairs.where((pair) => pair.targetItemId != targetItemId),
    );
  }

  MatchingAnswerInput completeAnswerFor(Question question) {
    final answer = MatchingAnswerInput(pairs);
    if (activeTargetItemId != null || !answer.hasExactCoverageOf(question)) {
      throw StateError('Matching draft is incomplete');
    }
    return answer;
  }

  static void _requireMatchingQuestion(Question question) {
    if (question.answerKind != AnswerKind.matching) {
      throw ArgumentError('Matching draft requires a matching question');
    }
  }

  @override
  String toString() => 'MatchingDraft(<redacted>)';
}

sealed class AttemptState {
  const AttemptState();

  String get testId;

  bool get controlsLocked => false;

  bool get revealsAnswerKey => false;
}

final class AttemptLoading extends AttemptState {
  const AttemptLoading({required this.testId, required this.startCommandId});

  @override
  final String testId;
  final String startCommandId;

  @override
  bool get controlsLocked => true;
}

final class AttemptPresenting extends AttemptState {
  const AttemptPresenting({
    required this.context,
    required this.questionIndex,
    this.selectedOptionId,
    this.resumeSubmissionId,
    this.matchingDraft = const MatchingDraft.empty(),
  });

  final ActiveAttempt context;
  final int questionIndex;
  final String? selectedOptionId;
  final String? resumeSubmissionId;
  final MatchingDraft matchingDraft;

  Question get question => context.session.questions[questionIndex];

  @override
  String get testId => context.session.testId;
}

final class AttemptSubmitting extends AttemptState {
  const AttemptSubmitting({
    required this.context,
    required this.questionIndex,
    required this.pending,
  });

  final ActiveAttempt context;
  final int questionIndex;
  final PendingAnswer pending;

  Question get question => context.session.questions[questionIndex];

  @override
  String get testId => context.session.testId;

  @override
  bool get controlsLocked => true;
}

final class AttemptReconciling extends AttemptState {
  const AttemptReconciling({
    required this.context,
    required this.questionIndex,
    required this.submissionId,
    required this.answerKind,
    this.pending,
    this.originalFailure,
  });

  final ActiveAttempt context;
  final int questionIndex;
  final String submissionId;
  final AnswerKind answerKind;

  /// Present only while the process that submitted the answer is still alive.
  /// A typed [PendingAnswer] is never persisted by the recovery store.
  final PendingAnswer? pending;
  final AppFailure? originalFailure;

  Question get question => context.session.questions[questionIndex];

  @override
  String get testId => context.session.testId;

  @override
  bool get controlsLocked => true;
}

final class AttemptFeedback extends AttemptState {
  const AttemptFeedback({
    required this.context,
    required this.questionIndex,
    required this.answerKind,
    required this.feedback,
    this.selectedOptionId,
    this.submittedMatches,
  });

  final ActiveAttempt context;
  final int questionIndex;
  final AnswerKind answerKind;
  final String? selectedOptionId;

  /// Present only for live matching feedback; never written to recovery data.
  final MatchingAnswerInput? submittedMatches;
  final AnswerFeedback feedback;

  Question get question => context.session.questions[questionIndex];

  bool get isLastQuestion =>
      questionIndex == context.session.questions.length - 1;

  @override
  String get testId => context.session.testId;

  @override
  bool get revealsAnswerKey => true;
}

final class AttemptFinishing extends AttemptState {
  const AttemptFinishing({
    required this.context,
    required this.finishCommandId,
  });

  final ActiveAttempt context;
  final String finishCommandId;

  @override
  String get testId => context.session.testId;

  @override
  bool get controlsLocked => true;
}

final class AttemptPassed extends AttemptState {
  const AttemptPassed({required this.testId, required this.result});

  @override
  final String testId;
  final AttemptResult result;
}

final class AttemptFailed extends AttemptState {
  const AttemptFailed({required this.testId, required this.result});

  @override
  final String testId;
  final AttemptResult result;
}

final class AttemptInterrupted extends AttemptState {
  const AttemptInterrupted({
    required this.testId,
    this.context,
    this.energy,
    this.failure,
  });

  @override
  final String testId;
  final ActiveAttempt? context;
  final Energy? energy;
  final AppFailure? failure;
}

final class AttemptContentChanged extends AttemptState {
  const AttemptContentChanged({
    required this.testId,
    required this.failure,
    this.context,
  });

  @override
  final String testId;
  final ContentChangedFailure failure;
  final ActiveAttempt? context;
}

sealed class AttemptRecoveryContext {
  const AttemptRecoveryContext();

  String get testId;
}

final class StartRecoveryContext extends AttemptRecoveryContext {
  const StartRecoveryContext({
    required this.testId,
    required this.startCommandId,
  });

  @override
  final String testId;
  final String startCommandId;
}

final class SubmissionRecoveryContext extends AttemptRecoveryContext {
  const SubmissionRecoveryContext({
    required this.context,
    required this.questionIndex,
    required this.pending,
  });

  final ActiveAttempt context;
  final int questionIndex;
  final PendingAnswer pending;

  @override
  String get testId => context.session.testId;
}

final class ReconciliationRecoveryContext extends AttemptRecoveryContext {
  const ReconciliationRecoveryContext({
    required this.context,
    required this.questionIndex,
    required this.submissionId,
    required this.answerKind,
    this.pending,
    this.originalFailure,
  });

  final ActiveAttempt context;
  final int questionIndex;
  final String submissionId;
  final AnswerKind answerKind;
  final PendingAnswer? pending;
  final AppFailure? originalFailure;

  @override
  String get testId => context.session.testId;
}

final class FinishRecoveryContext extends AttemptRecoveryContext {
  const FinishRecoveryContext({
    required this.context,
    required this.finishCommandId,
  });

  final ActiveAttempt context;
  final String finishCommandId;

  @override
  String get testId => context.session.testId;
}

final class AttemptRecovery extends AttemptState {
  const AttemptRecovery({required this.recovery, required this.failure});

  final AttemptRecoveryContext recovery;
  final AppFailure failure;

  @override
  String get testId => recovery.testId;
}

final class AttemptFatal extends AttemptState {
  const AttemptFatal({
    required this.testId,
    required this.failure,
    this.context,
  });

  @override
  final String testId;
  final AppFailure failure;
  final ActiveAttempt? context;
}

sealed class AttemptEvent {
  const AttemptEvent();
}

final class AttemptLoaded extends AttemptEvent {
  const AttemptLoaded(
    this.session, {
    this.questionIndex = 0,
    this.resumeFinishCommandId,
  });

  final AttemptSession session;
  final int questionIndex;
  final String? resumeFinishCommandId;
}

final class AttemptLoadFailed extends AttemptEvent {
  const AttemptLoadFailed(this.failure);

  final AppFailure failure;
}

final class AttemptOptionSelected extends AttemptEvent {
  const AttemptOptionSelected(this.optionId);

  final String optionId;
}

final class AttemptSubmitRequested extends AttemptEvent {
  const AttemptSubmitRequested(this.submissionId);

  final String submissionId;
}

final class AttemptTypedSubmitRequested extends AttemptEvent {
  const AttemptTypedSubmitRequested(this.submissionId, this.answer);

  final String submissionId;
  final TypedAnswerInput answer;
}

final class AttemptTypedSubmissionReserved extends AttemptEvent {
  const AttemptTypedSubmissionReserved(this.submissionId);

  final String submissionId;
}

final class AttemptMatchingTargetSelected extends AttemptEvent {
  const AttemptMatchingTargetSelected(this.targetItemId);

  final String targetItemId;
}

final class AttemptMatchingSupportSelected extends AttemptEvent {
  const AttemptMatchingSupportSelected(this.supportItemId);

  final String supportItemId;
}

final class AttemptMatchingPairRemoved extends AttemptEvent {
  const AttemptMatchingPairRemoved(this.targetItemId);

  final String targetItemId;
}

final class AttemptMatchingSubmitRequested extends AttemptEvent {
  const AttemptMatchingSubmitRequested(this.submissionId);

  final String submissionId;
}

final class AttemptMatchingSubmissionReserved extends AttemptEvent {
  const AttemptMatchingSubmissionReserved(this.submissionId);

  final String submissionId;
}

final class AttemptReconciliationRequested extends AttemptEvent {
  const AttemptReconciliationRequested({
    required this.submissionId,
    required this.answerKind,
    this.pending,
    this.originalFailure,
  });

  final String submissionId;
  final AnswerKind answerKind;
  final PendingAnswer? pending;
  final AppFailure? originalFailure;
}

final class AttemptReconciliationRecorded extends AttemptEvent {
  const AttemptReconciliationRecorded(this.feedback);

  final AnswerFeedback feedback;
}

final class AttemptReconciliationMissing extends AttemptEvent {
  const AttemptReconciliationMissing();
}

final class AttemptReconciliationFailed extends AttemptEvent {
  const AttemptReconciliationFailed(this.failure);

  final AppFailure failure;
}

final class AttemptSubmissionRecorded extends AttemptEvent {
  const AttemptSubmissionRecorded(this.feedback);

  final AnswerFeedback feedback;
}

final class AttemptSubmissionFailed extends AttemptEvent {
  const AttemptSubmissionFailed(this.failure);

  final AppFailure failure;
}

final class AttemptAdvanceRequested extends AttemptEvent {
  const AttemptAdvanceRequested(this.finishCommandId);

  final String finishCommandId;
}

final class AttemptFinishRecorded extends AttemptEvent {
  const AttemptFinishRecorded(this.result);

  final AttemptResult result;
}

final class AttemptFinishFailed extends AttemptEvent {
  const AttemptFinishFailed(this.failure);

  final AppFailure failure;
}

final class AttemptRetryRequested extends AttemptEvent {
  const AttemptRetryRequested();
}

final class IllegalAttemptTransition implements Exception {
  const IllegalAttemptTransition(this.from, this.event);

  final Type from;
  final Type event;

  @override
  String toString() => 'Illegal attempt transition: $from + $event';
}

final class AttemptMachine {
  const AttemptMachine._();

  static AttemptState reduce(AttemptState state, AttemptEvent event) {
    if (state case final AttemptLoading loading) {
      if (event case final AttemptLoaded loaded) {
        if (loaded.session.testId != loading.testId ||
            loaded.session.status != ServerAttemptStatus.inProgress ||
            loaded.questionIndex < 0 ||
            loaded.questionIndex >= loaded.session.questions.length) {
          return AttemptFatal(
            testId: loading.testId,
            failure: const ProtocolFailure('Invalid attempt start payload'),
          );
        }
        final context = ActiveAttempt(
          session: loaded.session,
          startCommandId: loading.startCommandId,
        );
        final finishCommandId = loaded.resumeFinishCommandId;
        if (finishCommandId != null && finishCommandId.isNotEmpty) {
          return AttemptFinishing(
            context: context,
            finishCommandId: finishCommandId,
          );
        }
        return AttemptPresenting(
          context: context,
          questionIndex: loaded.questionIndex,
        );
      }
      if (event case final AttemptLoadFailed failed) {
        return _fromStartFailure(loading, failed.failure);
      }
    }

    if (state case final AttemptPresenting presenting) {
      if (event case final AttemptOptionSelected selected) {
        if (presenting.question.answerKind != AnswerKind.option ||
            !presenting.question.containsOption(selected.optionId)) {
          throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
        }
        return AttemptPresenting(
          context: presenting.context,
          questionIndex: presenting.questionIndex,
          selectedOptionId: selected.optionId,
          resumeSubmissionId: presenting.resumeSubmissionId,
          matchingDraft: presenting.matchingDraft,
        );
      }
      if (event case final AttemptSubmitRequested requested) {
        final selected = presenting.selectedOptionId;
        if (presenting.question.answerKind != AnswerKind.option ||
            selected == null ||
            requested.submissionId.isEmpty) {
          throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
        }
        return AttemptSubmitting(
          context: presenting.context,
          questionIndex: presenting.questionIndex,
          pending: PendingAnswer(
            submissionId: requested.submissionId,
            questionRevisionId: presenting.question.revisionId,
            input: OptionAnswerInput(selected),
          ),
        );
      }
      if (event case final AttemptTypedSubmitRequested requested) {
        if (presenting.question.answerKind != AnswerKind.typed ||
            requested.submissionId.isEmpty ||
            (presenting.resumeSubmissionId != null &&
                presenting.resumeSubmissionId != requested.submissionId)) {
          throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
        }
        return AttemptSubmitting(
          context: presenting.context,
          questionIndex: presenting.questionIndex,
          pending: PendingAnswer(
            submissionId: requested.submissionId,
            questionRevisionId: presenting.question.revisionId,
            input: requested.answer,
          ),
        );
      }
      if (event case final AttemptTypedSubmissionReserved reserved) {
        if (presenting.question.answerKind != AnswerKind.typed ||
            presenting.resumeSubmissionId != null ||
            reserved.submissionId.isEmpty) {
          throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
        }
        return AttemptPresenting(
          context: presenting.context,
          questionIndex: presenting.questionIndex,
          resumeSubmissionId: reserved.submissionId,
          matchingDraft: presenting.matchingDraft,
        );
      }
      if (event case final AttemptMatchingTargetSelected selected) {
        if (presenting.question.answerKind != AnswerKind.matching) {
          throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
        }
        final MatchingDraft draft;
        try {
          draft = presenting.matchingDraft.selectTarget(
            presenting.question,
            selected.targetItemId,
          );
        } on ArgumentError {
          throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
        }
        return AttemptPresenting(
          context: presenting.context,
          questionIndex: presenting.questionIndex,
          resumeSubmissionId: presenting.resumeSubmissionId,
          matchingDraft: draft,
        );
      }
      if (event case final AttemptMatchingSupportSelected selected) {
        if (presenting.question.answerKind != AnswerKind.matching) {
          throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
        }
        final MatchingDraft draft;
        try {
          draft = presenting.matchingDraft.selectSupport(
            presenting.question,
            selected.supportItemId,
          );
        } on ArgumentError {
          throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
        }
        return AttemptPresenting(
          context: presenting.context,
          questionIndex: presenting.questionIndex,
          resumeSubmissionId: presenting.resumeSubmissionId,
          matchingDraft: draft,
        );
      }
      if (event case final AttemptMatchingPairRemoved removed) {
        if (presenting.question.answerKind != AnswerKind.matching) {
          throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
        }
        final MatchingDraft draft;
        try {
          draft = presenting.matchingDraft.removePair(
            presenting.question,
            removed.targetItemId,
          );
        } on ArgumentError {
          throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
        }
        return AttemptPresenting(
          context: presenting.context,
          questionIndex: presenting.questionIndex,
          resumeSubmissionId: presenting.resumeSubmissionId,
          matchingDraft: draft,
        );
      }
      if (event case final AttemptMatchingSubmitRequested requested) {
        if (presenting.question.answerKind != AnswerKind.matching ||
            requested.submissionId.isEmpty ||
            (presenting.resumeSubmissionId != null &&
                presenting.resumeSubmissionId != requested.submissionId)) {
          throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
        }
        if (!presenting.matchingDraft.isCompleteFor(presenting.question)) {
          throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
        }
        final answer = presenting.matchingDraft.completeAnswerFor(
          presenting.question,
        );
        return AttemptSubmitting(
          context: presenting.context,
          questionIndex: presenting.questionIndex,
          pending: PendingAnswer(
            submissionId: requested.submissionId,
            questionRevisionId: presenting.question.revisionId,
            input: answer,
          ),
        );
      }
      if (event case final AttemptMatchingSubmissionReserved reserved) {
        if (presenting.question.answerKind != AnswerKind.matching ||
            presenting.resumeSubmissionId != null ||
            reserved.submissionId.isEmpty ||
            presenting.matchingDraft.pairs.isNotEmpty ||
            presenting.matchingDraft.activeTargetItemId != null) {
          throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
        }
        return AttemptPresenting(
          context: presenting.context,
          questionIndex: presenting.questionIndex,
          resumeSubmissionId: reserved.submissionId,
        );
      }
      if (event case final AttemptReconciliationRequested requested) {
        if (requested.submissionId.isEmpty ||
            requested.answerKind != presenting.question.answerKind ||
            requested.pending != null) {
          throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
        }
        return AttemptReconciling(
          context: presenting.context,
          questionIndex: presenting.questionIndex,
          submissionId: requested.submissionId,
          answerKind: requested.answerKind,
          originalFailure: requested.originalFailure,
        );
      }
    }

    if (state case final AttemptSubmitting submitting) {
      if (event case final AttemptSubmissionRecorded recorded) {
        return _feedbackState(
          context: submitting.context,
          questionIndex: submitting.questionIndex,
          submissionId: submitting.pending.submissionId,
          answerKind: submitting.pending.kind,
          selectedOptionId: switch (submitting.pending.input) {
            final OptionAnswerInput option => option.selectedOptionId,
            TypedAnswerInput() || MatchingAnswerInput() => null,
          },
          submittedMatches: switch (submitting.pending.input) {
            final MatchingAnswerInput matching => matching,
            _ => null,
          },
          feedback: recorded.feedback,
        );
      }
      if (event case final AttemptSubmissionFailed failed) {
        return _fromSubmissionFailure(submitting, failed.failure);
      }
      if (event case final AttemptReconciliationRequested requested) {
        if (requested.submissionId != submitting.pending.submissionId ||
            requested.answerKind != submitting.pending.kind ||
            !identical(requested.pending, submitting.pending)) {
          throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
        }
        return AttemptReconciling(
          context: submitting.context,
          questionIndex: submitting.questionIndex,
          submissionId: requested.submissionId,
          answerKind: requested.answerKind,
          pending: requested.pending,
          originalFailure: requested.originalFailure,
        );
      }
    }

    if (state case final AttemptReconciling reconciling) {
      if (event case final AttemptReconciliationRecorded recorded) {
        final selectedOptionId = switch (reconciling.pending?.input) {
          final OptionAnswerInput option => option.selectedOptionId,
          _ => null,
        };
        final submittedMatches = switch (reconciling.pending?.input) {
          final MatchingAnswerInput matching => matching,
          _ => null,
        };
        return _feedbackState(
          context: reconciling.context,
          questionIndex: reconciling.questionIndex,
          submissionId: reconciling.submissionId,
          answerKind: reconciling.answerKind,
          selectedOptionId: selectedOptionId,
          submittedMatches: submittedMatches,
          feedback: recorded.feedback,
        );
      }
      if (event is AttemptReconciliationMissing) {
        if ((reconciling.answerKind == AnswerKind.typed ||
                reconciling.answerKind == AnswerKind.matching) &&
            reconciling.pending == null) {
          return AttemptPresenting(
            context: reconciling.context,
            questionIndex: reconciling.questionIndex,
            resumeSubmissionId: reconciling.submissionId,
          );
        }
        if (reconciling.answerKind == AnswerKind.matching &&
            reconciling.pending != null &&
            reconciling.originalFailure?.isRetryable == true &&
            !reconciling.pending!.matchingResendUsed) {
          return AttemptSubmitting(
            context: reconciling.context,
            questionIndex: reconciling.questionIndex,
            pending: reconciling.pending!.markMatchingResendUsed(),
          );
        }
        return AttemptFatal(
          testId: reconciling.testId,
          context: reconciling.context,
          failure:
              reconciling.originalFailure ??
              const ProtocolFailure('Recorded answer was not found'),
        );
      }
      if (event case final AttemptReconciliationFailed failed) {
        return _fromReconciliationFailure(reconciling, failed.failure);
      }
    }

    if (state case final AttemptFeedback feedback) {
      if (event case final AttemptAdvanceRequested advance) {
        if (!feedback.isLastQuestion) {
          return AttemptPresenting(
            context: feedback.context,
            questionIndex: feedback.questionIndex + 1,
          );
        }
        if (advance.finishCommandId.isEmpty) {
          throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
        }
        return AttemptFinishing(
          context: feedback.context,
          finishCommandId: advance.finishCommandId,
        );
      }
    }

    if (state case final AttemptFinishing finishing) {
      if (event case final AttemptFinishRecorded recorded) {
        final result = recorded.result;
        if (result.attemptId != finishing.context.session.id) {
          return AttemptFatal(
            testId: state.testId,
            context: finishing.context,
            failure: const ProtocolFailure('Finish response attempt mismatch'),
          );
        }
        return switch (result.status) {
          ServerAttemptStatus.completedPass => AttemptPassed(
            testId: state.testId,
            result: result,
          ),
          ServerAttemptStatus.completedFail => AttemptFailed(
            testId: state.testId,
            result: result,
          ),
          ServerAttemptStatus.interruptedEnergy => AttemptInterrupted(
            testId: state.testId,
            context: finishing.context,
          ),
          ServerAttemptStatus.inProgress => AttemptFatal(
            testId: state.testId,
            context: finishing.context,
            failure: const ProtocolFailure(
              'Finish response remained in progress',
            ),
          ),
        };
      }
      if (event case final AttemptFinishFailed failed) {
        return _fromFinishFailure(finishing, failed.failure);
      }
    }

    if (state case final AttemptRecovery recovery) {
      if (event is! AttemptRetryRequested) {
        throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
      }
      return switch (recovery.recovery) {
        final StartRecoveryContext start => AttemptLoading(
          testId: start.testId,
          startCommandId: start.startCommandId,
        ),
        final SubmissionRecoveryContext submission => AttemptSubmitting(
          context: submission.context,
          questionIndex: submission.questionIndex,
          pending: submission.pending,
        ),
        final ReconciliationRecoveryContext reconciliation =>
          AttemptReconciling(
            context: reconciliation.context,
            questionIndex: reconciliation.questionIndex,
            submissionId: reconciliation.submissionId,
            answerKind: reconciliation.answerKind,
            pending: reconciliation.pending,
            originalFailure: reconciliation.originalFailure,
          ),
        final FinishRecoveryContext finish => AttemptFinishing(
          context: finish.context,
          finishCommandId: finish.finishCommandId,
        ),
      };
    }

    throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
  }

  static AttemptState _feedbackState({
    required ActiveAttempt context,
    required int questionIndex,
    required String submissionId,
    required AnswerKind answerKind,
    required String? selectedOptionId,
    required MatchingAnswerInput? submittedMatches,
    required AnswerFeedback feedback,
  }) {
    final question = context.session.questions[questionIndex];
    final responseMatches = switch (answerKind) {
      AnswerKind.option =>
        selectedOptionId != null &&
            feedback.correctOptionId != null &&
            feedback.correctAnswerText == null &&
            question.containsOption(selectedOptionId) &&
            question.containsOption(feedback.correctOptionId!),
      AnswerKind.typed =>
        selectedOptionId == null &&
            feedback.correctOptionId == null &&
            feedback.correctAnswerText != null &&
            feedback.correctMatches == null &&
            submittedMatches == null,
      AnswerKind.matching =>
        selectedOptionId == null &&
            feedback.correctOptionId == null &&
            feedback.correctAnswerText == null &&
            feedback.correctMatches != null &&
            MatchingAnswerInput(
              feedback.correctMatches!,
            ).hasExactCoverageOf(question) &&
            (submittedMatches == null ||
                (submittedMatches.hasExactCoverageOf(question) &&
                    feedback.correct ==
                        submittedMatches.hasSameMappingAs(
                          feedback.correctMatches!,
                        ))),
    };
    if (feedback.submissionId != submissionId ||
        question.answerKind != answerKind ||
        !responseMatches) {
      return AttemptFatal(
        testId: context.session.testId,
        context: context,
        failure: const ProtocolFailure(
          'Answer response does not match submission',
        ),
      );
    }
    if (feedback.attemptStatus == ServerAttemptStatus.interruptedEnergy) {
      return AttemptInterrupted(
        testId: context.session.testId,
        context: context,
        energy: feedback.energy,
      );
    }
    return AttemptFeedback(
      context: context,
      questionIndex: questionIndex,
      answerKind: answerKind,
      selectedOptionId: selectedOptionId,
      submittedMatches: submittedMatches,
      feedback: feedback,
    );
  }

  static AttemptState _fromStartFailure(
    AttemptLoading state,
    AppFailure failure,
  ) {
    if (failure is ContentChangedFailure) {
      return AttemptContentChanged(testId: state.testId, failure: failure);
    }
    if (failure is EnergyDepletedFailure) {
      return AttemptInterrupted(testId: state.testId, failure: failure);
    }
    if (failure.isRetryable) {
      return AttemptRecovery(
        recovery: StartRecoveryContext(
          testId: state.testId,
          startCommandId: state.startCommandId,
        ),
        failure: failure,
      );
    }
    return AttemptFatal(testId: state.testId, failure: failure);
  }

  static AttemptState _fromSubmissionFailure(
    AttemptSubmitting state,
    AppFailure failure,
  ) {
    final requiresBlankSameId =
        failure is ValidationFailure ||
        (failure is ServerFailure && failure.status == 413);
    if (requiresBlankSameId &&
        (state.pending.kind == AnswerKind.typed ||
            state.pending.kind == AnswerKind.matching)) {
      return AttemptPresenting(
        context: state.context,
        questionIndex: state.questionIndex,
        resumeSubmissionId: state.pending.submissionId,
      );
    }
    if (failure is ContentChangedFailure) {
      return AttemptContentChanged(
        testId: state.testId,
        context: state.context,
        failure: failure,
      );
    }
    if (failure is EnergyDepletedFailure) {
      return AttemptInterrupted(
        testId: state.testId,
        context: state.context,
        failure: failure,
      );
    }
    if (failure.isRetryable) {
      if (state.pending.kind == AnswerKind.matching) {
        return AttemptRecovery(
          recovery: ReconciliationRecoveryContext(
            context: state.context,
            questionIndex: state.questionIndex,
            submissionId: state.pending.submissionId,
            answerKind: state.pending.kind,
            pending: state.pending,
            originalFailure: failure,
          ),
          failure: failure,
        );
      }
      return AttemptRecovery(
        recovery: SubmissionRecoveryContext(
          context: state.context,
          questionIndex: state.questionIndex,
          pending: state.pending,
        ),
        failure: failure,
      );
    }
    return AttemptFatal(
      testId: state.testId,
      context: state.context,
      failure: failure,
    );
  }

  static AttemptState _fromReconciliationFailure(
    AttemptReconciling state,
    AppFailure failure,
  ) {
    if (failure is ContentChangedFailure) {
      return AttemptContentChanged(
        testId: state.testId,
        context: state.context,
        failure: failure,
      );
    }
    if (failure is EnergyDepletedFailure) {
      return AttemptInterrupted(
        testId: state.testId,
        context: state.context,
        failure: failure,
      );
    }
    if (failure.isRetryable) {
      return AttemptRecovery(
        recovery: ReconciliationRecoveryContext(
          context: state.context,
          questionIndex: state.questionIndex,
          submissionId: state.submissionId,
          answerKind: state.answerKind,
          pending: state.pending,
          originalFailure: state.originalFailure,
        ),
        failure: failure,
      );
    }
    return AttemptFatal(
      testId: state.testId,
      context: state.context,
      failure: failure,
    );
  }

  static AttemptState _fromFinishFailure(
    AttemptFinishing state,
    AppFailure failure,
  ) {
    if (failure is ContentChangedFailure) {
      return AttemptContentChanged(
        testId: state.testId,
        context: state.context,
        failure: failure,
      );
    }
    if (failure is EnergyDepletedFailure) {
      return AttemptInterrupted(
        testId: state.testId,
        context: state.context,
        failure: failure,
      );
    }
    if (failure.isRetryable) {
      return AttemptRecovery(
        recovery: FinishRecoveryContext(
          context: state.context,
          finishCommandId: state.finishCommandId,
        ),
        failure: failure,
      );
    }
    return AttemptFatal(
      testId: state.testId,
      context: state.context,
      failure: failure,
    );
  }
}
