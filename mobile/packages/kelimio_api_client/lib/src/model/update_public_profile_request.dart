//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'update_public_profile_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class UpdatePublicProfileRequest {
  /// Returns a new [UpdatePublicProfileRequest] instance.
  UpdatePublicProfileRequest({
    this.username,

    required this.displayName,

    this.bio,

    this.avatarSeed,

    required this.publicProfileEnabled,

    required this.leaderboardOptIn,
  });

  @JsonKey(name: r'username', required: false, includeIfNull: false)
  final String? username;

  @JsonKey(name: r'displayName', required: true, includeIfNull: false)
  final String displayName;

  @JsonKey(name: r'bio', required: false, includeIfNull: false)
  final String? bio;

  @JsonKey(name: r'avatarSeed', required: false, includeIfNull: false)
  final String? avatarSeed;

  @JsonKey(name: r'publicProfileEnabled', required: true, includeIfNull: false)
  final bool publicProfileEnabled;

  @JsonKey(name: r'leaderboardOptIn', required: true, includeIfNull: false)
  final bool leaderboardOptIn;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdatePublicProfileRequest &&
          other.username == username &&
          other.displayName == displayName &&
          other.bio == bio &&
          other.avatarSeed == avatarSeed &&
          other.publicProfileEnabled == publicProfileEnabled &&
          other.leaderboardOptIn == leaderboardOptIn;

  @override
  int get hashCode =>
      (username == null ? 0 : username.hashCode) +
      displayName.hashCode +
      (bio == null ? 0 : bio.hashCode) +
      (avatarSeed == null ? 0 : avatarSeed.hashCode) +
      publicProfileEnabled.hashCode +
      leaderboardOptIn.hashCode;

  factory UpdatePublicProfileRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdatePublicProfileRequestFromJson(json);

  Map<String, dynamic> toJson() => _$UpdatePublicProfileRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
