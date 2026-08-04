// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'energy_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EnergyResponse _$EnergyResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('EnergyResponse', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['balance', 'maximum', 'unlimited', 'asOf'],
      );
      final val = EnergyResponse(
        balance: $checkedConvert('balance', (v) => (v as num).toInt()),
        maximum: $checkedConvert(
          'maximum',
          (v) => $enumDecode(_$EnergyResponseMaximumEnumEnumMap, v),
        ),
        unlimited: $checkedConvert('unlimited', (v) => v as bool),
        nextRegenerationAt: $checkedConvert(
          'nextRegenerationAt',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
        asOf: $checkedConvert('asOf', (v) => DateTime.parse(v as String)),
      );
      return val;
    });

Map<String, dynamic> _$EnergyResponseToJson(EnergyResponse instance) =>
    <String, dynamic>{
      'balance': instance.balance,
      'maximum': _$EnergyResponseMaximumEnumEnumMap[instance.maximum]!,
      'unlimited': instance.unlimited,
      if (instance.nextRegenerationAt?.toIso8601String() case final value?)
        'nextRegenerationAt': value,
      'asOf': instance.asOf.toIso8601String(),
    };

const _$EnergyResponseMaximumEnumEnumMap = {
  EnergyResponseMaximumEnum.number5: 5,
};
