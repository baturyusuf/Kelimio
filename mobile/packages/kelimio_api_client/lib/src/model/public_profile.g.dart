// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'public_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PublicProfile _$PublicProfileFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PublicProfile', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'username',
      'displayName',
      'targetLanguage',
      'lifetimeScore',
      'completedAttempts',
      'joinedAt',
    ],
  );
  final val = PublicProfile(
    username: $checkedConvert('username', (v) => v as String),
    displayName: $checkedConvert('displayName', (v) => v as String),
    bio: $checkedConvert('bio', (v) => v as String?),
    avatarSeed: $checkedConvert('avatarSeed', (v) => v as String?),
    targetLanguage: $checkedConvert('targetLanguage', (v) => v as String),
    lifetimeScore: $checkedConvert('lifetimeScore', (v) => (v as num).toInt()),
    completedAttempts: $checkedConvert(
      'completedAttempts',
      (v) => (v as num).toInt(),
    ),
    joinedAt: $checkedConvert('joinedAt', (v) => DateTime.parse(v as String)),
  );
  return val;
});

Map<String, dynamic> _$PublicProfileToJson(PublicProfile instance) =>
    <String, dynamic>{
      'username': instance.username,
      'displayName': instance.displayName,
      if (instance.bio case final value?) 'bio': value,
      if (instance.avatarSeed case final value?) 'avatarSeed': value,
      'targetLanguage': instance.targetLanguage,
      'lifetimeScore': instance.lifetimeScore,
      'completedAttempts': instance.completedAttempts,
      'joinedAt': instance.joinedAt.toIso8601String(),
    };
