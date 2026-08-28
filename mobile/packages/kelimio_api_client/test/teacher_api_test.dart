import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

/// tests for TeacherApi
void main() {
  final instance = KelimioApiClient().getTeacherApi();

  group(TeacherApi, () {
    // Accept the exact current version of the production authoring terms
    //
    // Appends one auditable owner-scoped acceptance fact. The account must be eligible through the managed identity group and production teacher features must already be enabled.
    //
    //Future<TeacherAccessResponse> acceptTeacherTerms(AcceptTeacherTermsRequest acceptTeacherTermsRequest) async
    test('test acceptTeacherTerms', () async {
      // TODO
    });

    // Create an expiring private free-course invitation
    //
    //Future<CourseInvitationCreated> createCourseInvitation(String courseId, CreateCourseInvitationRequest createCourseInvitationRequest) async
    test('test createCourseInvitation', () async {
      // TODO
    });

    // Save an ETag-bound complete immutable course draft
    //
    //Future<FullCourseEditorDraftResponse> createFullCourseEditorDraft(String courseId, String idempotencyKey, String ifMatch, SaveFullCourseEditorDraftRequest saveFullCourseEditorDraftRequest) async
    test('test createFullCourseEditorDraft', () async {
      // TODO
    });

    // Read the active immutable release as a full owner-scoped editor document
    //
    //Future<FullCourseEditorDocument> getFullCourseEditor(String courseId) async
    test('test getFullCourseEditor', () async {
      // TODO
    });

    // Return the authenticated user's production teacher access state
    //
    // Reports server-authoritative feature enablement, Cognito group eligibility, and current versioned terms acceptance. A client flag never grants access.
    //
    //Future<TeacherAccessResponse> getTeacherAccess() async
    test('test getTeacherAccess', () async {
      // TODO
    });

    // List courses owned by the authenticated authorized teacher
    //
    //Future<TeacherCoursePage> listTeacherCourses({ String cursor, int limit }) async
    test('test listTeacherCourses', () async {
      // TODO
    });
  });
}
