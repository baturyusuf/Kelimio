import 'package:kelimio_api_client/src/model/answer_option.dart';
import 'package:kelimio_api_client/src/model/answer_recorded_response.dart';
import 'package:kelimio_api_client/src/model/attempt_response.dart';
import 'package:kelimio_api_client/src/model/course_detail.dart';
import 'package:kelimio_api_client/src/model/course_page.dart';
import 'package:kelimio_api_client/src/model/course_progress_response.dart';
import 'package:kelimio_api_client/src/model/course_summary.dart';
import 'package:kelimio_api_client/src/model/create_enrollment_request.dart';
import 'package:kelimio_api_client/src/model/energy_response.dart';
import 'package:kelimio_api_client/src/model/enrollment_response.dart';
import 'package:kelimio_api_client/src/model/finish_attempt_response.dart';
import 'package:kelimio_api_client/src/model/local_starter_course_response.dart';
import 'package:kelimio_api_client/src/model/me_response.dart';
import 'package:kelimio_api_client/src/model/problem.dart';
import 'package:kelimio_api_client/src/model/question_payload.dart';
import 'package:kelimio_api_client/src/model/submit_answer_request.dart';
import 'package:kelimio_api_client/src/model/test_summary.dart';

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
    case 'AnswerOption':
      return AnswerOption.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'AnswerRecordedResponse':
      return AnswerRecordedResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AttemptResponse':
      return AttemptResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'AttemptState':
    case 'CourseDetail':
      return CourseDetail.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'CoursePage':
      return CoursePage.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'CourseProgressResponse':
      return CourseProgressResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CourseSummary':
      return CourseSummary.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'CreateEnrollmentRequest':
      return CreateEnrollmentRequest.fromJson(value as Map<String, dynamic>)
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
    case 'LocalStarterCourseResponse':
      return LocalStarterCourseResponse.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'MeResponse':
      return MeResponse.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'Problem':
      return Problem.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'QuestionPayload':
      return QuestionPayload.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'SubmitAnswerRequest':
      return SubmitAnswerRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'TestSummary':
      return TestSummary.fromJson(value as Map<String, dynamic>) as ReturnType;
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
