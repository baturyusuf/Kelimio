//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/answer_option.dart';
import 'package:kelimio_api_client/src/model/matching_item.dart';
import 'package:json_annotation/json_annotation.dart';

part 'question_payload.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class QuestionPayload {
  /// Returns a new [QuestionPayload] instance.
  QuestionPayload({
    required this.questionId,

    required this.questionRevisionId,

    required this.type,

    required this.position,

    required this.prompt,

    required this.options,

    required this.targetItems,

    required this.supportItems,
  });

  @JsonKey(name: r'questionId', required: true, includeIfNull: false)
  final String questionId;

  @JsonKey(name: r'questionRevisionId', required: true, includeIfNull: false)
  final String questionRevisionId;

  @JsonKey(name: r'type', required: true, includeIfNull: false)
  final QuestionPayloadTypeEnum type;

  // minimum: 1
  @JsonKey(name: r'position', required: true, includeIfNull: false)
  final int position;

  /// Required question prompt value. MATCHING carries an explicit null; every other question type carries nonblank target-language text.
  @JsonKey(name: r'prompt', required: true, includeIfNull: true)
  final String? prompt;

  @JsonKey(name: r'options', required: true, includeIfNull: false)
  final List<AnswerOption> options;

  @JsonKey(name: r'targetItems', required: true, includeIfNull: false)
  final List<MatchingItem> targetItems;

  @JsonKey(name: r'supportItems', required: true, includeIfNull: false)
  final List<MatchingItem> supportItems;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionPayload &&
          other.questionId == questionId &&
          other.questionRevisionId == questionRevisionId &&
          other.type == type &&
          other.position == position &&
          other.prompt == prompt &&
          other.options == options &&
          other.targetItems == targetItems &&
          other.supportItems == supportItems;

  @override
  int get hashCode =>
      questionId.hashCode +
      questionRevisionId.hashCode +
      type.hashCode +
      position.hashCode +
      (prompt == null ? 0 : prompt.hashCode) +
      options.hashCode +
      targetItems.hashCode +
      supportItems.hashCode;

  factory QuestionPayload.fromJson(Map<String, dynamic> json) =>
      _$QuestionPayloadFromJson(json);

  Map<String, dynamic> toJson() => _$QuestionPayloadToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum QuestionPayloadTypeEnum {
  @JsonValue(r'WORD_MULTIPLE_CHOICE')
  WORD_MULTIPLE_CHOICE(r'WORD_MULTIPLE_CHOICE'),
  @JsonValue(r'MULTIPLE_CHOICE_CLOZE')
  MULTIPLE_CHOICE_CLOZE(r'MULTIPLE_CHOICE_CLOZE'),
  @JsonValue(r'TYPED_CLOZE')
  TYPED_CLOZE(r'TYPED_CLOZE'),
  @JsonValue(r'MATCHING')
  MATCHING(r'MATCHING');

  const QuestionPayloadTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
