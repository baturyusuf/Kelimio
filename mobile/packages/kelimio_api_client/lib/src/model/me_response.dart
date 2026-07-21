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

    required this.subject,

    required this.displayName,

    this.username,

    required this.appLocale,

    required this.activeTargetLanguage,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'subject', required: true, includeIfNull: false)
  final String subject;

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeResponse &&
          other.id == id &&
          other.subject == subject &&
          other.displayName == displayName &&
          other.username == username &&
          other.appLocale == appLocale &&
          other.activeTargetLanguage == activeTargetLanguage;

  @override
  int get hashCode =>
      id.hashCode +
      subject.hashCode +
      displayName.hashCode +
      (username == null ? 0 : username.hashCode) +
      appLocale.hashCode +
      activeTargetLanguage.hashCode;

  factory MeResponse.fromJson(Map<String, dynamic> json) =>
      _$MeResponseFromJson(json);

  Map<String, dynamic> toJson() => _$MeResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
