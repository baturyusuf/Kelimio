//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'learning_history_item.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LearningHistoryItem {
  /// Returns a new [LearningHistoryItem] instance.
  LearningHistoryItem({
    required this.attemptId,

    required this.courseId,

    required this.courseName,

    required this.testTitle,

    required this.status,

    required this.answeredCount,

    required this.correctCount,

    required this.totalQuestions,

    required this.finishedAt,
  });

  @JsonKey(name: r'attemptId', required: true, includeIfNull: false)
  final String attemptId;

  @JsonKey(name: r'courseId', required: true, includeIfNull: false)
  final String courseId;

  @JsonKey(name: r'courseName', required: true, includeIfNull: false)
  final String courseName;

  @JsonKey(name: r'testTitle', required: true, includeIfNull: false)
  final String testTitle;

  @JsonKey(name: r'status', required: true, includeIfNull: false)
  final LearningHistoryItemStatusEnum status;

  // minimum: 0
  @JsonKey(name: r'answeredCount', required: true, includeIfNull: false)
  final int answeredCount;

  // minimum: 0
  @JsonKey(name: r'correctCount', required: true, includeIfNull: false)
  final int correctCount;

  // minimum: 1
  @JsonKey(name: r'totalQuestions', required: true, includeIfNull: false)
  final int totalQuestions;

  @JsonKey(name: r'finishedAt', required: true, includeIfNull: false)
  final DateTime finishedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningHistoryItem &&
          other.attemptId == attemptId &&
          other.courseId == courseId &&
          other.courseName == courseName &&
          other.testTitle == testTitle &&
          other.status == status &&
          other.answeredCount == answeredCount &&
          other.correctCount == correctCount &&
          other.totalQuestions == totalQuestions &&
          other.finishedAt == finishedAt;

  @override
  int get hashCode =>
      attemptId.hashCode +
      courseId.hashCode +
      courseName.hashCode +
      testTitle.hashCode +
      status.hashCode +
      answeredCount.hashCode +
      correctCount.hashCode +
      totalQuestions.hashCode +
      finishedAt.hashCode;

  factory LearningHistoryItem.fromJson(Map<String, dynamic> json) =>
      _$LearningHistoryItemFromJson(json);

  Map<String, dynamic> toJson() => _$LearningHistoryItemToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum LearningHistoryItemStatusEnum {
  @JsonValue(r'COMPLETED_PASS')
  COMPLETED_PASS(r'COMPLETED_PASS'),
  @JsonValue(r'COMPLETED_FAIL')
  COMPLETED_FAIL(r'COMPLETED_FAIL');

  const LearningHistoryItemStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
