//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/attempt_state.dart';
import 'package:json_annotation/json_annotation.dart';

part 'finish_attempt_response.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FinishAttemptResponse {
  /// Returns a new [FinishAttemptResponse] instance.
  FinishAttemptResponse({
    required this.attemptId,

    required this.state,

    required this.correctCount,

    required this.questionCount,

    required this.correctRatio,

    required this.completedAt,
  });

  @JsonKey(name: r'attemptId', required: true, includeIfNull: false)
  final String attemptId;

  @JsonKey(name: r'state', required: true, includeIfNull: false)
  final AttemptState state;

  // minimum: 0
  @JsonKey(name: r'correctCount', required: true, includeIfNull: false)
  final int correctCount;

  // minimum: 1
  @JsonKey(name: r'questionCount', required: true, includeIfNull: false)
  final int questionCount;

  // minimum: 0
  // maximum: 1
  @JsonKey(name: r'correctRatio', required: true, includeIfNull: false)
  final num correctRatio;

  @JsonKey(name: r'completedAt', required: true, includeIfNull: false)
  final DateTime completedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinishAttemptResponse &&
          other.attemptId == attemptId &&
          other.state == state &&
          other.correctCount == correctCount &&
          other.questionCount == questionCount &&
          other.correctRatio == correctRatio &&
          other.completedAt == completedAt;

  @override
  int get hashCode =>
      attemptId.hashCode +
      state.hashCode +
      correctCount.hashCode +
      questionCount.hashCode +
      correctRatio.hashCode +
      completedAt.hashCode;

  factory FinishAttemptResponse.fromJson(Map<String, dynamic> json) =>
      _$FinishAttemptResponseFromJson(json);

  Map<String, dynamic> toJson() => _$FinishAttemptResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
