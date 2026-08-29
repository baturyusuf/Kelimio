//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'teacher_course_performance.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TeacherCoursePerformance {
  /// Returns a new [TeacherCoursePerformance] instance.
  TeacherCoursePerformance({
    required this.answeredQuestions,

    required this.correctAnswers,

    required this.completedAttempts,

    required this.passedAttempts,
  });

  // minimum: 0
  @JsonKey(name: r'answeredQuestions', required: true, includeIfNull: false)
  final int answeredQuestions;

  // minimum: 0
  @JsonKey(name: r'correctAnswers', required: true, includeIfNull: false)
  final int correctAnswers;

  // minimum: 0
  @JsonKey(name: r'completedAttempts', required: true, includeIfNull: false)
  final int completedAttempts;

  // minimum: 0
  @JsonKey(name: r'passedAttempts', required: true, includeIfNull: false)
  final int passedAttempts;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherCoursePerformance &&
          other.answeredQuestions == answeredQuestions &&
          other.correctAnswers == correctAnswers &&
          other.completedAttempts == completedAttempts &&
          other.passedAttempts == passedAttempts;

  @override
  int get hashCode =>
      answeredQuestions.hashCode +
      correctAnswers.hashCode +
      completedAttempts.hashCode +
      passedAttempts.hashCode;

  factory TeacherCoursePerformance.fromJson(Map<String, dynamic> json) =>
      _$TeacherCoursePerformanceFromJson(json);

  Map<String, dynamic> toJson() => _$TeacherCoursePerformanceToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
