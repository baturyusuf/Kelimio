//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/energy_response.dart';
import 'package:kelimio_api_client/src/model/attempt_state.dart';
import 'package:json_annotation/json_annotation.dart';

part 'answer_recorded_response.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AnswerRecordedResponse {
  /// Returns a new [AnswerRecordedResponse] instance.
  AnswerRecordedResponse({
    required this.submissionId,

    required this.correct,

    this.correctOptionId,

    this.correctAnswerText,

    required this.activeScoreDelta,

    required this.lifetimeScoreDelta,

    required this.activeQuestionScore,

    required this.lifetimeScore,

    required this.energy,

    required this.attemptState,
  });

  @JsonKey(name: r'submissionId', required: true, includeIfNull: false)
  final String submissionId;

  @JsonKey(name: r'correct', required: true, includeIfNull: false)
  final bool correct;

  @JsonKey(name: r'correctOptionId', required: false, includeIfNull: false)
  final String? correctOptionId;

  @JsonKey(name: r'correctAnswerText', required: false, includeIfNull: false)
  final String? correctAnswerText;

  // minimum: 0
  // maximum: 60
  @JsonKey(name: r'activeScoreDelta', required: true, includeIfNull: false)
  final int activeScoreDelta;

  // minimum: 0
  // maximum: 60
  @JsonKey(name: r'lifetimeScoreDelta', required: true, includeIfNull: false)
  final int lifetimeScoreDelta;

  // minimum: 0
  // maximum: 60
  @JsonKey(name: r'activeQuestionScore', required: true, includeIfNull: false)
  final int activeQuestionScore;

  // minimum: 0
  @JsonKey(name: r'lifetimeScore', required: true, includeIfNull: false)
  final int lifetimeScore;

  @JsonKey(name: r'energy', required: true, includeIfNull: false)
  final EnergyResponse energy;

  @JsonKey(name: r'attemptState', required: true, includeIfNull: false)
  final AttemptState attemptState;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnswerRecordedResponse &&
          other.submissionId == submissionId &&
          other.correct == correct &&
          other.correctOptionId == correctOptionId &&
          other.correctAnswerText == correctAnswerText &&
          other.activeScoreDelta == activeScoreDelta &&
          other.lifetimeScoreDelta == lifetimeScoreDelta &&
          other.activeQuestionScore == activeQuestionScore &&
          other.lifetimeScore == lifetimeScore &&
          other.energy == energy &&
          other.attemptState == attemptState;

  @override
  int get hashCode =>
      submissionId.hashCode +
      correct.hashCode +
      correctOptionId.hashCode +
      correctAnswerText.hashCode +
      activeScoreDelta.hashCode +
      lifetimeScoreDelta.hashCode +
      activeQuestionScore.hashCode +
      lifetimeScore.hashCode +
      energy.hashCode +
      attemptState.hashCode;

  factory AnswerRecordedResponse.fromJson(Map<String, dynamic> json) =>
      _$AnswerRecordedResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AnswerRecordedResponseToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'correctOptionId')) {
      json[r'correctOptionId'] = '[REDACTED]';
    }
    if (json.containsKey(r'correctAnswerText')) {
      json[r'correctAnswerText'] = '[REDACTED]';
    }
    return json.toString();
  }
}
