//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'notification_preference.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class NotificationPreference {
  /// Returns a new [NotificationPreference] instance.
  NotificationPreference({
    required this.learningReminders,

    required this.courseUpdates,

    required this.productAnnouncements,

    required this.pushEnabled,

    required this.emailEnabled,

    required this.pushAvailable,

    required this.emailAvailable,

    this.quietHoursStart,

    this.quietHoursEnd,

    required this.version,

    this.updatedAt,
  });

  @JsonKey(name: r'learningReminders', required: true, includeIfNull: false)
  final bool learningReminders;

  @JsonKey(name: r'courseUpdates', required: true, includeIfNull: false)
  final bool courseUpdates;

  @JsonKey(name: r'productAnnouncements', required: true, includeIfNull: false)
  final bool productAnnouncements;

  @JsonKey(name: r'pushEnabled', required: true, includeIfNull: false)
  final bool pushEnabled;

  @JsonKey(name: r'emailEnabled', required: true, includeIfNull: false)
  final bool emailEnabled;

  @JsonKey(name: r'pushAvailable', required: true, includeIfNull: false)
  final bool pushAvailable;

  @JsonKey(name: r'emailAvailable', required: true, includeIfNull: false)
  final bool emailAvailable;

  @JsonKey(name: r'quietHoursStart', required: false, includeIfNull: false)
  final String? quietHoursStart;

  @JsonKey(name: r'quietHoursEnd', required: false, includeIfNull: false)
  final String? quietHoursEnd;

  // minimum: 0
  @JsonKey(name: r'version', required: true, includeIfNull: false)
  final int version;

  @JsonKey(name: r'updatedAt', required: false, includeIfNull: false)
  final DateTime? updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreference &&
          other.learningReminders == learningReminders &&
          other.courseUpdates == courseUpdates &&
          other.productAnnouncements == productAnnouncements &&
          other.pushEnabled == pushEnabled &&
          other.emailEnabled == emailEnabled &&
          other.pushAvailable == pushAvailable &&
          other.emailAvailable == emailAvailable &&
          other.quietHoursStart == quietHoursStart &&
          other.quietHoursEnd == quietHoursEnd &&
          other.version == version &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      learningReminders.hashCode +
      courseUpdates.hashCode +
      productAnnouncements.hashCode +
      pushEnabled.hashCode +
      emailEnabled.hashCode +
      pushAvailable.hashCode +
      emailAvailable.hashCode +
      (quietHoursStart == null ? 0 : quietHoursStart.hashCode) +
      (quietHoursEnd == null ? 0 : quietHoursEnd.hashCode) +
      version.hashCode +
      (updatedAt == null ? 0 : updatedAt.hashCode);

  factory NotificationPreference.fromJson(Map<String, dynamic> json) =>
      _$NotificationPreferenceFromJson(json);

  Map<String, dynamic> toJson() => _$NotificationPreferenceToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
