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
  test('duplicate taps produce one network submission', () async {
    final response = Completer<AnswerFeedback>();
    final repository = RecordingLearningRepository(
      answerBehaviors: [(id) => response.future],
    );
    final store = MemoryRecoveryStore();
    final container = ProviderContainer(
      overrides: [
        learningRepositoryProvider.overrideWithValue(repository),
        recoveryStoreProvider.overrideWith((ref) async => store),
        identifierFactoryProvider.overrideWithValue(
          SequenceIdentifierFactory(const [
            '00000000-0000-4000-8000-000000000020',
            submissionId,
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(attemptControllerProvider.notifier);
    await controller.recoverOrStart(testId);
    controller.selectOption('00000000-0000-4000-8000-000000000010');

    final first = controller.submitSelected();
    final duplicate = controller.submitSelected();
    await Future<void>.delayed(Duration.zero);

    expect(repository.submittedIds, [submissionId]);
    expect(container.read(attemptControllerProvider), isA<AttemptSubmitting>());
    response.complete(fixtureFeedback());
    await Future.wait([first, duplicate]);
    expect(container.read(attemptControllerProvider), isA<AttemptFeedback>());
  });

  test('network retry reuses the original submissionId', () async {
    final repository = RecordingLearningRepository(
      answerBehaviors: [
        (id) => Future<AnswerFeedback>.error(const NetworkFailure()),
        (id) async => fixtureFeedback(id: id),
      ],
    );
    final store = MemoryRecoveryStore();
    final container = ProviderContainer(
      overrides: [
        learningRepositoryProvider.overrideWithValue(repository),
        recoveryStoreProvider.overrideWith((ref) async => store),
        identifierFactoryProvider.overrideWithValue(
          SequenceIdentifierFactory(const [
            '00000000-0000-4000-8000-000000000020',
            submissionId,
          ]),
        ),
      ],
    );
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
}
