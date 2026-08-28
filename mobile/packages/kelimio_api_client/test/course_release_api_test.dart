import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

/// tests for CourseReleaseApi
void main() {
  final instance = KelimioApiClient().getCourseReleaseApi();

  group(CourseReleaseApi, () {
    // Mark an inactive draft release as abandoned without deleting its facts
    //
    // Atomically changes only a DRAFT release to ABANDONED and appends an owner-scoped abandonment fact plus an outbox event. Active and historical releases cannot be abandoned.
    //
    //Future<CourseReleaseAbandonmentResponse> abandonCourseRelease(String courseId, String releaseId, String idempotencyKey) async
    test('test abandonCourseRelease', () async {
      // TODO
    });

    // Publish or roll back to an exact reviewed immutable release
    //
    // Atomically activates the reviewed release, appends the activation and outbox facts, and creates a cutoff-bound progress reprojection job. In production this endpoint additionally requires the server-side teacher feature gate, Cognito teacher-group eligibility, and current versioned authoring-terms acceptance.
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
