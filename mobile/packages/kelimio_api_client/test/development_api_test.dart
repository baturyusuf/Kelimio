import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

/// tests for DevelopmentApi
void main() {
  final instance = KelimioApiClient().getDevelopmentApi();

  group(DevelopmentApi, () {
    // Save one ETag-bound immutable local editor draft
    //
    // Creates a committed MOBILE_AUTHORING change set and an unpublished immutable release only when If-Match still names the current owner-scoped editor document. It accepts a changed typed-cloze prompt but no answer, score, entitlement, ownership, or publication assertion. Publication remains a separate impact-bound operation.
    //
    //Future<SubsequentCourseDraftResult> createLocalCourseEditorDraft(String courseId, String idempotencyKey, String ifMatch, CreateLocalCourseEditorDraftRequest createLocalCourseEditorDraftRequest) async
    test('test createLocalCourseEditorDraft', () async {
      // TODO
    });

    // Create one subsequent immutable course release for local verification
    //
    // Available only in explicitly enabled local/test environments. The owner creates one real MOBILE_AUTHORING change set from the exact active release, revises one eligible typed-cloze prompt without returning authored text or answer material, and receives an unpublished immutable release. Publication and rollback still require the separate impact-bound release operations.
    //
    //Future<SubsequentCourseDraftResult> createLocalCourseRevision(String courseId, String idempotencyKey, CreateLocalCourseRevisionRequest createLocalCourseRevisionRequest) async
    test('test createLocalCourseRevision', () async {
      // TODO
    });

    // Read the owner-scoped local course editor document
    //
    // Returns the first eligible typed-cloze prompt and its immutable hierarchy from the exact active release. The response is owner-scoped, no-store, answer-key-free, and carries the strong ETag required by draft creation. It is unavailable outside explicitly enabled local/test environments.
    //
    //Future<LocalCourseEditorSnapshot> getLocalCourseEditor(String courseId) async
    test('test getLocalCourseEditor', () async {
      // TODO
    });

    // Install the authenticated owner's local starter course idempotently
    //
    // Available only when the backend is explicitly running in the local environment with starter-course installation enabled. It creates one immutable Type-A/Type-B/Type-C English-support release derived from the reviewed workbook subset and never creates users or learning results.
    //
    //Future<LocalStarterCourseResponse> installLocalStarterCourse(String idempotencyKey) async
    test('test installLocalStarterCourse', () async {
      // TODO
    });
  });
}
