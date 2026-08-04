import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/failures.dart';
import '../domain/learning/attempt_machine.dart';
import '../domain/learning/learning.dart';
import 'energy_controller.dart';
import 'providers.dart';

final attemptControllerProvider =
    NotifierProvider<AttemptController, AttemptState>(AttemptController.new);

final class AttemptController extends Notifier<AttemptState> {
  bool _operationActive = false;

  @override
  AttemptState build() => const AttemptLoading(testId: '', startCommandId: '');

  Future<void> recoverOrStart(String testId) async {
    if (_operationActive || _isActiveFor(testId)) {
      return;
    }
    _operationActive = true;
    try {
      final store = await ref.read(recoveryStoreProvider.future);
      final snapshot = await store.read();
      if (snapshot != null && snapshot.testId == testId) {
        await _load(
          testId: testId,
          startCommandId: snapshot.startCommandId,
          snapshot: snapshot,
        );
      } else {
        await store.clear();
        final startCommandId = ref.read(identifierFactoryProvider).create();
        await _load(testId: testId, startCommandId: startCommandId);
      }
    } on Object catch (error) {
      state = AttemptFatal(testId: testId, failure: _failure(error));
    } finally {
      _operationActive = false;
    }
  }

  void selectOption(String optionId) {
    final current = state;
    if (current is! AttemptPresenting || _operationActive) {
      return;
    }
    state = AttemptMachine.reduce(current, AttemptOptionSelected(optionId));
    unawaited(_persistCurrent());
  }

  void selectMatchingTarget(String targetItemId) {
    final current = state;
    if (current is! AttemptPresenting ||
        current.question.answerKind != AnswerKind.matching ||
        _operationActive) {
      return;
    }
    state = AttemptMachine.reduce(
      current,
      AttemptMatchingTargetSelected(targetItemId),
    );
    unawaited(_persistCurrent());
  }

  void selectMatchingSupport(String supportItemId) {
    final current = state;
    if (current is! AttemptPresenting ||
        current.question.answerKind != AnswerKind.matching ||
        _operationActive) {
      return;
    }
    state = AttemptMachine.reduce(
      current,
      AttemptMatchingSupportSelected(supportItemId),
    );
    unawaited(_persistCurrent());
  }

  void removeMatchingPair(String targetItemId) {
    final current = state;
    if (current is! AttemptPresenting ||
        current.question.answerKind != AnswerKind.matching ||
        _operationActive) {
      return;
    }
    state = AttemptMachine.reduce(
      current,
      AttemptMatchingPairRemoved(targetItemId),
    );
    unawaited(_persistCurrent());
  }

  Future<void> submitSelected() async {
    final current = state;
    if (_operationActive ||
        current is! AttemptPresenting ||
        current.question.answerKind != AnswerKind.option ||
        current.selectedOptionId == null) {
      return;
    }
    final submissionId = ref.read(identifierFactoryProvider).create();
    state = AttemptMachine.reduce(
      current,
      AttemptSubmitRequested(submissionId),
    );
    _operationActive = true;
    try {
      await _persistCurrent();
      await _submitCurrent();
    } on Object catch (error) {
      final submitting = state;
      if (submitting is AttemptSubmitting) {
        state = AttemptMachine.reduce(
          submitting,
          AttemptSubmissionFailed(_failure(error)),
        );
      }
    } finally {
      _operationActive = false;
    }
  }

  Future<void> submitTyped(String rawAnswer) async {
    final current = state;
    if (_operationActive ||
        current is! AttemptPresenting ||
        current.question.answerKind != AnswerKind.typed) {
      return;
    }
    final TypedAnswerInput answer;
    try {
      answer = TypedAnswerInput(rawAnswer);
    } on ArgumentError {
      return;
    }
    final submissionId =
        current.resumeSubmissionId ??
        ref.read(identifierFactoryProvider).create();
    state = AttemptMachine.reduce(
      current,
      AttemptTypedSubmitRequested(submissionId, answer),
    );
    _operationActive = true;
    try {
      await _persistCurrent();
      await _submitCurrent();
    } on Object catch (error) {
      final submitting = state;
      if (submitting is AttemptSubmitting) {
        state = AttemptMachine.reduce(
          submitting,
          AttemptSubmissionFailed(_failure(error)),
        );
      }
    } finally {
      _operationActive = false;
    }
  }

