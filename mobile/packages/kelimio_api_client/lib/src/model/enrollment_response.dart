//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'enrollment_response.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class EnrollmentResponse {
  /// Returns a new [EnrollmentResponse] instance.
  EnrollmentResponse({
    required this.id,

    required this.courseId,

    required this.supportLanguage,

    required this.status,

    required this.enrolledAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'courseId', required: true, includeIfNull: false)
  final String courseId;

  /// Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract.
  @JsonKey(name: r'supportLanguage', required: true, includeIfNull: false)
  final String supportLanguage;

  @JsonKey(name: r'status', required: true, includeIfNull: false)
  final EnrollmentResponseStatusEnum status;

  @JsonKey(name: r'enrolledAt', required: true, includeIfNull: false)
  final DateTime enrolledAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnrollmentResponse &&
          other.id == id &&
          other.courseId == courseId &&
          other.supportLanguage == supportLanguage &&
          other.status == status &&
          other.enrolledAt == enrolledAt;

  @override
  int get hashCode =>
      id.hashCode +
      courseId.hashCode +
      supportLanguage.hashCode +
      status.hashCode +
      enrolledAt.hashCode;

  factory EnrollmentResponse.fromJson(Map<String, dynamic> json) =>
      _$EnrollmentResponseFromJson(json);

  Map<String, dynamic> toJson() => _$EnrollmentResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum EnrollmentResponseStatusEnum {
  @JsonValue(r'ACTIVE')
  ACTIVE(r'ACTIVE');

  const EnrollmentResponseStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
