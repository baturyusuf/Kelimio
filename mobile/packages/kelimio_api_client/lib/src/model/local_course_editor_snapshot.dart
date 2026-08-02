//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'local_course_editor_snapshot.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LocalCourseEditorSnapshot {
  /// Returns a new [LocalCourseEditorSnapshot] instance.
  LocalCourseEditorSnapshot({
    required this.courseId,

    required this.courseName,

    required this.activeReleaseId,

    required this.releaseRevision,

    required this.levelTitle,

    required this.unitTitle,

    required this.topicTitle,

    required this.testId,

    required this.testTitle,

    required this.questionId,

    required this.questionRevisionId,

    required this.questionRevision,

    required this.prompt,
  });

  @JsonKey(name: r'courseId', required: true, includeIfNull: false)
  final String courseId;

  @JsonKey(name: r'courseName', required: true, includeIfNull: false)
  final String courseName;

  @JsonKey(name: r'activeReleaseId', required: true, includeIfNull: false)
  final String activeReleaseId;

  // minimum: 1
  @JsonKey(name: r'releaseRevision', required: true, includeIfNull: false)
  final int releaseRevision;

  @JsonKey(name: r'levelTitle', required: true, includeIfNull: false)
  final String levelTitle;

  @JsonKey(name: r'unitTitle', required: true, includeIfNull: false)
  final String unitTitle;

  @JsonKey(name: r'topicTitle', required: true, includeIfNull: false)
  final String topicTitle;

  @JsonKey(name: r'testId', required: true, includeIfNull: false)
  final String testId;

  @JsonKey(name: r'testTitle', required: true, includeIfNull: false)
  final String testTitle;

  @JsonKey(name: r'questionId', required: true, includeIfNull: false)
  final String questionId;

  @JsonKey(name: r'questionRevisionId', required: true, includeIfNull: false)
  final String questionRevisionId;

  // minimum: 1
  @JsonKey(name: r'questionRevision', required: true, includeIfNull: false)
  final int questionRevision;

  @JsonKey(name: r'prompt', required: true, includeIfNull: false)
  final String prompt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalCourseEditorSnapshot &&
          other.courseId == courseId &&
          other.courseName == courseName &&
          other.activeReleaseId == activeReleaseId &&
          other.releaseRevision == releaseRevision &&
          other.levelTitle == levelTitle &&
          other.unitTitle == unitTitle &&
          other.topicTitle == topicTitle &&
          other.testId == testId &&
          other.testTitle == testTitle &&
          other.questionId == questionId &&
          other.questionRevisionId == questionRevisionId &&
          other.questionRevision == questionRevision &&
          other.prompt == prompt;

  @override
  int get hashCode =>
      courseId.hashCode +
      courseName.hashCode +
      activeReleaseId.hashCode +
      releaseRevision.hashCode +
      levelTitle.hashCode +
      unitTitle.hashCode +
      topicTitle.hashCode +
      testId.hashCode +
      testTitle.hashCode +
      questionId.hashCode +
      questionRevisionId.hashCode +
      questionRevision.hashCode +
      prompt.hashCode;

  factory LocalCourseEditorSnapshot.fromJson(Map<String, dynamic> json) =>
      _$LocalCourseEditorSnapshotFromJson(json);

  Map<String, dynamic> toJson() => _$LocalCourseEditorSnapshotToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'courseName')) {
      json[r'courseName'] = '[REDACTED]';
    }
    if (json.containsKey(r'levelTitle')) {
      json[r'levelTitle'] = '[REDACTED]';
    }
    if (json.containsKey(r'unitTitle')) {
      json[r'unitTitle'] = '[REDACTED]';
    }
    if (json.containsKey(r'topicTitle')) {
      json[r'topicTitle'] = '[REDACTED]';
    }
    if (json.containsKey(r'testTitle')) {
      json[r'testTitle'] = '[REDACTED]';
    }
    if (json.containsKey(r'prompt')) {
      json[r'prompt'] = '[REDACTED]';
    }
    return json.toString();
  }
}
