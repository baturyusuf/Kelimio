//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/attempt_state.dart';
import 'package:kelimio_api_client/src/model/question_payload.dart';
import 'package:json_annotation/json_annotation.dart';

part 'attempt_response.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AttemptResponse {
  /// Returns a new [AttemptResponse] instance.
  AttemptResponse({
    required this.id,

    required this.testId,

    required this.testRevisionId,

    required this.state,

    required this.questions,

    required this.startedAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'testId', required: true, includeIfNull: false)
  final String testId;

  @JsonKey(name: r'testRevisionId', required: true, includeIfNull: false)
  final String testRevisionId;

  @JsonKey(name: r'state', required: true, includeIfNull: false)
  final AttemptState state;

  @JsonKey(name: r'questions', required: true, includeIfNull: false)
  final List<QuestionPayload> questions;

  @JsonKey(name: r'startedAt', required: true, includeIfNull: false)
  final DateTime startedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttemptResponse &&
          other.id == id &&
          other.testId == testId &&
          other.testRevisionId == testRevisionId &&
          other.state == state &&
          other.questions == questions &&
          other.startedAt == startedAt;

  @override
  int get hashCode =>
      id.hashCode +
      testId.hashCode +
      testRevisionId.hashCode +
      state.hashCode +
      questions.hashCode +
      startedAt.hashCode;

  factory AttemptResponse.fromJson(Map<String, dynamic> json) =>
      _$AttemptResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AttemptResponseToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
