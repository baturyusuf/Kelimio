// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_export.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountExport _$AccountExportFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AccountExport', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'generatedAt',
          'profile',
          'enrollments',
          'completedAttempts',
          'scoreEvents',
          'legalConsents',
        ],
      );
      final val = AccountExport(
        generatedAt: $checkedConvert(
          'generatedAt',
          (v) => DateTime.parse(v as String),
        ),
        profile: $checkedConvert(
          'profile',
          (v) => AccountExportProfile.fromJson(v as Map<String, dynamic>),
        ),
        enrollments: $checkedConvert(
          'enrollments',
          (v) => (v as List<dynamic>).map((e) => e as Object).toList(),
        ),
        completedAttempts: $checkedConvert(
          'completedAttempts',
          (v) => (v as List<dynamic>).map((e) => e as Object).toList(),
        ),
        scoreEvents: $checkedConvert(
          'scoreEvents',
          (v) => (v as List<dynamic>).map((e) => e as Object).toList(),
        ),
        legalConsents: $checkedConvert(
          'legalConsents',
          (v) => (v as List<dynamic>)
              .map((e) => LegalConsent.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$AccountExportToJson(AccountExport instance) =>
    <String, dynamic>{
      'generatedAt': instance.generatedAt.toIso8601String(),
      'profile': instance.profile.toJson(),
      'enrollments': instance.enrollments,
      'completedAttempts': instance.completedAttempts,
      'scoreEvents': instance.scoreEvents,
      'legalConsents': instance.legalConsents.map((e) => e.toJson()).toList(),
    };
