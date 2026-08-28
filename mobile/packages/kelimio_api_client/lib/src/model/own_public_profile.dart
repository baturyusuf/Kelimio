//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'own_public_profile.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OwnPublicProfile {
  /// Returns a new [OwnPublicProfile] instance.
  OwnPublicProfile({
    this.username,

    required this.displayName,

    this.bio,

    this.avatarSeed,

    required this.targetLanguage,

    required this.publicProfileEnabled,

    required this.leaderboardOptIn,

    required this.lifetimeScore,

    required this.completedAttempts,

    this.updatedAt,
  });

  @JsonKey(name: r'username', required: false, includeIfNull: false)
  final String? username;

  @JsonKey(name: r'displayName', required: true, includeIfNull: false)
  final String displayName;

  @JsonKey(name: r'bio', required: false, includeIfNull: false)
  final String? bio;

  @JsonKey(name: r'avatarSeed', required: false, includeIfNull: false)
  final String? avatarSeed;

  /// Canonically cased BCP 47 subset: lowercase primary language, optional title-case script, uppercase region, and lowercase variants. Extensions and private-use subtags are outside the initial API contract.
  @JsonKey(name: r'targetLanguage', required: true, includeIfNull: false)
  final String targetLanguage;

  @JsonKey(name: r'publicProfileEnabled', required: true, includeIfNull: false)
  final bool publicProfileEnabled;

  @JsonKey(name: r'leaderboardOptIn', required: true, includeIfNull: false)
  final bool leaderboardOptIn;

  // minimum: 0
  @JsonKey(name: r'lifetimeScore', required: true, includeIfNull: false)
  final int lifetimeScore;

  // minimum: 0
  @JsonKey(name: r'completedAttempts', required: true, includeIfNull: false)
  final int completedAttempts;

  @JsonKey(name: r'updatedAt', required: false, includeIfNull: false)
  final DateTime? updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OwnPublicProfile &&
          other.username == username &&
          other.displayName == displayName &&
          other.bio == bio &&
          other.avatarSeed == avatarSeed &&
          other.targetLanguage == targetLanguage &&
          other.publicProfileEnabled == publicProfileEnabled &&
          other.leaderboardOptIn == leaderboardOptIn &&
          other.lifetimeScore == lifetimeScore &&
          other.completedAttempts == completedAttempts &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      (username == null ? 0 : username.hashCode) +
      displayName.hashCode +
      (bio == null ? 0 : bio.hashCode) +
      (avatarSeed == null ? 0 : avatarSeed.hashCode) +
      targetLanguage.hashCode +
      publicProfileEnabled.hashCode +
      leaderboardOptIn.hashCode +
      lifetimeScore.hashCode +
      completedAttempts.hashCode +
      (updatedAt == null ? 0 : updatedAt.hashCode);

  factory OwnPublicProfile.fromJson(Map<String, dynamic> json) =>
      _$OwnPublicProfileFromJson(json);

  Map<String, dynamic> toJson() => _$OwnPublicProfileToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
