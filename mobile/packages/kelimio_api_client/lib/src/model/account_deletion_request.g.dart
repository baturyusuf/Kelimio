// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_deletion_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountDeletionRequest _$AccountDeletionRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AccountDeletionRequest', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'id',
      'status',
      'requestedAt',
      'scheduledFor',
      'created',
    ],
  );
  final val = AccountDeletionRequest(
    id: $checkedConvert('id', (v) => v as String),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(_$AccountDeletionRequestStatusEnumEnumMap, v),
    ),
    requestedAt: $checkedConvert(
      'requestedAt',
      (v) => DateTime.parse(v as String),
    ),
    scheduledFor: $checkedConvert(
      'scheduledFor',
      (v) => DateTime.parse(v as String),
    ),
    created: $checkedConvert('created', (v) => v as bool),
  );
  return val;
});

Map<String, dynamic> _$AccountDeletionRequestToJson(
  AccountDeletionRequest instance,
) => <String, dynamic>{
  'id': instance.id,
  'status': _$AccountDeletionRequestStatusEnumEnumMap[instance.status]!,
  'requestedAt': instance.requestedAt.toIso8601String(),
  'scheduledFor': instance.scheduledFor.toIso8601String(),
  'created': instance.created,
};

const _$AccountDeletionRequestStatusEnumEnumMap = {
  AccountDeletionRequestStatusEnum.PENDING: 'PENDING',
  AccountDeletionRequestStatusEnum.CANCELLED: 'CANCELLED',
  AccountDeletionRequestStatusEnum.COMPLETED: 'COMPLETED',
};
