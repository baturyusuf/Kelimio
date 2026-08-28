//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/leaderboard_entry.dart';
import 'package:json_annotation/json_annotation.dart';

part 'leaderboard.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Leaderboard {
  /// Returns a new [Leaderboard] instance.
  Leaderboard({required this.entries, required this.generatedAt});

  @JsonKey(name: r'entries', required: true, includeIfNull: false)
  final List<LeaderboardEntry> entries;

  @JsonKey(name: r'generatedAt', required: true, includeIfNull: false)
  final DateTime generatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Leaderboard &&
          other.entries == entries &&
          other.generatedAt == generatedAt;

  @override
  int get hashCode => entries.hashCode + generatedAt.hashCode;

  factory Leaderboard.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardFromJson(json);

  Map<String, dynamic> toJson() => _$LeaderboardToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
