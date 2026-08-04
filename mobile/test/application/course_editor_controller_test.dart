import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/application/course_editor_controller.dart';
import 'package:kelimio_mobile/application/providers.dart';
import 'package:kelimio_mobile/core/config/app_config.dart';
import 'package:kelimio_mobile/domain/course_authoring/course_authoring.dart';

import '../support/course_authoring_fixtures.dart';
import '../support/test_doubles.dart';

void main() {
  test('restores and updates an unsaved prompt from secure recovery', () async {
    final recovery = MemoryCourseEditorRecoveryStore()
      ..value = LocalCourseEditorRecoveryDraft(
        courseId: authoredEditorDocument.courseId,
        baseReleaseId: authoredEditorDocument.activeReleaseId,
        questionRevisionId: authoredEditorDocument.questionRevisionId,
        entityTag: authoredEditorDocument.entityTag,
        originalPrompt: authoredEditorDocument.prompt,
        editedPrompt: 'Ben her sabah ---.',
        updatedAt: DateTime.utc(2026, 8, 2),
      );
    final container = _container(
      RecordingCourseAuthoringRepository(),
      recovery,
    );
    addTearDown(container.dispose);
    final controller = container.read(courseEditorControllerProvider.notifier);

    await controller.open(authoredCourseId);
    var state = container.read(courseEditorControllerProvider);
    expect(state.recoveryRestored, isTrue);
    expect(state.editedPrompt, 'Ben her sabah ---.');

    controller.updatePrompt('Ben her gece ---.');
    await Future<void>.delayed(Duration.zero);
    state = container.read(courseEditorControllerProvider);
    expect(state.dirty, isTrue);
    expect(recovery.value?.editedPrompt, 'Ben her gece ---.');
  });

  test('draft impact and publication remain separate gates', () async {
    final repository = RecordingCourseAuthoringRepository();
    final recovery = MemoryCourseEditorRecoveryStore();
    final container = _container(repository, recovery);
    addTearDown(container.dispose);
    final controller = container.read(courseEditorControllerProvider.notifier);

    await controller.open(authoredCourseId);
    controller.updatePrompt('Ben her sabah ---.');
    await controller.save();
    var state = container.read(courseEditorControllerProvider);

    expect(repository.editorPrompts, ['Ben her sabah ---.']);
    expect(state.impact?.changedQuestionCount, 1);
    expect(repository.activationCommands, isEmpty);
    await controller.activate();
    expect(repository.activationCommands, isEmpty);

    controller.acknowledgeImpact(true);
    await controller.activate();
    state = container.read(courseEditorControllerProvider);
    expect(state.activation?.operation, CourseReleaseOperation.publication);
    expect(recovery.value, isNull);
  });

  test('a stale ETag exposes three versions and requires reapply', () async {
    final repository = RecordingCourseAuthoringRepository(
      failFirstEditorDraftWithConflict: true,
      editorDocuments: [authoredEditorDocument, latestAuthoredEditorDocument],
    );
    final recovery = MemoryCourseEditorRecoveryStore();
    final container = _container(repository, recovery);
    addTearDown(container.dispose);
    final controller = container.read(courseEditorControllerProvider.notifier);

    await controller.open(authoredCourseId);
    controller.updatePrompt('Ben her sabah ---.');
    await controller.save();
    var state = container.read(courseEditorControllerProvider);
    expect(state.conflict?.originalPrompt, 'Ben her gun ---.');
    expect(state.conflict?.editedPrompt, 'Ben her sabah ---.');
    expect(state.conflict?.latestDocument.prompt, 'Ben her aksam ---.');

    await controller.reapplyMine();
    state = container.read(courseEditorControllerProvider);
    expect(state.document?.entityTag, latestAuthoredEditorDocument.entityTag);
    expect(state.editedPrompt, 'Ben her sabah ---.');
    await controller.save();
    expect(repository.editorDraftCommands, [
      '00000000-0000-4000-8000-000000000001',
      '00000000-0000-4000-8000-000000000002',
    ]);
  });
}

ProviderContainer _container(
  RecordingCourseAuthoringRepository repository,
  MemoryCourseEditorRecoveryStore recovery,
) => ProviderContainer(
  overrides: [
    appConfigProvider.overrideWithValue(_config),
    courseAuthoringRepositoryProvider.overrideWithValue(repository),
    courseEditorRecoveryStoreProvider.overrideWithValue(recovery),
    identifierFactoryProvider.overrideWithValue(
      SequenceIdentifierFactory([
        '00000000-0000-4000-8000-000000000001',
        '00000000-0000-4000-8000-000000000002',
        '00000000-0000-4000-8000-000000000003',
      ]),
    ),
  ],
);

final _config = AppConfig(
  apiBaseUri: Uri.parse('http://localhost:8080'),
  oidcIssuer: Uri.parse('http://localhost:8081/realms/kelimio'),
  oidcClientId: 'kelimio-mobile',
  redirectUri: 'com.kelimio.app:/oauthredirect',
  postLogoutRedirectUri: 'com.kelimio.app:/logout',
  isProduction: false,
  localDevelopmentToolsEnabled: true,
);
