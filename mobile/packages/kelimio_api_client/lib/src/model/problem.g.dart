// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'problem.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Problem _$ProblemFromJson(Map<String, dynamic> json) =>
    $checkedCreate('Problem', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['type', 'title', 'status']);
      final val = Problem(
        type: $checkedConvert('type', (v) => v as String),
        title: $checkedConvert('title', (v) => v as String),
        status: $checkedConvert('status', (v) => (v as num).toInt()),
        detail: $checkedConvert('detail', (v) => v as String?),
        instance: $checkedConvert('instance', (v) => v as String?),
        code: $checkedConvert('code', (v) => v as String?),
        requestId: $checkedConvert('requestId', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$ProblemToJson(Problem instance) => <String, dynamic>{
  'type': instance.type,
  'title': instance.title,
  'status': instance.status,
  if (instance.detail case final value?) 'detail': value,
  if (instance.instance case final value?) 'instance': value,
  if (instance.code case final value?) 'code': value,
  if (instance.requestId case final value?) 'requestId': value,
};
