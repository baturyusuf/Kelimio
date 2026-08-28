//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'legal_consent.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LegalConsent {
  /// Returns a new [LegalConsent] instance.
  LegalConsent({
    required this.documentId,

    required this.documentVersion,

    required this.action,

    required this.occurredAt,
  });

  @JsonKey(name: r'documentId', required: true, includeIfNull: false)
  final String documentId;

  @JsonKey(name: r'documentVersion', required: true, includeIfNull: false)
  final String documentVersion;

  @JsonKey(name: r'action', required: true, includeIfNull: false)
  final LegalConsentActionEnum action;

  @JsonKey(name: r'occurredAt', required: true, includeIfNull: false)
  final DateTime occurredAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LegalConsent &&
          other.documentId == documentId &&
          other.documentVersion == documentVersion &&
          other.action == action &&
          other.occurredAt == occurredAt;

  @override
  int get hashCode =>
      documentId.hashCode +
      documentVersion.hashCode +
      action.hashCode +
      occurredAt.hashCode;

  factory LegalConsent.fromJson(Map<String, dynamic> json) =>
      _$LegalConsentFromJson(json);

  Map<String, dynamic> toJson() => _$LegalConsentToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum LegalConsentActionEnum {
  @JsonValue(r'ACCEPTED')
  ACCEPTED(r'ACCEPTED'),
  @JsonValue(r'WITHDRAWN')
  WITHDRAWN(r'WITHDRAWN');

  const LegalConsentActionEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
