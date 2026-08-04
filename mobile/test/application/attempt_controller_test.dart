import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/application/attempt_controller.dart';
import 'package:kelimio_mobile/application/providers.dart';
import 'package:kelimio_mobile/domain/failures.dart';
import 'package:kelimio_mobile/domain/learning/attempt_machine.dart';
import 'package:kelimio_mobile/domain/learning/learning.dart';

import '../support/fixtures.dart';
import '../support/test_doubles.dart';

void main() {
  group('option answer controller flow', () {
    test('duplicate taps produce one network submission', () async {
      final response = Completer<AnswerFeedback>();
      final repository = RecordingLearningRepository(
        answerBehaviors: [(id, answer) => response.future],
      );
      final store = MemoryRecoveryStore();
      final container = _container(repository: repository, store: store);
      addTearDown(container.dispose);
      final controller = container.read(attemptControllerProvider.notifier);
      await controller.recoverOrStart(testId);
      controller.selectOption('00000000-0000-4000-8000-000000000010');

      final first = controller.submitSelected();
      final duplicate = controller.submitSelected();
      await Future<void>.delayed(Duration.zero);

      expect(repository.submittedIds, [submissionId]);
      expect(
        container.read(attemptControllerProvider),
        isA<AttemptSubmitting>(),
      );
      response.complete(fixtureFeedback());
      await Future.wait([first, duplicate]);
      expect(container.read(attemptControllerProvider), isA<AttemptFeedback>());
    });

    test('network retry reuses the original submissionId', () async {
      final repository = RecordingLearningRepository(
        answerBehaviors: [
          (id, answer) => Future<AnswerFeedback>.error(const NetworkFailure()),
          (id, answer) async => fixtureFeedback(id: id),
        ],
      );
      final store = MemoryRecoveryStore();
      final container = _container(repository: repository, store: store);
      addTearDown(container.dispose);
      final controller = container.read(attemptControllerProvider.notifier);
      await controller.recoverOrStart(testId);
      controller.selectOption('00000000-0000-4000-8000-000000000010');
      await controller.submitSelected();

      expect(container.read(attemptControllerProvider), isA<AttemptRecovery>());
      await controller.retry();

      expect(repository.submittedIds, [submissionId, submissionId]);
      expect(container.read(attemptControllerProvider), isA<AttemptFeedback>());
    });
  });

  group('typed answer controller flow', () {
    test(
      'network retry keeps raw text only in memory with the same ID',
      () async {
        const raw = 'private typed answer';
        final observedRaw = <String>[];
        final store = MemoryRecoveryStore();
        final repository = RecordingLearningRepository(
          session: fixtureTypedSession(),
          answerBehaviors: [
            (id, answer) {
              observedRaw.add(
                (answer as TypedAnswerInput).rawValueForSubmission,
              );
              expect(store.value?.answerKind, AnswerKind.typed);
              expect(store.value?.selectedOptionId, isNull);
              expect(store.value.toString(), isNot(contains(raw)));
              return Future<AnswerFeedback>.error(const NetworkFailure());
            },
            (id, answer) async {
              observedRaw.add(
                (answer as TypedAnswerInput).rawValueForSubmission,
              );
              return fixtureTypedFeedback(id: id);
            },
          ],
        );
        final container = _container(repository: repository, store: store);
        addTearDown(container.dispose);
        final controller = container.read(attemptControllerProvider.notifier);
        await controller.recoverOrStart(testId);

        await controller.submitTyped(raw);
        expect(
          container.read(attemptControllerProvider),
          isA<AttemptRecovery>(),
        );
        expect(store.value?.submissionId, submissionId);
        expect(store.value?.selectedOptionId, isNull);

        await controller.retry();

        expect(observedRaw, [raw, raw]);
        expect(repository.submittedIds, [submissionId, submissionId]);
        expect(repository.submittedKinds, [AnswerKind.typed, AnswerKind.typed]);
        expect(
          container.read(attemptControllerProvider),
          isA<AttemptFeedback>(),
        );
        expect(store.value?.phase, RecoveryPhase.feedback);
      },
    );

    test(
      '422 validation returns to blank re-entry with the same submission ID',
      () async {
        const rejectedRaw = 'rejected private answer';
        final observedRaw = <String>[];
        final store = MemoryRecoveryStore();
        final repository = RecordingLearningRepository(
          session: fixtureTypedSession(),
          answerBehaviors: [
            (id, answer) {
              observedRaw.add(
                (answer as TypedAnswerInput).rawValueForSubmission,
              );
              return Future<AnswerFeedback>.error(
                const ValidationFailure(code: 'INVALID_ANSWER'),
              );
            },
            (id, answer) async {
              observedRaw.add(
                (answer as TypedAnswerInput).rawValueForSubmission,
              );
              return fixtureTypedFeedback(id: id);
            },
          ],
        );
        final container = _container(repository: repository, store: store);
        addTearDown(container.dispose);
        final controller = container.read(attemptControllerProvider.notifier);
        await controller.recoverOrStart(testId);

        await controller.submitTyped(rejectedRaw);

        final presenting = container.read(attemptControllerProvider);
        expect(presenting, isA<AttemptPresenting>());
        expect(
          (presenting as AttemptPresenting).resumeSubmissionId,
          submissionId,
        );
        expect(presenting.selectedOptionId, isNull);
        expect(presenting.toString(), isNot(contains(rejectedRaw)));
        expect(store.value?.phase, RecoveryPhase.presenting);
        expect(store.value?.answerKind, AnswerKind.typed);
        expect(store.value?.submissionId, submissionId);
        expect(store.value?.selectedOptionId, isNull);
        expect(store.value.toString(), isNot(contains(rejectedRaw)));

        await controller.submitTyped('fresh re-entry');

        expect(repository.submittedIds, [submissionId, submissionId]);
        expect(observedRaw, [rejectedRaw, 'fresh re-entry']);
        expect(
          container.read(attemptControllerProvider),
          isA<AttemptFeedback>(),
        );
      },
    );

    test(
      'process death reconciles a recorded typed answer without POST',
      () async {
        final store = MemoryRecoveryStore()
          ..value = fixtureRecovery(
            RecoveryPhase.submitting,
            answerKind: AnswerKind.typed,
            recoveredSubmissionId: submissionId,
          );
        final repository = RecordingLearningRepository(
          session: fixtureTypedSession(),
          answerBehaviors: const [],
          recordedAnswerBehaviors: [(id) async => fixtureTypedFeedback(id: id)],
        );
        final container = _container(
          repository: repository,
          store: store,
          identifierValues: const [],
        );
        addTearDown(container.dispose);

        await container
            .read(attemptControllerProvider.notifier)
            .recoverOrStart(testId);

        final state = container.read(attemptControllerProvider);
        expect(state, isA<AttemptFeedback>());
        expect(
          (state as AttemptFeedback).feedback.correctAnswerText,
          isNotNull,
        );
        expect(repository.submittedIds, isEmpty);
        expect(repository.reconciliationIds, [submissionId]);
      },
    );

    test(
      'missing recovered record asks for blank input with the same ID',
      () async {
        final store = MemoryRecoveryStore()
          ..value = fixtureRecovery(
            RecoveryPhase.feedback,
            answerKind: AnswerKind.typed,
            recoveredSubmissionId: submissionId,
          );
        final repository = RecordingLearningRepository(
          session: fixtureTypedSession(),
          answerBehaviors: [(id, answer) async => fixtureTypedFeedback(id: id)],
          recordedAnswerBehaviors: [(id) async => null],
        );
        final container = _container(
          repository: repository,
          store: store,
          identifierValues: const [],
        );
        addTearDown(container.dispose);
        final controller = container.read(attemptControllerProvider.notifier);

        await controller.recoverOrStart(testId);

        final presenting = container.read(attemptControllerProvider);
        expect(presenting, isA<AttemptPresenting>());
        expect(
          (presenting as AttemptPresenting).resumeSubmissionId,
          submissionId,
        );
        expect(presenting.selectedOptionId, isNull);
        expect(store.value?.phase, RecoveryPhase.presenting);
        expect(store.value?.submissionId, submissionId);

        await controller.submitTyped('fresh re-entry');

        expect(repository.submittedIds, [submissionId]);
        expect(
          container.read(attemptControllerProvider),
          isA<AttemptFeedback>(),
        );
      },
    );

    test(
      'submission conflict reconciles the committed server answer',
      () async {
        final store = MemoryRecoveryStore();
        final repository = RecordingLearningRepository(
          session: fixtureTypedSession(),
          answerBehaviors: [
            (id, answer) => Future<AnswerFeedback>.error(
              const ConflictFailure(code: 'submission_conflict'),
            ),
          ],
          recordedAnswerBehaviors: [(id) async => fixtureTypedFeedback(id: id)],
        );
        final container = _container(repository: repository, store: store);
        addTearDown(container.dispose);
        final controller = container.read(attemptControllerProvider.notifier);
        await controller.recoverOrStart(testId);

        await controller.submitTyped('private answer');

        expect(repository.submittedIds, [submissionId]);
        expect(repository.reconciliationIds, [submissionId]);
        expect(
          container.read(attemptControllerProvider),
          isA<AttemptFeedback>(),
        );
      },
    );
  });

  group('matching answer controller flow', () {
    test('two-stage actions submit one complete transient mapping', () async {
      final store = MemoryRecoveryStore();
      final repository = RecordingLearningRepository(
        session: fixtureMatchingSession(),
        answerBehaviors: [
          (id, answer) async {
            expect(answer, isA<MatchingAnswerInput>());
            expect(
              (answer as MatchingAnswerInput).hasSameMappingAs(
                fixtureCorrectMatches(),
              ),
              isTrue,
            );
            expect(store.value?.answerKind, AnswerKind.matching);
            expect(store.value?.selectedOptionId, isNull);
            expect(store.value.toString(), isNot(contains(targetItemOneId)));
            expect(store.value.toString(), isNot(contains(supportItemOneId)));
            return fixtureMatchingFeedback(id: id);
          },
        ],
      );
      final container = _container(repository: repository, store: store);
      addTearDown(container.dispose);
      final controller = container.read(attemptControllerProvider.notifier);
      await controller.recoverOrStart(testId);

      controller.selectMatchingTarget(targetItemOneId);
      controller.selectMatchingSupport(supportItemOneId);
      controller.removeMatchingPair(targetItemOneId);
      _completeMatching(controller);
      await controller.submitMatching();

      final state = container.read(attemptControllerProvider);
      expect(state, isA<AttemptFeedback>());
      expect((state as AttemptFeedback).submittedMatches, isNotNull);
      expect(repository.submittedIds, [submissionId]);
      expect(repository.submittedKinds, [AnswerKind.matching]);
      expect(store.value?.phase, RecoveryPhase.feedback);
      expect(store.value?.selectedOptionId, isNull);
      expect(store.value.toString(), isNot(contains(targetItemOneId)));
    });

    test('retry performs GET then one exact same-ID resend', () async {
      final store = MemoryRecoveryStore();
      final repository = RecordingLearningRepository(
        session: fixtureMatchingSession(),
        answerBehaviors: [
          (id, answer) => Future<AnswerFeedback>.error(const NetworkFailure()),
          (id, answer) async => fixtureMatchingFeedback(id: id),
        ],
        recordedAnswerBehaviors: [(id) async => null],
      );
      final container = _container(repository: repository, store: store);
      addTearDown(container.dispose);
      final controller = container.read(attemptControllerProvider.notifier);
      await controller.recoverOrStart(testId);
      _completeMatching(controller);

      await controller.submitMatching();
      expect(container.read(attemptControllerProvider), isA<AttemptRecovery>());

      await controller.retry();

      expect(repository.reconciliationIds, [submissionId]);
      expect(repository.submittedIds, [submissionId, submissionId]);
      expect(
        identical(
          repository.submittedAnswers.first,
          repository.submittedAnswers.last,
        ),
        isTrue,
      );
      expect(container.read(attemptControllerProvider), isA<AttemptFeedback>());
    });

    test('a retry cannot resend the matching mapping twice', () async {
      final repository = RecordingLearningRepository(
        session: fixtureMatchingSession(),
        answerBehaviors: [
          (id, answer) => Future<AnswerFeedback>.error(const NetworkFailure()),
          (id, answer) => Future<AnswerFeedback>.error(const NetworkFailure()),
        ],
        recordedAnswerBehaviors: [(id) async => null, (id) async => null],
      );
      final container = _container(
        repository: repository,
        store: MemoryRecoveryStore(),
      );
      addTearDown(container.dispose);
      final controller = container.read(attemptControllerProvider.notifier);
      await controller.recoverOrStart(testId);
      _completeMatching(controller);

      await controller.submitMatching();
      await controller.retry();
      expect(container.read(attemptControllerProvider), isA<AttemptRecovery>());
      await controller.retry();

      expect(repository.reconciliationIds, [submissionId, submissionId]);
      expect(repository.submittedIds, [submissionId, submissionId]);
      expect(container.read(attemptControllerProvider), isA<AttemptFatal>());
    });

    test('GET hit after a retryable failure never resends', () async {
      final repository = RecordingLearningRepository(
        session: fixtureMatchingSession(),
        answerBehaviors: [
          (id, answer) => Future<AnswerFeedback>.error(const NetworkFailure()),
        ],
        recordedAnswerBehaviors: [
          (id) async => fixtureMatchingFeedback(id: id),
        ],
      );
      final container = _container(
        repository: repository,
        store: MemoryRecoveryStore(),
      );
      addTearDown(container.dispose);
      final controller = container.read(attemptControllerProvider.notifier);
      await controller.recoverOrStart(testId);
      _completeMatching(controller);

      await controller.submitMatching();
      await controller.retry();

      expect(repository.reconciliationIds, [submissionId]);
      expect(repository.submittedIds, [submissionId]);
      expect(container.read(attemptControllerProvider), isA<AttemptFeedback>());
    });

    test(
      'cold GET hit degrades without reconstructing submitted pairs',
      () async {
        final store = MemoryRecoveryStore()
          ..value = fixtureRecovery(
            RecoveryPhase.submitting,
            answerKind: AnswerKind.matching,
            recoveredSubmissionId: submissionId,
          );
        final repository = RecordingLearningRepository(
          session: fixtureMatchingSession(),
          answerBehaviors: const [],
          recordedAnswerBehaviors: [
            (id) async => fixtureMatchingFeedback(id: id),
          ],
        );
        final container = _container(
          repository: repository,
          store: store,
          identifierValues: const [],
        );
        addTearDown(container.dispose);

        await container
            .read(attemptControllerProvider.notifier)
            .recoverOrStart(testId);

        final state = container.read(attemptControllerProvider);
        expect(state, isA<AttemptFeedback>());
        expect((state as AttemptFeedback).submittedMatches, isNull);
        expect(state.feedback.correctMatches, hasLength(2));
        expect(repository.submittedIds, isEmpty);
        expect(repository.reconciliationIds, [submissionId]);
        expect(store.value.toString(), isNot(contains(targetItemOneId)));
      },
    );

    test('cold GET miss returns a blank same-ID board', () async {
      final store = MemoryRecoveryStore()
        ..value = fixtureRecovery(
          RecoveryPhase.feedback,
          answerKind: AnswerKind.matching,
          recoveredSubmissionId: submissionId,
        );
      final repository = RecordingLearningRepository(
        session: fixtureMatchingSession(),
        answerBehaviors: [
          (id, answer) async => fixtureMatchingFeedback(id: id),
        ],
        recordedAnswerBehaviors: [(id) async => null],
      );
      final container = _container(
        repository: repository,
        store: store,
        identifierValues: const [],
      );
      addTearDown(container.dispose);
      final controller = container.read(attemptControllerProvider.notifier);

      await controller.recoverOrStart(testId);

      final presenting = container.read(attemptControllerProvider);
      expect(presenting, isA<AttemptPresenting>());
      expect(
        (presenting as AttemptPresenting).resumeSubmissionId,
        submissionId,
      );
      expect(presenting.matchingDraft.pairs, isEmpty);
      expect(presenting.matchingDraft.activeTargetItemId, isNull);
      expect(store.value?.answerKind, AnswerKind.matching);
      expect(store.value?.selectedOptionId, isNull);

      _completeMatching(controller);
      await controller.submitMatching();

      expect(repository.submittedIds, [submissionId]);
      expect(container.read(attemptControllerProvider), isA<AttemptFeedback>());
    });

    test(
      'cold private submission without MATCHING kind fails closed',
      () async {
        final store = MemoryRecoveryStore()
          ..value = fixtureRecovery(
            RecoveryPhase.presenting,
            recoveredSubmissionId: submissionId,
          );
        final repository = RecordingLearningRepository(
          session: fixtureMatchingSession(),
          answerBehaviors: const [],
        );
        final container = _container(
          repository: repository,
          store: store,
          identifierValues: const [],
        );
        addTearDown(container.dispose);

        await container
            .read(attemptControllerProvider.notifier)
            .recoverOrStart(testId);

        expect(container.read(attemptControllerProvider), isA<AttemptFatal>());
        expect(repository.submittedIds, isEmpty);
        expect(repository.reconciliationIds, isEmpty);
        expect(store.value, isNull);
      },
    );
  });
}

void _completeMatching(AttemptController controller) {
  controller.selectMatchingTarget(targetItemOneId);
  controller.selectMatchingSupport(supportItemOneId);
  controller.selectMatchingTarget(targetItemTwoId);
  controller.selectMatchingSupport(supportItemTwoId);
}

ProviderContainer _container({
  required RecordingLearningRepository repository,
  required MemoryRecoveryStore store,
  List<String> identifierValues = const [
    '00000000-0000-4000-8000-000000000020',
    submissionId,
  ],
}) => ProviderContainer(
  overrides: [
    learningRepositoryProvider.overrideWithValue(repository),
    recoveryStoreProvider.overrideWith((ref) async => store),
    identifierFactoryProvider.overrideWithValue(
      SequenceIdentifierFactory(identifierValues),
    ),
  ],
);
