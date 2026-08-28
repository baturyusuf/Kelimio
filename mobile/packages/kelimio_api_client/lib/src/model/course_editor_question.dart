//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_editor_matching_pair.dart';
import 'package:kelimio_api_client/src/model/course_editor_option.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_editor_question.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseEditorQuestion {
  /// Returns a new [CourseEditorQuestion] instance.
  CourseEditorQuestion({
    this.id,

    required this.type,

    this.prompt,

    this.correctAnswer,

    this.alternativeCorrectAnswer,

    required this.translations,

    required this.options,

    required this.matchingPairs,
  });

  @JsonKey(name: r'id', required: false, includeIfNull: false)
  final String? id;

  @JsonKey(name: r'type', required: true, includeIfNull: false)
  final CourseEditorQuestionTypeEnum type;

  @JsonKey(name: r'prompt', required: false, includeIfNull: false)
  final String? prompt;

  @JsonKey(name: r'correctAnswer', required: false, includeIfNull: false)
  final String? correctAnswer;

  @JsonKey(
    name: r'alternativeCorrectAnswer',
    required: false,
    includeIfNull: false,
  )
  final String? alternativeCorrectAnswer;

  @JsonKey(name: r'translations', required: true, includeIfNull: false)
  final Map<String, String> translations;

  @JsonKey(name: r'options', required: true, includeIfNull: false)
  final List<CourseEditorOption> options;

  @JsonKey(name: r'matchingPairs', required: true, includeIfNull: false)
  final List<CourseEditorMatchingPair> matchingPairs;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseEditorQuestion &&
          other.id == id &&
          other.type == type &&
          other.prompt == prompt &&
          other.correctAnswer == correctAnswer &&
          other.alternativeCorrectAnswer == alternativeCorrectAnswer &&
          other.translations == translations &&
          other.options == options &&
          other.matchingPairs == matchingPairs;

  @override
  int get hashCode =>
      (id == null ? 0 : id.hashCode) +
      type.hashCode +
      (prompt == null ? 0 : prompt.hashCode) +
      (correctAnswer == null ? 0 : correctAnswer.hashCode) +
      (alternativeCorrectAnswer == null
          ? 0
          : alternativeCorrectAnswer.hashCode) +
      translations.hashCode +
      options.hashCode +
      matchingPairs.hashCode;

  factory CourseEditorQuestion.fromJson(Map<String, dynamic> json) =>
      _$CourseEditorQuestionFromJson(json);

  Map<String, dynamic> toJson() => _$CourseEditorQuestionToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'prompt')) {
      json[r'prompt'] = '[REDACTED]';
    }
    if (json.containsKey(r'correctAnswer')) {
      json[r'correctAnswer'] = '[REDACTED]';
    }
    if (json.containsKey(r'alternativeCorrectAnswer')) {
      json[r'alternativeCorrectAnswer'] = '[REDACTED]';
    }
    if (json.containsKey(r'translations')) {
      json[r'translations'] = '[REDACTED]';
    }
    if (json.containsKey(r'options')) {
      json[r'options'] = '[REDACTED]';
    }
    if (json.containsKey(r'matchingPairs')) {
      json[r'matchingPairs'] = '[REDACTED]';
    }
    return json.toString();
  }
}

enum CourseEditorQuestionTypeEnum {
  @JsonValue(r'WORD_MULTIPLE_CHOICE')
  WORD_MULTIPLE_CHOICE(r'WORD_MULTIPLE_CHOICE'),
  @JsonValue(r'MULTIPLE_CHOICE_CLOZE')
  MULTIPLE_CHOICE_CLOZE(r'MULTIPLE_CHOICE_CLOZE'),
  @JsonValue(r'TYPED_CLOZE')
  TYPED_CLOZE(r'TYPED_CLOZE'),
  @JsonValue(r'MATCHING')
  MATCHING(r'MATCHING');

  const CourseEditorQuestionTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
