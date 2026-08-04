import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/application/course_authoring_controller.dart';
import 'package:kelimio_mobile/application/providers.dart';
import 'package:kelimio_mobile/core/config/app_config.dart';
import 'package:kelimio_mobile/domain/course_authoring/course_authoring.dart';
import 'package:kelimio_mobile/domain/failures.dart';

import '../support/course_authoring_fixtures.dart';
import '../support/test_doubles.dart';

void main() {
  test(
    'uncertain upload retry reuses commands and preserves explicit gates',
    () async {
      final repository = RecordingCourseAuthoringRepository(
        failFirstUpload: true,
      );
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_config),
          workbookPickerProvider.overrideWithValue(const StubWorkbookPicker()),
          courseAuthoringRepositoryProvider.overrideWithValue(repository),
          identifierFactoryProvider.overrideWithValue(
            SequenceIdentifierFactory([
              '00000000-0000-4000-8000-000000000001',
              '00000000-0000-4000-8000-000000000002',
              '00000000-0000-4000-8000-000000000003',
              '00000000-0000-4000-8000-000000000004',
              '00000000-0000-4000-8000-000000000005',
            ]),
          ),
          courseAuthoringPollDelayProvider.overrideWithValue(Duration.zero),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        courseAuthoringControllerProvider.notifier,
      );

      await controller.selectAndUpload();
      expect(
        container.read(courseAuthoringControllerProvider).error,
        isA<NetworkFailure>(),
      );

      await controller.retry();
      var state = container.read(courseAuthoringControllerProvider);
      expect(repository.uploadCommands, [
        (
          '00000000-0000-4000-8000-000000000001',
          '00000000-0000-4000-8000-000000000002',
        ),
        (
          '00000000-0000-4000-8000-000000000001',
          '00000000-0000-4000-8000-000000000002',
        ),
      ]);
      expect(state.importSummary?.status, CourseImportStatus.previewReady);
      expect(state.previewRows, hasLength(1));

      await controller.approve();
      expect(repository.approvalCommands, isEmpty);
      controller.acknowledgePreview(true);
      await controller.approve();
      state = container.read(courseAuthoringControllerProvider);
      expect(state.importSummary?.status, CourseImportStatus.approved);
      expect(repository.approvalCommands, [
        '00000000-0000-4000-8000-000000000003',
      ]);

      await controller.commitDraft();
      expect(repository.commitCommands, isEmpty);
      controller.acknowledgeDraftCreation(true);
      await controller.commitDraft();
      state = container.read(courseAuthoringControllerProvider);
      expect(state.impact?.targetQuestionCount, 14);
      expect(repository.commitCommands, [
        '00000000-0000-4000-8000-000000000004',
      ]);

      await controller.activateRelease();
      expect(repository.activationCommands, isEmpty);
      controller.acknowledgeImpact(true);
      await controller.activateRelease();
      state = container.read(courseAuthoringControllerProvider);
      expect(state.activation?.releaseId, draftReleaseId);
      expect(repository.activationCommands, [
        '00000000-0000-4000-8000-000000000005',
      ]);
    },
  );

  test(
    'discovers and resumes a review after controller state is lost',
    () async {
      final resumable = courseImportSummary(CourseImportStatus.previewReady);
      final repository = RecordingCourseAuthoringRepository(
        importToGet: resumable,
        importsToDiscover: [resumable],
      );
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_config),
          workbookPickerProvider.overrideWithValue(const StubWorkbookPicker()),
          courseAuthoringRepositoryProvider.overrideWithValue(repository),
          courseAuthoringPollDelayProvider.overrideWithValue(Duration.zero),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        courseAuthoringControllerProvider.notifier,
      );

      await controller.discoverImports();
      var state = container.read(courseAuthoringControllerProvider);
      expect(repository.listCalls, 1);
      expect(state.discoveredImports, [resumable]);

      await controller.resumeImport(resumable);
      state = container.read(courseAuthoringControllerProvider);
      expect(state.importSummary?.id, courseImportId);
      expect(state.previewRows, hasLength(1));
      expect(state.activity, CourseAuthoringActivity.idle);
    },
  );

  test(
    'discovered publication evidence prevents a second activation',
    () async {
      final published = courseImportSummary(
        CourseImportStatus.committed,
        activation: CourseImportActivationSummary(
          releaseId: draftReleaseId,
          operation: CourseReleaseOperation.initialPublication,
          activatedAt: DateTime.utc(2026, 8, 2, 9),
          reprojectionStatus: 'PENDING',
        ),
      );
      final repository = RecordingCourseAuthoringRepository(
        importToGet: published,
        importsToDiscover: [published],
      );
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_config),
          workbookPickerProvider.overrideWithValue(const StubWorkbookPicker()),
          courseAuthoringRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        courseAuthoringControllerProvider.notifier,
      );

      await controller.discoverImports();
      await controller.resumeImport(published);
      final state = container.read(courseAuthoringControllerProvider);

      expect(state.importSummary?.activation, isNotNull);
      expect(state.impact, isNull);
      expect(state.activation, isNull);
      expect(repository.activationCommands, isEmpty);
    },
  );
}

final _config = AppConfig(
  apiBaseUri: Uri.parse('http://localhost:8080'),
  oidcIssuer: Uri.parse('http://localhost:8081/realms/kelimio'),
  oidcClientId: 'kelimio-mobile',
  redirectUri: 'com.kelimio.app:/oauthredirect',
  postLogoutRedirectUri: 'com.kelimio.app:/logout',
  isProduction: false,
  localDevelopmentToolsEnabled: true,
);
