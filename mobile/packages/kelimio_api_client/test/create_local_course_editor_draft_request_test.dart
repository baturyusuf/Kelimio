import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

// tests for CreateLocalCourseEditorDraftRequest
void main() {
  final CreateLocalCourseEditorDraftRequest?
  instance = /* CreateLocalCourseEditorDraftRequest(...) */ null;
  // TODO add properties to the entity

  group(CreateLocalCourseEditorDraftRequest, () {
    // String baseReleaseId
    test('to test the property `baseReleaseId`', () async {
      // TODO
    });

    // String questionRevisionId
    test('to test the property `questionRevisionId`', () async {
      // TODO
    });

    // Changed typed-cloze prompt containing exactly one literal --- marker.
    // String editedPrompt
    test('to test the property `editedPrompt`', () async {
      // TODO
    });

    test('redacts private editor content from diagnostics', () {
      const editedPrompt = 'SECRET_EDITED_PROMPT ---';
      final request = CreateLocalCourseEditorDraftRequest(
        baseReleaseId: '00000000-0000-4000-8000-000000000001',
        questionRevisionId: '00000000-0000-4000-8000-000000000002',
        editedPrompt: editedPrompt,
      );
      final snapshot = LocalCourseEditorSnapshot(
        courseId: '00000000-0000-4000-8000-000000000003',
        courseName: 'SECRET_COURSE',
        activeReleaseId: '00000000-0000-4000-8000-000000000004',
        releaseRevision: 1,
        levelTitle: 'SECRET_LEVEL',
        unitTitle: 'SECRET_UNIT',
        topicTitle: 'SECRET_TOPIC',
        testId: '00000000-0000-4000-8000-000000000005',
        testTitle: 'SECRET_TEST',
        questionId: '00000000-0000-4000-8000-000000000006',
        questionRevisionId: '00000000-0000-4000-8000-000000000007',
        questionRevision: 1,
        prompt: 'SECRET_PROMPT ---',
      );

      expect(request.toString(), contains('[REDACTED]'));
      expect(request.toString(), isNot(contains(editedPrompt)));
      for (final secret in const [
        'SECRET_COURSE',
        'SECRET_LEVEL',
        'SECRET_UNIT',
        'SECRET_TOPIC',
        'SECRET_TEST',
        'SECRET_PROMPT',
      ]) {
        expect(snapshot.toString(), isNot(contains(secret)));
      }
      expect(request.toJson()['editedPrompt'], editedPrompt);
      expect(snapshot.toJson()['prompt'], 'SECRET_PROMPT ---');
    });
  });
}
