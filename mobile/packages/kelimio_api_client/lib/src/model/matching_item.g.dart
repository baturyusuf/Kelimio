// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'matching_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MatchingItem _$MatchingItemFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MatchingItem', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['id', 'text']);
      final val = MatchingItem(
        id: $checkedConvert('id', (v) => v as String),
        text: $checkedConvert('text', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$MatchingItemToJson(MatchingItem instance) =>
    <String, dynamic>{'id': instance.id, 'text': instance.text};
