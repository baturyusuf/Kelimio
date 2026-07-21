//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'create_enrollment_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateEnrollmentRequest {
  /// Returns a new [CreateEnrollmentRequest] instance.
  CreateEnrollmentRequest({required this.supportLanguage});

  /// Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract.
  @JsonKey(name: r'supportLanguage', required: true, includeIfNull: false)
  final String supportLanguage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateEnrollmentRequest &&
          other.supportLanguage == supportLanguage;

  @override
  int get hashCode => supportLanguage.hashCode;

  factory CreateEnrollmentRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateEnrollmentRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreateEnrollmentRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
