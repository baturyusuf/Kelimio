// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matching_selection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MatchingSelection _$MatchingSelectionFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MatchingSelection', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['targetItemId', 'supportItemId']);
      final val = MatchingSelection(
        targetItemId: $checkedConvert('targetItemId', (v) => v as String),
        supportItemId: $checkedConvert('supportItemId', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$MatchingSelectionToJson(MatchingSelection instance) =>
    <String, dynamic>{
      'targetItemId': instance.targetItemId,
      'supportItemId': instance.supportItemId,
    };
