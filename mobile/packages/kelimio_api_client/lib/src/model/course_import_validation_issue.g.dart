// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_import_validation_issue.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseImportValidationIssue _$CourseImportValidationIssueFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseImportValidationIssue', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['ordinal', 'severity', 'code', 'source', 'message'],
  );
  final val = CourseImportValidationIssue(
    ordinal: $checkedConvert('ordinal', (v) => (v as num).toInt()),
    severity: $checkedConvert(
      'severity',
      (v) => $enumDecode(_$CourseImportValidationIssueSeverityEnumEnumMap, v),
    ),
    code: $checkedConvert('code', (v) => v as String),
    source_: $checkedConvert(
      'source',
      (v) => v == null
          ? null
          : CourseImportSource.fromJson(v as Map<String, dynamic>),
    ),
    message: $checkedConvert('message', (v) => v as String),
  );
  return val;
}, fieldKeyMap: const {'source_': 'source'});

Map<String, dynamic> _$CourseImportValidationIssueToJson(
  CourseImportValidationIssue instance,
) => <String, dynamic>{
  'ordinal': instance.ordinal,
  'severity':
      _$CourseImportValidationIssueSeverityEnumEnumMap[instance.severity]!,
  'code': instance.code,
  'source': instance.source_?.toJson(),
  'message': instance.message,
};

const _$CourseImportValidationIssueSeverityEnumEnumMap = {
  CourseImportValidationIssueSeverityEnum.WARNING: 'WARNING',
  CourseImportValidationIssueSeverityEnum.ERROR: 'ERROR',
};
