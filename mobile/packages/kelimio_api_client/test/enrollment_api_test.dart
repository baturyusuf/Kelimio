import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

/// tests for EnrollmentApi
void main() {
  final instance = KelimioApiClient().getEnrollmentApi();

  group(EnrollmentApi, () {
    // Accept an opaque invitation and create active course access
    //
    //Future<CourseInvitationAccepted> acceptCourseInvitation(String token, AcceptCourseInvitationRequest acceptCourseInvitationRequest) async
    test('test acceptCourseInvitation', () async {
      // TODO
    });

    // Enroll the authenticated user in a free public course
    //
    //Future<EnrollmentResponse> enrollInCourse(String courseId, String idempotencyKey, CreateEnrollmentRequest createEnrollmentRequest, { String xKelimioClientCapabilities }) async
    test('test enrollInCourse', () async {
      // TODO
    });
  });
}
