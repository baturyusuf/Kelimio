import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/application/providers.dart';
import 'package:kelimio_mobile/domain/catalog/catalog.dart';
import 'package:kelimio_mobile/domain/failures.dart';

import '../support/test_doubles.dart';

void main() {
  const courseId = '00000000-0000-4000-8000-000000000101';

  test('stops polling as soon as the projection is current', () async {
    final catalog = RecordingCatalogRepository(
      progressResults: [
        _progress(courseId, version: 1, updating: true),
        _progress(courseId, version: 2, updating: false),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(catalog),
        courseProgressRefreshDelaysProvider.overrideWithValue(const [
          Duration.zero,
          Duration.zero,
        ]),
      ],
    );
    addTearDown(container.dispose);
    final ready = Completer<CourseProgress>();
    final subscription = container.listen(courseProgressProvider(courseId), (
      previous,
      next,
    ) {
      if (next.hasValue && !next.requireValue.updating && !ready.isCompleted) {
        ready.complete(next.requireValue);
      }
    });
    addTearDown(subscription.close);

    expect((await ready.future).projectionVersion, 2);
    expect(catalog.progressCalls, 2);
  });

  test('surfaces retryable timeout after bounded projection polling', () async {
    final catalog = RecordingCatalogRepository(
      progressResults: [
        _progress(courseId, version: 1, updating: true),
        _progress(courseId, version: 1, updating: true),
        _progress(courseId, version: 1, updating: true),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(catalog),
        courseProgressRefreshDelaysProvider.overrideWithValue(const [
          Duration.zero,
          Duration.zero,
        ]),
      ],
    );
    addTearDown(container.dispose);
    final failure = Completer<Object>();
    var sawFailure = false;
    var loadedAfterFailure = false;
    final subscription = container.listen(courseProgressProvider(courseId), (
      previous,
      next,
    ) {
      if (sawFailure && next.isLoading) {
        loadedAfterFailure = true;
      }
      if (next.hasError && !failure.isCompleted) {
        sawFailure = true;
        failure.complete(next.error!);
      }
    });
    addTearDown(subscription.close);

    expect(await failure.future, isA<TimeoutFailure>());
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(catalog.progressCalls, 3);
    expect(loadedAfterFailure, isFalse);
  });
}

CourseProgress _progress(
  String courseId, {
  required int version,
  required bool updating,
}) {
  return CourseProgress(
    courseId: courseId,
    answeredQuestions: version,
    correctAnswers: version,
    completedAttempts: 0,
    passedAttempts: 0,
    activeScore: version * 60,
    lifetimeScore: version * 60,
    projectionVersion: version,
    updating: updating,
    updatedAt: DateTime.utc(2026),
  );
}
