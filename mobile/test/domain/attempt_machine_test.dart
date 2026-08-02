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
}

AttemptState _presenting(AttemptSession session) => AttemptMachine.reduce(
  const AttemptLoading(
    testId: testId,
    startCommandId: '00000000-0000-4000-8000-000000000020',
  ),
  AttemptLoaded(session),
);
