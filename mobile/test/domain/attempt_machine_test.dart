import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/domain/failures.dart';
import 'package:kelimio_mobile/domain/learning/attempt_machine.dart';
import 'package:kelimio_mobile/domain/learning/learning.dart';

import '../support/fixtures.dart';

void main() {
  group('AttemptMachine option flow', () {
    test('rejects illegal transitions', () {
      const loading = AttemptLoading(
        testId: testId,
        startCommandId: '00000000-0000-4000-8000-000000000020',
      );

      expect(
        () => AttemptMachine.reduce(
          loading,
          const AttemptSubmitRequested(submissionId),
        ),
        throwsA(isA<IllegalAttemptTransition>()),
      );
    });

    test('locks submission and rejects a duplicate submit transition', () {
      var state = _presenting(fixtureSession());
      state = AttemptMachine.reduce(
        state,
        const AttemptOptionSelected('00000000-0000-4000-8000-000000000010'),
      );
      state = AttemptMachine.reduce(
        state,
        const AttemptSubmitRequested(submissionId),
      );

      expect(state, isA<AttemptSubmitting>());
      expect(state.controlsLocked, isTrue);
      expect(state.revealsAnswerKey, isFalse);
      expect(
        () => AttemptMachine.reduce(
          state,
          const AttemptSubmitRequested(submissionId),
        ),
        throwsA(isA<IllegalAttemptTransition>()),
      );
    });

    test('a retry preserves the exact submission identifier', () {
      var state = _presenting(fixtureSession());
      state = AttemptMachine.reduce(
        state,
        const AttemptOptionSelected('00000000-0000-4000-8000-000000000010'),
      );
      state = AttemptMachine.reduce(
        state,
        const AttemptSubmitRequested(submissionId),
      );
      state = AttemptMachine.reduce(
        state,
        const AttemptSubmissionFailed(NetworkFailure()),
      );

      state = AttemptMachine.reduce(state, const AttemptRetryRequested());
      expect((state as AttemptSubmitting).pending.submissionId, submissionId);
    });

    test('reveals correctness only after authoritative feedback', () {
      var state = _presenting(fixtureSession());
      state = AttemptMachine.reduce(
        state,
        const AttemptOptionSelected('00000000-0000-4000-8000-000000000010'),
      );
      expect(state.revealsAnswerKey, isFalse);
      state = AttemptMachine.reduce(
        state,
        const AttemptSubmitRequested(submissionId),
      );
      expect(state.revealsAnswerKey, isFalse);
      state = AttemptMachine.reduce(
        state,
        AttemptSubmissionRecorded(fixtureFeedback()),
      );
      expect(state, isA<AttemptFeedback>());
      expect(state.revealsAnswerKey, isTrue);
    });
  });

  group('AttemptMachine typed-cloze flow', () {
    test('rejects option selection and option submission', () {
      final state = _presenting(fixtureTypedSession());

      expect(
        () =>
            AttemptMachine.reduce(state, const AttemptOptionSelected('option')),
        throwsA(isA<IllegalAttemptTransition>()),
      );
      expect(
        () => AttemptMachine.reduce(
          state,
          const AttemptSubmitRequested(submissionId),
        ),
        throwsA(isA<IllegalAttemptTransition>()),
      );
    });

    test('network retry preserves one in-memory answer and submission ID', () {
      const raw = 'transient private answer';
      final input = TypedAnswerInput(raw);
      AttemptState state = AttemptMachine.reduce(
        _presenting(fixtureTypedSession()),
        AttemptTypedSubmitRequested(submissionId, input),
      );
      state = AttemptMachine.reduce(
        state,
        const AttemptSubmissionFailed(NetworkFailure()),
      );
      final recovery = state as AttemptRecovery;
      final pending = (recovery.recovery as SubmissionRecoveryContext).pending;

      state = AttemptMachine.reduce(state, const AttemptRetryRequested());
      final retried = state as AttemptSubmitting;
      expect(identical(retried.pending, pending), isTrue);
      expect(identical(retried.pending.input, input), isTrue);
      expect(retried.pending.submissionId, submissionId);
      expect(
        (retried.pending.input as TypedAnswerInput).rawValueForSubmission,
        raw,
      );
    });

    test('validation rejection drops raw text and reserves the same ID', () {
      const raw = 'rejected private answer';
      AttemptState state = AttemptMachine.reduce(
        _presenting(fixtureTypedSession()),
        AttemptTypedSubmitRequested(submissionId, TypedAnswerInput(raw)),
      );

      state = AttemptMachine.reduce(
        state,
        const AttemptSubmissionFailed(
          ValidationFailure(code: 'INVALID_ANSWER'),
        ),
      );

      final presenting = state as AttemptPresenting;
      expect(presenting.resumeSubmissionId, submissionId);
      expect(presenting.selectedOptionId, isNull);
      expect(presenting.toString(), isNot(contains(raw)));
    });

    test('option validation rejection retains the fail-closed behavior', () {
      AttemptState state = _presenting(fixtureSession());
      state = AttemptMachine.reduce(
        state,
        const AttemptOptionSelected('00000000-0000-4000-8000-000000000010'),
      );
      state = AttemptMachine.reduce(
        state,
        const AttemptSubmitRequested(submissionId),
      );

      state = AttemptMachine.reduce(
        state,
        const AttemptSubmissionFailed(ValidationFailure()),
      );

      expect(state, isA<AttemptFatal>());
    });

    test('authoritative typed feedback drops the submitted raw value', () {
      const raw = 'never keep this after feedback';
      AttemptState state = AttemptMachine.reduce(
        _presenting(fixtureTypedSession()),
        AttemptTypedSubmitRequested(submissionId, TypedAnswerInput(raw)),
      );

      state = AttemptMachine.reduce(
        state,
        AttemptSubmissionRecorded(fixtureTypedFeedback()),
      );

      final feedback = state as AttemptFeedback;
      expect(feedback.answerKind, AnswerKind.typed);
      expect(feedback.selectedOptionId, isNull);
      expect(feedback.feedback.correctOptionId, isNull);
      expect(feedback.feedback.correctAnswerText, isNotEmpty);
      expect(feedback.toString(), isNot(contains(raw)));
    });

    test('rejects a response from the wrong authoritative answer branch', () {
      AttemptState state = AttemptMachine.reduce(
        _presenting(fixtureTypedSession()),
        AttemptTypedSubmitRequested(
          submissionId,
          TypedAnswerInput('private answer'),
        ),
      );

      state = AttemptMachine.reduce(
        state,
        AttemptSubmissionRecorded(fixtureFeedback()),
      );

      expect(state, isA<AttemptFatal>());
      expect((state as AttemptFatal).failure, isA<ProtocolFailure>());
    });

    test('missing process-restored record requests blank re-entry', () {
      AttemptState state = AttemptMachine.reduce(
        _presenting(fixtureTypedSession()),
        const AttemptReconciliationRequested(
          submissionId: submissionId,
          answerKind: AnswerKind.typed,
        ),
      );

      state = AttemptMachine.reduce(
        state,
        const AttemptReconciliationMissing(),
      );

      final presenting = state as AttemptPresenting;
      expect(presenting.resumeSubmissionId, submissionId);
      expect(presenting.selectedOptionId, isNull);
    });
  });

  group('AttemptMachine matching flow', () {
    test('builds, removes, and completes a two-stage matching draft', () {
      AttemptState state = _presenting(fixtureMatchingSession());
      expect(
        () => AttemptMachine.reduce(
          state,
          const AttemptMatchingSupportSelected(supportItemOneId),
        ),
        throwsA(isA<IllegalAttemptTransition>()),
      );

      state = AttemptMachine.reduce(
        state,
        const AttemptMatchingTargetSelected(targetItemOneId),
      );
      expect(
        (state as AttemptPresenting).matchingDraft.activeTargetItemId,
        targetItemOneId,
      );
      state = AttemptMachine.reduce(
        state,
        const AttemptMatchingSupportSelected(supportItemOneId),
      );
      expect((state as AttemptPresenting).matchingDraft.pairs, hasLength(1));
      expect(state.matchingDraft.toString(), isNot(contains(targetItemOneId)));

      state = _addMatchingPair(state, targetItemTwoId, supportItemTwoId);
      expect(
        (state as AttemptPresenting).matchingDraft.isCompleteFor(
          state.question,
        ),
        isTrue,
      );

      state = AttemptMachine.reduce(
        state,
        const AttemptMatchingPairRemoved(targetItemOneId),
      );
      expect((state as AttemptPresenting).matchingDraft.pairs, hasLength(1));
      expect(state.matchingDraft.isCompleteFor(state.question), isFalse);

      state = _addMatchingPair(state, targetItemOneId, supportItemOneId);
      state = AttemptMachine.reduce(
        state,
        const AttemptMatchingSubmitRequested(submissionId),
      );

      final submitting = state as AttemptSubmitting;
      final answer = submitting.pending.input as MatchingAnswerInput;
      expect(answer.hasExactCoverageOf(submitting.question), isTrue);
      expect(answer.hasSameMappingAs(fixtureCorrectMatches()), isTrue);
      expect(submitting.pending.submissionId, submissionId);
    });

    test('rejects incomplete drafts and reuse of a paired item', () {
      AttemptState state = _presenting(fixtureMatchingSession());
      state = _addMatchingPair(state, targetItemOneId, supportItemOneId);

      expect(
        () => AttemptMachine.reduce(
          state,
          const AttemptMatchingSubmitRequested(submissionId),
        ),
        throwsA(isA<IllegalAttemptTransition>()),
      );
      expect(
        () => AttemptMachine.reduce(
          state,
          const AttemptMatchingTargetSelected(targetItemOneId),
        ),
        throwsA(isA<IllegalAttemptTransition>()),
      );

      state = AttemptMachine.reduce(
        state,
        const AttemptMatchingTargetSelected(targetItemTwoId),
      );
      expect(
        () => AttemptMachine.reduce(
          state,
          const AttemptMatchingSupportSelected(supportItemOneId),
        ),
        throwsA(isA<IllegalAttemptTransition>()),
      );
    });

    test('keeps submitted mapping only for live authoritative feedback', () {
      final submitting = _submittingMatching(fixtureCorrectMatches());
      final liveInput = submitting.pending.input as MatchingAnswerInput;

      final state = AttemptMachine.reduce(
        submitting,
        AttemptSubmissionRecorded(fixtureMatchingFeedback()),
      );

      final feedback = state as AttemptFeedback;
      expect(identical(feedback.submittedMatches, liveInput), isTrue);
      expect(feedback.feedback.correctMatches, hasLength(2));
      expect(feedback.revealsAnswerKey, isTrue);
      expect(feedback.toString(), isNot(contains(targetItemOneId)));
    });

    test('validates correctness against the live submitted mapping', () {
      final incorrect = _submittingMatching(fixtureIncorrectMatches());
      final accepted = AttemptMachine.reduce(
        incorrect,
        AttemptSubmissionRecorded(fixtureMatchingFeedback(correct: false)),
      );
      expect(accepted, isA<AttemptFeedback>());

      final rejected = AttemptMachine.reduce(
        _submittingMatching(fixtureIncorrectMatches()),
        AttemptSubmissionRecorded(fixtureMatchingFeedback(correct: true)),
      );
      expect(rejected, isA<AttemptFatal>());
      expect((rejected as AttemptFatal).failure, isA<ProtocolFailure>());
    });

    test('requires exact authoritative correctMatches coverage', () {
      final wrongCoverage = [
        MatchingPair(
          targetItemId: targetItemOneId,
          supportItemId: supportItemOneId,
        ),
        MatchingPair(
          targetItemId: targetItemTwoId,
          supportItemId: '00000000-0000-4000-8000-000000000499',
        ),
      ];

      final state = AttemptMachine.reduce(
        _submittingMatching(fixtureCorrectMatches()),
        AttemptSubmissionRecorded(
          fixtureMatchingFeedback(correctMatches: wrongCoverage),
        ),
      );

      expect(state, isA<AttemptFatal>());
      expect((state as AttemptFatal).failure, isA<ProtocolFailure>());
    });

    test(
      'validation and payload-size failures return a blank same-ID board',
      () {
        for (final failure in <AppFailure>[
          const ValidationFailure(code: 'INVALID_MATCHES'),
          const ServerFailure(status: 413),
        ]) {
          final state = AttemptMachine.reduce(
            _submittingMatching(fixtureCorrectMatches()),
            AttemptSubmissionFailed(failure),
          );

          final presenting = state as AttemptPresenting;
          expect(presenting.resumeSubmissionId, submissionId);
          expect(presenting.matchingDraft.pairs, isEmpty);
          expect(presenting.matchingDraft.activeTargetItemId, isNull);
        }
      },
    );

    test('retryable failure performs GET before one exact same-ID resend', () {
      final firstSubmission = _submittingMatching(fixtureCorrectMatches());
      final originalInput = firstSubmission.pending.input;
      AttemptState state = AttemptMachine.reduce(
        firstSubmission,
        const AttemptSubmissionFailed(NetworkFailure()),
      );

      final recovery = state as AttemptRecovery;
      final recoveryContext =
          recovery.recovery as ReconciliationRecoveryContext;
      expect(
        identical(recoveryContext.pending, firstSubmission.pending),
        isTrue,
      );

      state = AttemptMachine.reduce(state, const AttemptRetryRequested());
      final reconciling = state as AttemptReconciling;
      expect(reconciling.submissionId, submissionId);
      expect(identical(reconciling.pending, firstSubmission.pending), isTrue);

      state = AttemptMachine.reduce(
        state,
        const AttemptReconciliationMissing(),
      );
      final resend = state as AttemptSubmitting;
      expect(resend.pending.submissionId, submissionId);
      expect(identical(resend.pending.input, originalInput), isTrue);
      expect(resend.pending.matchingResendUsed, isTrue);

      state = AttemptMachine.reduce(
        resend,
        const AttemptSubmissionFailed(NetworkFailure()),
      );
      state = AttemptMachine.reduce(state, const AttemptRetryRequested());
      state = AttemptMachine.reduce(
        state,
        const AttemptReconciliationMissing(),
      );
      expect(state, isA<AttemptFatal>());
    });

    test('conflict GET miss is fatal without resubmission', () {
      final submitting = _submittingMatching(fixtureCorrectMatches());
      AttemptState state = AttemptMachine.reduce(
        submitting,
        AttemptReconciliationRequested(
          submissionId: submissionId,
          answerKind: AnswerKind.matching,
          pending: submitting.pending,
          originalFailure: const ConflictFailure(code: 'IDEMPOTENCY'),
        ),
      );

      state = AttemptMachine.reduce(
        state,
        const AttemptReconciliationMissing(),
      );

      expect(state, isA<AttemptFatal>());
      expect((state as AttemptFatal).failure, isA<ConflictFailure>());
    });

    test('cold GET hit gives degraded feedback without submitted pairs', () {
      AttemptState state = AttemptMachine.reduce(
        _presenting(fixtureMatchingSession()),
        const AttemptReconciliationRequested(
          submissionId: submissionId,
          answerKind: AnswerKind.matching,
        ),
      );

      state = AttemptMachine.reduce(
        state,
        AttemptReconciliationRecorded(fixtureMatchingFeedback()),
      );

      final feedback = state as AttemptFeedback;
      expect(feedback.submittedMatches, isNull);
      expect(feedback.feedback.correctMatches, hasLength(2));
    });

    test('cold GET miss gives a blank board with the same reserved ID', () {
      AttemptState state = AttemptMachine.reduce(
        _presenting(fixtureMatchingSession()),
        const AttemptReconciliationRequested(
          submissionId: submissionId,
          answerKind: AnswerKind.matching,
        ),
      );

      state = AttemptMachine.reduce(
        state,
        const AttemptReconciliationMissing(),
      );

      final presenting = state as AttemptPresenting;
      expect(presenting.resumeSubmissionId, submissionId);
      expect(presenting.matchingDraft.pairs, isEmpty);
      expect(presenting.matchingDraft.activeTargetItemId, isNull);
    });
  });
}

AttemptState _presenting(AttemptSession session) => AttemptMachine.reduce(
  const AttemptLoading(
    testId: testId,
    startCommandId: '00000000-0000-4000-8000-000000000020',
  ),
  AttemptLoaded(session),
);

AttemptState _addMatchingPair(
  AttemptState state,
  String targetItemId,
  String supportItemId,
) {
  state = AttemptMachine.reduce(
    state,
    AttemptMatchingTargetSelected(targetItemId),
  );
  return AttemptMachine.reduce(
    state,
    AttemptMatchingSupportSelected(supportItemId),
  );
}

AttemptSubmitting _submittingMatching(List<MatchingPair> pairs) {
  AttemptState state = _presenting(fixtureMatchingSession());
  for (final pair in pairs) {
    state = _addMatchingPair(state, pair.targetItemId, pair.supportItemId);
  }
  return AttemptMachine.reduce(
        state,
        const AttemptMatchingSubmitRequested(submissionId),
      )
      as AttemptSubmitting;
}