  Future<void> submitMatching() async {
    final current = state;
    if (_operationActive ||
        current is! AttemptPresenting ||
        current.question.answerKind != AnswerKind.matching ||
        !current.matchingDraft.isCompleteFor(current.question)) {
      return;
    }
    final submissionId =
        current.resumeSubmissionId ??
        ref.read(identifierFactoryProvider).create();
    state = AttemptMachine.reduce(
      current,
      AttemptMatchingSubmitRequested(submissionId),
    );
    _operationActive = true;
    try {
      await _persistCurrent();
      await _submitCurrent();
    } on Object catch (error) {
      final submitting = state;
      if (submitting is AttemptSubmitting) {
        state = AttemptMachine.reduce(
          submitting,
          AttemptSubmissionFailed(_failure(error)),
        );
      }
    } finally {
      _operationActive = false;
    }
  }

  Future<void> advance() async {
    final current = state;
    if (_operationActive || current is! AttemptFeedback) {
      return;
    }
    final finishCommandId = ref.read(identifierFactoryProvider).create();
    state = AttemptMachine.reduce(
      current,
      AttemptAdvanceRequested(finishCommandId),
    );
    if (state is AttemptPresenting) {
      await _persistCurrent();
      return;
    }

    _operationActive = true;
    try {
      await _persistCurrent();
      await _finishCurrent();
    } on Object catch (error) {
      final finishing = state;
      if (finishing is AttemptFinishing) {
        state = AttemptMachine.reduce(
          finishing,
          AttemptFinishFailed(_failure(error)),
        );
      }
    } finally {
      _operationActive = false;
    }
  }

  Future<void> retry() async {
    final current = state;
    if (_operationActive || current is! AttemptRecovery) {
      return;
    }
    state = AttemptMachine.reduce(current, const AttemptRetryRequested());
    _operationActive = true;
    try {
      await _persistCurrent();
      switch (state) {
        case final AttemptLoading loading:
          await _load(
            testId: loading.testId,
            startCommandId: loading.startCommandId,
          );
        case AttemptSubmitting():
          await _submitCurrent();
        case AttemptReconciling():
          await _reconcileCurrent();
        case AttemptFinishing():
          await _finishCurrent();
        default:
          throw StateError('Recovery produced an invalid attempt state');
      }
    } on Object catch (error) {
      final currentState = state;
      state = switch (currentState) {
        AttemptLoading() => AttemptMachine.reduce(
          currentState,
          AttemptLoadFailed(_failure(error)),
        ),
        AttemptSubmitting() => AttemptMachine.reduce(
          currentState,
          AttemptSubmissionFailed(_failure(error)),
        ),
        AttemptReconciling() => AttemptMachine.reduce(
          currentState,
          AttemptReconciliationFailed(_failure(error)),
        ),
        AttemptFinishing() => AttemptMachine.reduce(
          currentState,
          AttemptFinishFailed(_failure(error)),
        ),
        _ => AttemptFatal(
          testId: currentState.testId,
          failure: _failure(error),
        ),
      };
    } finally {
      _operationActive = false;
    }
  }

  bool _isActiveFor(String testId) {
    if (state.testId != testId) {
      return false;
    }
    return state is AttemptLoading ||
        state is AttemptPresenting ||
        state is AttemptSubmitting ||
        state is AttemptReconciling ||
        state is AttemptFeedback ||
        state is AttemptFinishing ||
        state is AttemptRecovery;
  }

