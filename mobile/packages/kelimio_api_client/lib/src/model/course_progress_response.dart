//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'course_progress_response.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseProgressResponse {
  /// Returns a new [CourseProgressResponse] instance.
  CourseProgressResponse({
    required this.courseId,

    required this.courseReleaseId,

    required this.answeredQuestions,

    required this.correctAnswers,

    required this.completedAttempts,

    required this.passedAttempts,

    required this.activeScore,

    required this.lifetimeScore,

    required this.projectionVersion,

    required this.updating,

    required this.updatedAt,
  });

  @JsonKey(name: r'courseId', required: true, includeIfNull: false)
  final String courseId;

  @JsonKey(name: r'courseReleaseId', required: true, includeIfNull: false)
  final String courseReleaseId;

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

  // minimum: 0
  @JsonKey(name: r'activeScore', required: true, includeIfNull: false)
  final int activeScore;

  // minimum: 0
  @JsonKey(name: r'lifetimeScore', required: true, includeIfNull: false)
  final int lifetimeScore;

  // minimum: 0
  @JsonKey(name: r'projectionVersion', required: true, includeIfNull: false)
  final int projectionVersion;

  @JsonKey(name: r'updating', required: true, includeIfNull: false)
  final bool updating;

  @JsonKey(name: r'updatedAt', required: true, includeIfNull: true)
  final DateTime? updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseProgressResponse &&
          other.courseId == courseId &&
          other.courseReleaseId == courseReleaseId &&
          other.answeredQuestions == answeredQuestions &&
          other.correctAnswers == correctAnswers &&
          other.completedAttempts == completedAttempts &&
          other.passedAttempts == passedAttempts &&
          other.activeScore == activeScore &&
          other.lifetimeScore == lifetimeScore &&
          other.projectionVersion == projectionVersion &&
          other.updating == updating &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      courseId.hashCode +
      courseReleaseId.hashCode +
      answeredQuestions.hashCode +
      correctAnswers.hashCode +
      completedAttempts.hashCode +
      passedAttempts.hashCode +
      activeScore.hashCode +
      lifetimeScore.hashCode +
      projectionVersion.hashCode +
      updating.hashCode +
      (updatedAt == null ? 0 : updatedAt.hashCode);

  factory CourseProgressResponse.fromJson(Map<String, dynamic> json) =>
      _$CourseProgressResponseFromJson(json);

  Map<String, dynamic> toJson() => _$CourseProgressResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
