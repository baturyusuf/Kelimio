import 'package:kelimio_api_client/src/model/accept_course_invitation_request.dart';
import 'package:kelimio_api_client/src/model/accept_teacher_terms_request.dart';
import 'package:kelimio_api_client/src/model/account_deletion_request.dart';
import 'package:kelimio_api_client/src/model/account_export.dart';
import 'package:kelimio_api_client/src/model/account_export_profile.dart';
import 'package:kelimio_api_client/src/model/activate_course_release_request.dart';
import 'package:kelimio_api_client/src/model/answer_option.dart';
import 'package:kelimio_api_client/src/model/answer_recorded_response.dart';
import 'package:kelimio_api_client/src/model/approve_course_import_request.dart';
import 'package:kelimio_api_client/src/model/attempt_response.dart';
import 'package:kelimio_api_client/src/model/commit_course_import_request.dart';
import 'package:kelimio_api_client/src/model/complete_course_import_upload_request.dart';
import 'package:kelimio_api_client/src/model/completed_course_import_part.dart';
import 'package:kelimio_api_client/src/model/course_detail.dart';
import 'package:kelimio_api_client/src/model/course_editor_level.dart';
import 'package:kelimio_api_client/src/model/course_editor_matching_pair.dart';
import 'package:kelimio_api_client/src/model/course_editor_option.dart';
import 'package:kelimio_api_client/src/model/course_editor_question.dart';
import 'package:kelimio_api_client/src/model/course_editor_test.dart';
import 'package:kelimio_api_client/src/model/course_editor_topic.dart';
import 'package:kelimio_api_client/src/model/course_editor_unit.dart';
import 'package:kelimio_api_client/src/model/course_import_activation_summary.dart';
import 'package:kelimio_api_client/src/model/course_import_approval_response.dart';
import 'package:kelimio_api_client/src/model/course_import_commit_response.dart';
import 'package:kelimio_api_client/src/model/course_import_commit_summary.dart';
import 'package:kelimio_api_client/src/model/course_import_issue_page.dart';
import 'package:kelimio_api_client/src/model/course_import_part_declaration.dart';
import 'package:kelimio_api_client/src/model/course_import_part_headers.dart';
import 'package:kelimio_api_client/src/model/course_import_presigned_part.dart';
import 'package:kelimio_api_client/src/model/course_import_preview_page.dart';
import 'package:kelimio_api_client/src/model/course_import_preview_row.dart';
import 'package:kelimio_api_client/src/model/course_import_preview_settings.dart';
import 'package:kelimio_api_client/src/model/course_import_preview_summary.dart';
import 'package:kelimio_api_client/src/model/course_import_source.dart';
import 'package:kelimio_api_client/src/model/course_import_status_page.dart';
import 'package:kelimio_api_client/src/model/course_import_status_response.dart';
import 'package:kelimio_api_client/src/model/course_import_upload_instructions.dart';
import 'package:kelimio_api_client/src/model/course_import_upload_session_response.dart';
import 'package:kelimio_api_client/src/model/course_import_validation_issue.dart';
import 'package:kelimio_api_client/src/model/course_invitation_accepted.dart';
import 'package:kelimio_api_client/src/model/course_invitation_created.dart';
import 'package:kelimio_api_client/src/model/course_page.dart';
import 'package:kelimio_api_client/src/model/course_progress_response.dart';
import 'package:kelimio_api_client/src/model/course_release_abandonment_response.dart';
import 'package:kelimio_api_client/src/model/course_release_activation_response.dart';
import 'package:kelimio_api_client/src/model/course_release_impact_response.dart';
import 'package:kelimio_api_client/src/model/course_summary.dart';
import 'package:kelimio_api_client/src/model/create_course_import_request.dart';
import 'package:kelimio_api_client/src/model/create_course_invitation_request.dart';
import 'package:kelimio_api_client/src/model/create_enrollment_request.dart';
import 'package:kelimio_api_client/src/model/create_local_course_editor_draft_request.dart';
import 'package:kelimio_api_client/src/model/create_local_course_revision_request.dart';
import 'package:kelimio_api_client/src/model/energy_response.dart';
import 'package:kelimio_api_client/src/model/enrollment_response.dart';
import 'package:kelimio_api_client/src/model/finish_attempt_response.dart';
import 'package:kelimio_api_client/src/model/full_course_editor_document.dart';
import 'package:kelimio_api_client/src/model/full_course_editor_draft_response.dart';
import 'package:kelimio_api_client/src/model/leaderboard.dart';
import 'package:kelimio_api_client/src/model/leaderboard_entry.dart';
import 'package:kelimio_api_client/src/model/learning_history_item.dart';
import 'package:kelimio_api_client/src/model/learning_summary.dart';
import 'package:kelimio_api_client/src/model/legal_consent.dart';
import 'package:kelimio_api_client/src/model/local_course_editor_snapshot.dart';
import 'package:kelimio_api_client/src/model/local_starter_course_response.dart';
import 'package:kelimio_api_client/src/model/matching_item.dart';
import 'package:kelimio_api_client/src/model/matching_selection.dart';
import 'package:kelimio_api_client/src/model/me_response.dart';
import 'package:kelimio_api_client/src/model/notification_preference.dart';
import 'package:kelimio_api_client/src/model/offline_package.dart';
import 'package:kelimio_api_client/src/model/own_public_profile.dart';
import 'package:kelimio_api_client/src/model/problem.dart';
import 'package:kelimio_api_client/src/model/profile_setup_request.dart';
import 'package:kelimio_api_client/src/model/public_profile.dart';
import 'package:kelimio_api_client/src/model/question_payload.dart';
import 'package:kelimio_api_client/src/model/save_full_course_editor_draft_request.dart';
import 'package:kelimio_api_client/src/model/session_revocation.dart';
import 'package:kelimio_api_client/src/model/submit_answer_request.dart';
import 'package:kelimio_api_client/src/model/subsequent_course_draft_result.dart';
import 'package:kelimio_api_client/src/model/teacher_access_response.dart';
import 'package:kelimio_api_client/src/model/teacher_course_page.dart';
import 'package:kelimio_api_client/src/model/teacher_course_summary.dart';
import 'package:kelimio_api_client/src/model/test_summary.dart';
import 'package:kelimio_api_client/src/model/update_notification_preference_request.dart';
import 'package:kelimio_api_client/src/model/update_public_profile_request.dart';

