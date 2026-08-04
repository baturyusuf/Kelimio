// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_import_status_page.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseImportStatusPage _$CourseImportStatusPageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseImportStatusPage', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['items', 'nextCursor']);
  final val = CourseImportStatusPage(
    items: $checkedConvert(
      'items',
      (v) => (v as List<dynamic>)
          .map(
            (e) =>
                CourseImportStatusResponse.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    ),
    nextCursor: $checkedConvert('nextCursor', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$CourseImportStatusPageToJson(
  CourseImportStatusPage instance,
) => <String, dynamic>{
  'items': instance.items.map((e) => e.toJson()).toList(),
  'nextCursor': instance.nextCursor,
};
