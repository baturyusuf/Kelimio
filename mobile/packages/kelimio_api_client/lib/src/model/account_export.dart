//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/legal_consent.dart';
import 'package:kelimio_api_client/src/model/account_export_profile.dart';
import 'package:json_annotation/json_annotation.dart';

part 'account_export.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AccountExport {
  /// Returns a new [AccountExport] instance.
  AccountExport({
    required this.generatedAt,

    required this.profile,

    required this.enrollments,

    required this.completedAttempts,

    required this.scoreEvents,

    required this.legalConsents,
  });

  @JsonKey(name: r'generatedAt', required: true, includeIfNull: false)
  final DateTime generatedAt;

  @JsonKey(name: r'profile', required: true, includeIfNull: false)
  final AccountExportProfile profile;

  @JsonKey(name: r'enrollments', required: true, includeIfNull: false)
  final List<Object> enrollments;

  @JsonKey(name: r'completedAttempts', required: true, includeIfNull: false)
  final List<Object> completedAttempts;

  @JsonKey(name: r'scoreEvents', required: true, includeIfNull: false)
  final List<Object> scoreEvents;

  @JsonKey(name: r'legalConsents', required: true, includeIfNull: false)
  final List<LegalConsent> legalConsents;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountExport &&
          other.generatedAt == generatedAt &&
          other.profile == profile &&
          other.enrollments == enrollments &&
          other.completedAttempts == completedAttempts &&
          other.scoreEvents == scoreEvents &&
          other.legalConsents == legalConsents;

  @override
  int get hashCode =>
      generatedAt.hashCode +
      profile.hashCode +
      enrollments.hashCode +
      completedAttempts.hashCode +
      scoreEvents.hashCode +
      legalConsents.hashCode;

  factory AccountExport.fromJson(Map<String, dynamic> json) =>
      _$AccountExportFromJson(json);

  Map<String, dynamic> toJson() => _$AccountExportToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
