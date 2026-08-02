import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

/// tests for DevelopmentApi
void main() {
  final instance = KelimioApiClient().getDevelopmentApi();

  group(DevelopmentApi, () {
    // Create one subsequent immutable course release for local verification
    //
    // Available only in explicitly enabled local/test environments. The owner creates one real MOBILE_AUTHORING change set from the exact active release, revises one eligible typed-cloze prompt without returning authored text or answer material, and receives an unpublished immutable release. Publication and rollback still require the separate impact-bound release operations.
    //
    //Future<SubsequentCourseDraftResult> createLocalCourseRevision(String courseId, String idempotencyKey, CreateLocalCourseRevisionRequest createLocalCourseRevisionRequest) async
    test('test createLocalCourseRevision', () async {
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
