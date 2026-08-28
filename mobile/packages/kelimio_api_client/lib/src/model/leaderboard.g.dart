// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'leaderboard.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Leaderboard _$LeaderboardFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Leaderboard', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['entries', 'generatedAt']);
      final val = Leaderboard(
        entries: $checkedConvert(
          'entries',
          (v) => (v as List<dynamic>)
              .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        generatedAt: $checkedConvert(
          'generatedAt',
          (v) => DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$LeaderboardToJson(Leaderboard instance) =>
    <String, dynamic>{
      'entries': instance.entries.map((e) => e.toJson()).toList(),
      'generatedAt': instance.generatedAt.toIso8601String(),
    };
