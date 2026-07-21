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
          'subject',
          'displayName',
          'appLocale',
          'activeTargetLanguage',
        ],
      );
      final val = MeResponse(
        id: $checkedConvert('id', (v) => v as String),
        subject: $checkedConvert('subject', (v) => v as String),
        displayName: $checkedConvert('displayName', (v) => v as String),
        username: $checkedConvert('username', (v) => v as String?),
        appLocale: $checkedConvert('appLocale', (v) => v as String),
        activeTargetLanguage: $checkedConvert(
          'activeTargetLanguage',
          (v) => v as String,
        ),
      );
      return val;
    });

Map<String, dynamic> _$MeResponseToJson(MeResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'subject': instance.subject,
      'displayName': instance.displayName,
      if (instance.username case final value?) 'username': value,
      'appLocale': instance.appLocale,
      'activeTargetLanguage': instance.activeTargetLanguage,
    };
