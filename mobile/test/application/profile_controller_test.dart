import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/application/auth_controller.dart';
import 'package:kelimio_mobile/application/profile_controller.dart';
import 'package:kelimio_mobile/application/providers.dart';
import 'package:kelimio_mobile/domain/auth/auth.dart';
import 'package:kelimio_mobile/domain/profile/profile.dart';

import '../support/test_doubles.dart';

void main() {
  test(
    'an uncertain profile setup retry reuses the command identifier',
    () async {
      final repository = RecordingProfileRepository(failFirstCompletion: true);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            RecordingAuthRepository(
              restoredSession: AuthSession(expiresAt: DateTime.utc(2030)),
            ),
          ),
          profileRepositoryProvider.overrideWithValue(repository),
          identifierFactoryProvider.overrideWithValue(
            SequenceIdentifierFactory(['setup-command-1']),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.future);
      final initial = await container.read(profileControllerProvider.future);
      expect(initial?.setupStatus, ProfileSetupStatus.required);

      const input = ProfileSetupInput(
        displayName: 'Profile User',
        appLocale: 'en',
        activeTargetLanguage: 'tr',
        preferredSupportLanguage: 'en',
        timeZone: 'Europe/Istanbul',
      );
      await container
          .read(profileControllerProvider.notifier)
          .completeSetup(input);
      expect(container.read(profileControllerProvider).hasError, isTrue);

      await container
          .read(profileControllerProvider.notifier)
          .completeSetup(input);
      expect(repository.commandIds, ['setup-command-1', 'setup-command-1']);
      expect(
        container.read(profileControllerProvider).requireValue?.setupStatus,
        ProfileSetupStatus.complete,
      );
    },
  );

  test(
    'a signed-out session cannot carry a pending command to another user',
    () async {
      final repository = RecordingProfileRepository(failFirstCompletion: true);
      final auth = RecordingAuthRepository(
        restoredSession: AuthSession(expiresAt: DateTime.utc(2030)),
      );
      final recovery = MemoryRecoveryStore();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          profileRepositoryProvider.overrideWithValue(repository),
          recoveryStoreProvider.overrideWith((ref) async => recovery),
          courseEditorRecoveryStoreProvider.overrideWithValue(
            MemoryCourseEditorRecoveryStore(),
          ),
          offlinePackageRepositoryProvider.overrideWithValue(
            RecordingOfflinePackageRepository(),
          ),
          identifierFactoryProvider.overrideWithValue(
            SequenceIdentifierFactory([
              'first-user-command',
              'next-user-command',
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.future);
      await container.read(profileControllerProvider.future);

      const input = ProfileSetupInput(
        displayName: 'Profile User',
        appLocale: 'en',
        activeTargetLanguage: 'tr',
        preferredSupportLanguage: 'en',
        timeZone: 'Europe/Istanbul',
      );
      await container
          .read(profileControllerProvider.notifier)
          .completeSetup(input);
      expect(container.read(profileControllerProvider).hasError, isTrue);

      await container.read(authControllerProvider.notifier).signOut();
      expect(await container.read(profileControllerProvider.future), isNull);
      await container.read(authControllerProvider.notifier).signIn();
      await container.read(profileControllerProvider.future);
      await container
          .read(profileControllerProvider.notifier)
          .completeSetup(input);

      expect(repository.commandIds, [
        'first-user-command',
        'next-user-command',
      ]);
    },
  );
}
