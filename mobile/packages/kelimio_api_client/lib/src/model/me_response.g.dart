// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'me_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MeResponse _$MeResponseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MeResponse', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'id',
          'displayName',
          'appLocale',
          'activeTargetLanguage',
          'timeZone',
          'profileVersion',
          'profileSetupStatus',
        ],
      );
      final val = MeResponse(
        id: $checkedConvert('id', (v) => v as String),
        displayName: $checkedConvert('displayName', (v) => v as String),
        appLocale: $checkedConvert('appLocale', (v) => v as String),
        activeTargetLanguage: $checkedConvert(
          'activeTargetLanguage',
          (v) => v as String,
        ),
        preferredSupportLanguage: $checkedConvert(
          'preferredSupportLanguage',
          (v) => v as String?,
        ),
        timeZone: $checkedConvert('timeZone', (v) => v as String),
        profileVersion: $checkedConvert(
          'profileVersion',
          (v) => (v as num).toInt(),
        ),
        profileSetupStatus: $checkedConvert(
          'profileSetupStatus',
          (v) => $enumDecode(_$MeResponseProfileSetupStatusEnumEnumMap, v),
        ),
      );
      return val;
    });

Map<String, dynamic> _$MeResponseToJson(
  MeResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'displayName': instance.displayName,
  'appLocale': instance.appLocale,
  'activeTargetLanguage': instance.activeTargetLanguage,
  if (instance.preferredSupportLanguage case final value?)
    'preferredSupportLanguage': value,
  'timeZone': instance.timeZone,
  'profileVersion': instance.profileVersion,
  'profileSetupStatus':
      _$MeResponseProfileSetupStatusEnumEnumMap[instance.profileSetupStatus]!,
};

const _$MeResponseProfileSetupStatusEnumEnumMap = {
  MeResponseProfileSetupStatusEnum.REQUIRED: 'REQUIRED',
  MeResponseProfileSetupStatusEnum.COMPLETE: 'COMPLETE',
};
