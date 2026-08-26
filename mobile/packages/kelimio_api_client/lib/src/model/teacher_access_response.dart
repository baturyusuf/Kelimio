//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'teacher_access_response.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TeacherAccessResponse {
  /// Returns a new [TeacherAccessResponse] instance.
  TeacherAccessResponse({
    required this.eligible,

    required this.termsAccepted,

    required this.productionFeaturesEnabled,

    required this.requiredTermsVersion,
  });

  /// Server-authoritative managed-identity teacher eligibility.
  @JsonKey(name: r'eligible', required: true, includeIfNull: false)
  final bool eligible;

  /// Whether the current required authoring-terms version was accepted.
  @JsonKey(name: r'termsAccepted', required: true, includeIfNull: false)
  final bool termsAccepted;

  /// Server-side production feature gate; never granted by the client.
  @JsonKey(
    name: r'productionFeaturesEnabled',
    required: true,
    includeIfNull: false,
  )
  final bool productionFeaturesEnabled;

  @JsonKey(name: r'requiredTermsVersion', required: true, includeIfNull: false)
  final String requiredTermsVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherAccessResponse &&
          other.eligible == eligible &&
          other.termsAccepted == termsAccepted &&
          other.productionFeaturesEnabled == productionFeaturesEnabled &&
          other.requiredTermsVersion == requiredTermsVersion;

  @override
  int get hashCode =>
      eligible.hashCode +
      termsAccepted.hashCode +
      productionFeaturesEnabled.hashCode +
      requiredTermsVersion.hashCode;

  factory TeacherAccessResponse.fromJson(Map<String, dynamic> json) =>
      _$TeacherAccessResponseFromJson(json);

  Map<String, dynamic> toJson() => _$TeacherAccessResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
