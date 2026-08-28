// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_editor_matching_pair.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CourseEditorMatchingPair _$CourseEditorMatchingPairFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('CourseEditorMatchingPair', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['targetText', 'translations']);
  final val = CourseEditorMatchingPair(
    targetText: $checkedConvert('targetText', (v) => v as String),
    translations: $checkedConvert(
      'translations',
      (v) => Map<String, String>.from(v as Map),
    ),
  );
  return val;
});

Map<String, dynamic> _$CourseEditorMatchingPairToJson(
  CourseEditorMatchingPair instance,
) => <String, dynamic>{
  'targetText': instance.targetText,
  'translations': instance.translations,
};
