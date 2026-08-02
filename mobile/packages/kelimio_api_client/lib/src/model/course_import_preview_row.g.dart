// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_import_preview_row.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseImportPreviewRow _$CourseImportPreviewRowFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseImportPreviewRow', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'ordinal',
      'source',
      'level',
      'unit',
      'topic',
      'testNumber',
      'allocationKind',
      'allocationReason',
      'resolvedMode',
      'recordType',
      'targetText',
      'translations',
      'sentence',
      'correctAnswer',
      'alternativeCorrectAnswer',
      'wrongAnswers',
      'matchingGroup',
      'hidden',
      'note',
    ],
  );
  final val = CourseImportPreviewRow(
    ordinal: $checkedConvert('ordinal', (v) => (v as num).toInt()),
    source_: $checkedConvert(
      'source',
      (v) => CourseImportSource.fromJson(v as Map<String, dynamic>),
    ),
    level: $checkedConvert('level', (v) => v as String),
    unit: $checkedConvert('unit', (v) => v as String),
    topic: $checkedConvert('topic', (v) => v as String),
    testNumber: $checkedConvert('testNumber', (v) => (v as num).toInt()),
    allocationKind: $checkedConvert(
      'allocationKind',
      (v) => $enumDecode(_$CourseImportPreviewRowAllocationKindEnumEnumMap, v),
    ),
    allocationReason: $checkedConvert(
      'allocationReason',
      (v) =>
          $enumDecode(_$CourseImportPreviewRowAllocationReasonEnumEnumMap, v),
    ),
    resolvedMode: $checkedConvert(
      'resolvedMode',
      (v) => $enumDecode(_$CourseImportPreviewRowResolvedModeEnumEnumMap, v),
    ),
    recordType: $checkedConvert(
      'recordType',
      (v) => $enumDecode(_$CourseImportPreviewRowRecordTypeEnumEnumMap, v),
    ),
    targetText: $checkedConvert('targetText', (v) => v as String),
    translations: $checkedConvert(
      'translations',
      (v) => Map<String, String>.from(v as Map),
    ),
    sentence: $checkedConvert('sentence', (v) => v as String?),
    correctAnswer: $checkedConvert('correctAnswer', (v) => v as String?),
    alternativeCorrectAnswer: $checkedConvert(
      'alternativeCorrectAnswer',
      (v) => v as String?,
    ),
    wrongAnswers: $checkedConvert(
      'wrongAnswers',
      (v) => (v as List<dynamic>).map((e) => e as String).toList(),
    ),
    matchingGroup: $checkedConvert('matchingGroup', (v) => v as String?),
    hidden: $checkedConvert('hidden', (v) => v as bool),
    note: $checkedConvert('note', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'source_': 'source'});

Map<String, dynamic> _$CourseImportPreviewRowToJson(
  CourseImportPreviewRow instance,
) => <String, dynamic>{
  'ordinal': instance.ordinal,
  'source': instance.source_.toJson(),
  'level': instance.level,
  'unit': instance.unit,
  'topic': instance.topic,
  'testNumber': instance.testNumber,
  'allocationKind':
      _$CourseImportPreviewRowAllocationKindEnumEnumMap[instance
          .allocationKind]!,
  'allocationReason':
      _$CourseImportPreviewRowAllocationReasonEnumEnumMap[instance
          .allocationReason]!,
  'resolvedMode':
      _$CourseImportPreviewRowResolvedModeEnumEnumMap[instance.resolvedMode]!,
  'recordType':
      _$CourseImportPreviewRowRecordTypeEnumEnumMap[instance.recordType]!,
  'targetText': instance.targetText,
  'translations': instance.translations,
  'sentence': instance.sentence,
  'correctAnswer': instance.correctAnswer,
  'alternativeCorrectAnswer': instance.alternativeCorrectAnswer,
  'wrongAnswers': instance.wrongAnswers,
  'matchingGroup': instance.matchingGroup,
  'hidden': instance.hidden,
  'note': instance.note,
};

const _$CourseImportPreviewRowAllocationKindEnumEnumMap = {
  CourseImportPreviewRowAllocationKindEnum.FIXED: 'FIXED',
  CourseImportPreviewRowAllocationKindEnum.AUTOMATIC: 'AUTOMATIC',
};

const _$CourseImportPreviewRowAllocationReasonEnumEnumMap = {
  CourseImportPreviewRowAllocationReasonEnum.FIXED_DECLARATION:
      'FIXED_DECLARATION',
  CourseImportPreviewRowAllocationReasonEnum.FIXED_TEST_FILL: 'FIXED_TEST_FILL',
  CourseImportPreviewRowAllocationReasonEnum.AUTOMATIC: 'AUTOMATIC',
};

const _$CourseImportPreviewRowResolvedModeEnumEnumMap = {
  CourseImportPreviewRowResolvedModeEnum.MIXED: 'MIXED',
  CourseImportPreviewRowResolvedModeEnum.WORD: 'WORD',
  CourseImportPreviewRowResolvedModeEnum.MATCHING: 'MATCHING',
  CourseImportPreviewRowResolvedModeEnum.MULTIPLE_CHOICE_CLOZE:
      'MULTIPLE_CHOICE_CLOZE',
  CourseImportPreviewRowResolvedModeEnum.TYPED_CLOZE: 'TYPED_CLOZE',
};

const _$CourseImportPreviewRowRecordTypeEnumEnumMap = {
  CourseImportPreviewRowRecordTypeEnum.WORD: 'WORD',
  CourseImportPreviewRowRecordTypeEnum.MULTIPLE_CHOICE_CLOZE:
      'MULTIPLE_CHOICE_CLOZE',
  CourseImportPreviewRowRecordTypeEnum.TYPED_CLOZE: 'TYPED_CLOZE',
};
