import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

/// tests for CourseReleaseApi
void main() {
  final instance = KelimioApiClient().getCourseReleaseApi();

  group(CourseReleaseApi, () {
    // Publish or roll back to an exact reviewed immutable release
    //
    // Atomically activates the reviewed release, appends the activation and outbox facts, and creates a cutoff-bound progress reprojection job. This endpoint is fail-closed outside explicitly enabled local/test environments.
    //
    //Future<CourseReleaseActivationResponse> activateCourseRelease(String courseId, String releaseId, String idempotencyKey, ActivateCourseReleaseRequest activateCourseReleaseRequest) async
    test('test activateCourseRelease', () async {
      // TODO
    });

    // Review the exact owner-scoped impact of activating an immutable release
    //
    // Returns a canonical binding digest over the locked release manifests and current active release. The enrollment count is advisory and deliberately excluded from the binding because projection membership is cutoff-bound at activation.
    //
    //Future<CourseReleaseImpactResponse> getCourseReleaseImpact(String courseId, String releaseId) async
    test('test getCourseReleaseImpact', () async {
      // TODO
    });
  });
}
