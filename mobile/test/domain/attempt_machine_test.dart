import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/domain/failures.dart';
import 'package:kelimio_mobile/domain/learning/attempt_machine.dart';

import '../support/fixtures.dart';

void main() {
  group('AttemptMachine', () {
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
      final session = fixtureSession();
      AttemptState state = AttemptMachine.reduce(
        const AttemptLoading(
          testId: testId,
          startCommandId: '00000000-0000-4000-8000-000000000020',
        ),
        AttemptLoaded(session),
      );
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
      final session = fixtureSession();
      AttemptState state = AttemptMachine.reduce(
        const AttemptLoading(
          testId: testId,
          startCommandId: '00000000-0000-4000-8000-000000000020',
        ),
        AttemptLoaded(session),
      );
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
      expect(state, isA<AttemptRecovery>());

      state = AttemptMachine.reduce(state, const AttemptRetryRequested());
      final retried = state as AttemptSubmitting;
      expect(retried.pending.submissionId, submissionId);
    });

    test('reveals correctness only after authoritative feedback', () {
      final session = fixtureSession();
      AttemptState state = AttemptMachine.reduce(
        const AttemptLoading(
          testId: testId,
          startCommandId: '00000000-0000-4000-8000-000000000020',
        ),
        AttemptLoaded(session),
      );
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
}
