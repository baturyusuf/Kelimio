//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'profile_setup_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ProfileSetupRequest {
  /// Returns a new [ProfileSetupRequest] instance.
  ProfileSetupRequest({
    required this.displayName,

    required this.appLocale,

    required this.activeTargetLanguage,

    required this.preferredSupportLanguage,

    required this.timeZone,
  });

  @JsonKey(name: r'displayName', required: true, includeIfNull: false)
  final String displayName;

  @JsonKey(name: r'appLocale', required: true, includeIfNull: false)
  final ProfileSetupRequestAppLocaleEnum appLocale;

  /// Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract.
  @JsonKey(name: r'activeTargetLanguage', required: true, includeIfNull: false)
  final String activeTargetLanguage;

  /// Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract.
  @JsonKey(
    name: r'preferredSupportLanguage',
    required: true,
    includeIfNull: false,
  )
  final String preferredSupportLanguage;

  /// Named IANA time-zone identifier accepted by the backend runtime, or UTC. Raw numeric offsets and GMT-prefixed fixed offsets are rejected.
  @JsonKey(name: r'timeZone', required: true, includeIfNull: false)
  final String timeZone;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileSetupRequest &&
          other.displayName == displayName &&
          other.appLocale == appLocale &&
          other.activeTargetLanguage == activeTargetLanguage &&
          other.preferredSupportLanguage == preferredSupportLanguage &&
          other.timeZone == timeZone;

  @override
  int get hashCode =>
      displayName.hashCode +
      appLocale.hashCode +
      activeTargetLanguage.hashCode +
      preferredSupportLanguage.hashCode +
      timeZone.hashCode;

  factory ProfileSetupRequest.fromJson(Map<String, dynamic> json) =>
      _$ProfileSetupRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileSetupRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum ProfileSetupRequestAppLocaleEnum {
  @JsonValue(r'tr')
  tr(r'tr'),
  @JsonValue(r'en')
  en(r'en'),
  @JsonValue(r'ar')
  ar(r'ar');

  const ProfileSetupRequestAppLocaleEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
