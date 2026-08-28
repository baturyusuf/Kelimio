// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'legal_consent.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LegalConsent _$LegalConsentFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LegalConsent', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'documentId',
          'documentVersion',
          'action',
          'occurredAt',
        ],
      );
      final val = LegalConsent(
        documentId: $checkedConvert('documentId', (v) => v as String),
        documentVersion: $checkedConvert('documentVersion', (v) => v as String),
        action: $checkedConvert(
          'action',
          (v) => $enumDecode(_$LegalConsentActionEnumEnumMap, v),
        ),
        occurredAt: $checkedConvert(
          'occurredAt',
          (v) => DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$LegalConsentToJson(LegalConsent instance) =>
    <String, dynamic>{
      'documentId': instance.documentId,
      'documentVersion': instance.documentVersion,
      'action': _$LegalConsentActionEnumEnumMap[instance.action]!,
      'occurredAt': instance.occurredAt.toIso8601String(),
    };

const _$LegalConsentActionEnumEnumMap = {
  LegalConsentActionEnum.ACCEPTED: 'ACCEPTED',
  LegalConsentActionEnum.WITHDRAWN: 'WITHDRAWN',
};
