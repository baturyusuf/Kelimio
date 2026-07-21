// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TestSummary _$TestSummaryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TestSummary', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'id',
          'revisionId',
          'name',
          'position',
          'questionCount',
        ],
      );
      final val = TestSummary(
        id: $checkedConvert('id', (v) => v as String),
        revisionId: $checkedConvert('revisionId', (v) => v as String),
        name: $checkedConvert('name', (v) => v as String),
        position: $checkedConvert('position', (v) => (v as num).toInt()),
        questionCount: $checkedConvert(
          'questionCount',
          (v) => (v as num).toInt(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$TestSummaryToJson(TestSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'revisionId': instance.revisionId,
      'name': instance.name,
      'position': instance.position,
      'questionCount': instance.questionCount,
    };
