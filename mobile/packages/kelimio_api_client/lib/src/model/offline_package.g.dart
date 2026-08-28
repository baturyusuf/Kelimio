// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_package.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OfflinePackage _$OfflinePackageFromJson(Map<String, dynamic> json) =>
    $checkedCreate('OfflinePackage', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'courseId',
          'courseReleaseId',
          'supportLanguage',
          'formatVersion',
          'sha256',
          'downloadUrl',
          'expiresAt',
        ],
      );
      final val = OfflinePackage(
        courseId: $checkedConvert('courseId', (v) => v as String),
        courseReleaseId: $checkedConvert('courseReleaseId', (v) => v as String),
        supportLanguage: $checkedConvert('supportLanguage', (v) => v as String),
        formatVersion: $checkedConvert(
          'formatVersion',
          (v) => $enumDecode(_$OfflinePackageFormatVersionEnumEnumMap, v),
        ),
        sha256: $checkedConvert('sha256', (v) => v as String),
        downloadUrl: $checkedConvert('downloadUrl', (v) => v as String),
        expiresAt: $checkedConvert(
          'expiresAt',
          (v) => DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$OfflinePackageToJson(OfflinePackage instance) =>
    <String, dynamic>{
      'courseId': instance.courseId,
      'courseReleaseId': instance.courseReleaseId,
      'supportLanguage': instance.supportLanguage,
      'formatVersion':
          _$OfflinePackageFormatVersionEnumEnumMap[instance.formatVersion]!,
      'sha256': instance.sha256,
      'downloadUrl': instance.downloadUrl,
      'expiresAt': instance.expiresAt.toIso8601String(),
    };

const _$OfflinePackageFormatVersionEnumEnumMap = {
  OfflinePackageFormatVersionEnum.number1: 1,
};
