// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'own_public_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OwnPublicProfile _$OwnPublicProfileFromJson(Map<String, dynamic> json) =>
    $checkedCreate('OwnPublicProfile', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'displayName',
          'targetLanguage',
          'publicProfileEnabled',
          'leaderboardOptIn',
          'lifetimeScore',
          'completedAttempts',
        ],
      );
      final val = OwnPublicProfile(
        username: $checkedConvert('username', (v) => v as String?),
        displayName: $checkedConvert('displayName', (v) => v as String),
        bio: $checkedConvert('bio', (v) => v as String?),
        avatarSeed: $checkedConvert('avatarSeed', (v) => v as String?),
        targetLanguage: $checkedConvert('targetLanguage', (v) => v as String),
        publicProfileEnabled: $checkedConvert(
          'publicProfileEnabled',
          (v) => v as bool,
        ),
        leaderboardOptIn: $checkedConvert('leaderboardOptIn', (v) => v as bool),
        lifetimeScore: $checkedConvert(
          'lifetimeScore',
          (v) => (v as num).toInt(),
        ),
        completedAttempts: $checkedConvert(
          'completedAttempts',
          (v) => (v as num).toInt(),
        ),
        updatedAt: $checkedConvert(
          'updatedAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$OwnPublicProfileToJson(OwnPublicProfile instance) =>
    <String, dynamic>{
      if (instance.username case final value?) 'username': value,
      'displayName': instance.displayName,
      if (instance.bio case final value?) 'bio': value,
      if (instance.avatarSeed case final value?) 'avatarSeed': value,
      'targetLanguage': instance.targetLanguage,
      'publicProfileEnabled': instance.publicProfileEnabled,
      'leaderboardOptIn': instance.leaderboardOptIn,
      'lifetimeScore': instance.lifetimeScore,
      'completedAttempts': instance.completedAttempts,
      if (instance.updatedAt?.toIso8601String() case final value?)
        'updatedAt': value,
    };
