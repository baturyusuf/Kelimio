import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/application/auth_controller.dart';
import 'package:kelimio_mobile/application/providers.dart';
import 'package:kelimio_mobile/domain/auth/auth.dart';
import 'package:kelimio_mobile/domain/learning/learning.dart';

import '../support/fixtures.dart';
import '../support/test_doubles.dart';

void main() {
  test('signed-out restoration clears stale attempt recovery', () async {
    final store = MemoryRecoveryStore()
      ..value = fixtureRecovery(RecoveryPhase.presenting);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(RecordingAuthRepository()),
        recoveryStoreProvider.overrideWith((ref) async => store),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(authControllerProvider.future), isNull);
    expect(store.value, isNull);
    expect(store.clearCalls, 1);
  });

  test('sign out purges recovery before exposing a signed-out state', () async {
    final session = AuthSession(expiresAt: DateTime.utc(2030));
    final auth = RecordingAuthRepository(restoredSession: session);
    final store = MemoryRecoveryStore()
      ..value = fixtureRecovery(RecoveryPhase.submitting);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        recoveryStoreProvider.overrideWith((ref) async => store),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(authControllerProvider.future), same(session));
    await container.read(authControllerProvider.notifier).signOut();

    expect(auth.signOutCalls, 1);
    expect(store.value, isNull);
    expect(container.read(authControllerProvider).value, isNull);
  });

  test('sign out invalidates user-scoped course progress', () async {
    const courseId = '00000000-0000-4000-8000-000000000101';
    final session = AuthSession(expiresAt: DateTime.utc(2030));
    final catalog = RecordingCatalogRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          RecordingAuthRepository(restoredSession: session),
        ),
        catalogRepositoryProvider.overrideWithValue(catalog),
        recoveryStoreProvider.overrideWith(
          (ref) async => MemoryRecoveryStore(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final progress = courseProgressProvider(courseId);
    final subscription = container.listen(progress, (previous, next) {});
    addTearDown(subscription.close);

    expect(await container.read(authControllerProvider.future), same(session));
    expect((await container.read(progress.future)).projectionVersion, 1);

    await container.read(authControllerProvider.notifier).signOut();

    expect((await container.read(progress.future)).projectionVersion, 2);
    expect(catalog.progressCalls, 2);
  });
}
