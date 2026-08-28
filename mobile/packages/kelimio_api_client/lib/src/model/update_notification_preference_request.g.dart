// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_notification_preference_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateNotificationPreferenceRequest
_$UpdateNotificationPreferenceRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('UpdateNotificationPreferenceRequest', json, (
  $checkedConvert,
) {
  $checkKeys(
    json,
    requiredKeys: const [
      'expectedVersion',
      'learningReminders',
      'courseUpdates',
      'productAnnouncements',
      'pushEnabled',
      'emailEnabled',
    ],
  );
  final val = UpdateNotificationPreferenceRequest(
    expectedVersion: $checkedConvert(
      'expectedVersion',
      (v) => (v as num).toInt(),
    ),
    learningReminders: $checkedConvert('learningReminders', (v) => v as bool),
    courseUpdates: $checkedConvert('courseUpdates', (v) => v as bool),
    productAnnouncements: $checkedConvert(
      'productAnnouncements',
      (v) => v as bool,
    ),
    pushEnabled: $checkedConvert('pushEnabled', (v) => v as bool),
    emailEnabled: $checkedConvert('emailEnabled', (v) => v as bool),
    quietHoursStart: $checkedConvert('quietHoursStart', (v) => v as String?),
    quietHoursEnd: $checkedConvert('quietHoursEnd', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$UpdateNotificationPreferenceRequestToJson(
  UpdateNotificationPreferenceRequest instance,
) => <String, dynamic>{
  'expectedVersion': instance.expectedVersion,
  'learningReminders': instance.learningReminders,
  'courseUpdates': instance.courseUpdates,
  'productAnnouncements': instance.productAnnouncements,
  'pushEnabled': instance.pushEnabled,
  'emailEnabled': instance.emailEnabled,
  if (instance.quietHoursStart case final value?) 'quietHoursStart': value,
  if (instance.quietHoursEnd case final value?) 'quietHoursEnd': value,
};
