//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'create_course_invitation_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateCourseInvitationRequest {
  /// Returns a new [CreateCourseInvitationRequest] instance.
  CreateCourseInvitationRequest({this.maxUses = 1, this.expiresInHours = 168});

  // minimum: 1
  // maximum: 100
  @JsonKey(
    defaultValue: 1,
    name: r'maxUses',
    required: true,
    includeIfNull: false,
  )
  final int maxUses;

  // minimum: 1
  // maximum: 720
  @JsonKey(
    defaultValue: 168,
    name: r'expiresInHours',
    required: true,
    includeIfNull: false,
  )
  final int expiresInHours;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateCourseInvitationRequest &&
          other.maxUses == maxUses &&
          other.expiresInHours == expiresInHours;

  @override
  int get hashCode => maxUses.hashCode + expiresInHours.hashCode;

  factory CreateCourseInvitationRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateCourseInvitationRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateCourseInvitationRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