  Future<void> _load({
    required String testId,
    required String startCommandId,
    AttemptRecoverySnapshot? snapshot,
  }) async {
    state = AttemptLoading(testId: testId, startCommandId: startCommandId);
    if (snapshot == null) {
      await _persistCurrent();
    }
    try {
      final session = await ref
          .read(learningRepositoryProvider)
          .startAttempt(testId: testId, commandId: startCommandId);
      if (snapshot?.attemptId != null && snapshot!.attemptId != session.id) {
        state = AttemptFatal(
          testId: testId,
          failure: const ProtocolFailure('Recovered attempt identity changed'),
        );
        await _clearRecovery();
        return;
      }
      final index = snapshot?.questionIndex ?? 0;
      final finishId = snapshot?.phase == RecoveryPhase.finishing
          ? snapshot?.finishCommandId
          : null;
      state = AttemptMachine.reduce(
        state,
        AttemptLoaded(
          session,
          questionIndex: index,
          resumeFinishCommandId: finishId,
        ),
      );

      if (state is AttemptFinishing) {
        await _finishCurrent();
        return;
      }
      if (snapshot != null && state is AttemptPresenting) {
        final presenting = state as AttemptPresenting;
        final questionKind = presenting.question.answerKind;
        final recoveredKind = snapshot.answerKind;
        if ((recoveredKind != null && recoveredKind != questionKind) ||
            (questionKind != AnswerKind.option &&
                snapshot.selectedOptionId != null) ||
            (questionKind != AnswerKind.option &&
                snapshot.submissionId != null &&
                recoveredKind != questionKind)) {
          await _invalidateRecoveredAttempt(
            presenting,
            'Recovered answer kind does not match the question',
          );
          return;
        }

        if (questionKind == AnswerKind.option) {
          if (snapshot.selectedOptionId != null) {
            state = AttemptMachine.reduce(
              presenting,
              AttemptOptionSelected(snapshot.selectedOptionId!),
            );
          }
          if (snapshot.phase == RecoveryPhase.submitting) {
            if (snapshot.submissionId == null ||
                snapshot.selectedOptionId == null ||
                state is! AttemptPresenting) {
              await _invalidateRecoveredAttempt(
                presenting,
                'Recovered option submission is incomplete',
              );
              return;
            }
            state = AttemptMachine.reduce(
              state,
              AttemptSubmitRequested(snapshot.submissionId!),
            );
            await _submitCurrent();
            return;
          }
        } else {
          if (snapshot.phase == RecoveryPhase.submitting ||
              snapshot.phase == RecoveryPhase.feedback) {
            final submissionId = snapshot.submissionId;
            if (submissionId == null || recoveredKind != questionKind) {
              await _invalidateRecoveredAttempt(
                presenting,
                'Recovered private submission metadata is incomplete',
              );
              return;
            }
            state = AttemptMachine.reduce(
              presenting,
              AttemptReconciliationRequested(
                submissionId: submissionId,
                answerKind: questionKind,
              ),
            );
            await _reconcileCurrent();
            return;
          }
          if (snapshot.phase == RecoveryPhase.presenting &&
              snapshot.submissionId != null) {
            state = AttemptMachine.reduce(
              presenting,
              questionKind == AnswerKind.typed
                  ? AttemptTypedSubmissionReserved(snapshot.submissionId!)
                  : AttemptMatchingSubmissionReserved(snapshot.submissionId!),
            );
          }
        }
      }
      await _persistCurrent();
    } on Object catch (error) {
      final loading = state;
      if (loading is AttemptLoading) {
        state = AttemptMachine.reduce(
          loading,
          AttemptLoadFailed(_failure(error)),
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> _submitCurrent() async {
    final submitting = state;
    if (submitting is! AttemptSubmitting) {
      throw StateError('No answer submission is pending');
    }
    try {
      final feedback = await ref
          .read(learningRepositoryProvider)
          .submitAnswer(
            attemptId: submitting.context.session.id,
            questionRevisionId: submitting.pending.questionRevisionId,
            answer: submitting.pending.input,
            submissionId: submitting.pending.submissionId,
          );
      state = AttemptMachine.reduce(
        submitting,
        AttemptSubmissionRecorded(feedback),
      );
      if (state is AttemptFeedback) {
        await _persistCurrent();
      }
      ref.invalidate(energyControllerProvider);
      ref.invalidate(courseProgressProvider);
      if (state is AttemptInterrupted || state is AttemptFatal) {
        await _clearRecovery();
      }
    } on ConflictFailure catch (failure) {
      state = AttemptMachine.reduce(
        submitting,
        AttemptReconciliationRequested(
          submissionId: submitting.pending.submissionId,
          answerKind: submitting.pending.kind,
          pending: submitting.pending,
          originalFailure: failure,
        ),
      );
      await _persistCurrent();
      await _reconcileCurrent();
    } on Object catch (error) {
      state = AttemptMachine.reduce(
        submitting,
        AttemptSubmissionFailed(_failure(error)),
      );
      if (state is AttemptPresenting) {
        await _persistCurrent();
      }
      if (state is AttemptContentChanged ||
          state is AttemptInterrupted ||
          state is AttemptFatal) {
        await _clearRecovery();
      }
    }
  }

  Future<void> _reconcileCurrent() async {
    final reconciling = state;
    if (reconciling is! AttemptReconciling) {
      throw StateError('No recorded-answer reconciliation is pending');
    }
    try {
      final feedback = await ref
          .read(learningRepositoryProvider)
          .getRecordedAnswer(
            attemptId: reconciling.context.session.id,
            submissionId: reconciling.submissionId,
          );
      state = AttemptMachine.reduce(
        reconciling,
        feedback == null
            ? const AttemptReconciliationMissing()
            : AttemptReconciliationRecorded(feedback),
      );
      if (state is AttemptSubmitting) {
        await _persistCurrent();
        await _submitCurrent();
        return;
      }
      if (state is AttemptFeedback || state is AttemptPresenting) {
        await _persistCurrent();
      }
      if (feedback != null) {
        ref.invalidate(energyControllerProvider);
        ref.invalidate(courseProgressProvider);
      }
      if (state is AttemptInterrupted || state is AttemptFatal) {
        await _clearRecovery();
      }
    } on Object catch (error) {
      state = AttemptMachine.reduce(
        reconciling,
        AttemptReconciliationFailed(_failure(error)),
      );
      if (state is AttemptContentChanged ||
          state is AttemptInterrupted ||
          state is AttemptFatal) {
        await _clearRecovery();
      }
    }
  }

  Future<void> _invalidateRecoveredAttempt(
    AttemptPresenting presenting,
    String message,
  ) async {
    state = AttemptFatal(
      testId: presenting.testId,
      context: presenting.context,
      failure: ProtocolFailure(message),
    );
    await _clearRecovery();
  }

  Future<void> _finishCurrent() async {
    final finishing = state;
    if (finishing is! AttemptFinishing) {
      throw StateError('Attempt is not ready to finish');
    }
    try {
      final result = await ref
          .read(learningRepositoryProvider)
          .finishAttempt(
            attemptId: finishing.context.session.id,
            commandId: finishing.finishCommandId,
          );
      state = AttemptMachine.reduce(finishing, AttemptFinishRecorded(result));
      await _clearRecovery();
      ref.invalidate(energyControllerProvider);
      ref.invalidate(courseProgressProvider);
    } on Object catch (error) {
      state = AttemptMachine.reduce(
        finishing,
        AttemptFinishFailed(_failure(error)),
      );
      if (state is AttemptContentChanged ||
          state is AttemptInterrupted ||
          state is AttemptFatal) {
        await _clearRecovery();
      }
    }
  }

  Future<void> _persistCurrent() async {
    final snapshot = _snapshot(state);
    if (snapshot == null) {
      return;
    }
    await (await ref.read(recoveryStoreProvider.future)).write(snapshot);
  }

  Future<void> _clearRecovery() async {
    await (await ref.read(recoveryStoreProvider.future)).clear();
  }

  AttemptRecoverySnapshot? _snapshot(AttemptState current) {
    final now = DateTime.now().toUtc();
    return switch (current) {
      final AttemptLoading loading when loading.testId.isNotEmpty =>
        AttemptRecoverySnapshot(
          testId: loading.testId,
          startCommandId: loading.startCommandId,
          phase: RecoveryPhase.starting,
          questionIndex: 0,
          updatedAt: now,
        ),
      final AttemptPresenting presenting => AttemptRecoverySnapshot(
        testId: presenting.testId,
        startCommandId: presenting.context.startCommandId,
        phase: RecoveryPhase.presenting,
        attemptId: presenting.context.session.id,
        questionIndex: presenting.questionIndex,
        answerKind: presenting.question.answerKind,
        selectedOptionId: presenting.selectedOptionId,
        submissionId: presenting.resumeSubmissionId,
        updatedAt: now,
      ),
      final AttemptSubmitting submitting => AttemptRecoverySnapshot(
        testId: submitting.testId,
        startCommandId: submitting.context.startCommandId,
        phase: RecoveryPhase.submitting,
        attemptId: submitting.context.session.id,
        questionIndex: submitting.questionIndex,
        answerKind: submitting.pending.kind,
        selectedOptionId: switch (submitting.pending.input) {
          final OptionAnswerInput option => option.selectedOptionId,
          TypedAnswerInput() || MatchingAnswerInput() => null,
        },
        submissionId: submitting.pending.submissionId,
        updatedAt: now,
      ),
      final AttemptReconciling reconciling => AttemptRecoverySnapshot(
        testId: reconciling.testId,
        startCommandId: reconciling.context.startCommandId,
        phase: RecoveryPhase.submitting,
        attemptId: reconciling.context.session.id,
        questionIndex: reconciling.questionIndex,
        answerKind: reconciling.answerKind,
        selectedOptionId: switch (reconciling.pending?.input) {
          final OptionAnswerInput option => option.selectedOptionId,
          _ => null,
        },
        submissionId: reconciling.submissionId,
        updatedAt: now,
      ),
      final AttemptFeedback feedback => AttemptRecoverySnapshot(
        testId: feedback.testId,
        startCommandId: feedback.context.startCommandId,
        phase: feedback.answerKind == AnswerKind.option
            ? RecoveryPhase.submitting
            : RecoveryPhase.feedback,
        attemptId: feedback.context.session.id,
        questionIndex: feedback.questionIndex,
        answerKind: feedback.answerKind,
        selectedOptionId: feedback.selectedOptionId,
        submissionId: feedback.feedback.submissionId,
        updatedAt: now,
      ),
      final AttemptFinishing finishing => AttemptRecoverySnapshot(
        testId: finishing.testId,
        startCommandId: finishing.context.startCommandId,
        phase: RecoveryPhase.finishing,
        attemptId: finishing.context.session.id,
        questionIndex: finishing.context.session.questions.length - 1,
        finishCommandId: finishing.finishCommandId,
        updatedAt: now,
      ),
      final AttemptRecovery recovery => _recoverySnapshot(recovery, now),
      _ => null,
    };
  }

  AttemptRecoverySnapshot _recoverySnapshot(
    AttemptRecovery recovery,
    DateTime now,
  ) => switch (recovery.recovery) {
    final StartRecoveryContext start => AttemptRecoverySnapshot(
      testId: start.testId,
      startCommandId: start.startCommandId,
      phase: RecoveryPhase.starting,
      questionIndex: 0,
      updatedAt: now,
    ),
    final SubmissionRecoveryContext submission => AttemptRecoverySnapshot(
      testId: submission.testId,
      startCommandId: submission.context.startCommandId,
      phase: RecoveryPhase.submitting,
      attemptId: submission.context.session.id,
      questionIndex: submission.questionIndex,
      answerKind: submission.pending.kind,
      selectedOptionId: switch (submission.pending.input) {
        final OptionAnswerInput option => option.selectedOptionId,
        TypedAnswerInput() || MatchingAnswerInput() => null,
      },
      submissionId: submission.pending.submissionId,
      updatedAt: now,
    ),
    final ReconciliationRecoveryContext reconciliation =>
      AttemptRecoverySnapshot(
        testId: reconciliation.testId,
        startCommandId: reconciliation.context.startCommandId,
        phase: RecoveryPhase.submitting,
        attemptId: reconciliation.context.session.id,
        questionIndex: reconciliation.questionIndex,
        answerKind: reconciliation.answerKind,
        selectedOptionId: switch (reconciliation.pending?.input) {
          final OptionAnswerInput option => option.selectedOptionId,
          _ => null,
        },
        submissionId: reconciliation.submissionId,
        updatedAt: now,
      ),
    final FinishRecoveryContext finish => AttemptRecoverySnapshot(
      testId: finish.testId,
      startCommandId: finish.context.startCommandId,
      phase: RecoveryPhase.finishing,
      attemptId: finish.context.session.id,
      questionIndex: finish.context.session.questions.length - 1,
      finishCommandId: finish.finishCommandId,
      updatedAt: now,
    ),
  };

  AppFailure _failure(Object error) =>
      error is AppFailure ? error : UnknownFailure(cause: error);
}
