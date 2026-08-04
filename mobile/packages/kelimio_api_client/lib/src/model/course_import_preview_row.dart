//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:kelimio_api_client/src/model/course_import_source.dart';
import 'package:json_annotation/json_annotation.dart';

part 'course_import_preview_row.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CourseImportPreviewRow {
  /// Returns a new [CourseImportPreviewRow] instance.
  CourseImportPreviewRow({
    required this.ordinal,

    required this.questionOrdinal,

    required this.projectedQuestionType,

    required this.compositionKind,

    required this.groupPosition,

    required this.source_,

    required this.level,

    required this.unit,

    required this.topic,

    required this.testNumber,

    required this.allocationKind,

    required this.allocationReason,

    required this.resolvedMode,

    required this.recordType,

    required this.targetText,

    required this.translations,

    required this.sentence,

    required this.correctAnswer,

    required this.alternativeCorrectAnswer,

    required this.wrongAnswers,

    required this.matchingGroup,

    required this.hidden,

    required this.note,
  });

  // minimum: 1
  // maximum: 10000
  @JsonKey(name: r'ordinal', required: true, includeIfNull: false)
  final int ordinal;

  // minimum: 1
  // maximum: 10000
  @JsonKey(name: r'questionOrdinal', required: true, includeIfNull: true)
  final int? questionOrdinal;

  @JsonKey(name: r'projectedQuestionType', required: true, includeIfNull: true)
  final CourseImportPreviewRowProjectedQuestionTypeEnum? projectedQuestionType;

  @JsonKey(name: r'compositionKind', required: true, includeIfNull: true)
  final CourseImportPreviewRowCompositionKindEnum? compositionKind;

  // minimum: 1
  // maximum: 6
  @JsonKey(name: r'groupPosition', required: true, includeIfNull: true)
  final int? groupPosition;

  @JsonKey(name: r'source', required: true, includeIfNull: false)
  final CourseImportSource source_;

  @JsonKey(name: r'level', required: true, includeIfNull: false)
  final String level;

  @JsonKey(name: r'unit', required: true, includeIfNull: false)
  final String unit;

  @JsonKey(name: r'topic', required: true, includeIfNull: false)
  final String topic;

  // minimum: 1
  // maximum: 10000
  @JsonKey(name: r'testNumber', required: true, includeIfNull: false)
  final int testNumber;

  @JsonKey(name: r'allocationKind', required: true, includeIfNull: false)
  final CourseImportPreviewRowAllocationKindEnum allocationKind;

  @JsonKey(name: r'allocationReason', required: true, includeIfNull: false)
  final CourseImportPreviewRowAllocationReasonEnum allocationReason;

  @JsonKey(name: r'resolvedMode', required: true, includeIfNull: false)
  final CourseImportPreviewRowResolvedModeEnum resolvedMode;

  @JsonKey(name: r'recordType', required: true, includeIfNull: false)
  final CourseImportPreviewRowRecordTypeEnum recordType;

  @JsonKey(name: r'targetText', required: true, includeIfNull: false)
  final String targetText;

  /// Required non-empty language map for WORD rows; intentionally empty for MULTIPLE_CHOICE_CLOZE and TYPED_CLOZE rows under xlsx-v1.
  @JsonKey(name: r'translations', required: true, includeIfNull: false)
  final Map<String, String> translations;

  @JsonKey(name: r'sentence', required: true, includeIfNull: true)
  final String? sentence;

  @JsonKey(name: r'correctAnswer', required: true, includeIfNull: true)
  final String? correctAnswer;

  @JsonKey(
    name: r'alternativeCorrectAnswer',
    required: true,
    includeIfNull: true,
  )
  final String? alternativeCorrectAnswer;

  @JsonKey(name: r'wrongAnswers', required: true, includeIfNull: false)
  final List<String> wrongAnswers;

  @JsonKey(name: r'matchingGroup', required: true, includeIfNull: true)
  final String? matchingGroup;

  @JsonKey(name: r'hidden', required: true, includeIfNull: false)
  final bool hidden;

  @JsonKey(name: r'note', required: true, includeIfNull: true)
  final String? note;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseImportPreviewRow &&
          other.ordinal == ordinal &&
          other.questionOrdinal == questionOrdinal &&
          other.projectedQuestionType == projectedQuestionType &&
          other.compositionKind == compositionKind &&
          other.groupPosition == groupPosition &&
          other.source_ == source_ &&
          other.level == level &&
          other.unit == unit &&
          other.topic == topic &&
          other.testNumber == testNumber &&
          other.allocationKind == allocationKind &&
          other.allocationReason == allocationReason &&
          other.resolvedMode == resolvedMode &&
          other.recordType == recordType &&
          other.targetText == targetText &&
          other.translations == translations &&
          other.sentence == sentence &&
          other.correctAnswer == correctAnswer &&
          other.alternativeCorrectAnswer == alternativeCorrectAnswer &&
          other.wrongAnswers == wrongAnswers &&
          other.matchingGroup == matchingGroup &&
          other.hidden == hidden &&
          other.note == note;

  @override
  int get hashCode =>
      ordinal.hashCode +
      (questionOrdinal == null ? 0 : questionOrdinal.hashCode) +
      (projectedQuestionType == null ? 0 : projectedQuestionType.hashCode) +
      (compositionKind == null ? 0 : compositionKind.hashCode) +
      (groupPosition == null ? 0 : groupPosition.hashCode) +
      source_.hashCode +
      level.hashCode +
      unit.hashCode +
      topic.hashCode +
      testNumber.hashCode +
      allocationKind.hashCode +
      allocationReason.hashCode +
      resolvedMode.hashCode +
      recordType.hashCode +
      targetText.hashCode +
      translations.hashCode +
      (sentence == null ? 0 : sentence.hashCode) +
      (correctAnswer == null ? 0 : correctAnswer.hashCode) +
      (alternativeCorrectAnswer == null
          ? 0
          : alternativeCorrectAnswer.hashCode) +
      wrongAnswers.hashCode +
      (matchingGroup == null ? 0 : matchingGroup.hashCode) +
      hidden.hashCode +
      (note == null ? 0 : note.hashCode);

  factory CourseImportPreviewRow.fromJson(Map<String, dynamic> json) =>
      _$CourseImportPreviewRowFromJson(json);

  Map<String, dynamic> toJson() => _$CourseImportPreviewRowToJson(this);

  @override
  String toString() {
    final json = toJson();
    if (json.containsKey(r'source')) {
      json[r'source'] = '[REDACTED]';
    }
    if (json.containsKey(r'level')) {
      json[r'level'] = '[REDACTED]';
    }
    if (json.containsKey(r'unit')) {
      json[r'unit'] = '[REDACTED]';
    }
    if (json.containsKey(r'topic')) {
      json[r'topic'] = '[REDACTED]';
    }
    if (json.containsKey(r'targetText')) {
      json[r'targetText'] = '[REDACTED]';
    }
    if (json.containsKey(r'translations')) {
      json[r'translations'] = '[REDACTED]';
    }
    if (json.containsKey(r'sentence')) {
      json[r'sentence'] = '[REDACTED]';
    }
    if (json.containsKey(r'correctAnswer')) {
      json[r'correctAnswer'] = '[REDACTED]';
    }
    if (json.containsKey(r'alternativeCorrectAnswer')) {
      json[r'alternativeCorrectAnswer'] = '[REDACTED]';
    }
    if (json.containsKey(r'wrongAnswers')) {
      json[r'wrongAnswers'] = '[REDACTED]';
    }
    if (json.containsKey(r'matchingGroup')) {
      json[r'matchingGroup'] = '[REDACTED]';
    }
    if (json.containsKey(r'note')) {
      json[r'note'] = '[REDACTED]';
    }
    return json.toString();
  }
}

