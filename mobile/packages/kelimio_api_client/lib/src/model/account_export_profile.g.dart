// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_export_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountExportProfile _$AccountExportProfileFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AccountExportProfile', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'id',
      'displayName',
      'appLocale',
      'activeTargetLanguage',
      'timeZone',
    ],
  );
  final val = AccountExportProfile(
    id: $checkedConvert('id', (v) => v as String),
    email: $checkedConvert('email', (v) => v as String?),
    displayName: $checkedConvert('displayName', (v) => v as String),
    username: $checkedConvert('username', (v) => v as String?),
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
  );
  return val;
});

Map<String, dynamic> _$AccountExportProfileToJson(
  AccountExportProfile instance,
) => <String, dynamic>{
  'id': instance.id,
  if (instance.email case final value?) 'email': value,
  'displayName': instance.displayName,
  if (instance.username case final value?) 'username': value,
  'appLocale': instance.appLocale,
  'activeTargetLanguage': instance.activeTargetLanguage,
  if (instance.preferredSupportLanguage case final value?)
    'preferredSupportLanguage': value,
  'timeZone': instance.timeZone,
};
