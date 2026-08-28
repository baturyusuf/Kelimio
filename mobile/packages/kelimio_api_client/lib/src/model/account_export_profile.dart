//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'account_export_profile.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AccountExportProfile {
  /// Returns a new [AccountExportProfile] instance.
  AccountExportProfile({
    required this.id,

    this.email,

    required this.displayName,

    this.username,

    required this.appLocale,

    required this.activeTargetLanguage,

    this.preferredSupportLanguage,

    required this.timeZone,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'email', required: false, includeIfNull: false)
  final String? email;

  @JsonKey(name: r'displayName', required: true, includeIfNull: false)
  final String displayName;

  @JsonKey(name: r'username', required: false, includeIfNull: false)
  final String? username;

  /// Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract.
  @JsonKey(name: r'appLocale', required: true, includeIfNull: false)
  final String appLocale;

  /// Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract.
  @JsonKey(name: r'activeTargetLanguage', required: true, includeIfNull: false)
  final String activeTargetLanguage;

  @JsonKey(
    name: r'preferredSupportLanguage',
    required: false,
    includeIfNull: false,
  )
  final String? preferredSupportLanguage;

  /// Named IANA time-zone identifier accepted by the backend runtime, or UTC. Raw numeric offsets and GMT-prefixed fixed offsets are rejected.
  @JsonKey(name: r'timeZone', required: true, includeIfNull: false)
  final String timeZone;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountExportProfile &&
          other.id == id &&
          other.email == email &&
          other.displayName == displayName &&
          other.username == username &&
          other.appLocale == appLocale &&
          other.activeTargetLanguage == activeTargetLanguage &&
          other.preferredSupportLanguage == preferredSupportLanguage &&
          other.timeZone == timeZone;

  @override
  int get hashCode =>
      id.hashCode +
      (email == null ? 0 : email.hashCode) +
      displayName.hashCode +
      (username == null ? 0 : username.hashCode) +
      appLocale.hashCode +
      activeTargetLanguage.hashCode +
      (preferredSupportLanguage == null
          ? 0
          : preferredSupportLanguage.hashCode) +
      timeZone.hashCode;

  factory AccountExportProfile.fromJson(Map<String, dynamic> json) =>
      _$AccountExportProfileFromJson(json);

  Map<String, dynamic> toJson() => _$AccountExportProfileToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
