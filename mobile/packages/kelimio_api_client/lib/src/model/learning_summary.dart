//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/learning_history_item.dart';
import 'package:json_annotation/json_annotation.dart';

part 'learning_summary.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LearningSummary {
  /// Returns a new [LearningSummary] instance.
  LearningSummary({
    required this.activeScore,

    required this.lifetimeScore,

    required this.answeredQuestions,

    required this.correctAnswers,

    required this.completedAttempts,

    required this.passedAttempts,

    required this.enrolledCourses,

    required this.completedCourses,

    required this.currentStreakDays,

    required this.history,
  });

  // minimum: 0
  @JsonKey(name: r'activeScore', required: true, includeIfNull: false)
  final int activeScore;

  // minimum: 0
  @JsonKey(name: r'lifetimeScore', required: true, includeIfNull: false)
  final int lifetimeScore;

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
  @JsonKey(name: r'enrolledCourses', required: true, includeIfNull: false)
  final int enrolledCourses;

  // minimum: 0
  @JsonKey(name: r'completedCourses', required: true, includeIfNull: false)
  final int completedCourses;

  // minimum: 0
  @JsonKey(name: r'currentStreakDays', required: true, includeIfNull: false)
  final int currentStreakDays;

  @JsonKey(name: r'history', required: true, includeIfNull: false)
  final List<LearningHistoryItem> history;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningSummary &&
          other.activeScore == activeScore &&
          other.lifetimeScore == lifetimeScore &&
          other.answeredQuestions == answeredQuestions &&
          other.correctAnswers == correctAnswers &&
          other.completedAttempts == completedAttempts &&
          other.passedAttempts == passedAttempts &&
          other.enrolledCourses == enrolledCourses &&
          other.completedCourses == completedCourses &&
          other.currentStreakDays == currentStreakDays &&
          other.history == history;

  @override
  int get hashCode =>
      activeScore.hashCode +
      lifetimeScore.hashCode +
      answeredQuestions.hashCode +
      correctAnswers.hashCode +
      completedAttempts.hashCode +
      passedAttempts.hashCode +
      enrolledCourses.hashCode +
      completedCourses.hashCode +
      currentStreakDays.hashCode +
      history.hashCode;

  factory LearningSummary.fromJson(Map<String, dynamic> json) =>
      _$LearningSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$LearningSummaryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
