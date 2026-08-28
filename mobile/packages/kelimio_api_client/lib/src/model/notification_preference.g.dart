// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_preference.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NotificationPreference _$NotificationPreferenceFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('NotificationPreference', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const [
      'learningReminders',
      'courseUpdates',
      'productAnnouncements',
      'pushEnabled',
      'emailEnabled',
      'pushAvailable',
      'emailAvailable',
      'version',
    ],
  );
  final val = NotificationPreference(
    learningReminders: $checkedConvert('learningReminders', (v) => v as bool),
    courseUpdates: $checkedConvert('courseUpdates', (v) => v as bool),
    productAnnouncements: $checkedConvert(
      'productAnnouncements',
      (v) => v as bool,
    ),
    pushEnabled: $checkedConvert('pushEnabled', (v) => v as bool),
    emailEnabled: $checkedConvert('emailEnabled', (v) => v as bool),
    pushAvailable: $checkedConvert('pushAvailable', (v) => v as bool),
    emailAvailable: $checkedConvert('emailAvailable', (v) => v as bool),
    quietHoursStart: $checkedConvert('quietHoursStart', (v) => v as String?),
    quietHoursEnd: $checkedConvert('quietHoursEnd', (v) => v as String?),
    version: $checkedConvert('version', (v) => (v as num).toInt()),
    updatedAt: $checkedConvert(
      'updatedAt',
      (v) => v == null ? null : DateTime.parse(v as String),
    ),
  );
  return val;
});

Map<String, dynamic> _$NotificationPreferenceToJson(
  NotificationPreference instance,
) => <String, dynamic>{
  'learningReminders': instance.learningReminders,
  'courseUpdates': instance.courseUpdates,
  'productAnnouncements': instance.productAnnouncements,
  'pushEnabled': instance.pushEnabled,
  'emailEnabled': instance.emailEnabled,
  'pushAvailable': instance.pushAvailable,
  'emailAvailable': instance.emailAvailable,
  if (instance.quietHoursStart case final value?) 'quietHoursStart': value,
  if (instance.quietHoursEnd case final value?) 'quietHoursEnd': value,
  'version': instance.version,
  if (instance.updatedAt?.toIso8601String() case final value?)
    'updatedAt': value,
};
