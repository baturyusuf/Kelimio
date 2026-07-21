//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
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

    required this.selectedOptionId,
  });

  @JsonKey(name: r'submissionId', required: true, includeIfNull: false)
  final String submissionId;

  @JsonKey(name: r'questionRevisionId', required: true, includeIfNull: false)
  final String questionRevisionId;

  @JsonKey(name: r'selectedOptionId', required: true, includeIfNull: false)
  final String selectedOptionId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubmitAnswerRequest &&
          other.submissionId == submissionId &&
          other.questionRevisionId == questionRevisionId &&
          other.selectedOptionId == selectedOptionId;

  @override
  int get hashCode =>
      submissionId.hashCode +
      questionRevisionId.hashCode +
      selectedOptionId.hashCode;

  factory SubmitAnswerRequest.fromJson(Map<String, dynamic> json) =>
      _$SubmitAnswerRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SubmitAnswerRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
