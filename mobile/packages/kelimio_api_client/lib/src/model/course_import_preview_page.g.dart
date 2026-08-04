// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_import_preview_page.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseImportPreviewPage _$CourseImportPreviewPageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseImportPreviewPage', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['items']);
  final val = CourseImportPreviewPage(
    items: $checkedConvert(
      'items',
      (v) => (v as List<dynamic>)
          .map(
            (e) => CourseImportPreviewRow.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    ),
    nextCursor: $checkedConvert('nextCursor', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$CourseImportPreviewPageToJson(
  CourseImportPreviewPage instance,
) => <String, dynamic>{
  'items': instance.items.map((e) => e.toJson()).toList(),
  if (instance.nextCursor case final value?) 'nextCursor': value,
};
