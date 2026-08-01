//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'me_response.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MeResponse {
  /// Returns a new [MeResponse] instance.
  MeResponse({
    required this.id,

    required this.displayName,

    required this.appLocale,

    required this.activeTargetLanguage,

    this.preferredSupportLanguage,

    required this.timeZone,

    required this.profileVersion,

    required this.profileSetupStatus,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'displayName', required: true, includeIfNull: false)
  final String displayName;

  /// Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract.
  @JsonKey(name: r'appLocale', required: true, includeIfNull: false)
  final String appLocale;

  /// Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract.
  @JsonKey(name: r'activeTargetLanguage', required: true, includeIfNull: false)
  final String activeTargetLanguage;

  /// Absent or null until first-login profile setup is complete.
  @JsonKey(
    name: r'preferredSupportLanguage',
    required: false,
    includeIfNull: false,
  )
  final String? preferredSupportLanguage;

  /// Named IANA time-zone identifier accepted by the backend runtime, or UTC. Raw numeric offsets and GMT-prefixed fixed offsets are rejected.
  @JsonKey(name: r'timeZone', required: true, includeIfNull: false)
  final String timeZone;

  // minimum: 0
  @JsonKey(name: r'profileVersion', required: true, includeIfNull: false)
  final int profileVersion;

  /// REQUIRED pairs with profileVersion 0 and no support language; COMPLETE pairs with profileVersion at least 1 and a support language.
  @JsonKey(name: r'profileSetupStatus', required: true, includeIfNull: false)
  final MeResponseProfileSetupStatusEnum profileSetupStatus;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeResponse &&
          other.id == id &&
          other.displayName == displayName &&
          other.appLocale == appLocale &&
          other.activeTargetLanguage == activeTargetLanguage &&
          other.preferredSupportLanguage == preferredSupportLanguage &&
          other.timeZone == timeZone &&
          other.profileVersion == profileVersion &&
          other.profileSetupStatus == profileSetupStatus;

  @override
  int get hashCode =>
      id.hashCode +
      displayName.hashCode +
      appLocale.hashCode +
      activeTargetLanguage.hashCode +
      (preferredSupportLanguage == null
          ? 0
          : preferredSupportLanguage.hashCode) +
      timeZone.hashCode +
      profileVersion.hashCode +
      profileSetupStatus.hashCode;

  factory MeResponse.fromJson(Map<String, dynamic> json) =>
      _$MeResponseFromJson(json);

  Map<String, dynamic> toJson() => _$MeResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

/// REQUIRED pairs with profileVersion 0 and no support language; COMPLETE pairs with profileVersion at least 1 and a support language.
enum MeResponseProfileSetupStatusEnum {
  /// REQUIRED pairs with profileVersion 0 and no support language; COMPLETE pairs with profileVersion at least 1 and a support language.
  @JsonValue(r'REQUIRED')
  REQUIRED(r'REQUIRED'),

  /// REQUIRED pairs with profileVersion 0 and no support language; COMPLETE pairs with profileVersion at least 1 and a support language.
  @JsonValue(r'COMPLETE')
  COMPLETE(r'COMPLETE');

  const MeResponseProfileSetupStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
