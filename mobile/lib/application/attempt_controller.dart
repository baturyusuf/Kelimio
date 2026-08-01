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

  Future<void> submitSelected() async {
    final current = state;
    if (_operationActive ||
        current is! AttemptPresenting ||
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
      if (snapshot?.selectedOptionId != null && state is AttemptPresenting) {
        state = AttemptMachine.reduce(
          state,
          AttemptOptionSelected(snapshot!.selectedOptionId!),
        );
      }
      if (snapshot?.phase == RecoveryPhase.submitting &&
          snapshot?.submissionId != null &&
          state is AttemptPresenting) {
        state = AttemptMachine.reduce(
          state,
          AttemptSubmitRequested(snapshot!.submissionId!),
        );
        await _submitCurrent();
        return;
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
            selectedOptionId: submitting.pending.selectedOptionId,
            submissionId: submitting.pending.submissionId,
          );
      state = AttemptMachine.reduce(
        submitting,
        AttemptSubmissionRecorded(feedback),
      );
      ref.invalidate(energyControllerProvider);
      ref.invalidate(courseProgressProvider);
      if (state is AttemptInterrupted || state is AttemptFatal) {
        await _clearRecovery();
      }
    } on Object catch (error) {
      state = AttemptMachine.reduce(
        submitting,
        AttemptSubmissionFailed(_failure(error)),
      );
      if (state is AttemptContentChanged ||
          state is AttemptInterrupted ||
          state is AttemptFatal) {
        await _clearRecovery();
      }
    }
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
        selectedOptionId: presenting.selectedOptionId,
        updatedAt: now,
      ),
      final AttemptSubmitting submitting => AttemptRecoverySnapshot(
        testId: submitting.testId,
        startCommandId: submitting.context.startCommandId,
        phase: RecoveryPhase.submitting,
        attemptId: submitting.context.session.id,
        questionIndex: submitting.questionIndex,
        selectedOptionId: submitting.pending.selectedOptionId,
        submissionId: submitting.pending.submissionId,
        updatedAt: now,
      ),
      final AttemptFeedback feedback => AttemptRecoverySnapshot(
        testId: feedback.testId,
        startCommandId: feedback.context.startCommandId,
        phase: RecoveryPhase.submitting,
        attemptId: feedback.context.session.id,
        questionIndex: feedback.questionIndex,
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
      selectedOptionId: submission.pending.selectedOptionId,
      submissionId: submission.pending.submissionId,
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
