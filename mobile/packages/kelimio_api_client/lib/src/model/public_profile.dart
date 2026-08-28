//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'public_profile.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PublicProfile {
  /// Returns a new [PublicProfile] instance.
  PublicProfile({
    required this.username,

    required this.displayName,

    this.bio,

    this.avatarSeed,

    required this.targetLanguage,

    required this.lifetimeScore,

    required this.completedAttempts,

    required this.joinedAt,
  });

  @JsonKey(name: r'username', required: true, includeIfNull: false)
  final String username;

  @JsonKey(name: r'displayName', required: true, includeIfNull: false)
  final String displayName;

  @JsonKey(name: r'bio', required: false, includeIfNull: false)
  final String? bio;

  @JsonKey(name: r'avatarSeed', required: false, includeIfNull: false)
  final String? avatarSeed;

  /// Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract.
  @JsonKey(name: r'targetLanguage', required: true, includeIfNull: false)
  final String targetLanguage;

  // minimum: 0
  @JsonKey(name: r'lifetimeScore', required: true, includeIfNull: false)
  final int lifetimeScore;

  // minimum: 0
  @JsonKey(name: r'completedAttempts', required: true, includeIfNull: false)
  final int completedAttempts;

  @JsonKey(name: r'joinedAt', required: true, includeIfNull: false)
  final DateTime joinedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicProfile &&
          other.username == username &&
          other.displayName == displayName &&
          other.bio == bio &&
          other.avatarSeed == avatarSeed &&
          other.targetLanguage == targetLanguage &&
          other.lifetimeScore == lifetimeScore &&
          other.completedAttempts == completedAttempts &&
          other.joinedAt == joinedAt;

  @override
  int get hashCode =>
      username.hashCode +
      displayName.hashCode +
      (bio == null ? 0 : bio.hashCode) +
      (avatarSeed == null ? 0 : avatarSeed.hashCode) +
      targetLanguage.hashCode +
      lifetimeScore.hashCode +
      completedAttempts.hashCode +
      joinedAt.hashCode;

  factory PublicProfile.fromJson(Map<String, dynamic> json) =>
      _$PublicProfileFromJson(json);

  Map<String, dynamic> toJson() => _$PublicProfileToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
