// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_import_issue_page.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseImportIssuePage _$CourseImportIssuePageFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseImportIssuePage', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['items']);
  final val = CourseImportIssuePage(
    items: $checkedConvert(
      'items',
      (v) => (v as List<dynamic>)
          .map(
            (e) =>
                CourseImportValidationIssue.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    ),
    nextCursor: $checkedConvert('nextCursor', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$CourseImportIssuePageToJson(
  CourseImportIssuePage instance,
) => <String, dynamic>{
  'items': instance.items.map((e) => e.toJson()).toList(),
  if (instance.nextCursor case final value?) 'nextCursor': value,
};