enum CourseImportPreviewRowProjectedQuestionTypeEnum {
  @JsonValue(r'A')
  A(r'A'),
  @JsonValue(r'B')
  B(r'B'),
  @JsonValue(r'C')
  C(r'C'),
  @JsonValue(r'D')
  D(r'D');

  const CourseImportPreviewRowProjectedQuestionTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CourseImportPreviewRowCompositionKindEnum {
  @JsonValue(r'ROW')
  ROW(r'ROW'),
  @JsonValue(r'MATCHING_GROUP')
  MATCHING_GROUP(r'MATCHING_GROUP');

  const CourseImportPreviewRowCompositionKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CourseImportPreviewRowAllocationKindEnum {
  @JsonValue(r'FIXED')
  FIXED(r'FIXED'),
  @JsonValue(r'AUTOMATIC')
  AUTOMATIC(r'AUTOMATIC');

  const CourseImportPreviewRowAllocationKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CourseImportPreviewRowAllocationReasonEnum {
  @JsonValue(r'FIXED_DECLARATION')
  FIXED_DECLARATION(r'FIXED_DECLARATION'),
  @JsonValue(r'FIXED_TEST_FILL')
  FIXED_TEST_FILL(r'FIXED_TEST_FILL'),
  @JsonValue(r'AUTOMATIC')
  AUTOMATIC(r'AUTOMATIC');

  const CourseImportPreviewRowAllocationReasonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CourseImportPreviewRowResolvedModeEnum {
  @JsonValue(r'MIXED')
  MIXED(r'MIXED'),
  @JsonValue(r'WORD')
  WORD(r'WORD'),
  @JsonValue(r'MATCHING')
  MATCHING(r'MATCHING'),
  @JsonValue(r'MULTIPLE_CHOICE_CLOZE')
  MULTIPLE_CHOICE_CLOZE(r'MULTIPLE_CHOICE_CLOZE'),
  @JsonValue(r'TYPED_CLOZE')
  TYPED_CLOZE(r'TYPED_CLOZE');

  const CourseImportPreviewRowResolvedModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum CourseImportPreviewRowRecordTypeEnum {
  @JsonValue(r'WORD')
  WORD(r'WORD'),
  @JsonValue(r'MULTIPLE_CHOICE_CLOZE')
  MULTIPLE_CHOICE_CLOZE(r'MULTIPLE_CHOICE_CLOZE'),
  @JsonValue(r'TYPED_CLOZE')
  TYPED_CLOZE(r'TYPED_CLOZE');

  const CourseImportPreviewRowRecordTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
