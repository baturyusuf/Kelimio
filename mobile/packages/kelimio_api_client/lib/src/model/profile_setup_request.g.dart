// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_setup_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileSetupRequest _$ProfileSetupRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ProfileSetupRequest', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'displayName',
          'appLocale',
          'activeTargetLanguage',
          'preferredSupportLanguage',
          'timeZone',
        ],
      );
      final val = ProfileSetupRequest(
        displayName: $checkedConvert('displayName', (v) => v as String),
        appLocale: $checkedConvert(
          'appLocale',
          (v) => $enumDecode(_$ProfileSetupRequestAppLocaleEnumEnumMap, v),
        ),
        activeTargetLanguage: $checkedConvert(
          'activeTargetLanguage',
          (v) => v as String,
        ),
        preferredSupportLanguage: $checkedConvert(
          'preferredSupportLanguage',
          (v) => v as String,
        ),
        timeZone: $checkedConvert('timeZone', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$ProfileSetupRequestToJson(
  ProfileSetupRequest instance,
) => <String, dynamic>{
  'displayName': instance.displayName,
  'appLocale': _$ProfileSetupRequestAppLocaleEnumEnumMap[instance.appLocale]!,
  'activeTargetLanguage': instance.activeTargetLanguage,
  'preferredSupportLanguage': instance.preferredSupportLanguage,
  'timeZone': instance.timeZone,
};

const _$ProfileSetupRequestAppLocaleEnumEnumMap = {
  ProfileSetupRequestAppLocaleEnum.tr: 'tr',
  ProfileSetupRequestAppLocaleEnum.en: 'en',
  ProfileSetupRequestAppLocaleEnum.ar: 'ar',
};
