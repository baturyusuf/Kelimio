//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/matching_selection.dart';
import 'package:json_annotation/json_annotation.dart';

part 'submit_answer_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SubmitAnswerRequest {
  /// Returns a new [SubmitAnswerRequest] instance.
  SubmitAnswerRequest({
    required this.submissionId,

    required this.questionRevisionId,

    this.selectedOptionId,

    this.typedAnswer,

    this.matches,
  });

  @JsonKey(name: r'submissionId', required: true, includeIfNull: false)
  final String submissionId;

  @JsonKey(name: r'questionRevisionId', required: true, includeIfNull: false)
  final String questionRevisionId;

  @JsonKey(name: r'selectedOptionId', required: false, includeIfNull: false)
  final String? selectedOptionId;

  @JsonKey(name: r'typedAnswer', required: false, includeIfNull: false)
  final String? typedAnswer;

  @JsonKey(name: r'matches', required: false, includeIfNull: false)
  final List<MatchingSelection>? matches;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubmitAnswerRequest &&
          other.submissionId == submissionId &&
          other.questionRevisionId == questionRevisionId &&
          other.selectedOptionId == selectedOptionId &&
          other.typedAnswer == typedAnswer &&
          other.matches == matches;

  @override
  int get hashCode =>
      submissionId.hashCode +
      questionRevisionId.hashCode +
      selectedOptionId.hashCode +
      typedAnswer.hashCode +
      matches.hashCode;

  factory SubmitAnswerRequest.fromJson(Map<String, dynamic> json) =>
      _$SubmitAnswerRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SubmitAnswerRequestToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'typedAnswer')) {
      json[r'typedAnswer'] = '[REDACTED]';
    }
    if (json.containsKey(r'matches')) {
      json[r'matches'] = '[REDACTED]';
    }
    return json.toString();
  }
}
