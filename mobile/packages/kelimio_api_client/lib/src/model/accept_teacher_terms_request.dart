//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'accept_teacher_terms_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AcceptTeacherTermsRequest {
  /// Returns a new [AcceptTeacherTermsRequest] instance.
  AcceptTeacherTermsRequest({required this.termsVersion});

  @JsonKey(name: r'termsVersion', required: true, includeIfNull: false)
  final String termsVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AcceptTeacherTermsRequest && other.termsVersion == termsVersion;

  @override
  int get hashCode => termsVersion.hashCode;

  factory AcceptTeacherTermsRequest.fromJson(Map<String, dynamic> json) =>
      _$AcceptTeacherTermsRequestFromJson(json);

  Map<String, dynamic> toJson() => _$AcceptTeacherTermsRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
