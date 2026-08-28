//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'leaderboard_entry.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LeaderboardEntry {
  /// Returns a new [LeaderboardEntry] instance.
  LeaderboardEntry({
    required this.rank,

    required this.username,

    required this.displayName,

    this.avatarSeed,

    required this.targetLanguage,

    required this.lifetimeScore,

    required this.completedAttempts,
  });

  // minimum: 1
  @JsonKey(name: r'rank', required: true, includeIfNull: false)
  final int rank;

  @JsonKey(name: r'username', required: true, includeIfNull: false)
  final String username;

  @JsonKey(name: r'displayName', required: true, includeIfNull: false)
  final String displayName;

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaderboardEntry &&
          other.rank == rank &&
          other.username == username &&
          other.displayName == displayName &&
          other.avatarSeed == avatarSeed &&
          other.targetLanguage == targetLanguage &&
          other.lifetimeScore == lifetimeScore &&
          other.completedAttempts == completedAttempts;

  @override
  int get hashCode =>
      rank.hashCode +
      username.hashCode +
      displayName.hashCode +
      (avatarSeed == null ? 0 : avatarSeed.hashCode) +
      targetLanguage.hashCode +
      lifetimeScore.hashCode +
      completedAttempts.hashCode;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardEntryFromJson(json);

  Map<String, dynamic> toJson() => _$LeaderboardEntryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
