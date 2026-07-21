import '../energy/energy.dart';
import '../failures.dart';
import 'learning.dart';

final class ActiveAttempt {
  const ActiveAttempt({required this.session, required this.startCommandId});

  final AttemptSession session;
  final String startCommandId;
}

final class PendingAnswer {
  const PendingAnswer({
    required this.submissionId,
    required this.questionRevisionId,
    required this.selectedOptionId,
  });

  final String submissionId;
  final String questionRevisionId;
  final String selectedOptionId;
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
  });

  final ActiveAttempt context;
  final int questionIndex;
  final String? selectedOptionId;

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

final class AttemptFeedback extends AttemptState {
  const AttemptFeedback({
    required this.context,
    required this.questionIndex,
    required this.selectedOptionId,
    required this.feedback,
  });

  final ActiveAttempt context;
  final int questionIndex;
  final String selectedOptionId;
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
        if (!presenting.question.containsOption(selected.optionId)) {
          throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
        }
        return AttemptPresenting(
          context: presenting.context,
          questionIndex: presenting.questionIndex,
          selectedOptionId: selected.optionId,
        );
      }
      if (event case final AttemptSubmitRequested requested) {
        final selected = presenting.selectedOptionId;
        if (selected == null || requested.submissionId.isEmpty) {
          throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
        }
        return AttemptSubmitting(
          context: presenting.context,
          questionIndex: presenting.questionIndex,
          pending: PendingAnswer(
            submissionId: requested.submissionId,
            questionRevisionId: presenting.question.revisionId,
            selectedOptionId: selected,
          ),
        );
      }
    }

    if (state case final AttemptSubmitting submitting) {
      if (event case final AttemptSubmissionRecorded recorded) {
        final feedback = recorded.feedback;
        if (feedback.submissionId != submitting.pending.submissionId ||
            !submitting.question.containsOption(feedback.correctOptionId)) {
          return AttemptFatal(
            testId: state.testId,
            context: submitting.context,
            failure: const ProtocolFailure(
              'Answer response does not match submission',
            ),
          );
        }
        if (feedback.attemptStatus == ServerAttemptStatus.interruptedEnergy) {
          return AttemptInterrupted(
            testId: state.testId,
            context: submitting.context,
            energy: feedback.energy,
          );
        }
        return AttemptFeedback(
          context: submitting.context,
          questionIndex: submitting.questionIndex,
          selectedOptionId: submitting.pending.selectedOptionId,
          feedback: feedback,
        );
      }
      if (event case final AttemptSubmissionFailed failed) {
        return _fromSubmissionFailure(submitting, failed.failure);
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
        final FinishRecoveryContext finish => AttemptFinishing(
          context: finish.context,
          finishCommandId: finish.finishCommandId,
        ),
      };
    }

    throw IllegalAttemptTransition(state.runtimeType, event.runtimeType);
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
