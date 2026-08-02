// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_import_source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseImportSource _$CourseImportSourceFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseImportSource', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'sheetOrdinal',
      'sheetName',
      'rowNumber',
      'columnNumber',
      'reference',
    ],
  );
  final val = CourseImportSource(
    sheetOrdinal: $checkedConvert('sheetOrdinal', (v) => (v as num).toInt()),
    sheetName: $checkedConvert('sheetName', (v) => v as String),
    rowNumber: $checkedConvert('rowNumber', (v) => (v as num).toInt()),
    columnNumber: $checkedConvert('columnNumber', (v) => (v as num?)?.toInt()),
    reference: $checkedConvert('reference', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$CourseImportSourceToJson(CourseImportSource instance) =>
    <String, dynamic>{
      'sheetOrdinal': instance.sheetOrdinal,
      'sheetName': instance.sheetName,
      'rowNumber': instance.rowNumber,
      'columnNumber': instance.columnNumber,
      'reference': instance.reference,
    };
