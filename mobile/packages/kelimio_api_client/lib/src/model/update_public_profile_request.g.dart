// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_public_profile_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdatePublicProfileRequest _$UpdatePublicProfileRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('UpdatePublicProfileRequest', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'displayName',
      'publicProfileEnabled',
      'leaderboardOptIn',
    ],
  );
  final val = UpdatePublicProfileRequest(
    username: $checkedConvert('username', (v) => v as String?),
    displayName: $checkedConvert('displayName', (v) => v as String),
    bio: $checkedConvert('bio', (v) => v as String?),
    avatarSeed: $checkedConvert('avatarSeed', (v) => v as String?),
    publicProfileEnabled: $checkedConvert(
      'publicProfileEnabled',
      (v) => v as bool,
    ),
    leaderboardOptIn: $checkedConvert('leaderboardOptIn', (v) => v as bool),
  );
  return val;
});

Map<String, dynamic> _$UpdatePublicProfileRequestToJson(
  UpdatePublicProfileRequest instance,
) => <String, dynamic>{
  if (instance.username case final value?) 'username': value,
  'displayName': instance.displayName,
  if (instance.bio case final value?) 'bio': value,
  if (instance.avatarSeed case final value?) 'avatarSeed': value,
  'publicProfileEnabled': instance.publicProfileEnabled,
  'leaderboardOptIn': instance.leaderboardOptIn,
};
