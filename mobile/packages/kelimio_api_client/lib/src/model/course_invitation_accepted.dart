//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'course_invitation_accepted.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseInvitationAccepted {
  /// Returns a new [CourseInvitationAccepted] instance.
  CourseInvitationAccepted({
    required this.courseId,

    required this.enrollmentId,

    required this.supportLanguage,

    required this.acceptedAt,
  });

  @JsonKey(name: r'courseId', required: true, includeIfNull: false)
  final String courseId;

  @JsonKey(name: r'enrollmentId', required: true, includeIfNull: false)
  final String enrollmentId;

  /// Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract.
  @JsonKey(name: r'supportLanguage', required: true, includeIfNull: false)
  final String supportLanguage;

  @JsonKey(name: r'acceptedAt', required: true, includeIfNull: false)
  final DateTime acceptedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseInvitationAccepted &&
          other.courseId == courseId &&
          other.enrollmentId == enrollmentId &&
          other.supportLanguage == supportLanguage &&
          other.acceptedAt == acceptedAt;

  @override
  int get hashCode =>
      courseId.hashCode +
      enrollmentId.hashCode +
      supportLanguage.hashCode +
      acceptedAt.hashCode;

  factory CourseInvitationAccepted.fromJson(Map<String, dynamic> json) =>
      _$CourseInvitationAcceptedFromJson(json);

  Map<String, dynamic> toJson() => _$CourseInvitationAcceptedToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