final _regList = RegExp(r'^List<(.*)>$');
final _regSet = RegExp(r'^Set<(.*)>$');
final _regMap = RegExp(r'^Map<String,(.*)>$');

ReturnType deserialize<ReturnType, BaseType>(
  dynamic value,
  String targetType, {
  bool growable = true,
}) {
  switch (targetType) {
    case 'String':
      return '$value' as ReturnType;
    case 'int':
      return (value is int ? value : int.parse('$value')) as ReturnType;
    case 'bool':
      if (value is bool) {
        return value as ReturnType;
      }
      final valueString = '$value'.toLowerCase();
      return (valueString == 'true' || valueString == '1') as ReturnType;
    case 'double':
      return (value is double ? value : double.parse('$value')) as ReturnType;
    case 'AcceptCourseInvitationRequest':
      return AcceptCourseInvitationRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'AcceptTeacherTermsRequest':
      return AcceptTeacherTermsRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AccountDeletionRequest':
      return AccountDeletionRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AccountExport':
      return AccountExport.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AccountExportProfile':
      return AccountExportProfile.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ActivateCourseReleaseRequest':
      return ActivateCourseReleaseRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'AnswerOption':
      return AnswerOption.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'AnswerRecordedResponse':
      return AnswerRecordedResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ApproveCourseImportRequest':
      return ApproveCourseImportRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AttemptResponse':
      return AttemptResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AttemptState':
    case 'CommitCourseImportRequest':
      return CommitCourseImportRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CompleteCourseImportUploadRequest':
      return CompleteCourseImportUploadRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CompletedCourseImportPart':
      return CompletedCourseImportPart.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseDetail':
      return CourseDetail.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'CourseEditorLevel':
      return CourseEditorLevel.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseEditorMatchingPair':
      return CourseEditorMatchingPair.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseEditorOption':
      return CourseEditorOption.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseEditorQuestion':
      return CourseEditorQuestion.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseEditorTest':
      return CourseEditorTest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseEditorTopic':
      return CourseEditorTopic.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseEditorUnit':
      return CourseEditorUnit.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseImportActivationSummary':
      return CourseImportActivationSummary.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CourseImportApprovalResponse':
      return CourseImportApprovalResponse.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CourseImportCommitResponse':
      return CourseImportCommitResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseImportCommitSummary':
      return CourseImportCommitSummary.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseImportIssuePage':
      return CourseImportIssuePage.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseImportPartDeclaration':
      return CourseImportPartDeclaration.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseImportPartHeaders':
      return CourseImportPartHeaders.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseImportPresignedPart':
      return CourseImportPresignedPart.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseImportPreviewPage':
      return CourseImportPreviewPage.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseImportPreviewRow':
      return CourseImportPreviewRow.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseImportPreviewSettings':
      return CourseImportPreviewSettings.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseImportPreviewSummary':
      return CourseImportPreviewSummary.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseImportSource':
      return CourseImportSource.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseImportStatus':
    case 'CourseImportStatusPage':
      return CourseImportStatusPage.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseImportStatusResponse':
      return CourseImportStatusResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseImportUploadInstructions':
      return CourseImportUploadInstructions.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CourseImportUploadSessionResponse':
      return CourseImportUploadSessionResponse.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CourseImportValidationIssue':
      return CourseImportValidationIssue.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseInvitationAccepted':
      return CourseInvitationAccepted.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseInvitationCreated':
      return CourseInvitationCreated.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CoursePage':
      return CoursePage.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'CourseProgressResponse':
      return CourseProgressResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseReleaseAbandonmentResponse':
      return CourseReleaseAbandonmentResponse.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CourseReleaseActivationResponse':
      return CourseReleaseActivationResponse.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CourseReleaseImpactResponse':
      return CourseReleaseImpactResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseReleaseOperation':
    case 'CourseSummary':
      return CourseSummary.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateCourseImportRequest':
      return CreateCourseImportRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateCourseInvitationRequest':
      return CreateCourseInvitationRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateEnrollmentRequest':
      return CreateEnrollmentRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateLocalCourseEditorDraftRequest':
      return CreateLocalCourseEditorDraftRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'CreateLocalCourseRevisionRequest':
      return CreateLocalCourseRevisionRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'EnergyResponse':
      return EnergyResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'EnrollmentResponse':
      return EnrollmentResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'FinishAttemptResponse':
      return FinishAttemptResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'FullCourseEditorDocument':
      return FullCourseEditorDocument.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'FullCourseEditorDraftResponse':
      return FullCourseEditorDraftResponse.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'Leaderboard':
      return Leaderboard.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'LeaderboardEntry':
      return LeaderboardEntry.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'LearningHistoryItem':
      return LearningHistoryItem.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'LearningSummary':
      return LearningSummary.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'LegalConsent':
      return LegalConsent.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'LocalCourseEditorSnapshot':
      return LocalCourseEditorSnapshot.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'LocalStarterCourseResponse':
      return LocalStarterCourseResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MatchingItem':
      return MatchingItem.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'MatchingSelection':
      return MatchingSelection.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MeResponse':
      return MeResponse.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'NotificationPreference':
      return NotificationPreference.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'OfflinePackage':
      return OfflinePackage.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'OwnPublicProfile':
      return OwnPublicProfile.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Problem':
      return Problem.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ProfileSetupRequest':
      return ProfileSetupRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PublicProfile':
      return PublicProfile.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'QuestionPayload':
      return QuestionPayload.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SaveFullCourseEditorDraftRequest':
      return SaveFullCourseEditorDraftRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'SessionRevocation':
      return SessionRevocation.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SubmitAnswerRequest':
      return SubmitAnswerRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SubsequentCourseDraftResult':
      return SubsequentCourseDraftResult.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'TeacherAccessResponse':
      return TeacherAccessResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'TeacherCoursePage':
      return TeacherCoursePage.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'TeacherCourseSummary':
      return TeacherCourseSummary.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'TestSummary':
      return TestSummary.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'UpdateNotificationPreferenceRequest':
      return UpdateNotificationPreferenceRequest.fromJson(
            value as Map<String, dynamic>,
          )
          as ReturnType;
    case 'UpdatePublicProfileRequest':
      return UpdatePublicProfileRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    default:
      RegExpMatch? match;

      if (value is List && (match = _regList.firstMatch(targetType)) != null) {
        targetType = match![1]!; // ignore: parameter_assignments
        return value
                .map<BaseType>(
                  (dynamic v) => deserialize<BaseType, BaseType>(
                    v,
                    targetType,
                    growable: growable,
                  ),
                )
                .toList(growable: growable)
            as ReturnType;
      }
      if (value is Set && (match = _regSet.firstMatch(targetType)) != null) {
        targetType = match![1]!; // ignore: parameter_assignments
        return value
                .map<BaseType>(
                  (dynamic v) => deserialize<BaseType, BaseType>(
                    v,
                    targetType,
                    growable: growable,
                  ),
                )
                .toSet()
            as ReturnType;
      }
      if (value is Map && (match = _regMap.firstMatch(targetType)) != null) {
        targetType = match![1]!.trim(); // ignore: parameter_assignments
        return Map<String, BaseType>.fromIterables(
              value.keys as Iterable<String>,
              value.values.map(
                (dynamic v) => deserialize<BaseType, BaseType>(
                  v,
                  targetType,
                  growable: growable,
                ),
              ),
            )
            as ReturnType;
      }
      break;
  }
  throw Exception('Cannot deserialize');
}
