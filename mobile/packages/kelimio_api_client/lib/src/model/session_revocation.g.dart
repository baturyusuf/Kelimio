// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_revocation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SessionRevocation _$SessionRevocationFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SessionRevocation', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['revokedAt']);
      final val = SessionRevocation(
        revokedAt: $checkedConvert(
          'revokedAt',
          (v) => DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SessionRevocationToJson(SessionRevocation instance) =>
    <String, dynamic>{'revokedAt': instance.revokedAt.toIso8601String()};
