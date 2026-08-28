//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'course_invitation_created.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseInvitationCreated {
  /// Returns a new [CourseInvitationCreated] instance.
  CourseInvitationCreated({
    required this.id,

    required this.courseId,

    required this.token,

    required this.maxUses,

    required this.expiresAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'courseId', required: true, includeIfNull: false)
  final String courseId;

  @JsonKey(name: r'token', required: true, includeIfNull: false)
  final String token;

  // minimum: 1
  // maximum: 100
  @JsonKey(name: r'maxUses', required: true, includeIfNull: false)
  final int maxUses;

  @JsonKey(name: r'expiresAt', required: true, includeIfNull: false)
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseInvitationCreated &&
          other.id == id &&
          other.courseId == courseId &&
          other.token == token &&
          other.maxUses == maxUses &&
          other.expiresAt == expiresAt;

  @override
  int get hashCode =>
      id.hashCode +
      courseId.hashCode +
      token.hashCode +
      maxUses.hashCode +
      expiresAt.hashCode;

  factory CourseInvitationCreated.fromJson(Map<String, dynamic> json) =>
      _$CourseInvitationCreatedFromJson(json);

  Map<String, dynamic> toJson() => _$CourseInvitationCreatedToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
