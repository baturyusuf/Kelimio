// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'leaderboard_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LeaderboardEntry _$LeaderboardEntryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LeaderboardEntry', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'rank',
          'username',
          'displayName',
          'targetLanguage',
          'lifetimeScore',
          'completedAttempts',
        ],
      );
      final val = LeaderboardEntry(
        rank: $checkedConvert('rank', (v) => (v as num).toInt()),
        username: $checkedConvert('username', (v) => v as String),
        displayName: $checkedConvert('displayName', (v) => v as String),
        avatarSeed: $checkedConvert('avatarSeed', (v) => v as String?),
        targetLanguage: $checkedConvert('targetLanguage', (v) => v as String),
        lifetimeScore: $checkedConvert(
          'lifetimeScore',
          (v) => (v as num).toInt(),
        ),
        completedAttempts: $checkedConvert(
          'completedAttempts',
          (v) => (v as num).toInt(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$LeaderboardEntryToJson(LeaderboardEntry instance) =>
    <String, dynamic>{
      'rank': instance.rank,
      'username': instance.username,
      'displayName': instance.displayName,
      if (instance.avatarSeed case final value?) 'avatarSeed': value,
      'targetLanguage': instance.targetLanguage,
      'lifetimeScore': instance.lifetimeScore,
      'completedAttempts': instance.completedAttempts,
    };
