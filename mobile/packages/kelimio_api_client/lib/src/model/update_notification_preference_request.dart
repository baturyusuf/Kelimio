//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

part 'update_notification_preference_request.g.dart';

@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class UpdateNotificationPreferenceRequest {
  /// Returns a new [UpdateNotificationPreferenceRequest] instance.
  UpdateNotificationPreferenceRequest({
    required this.expectedVersion,

    required this.learningReminders,

    required this.courseUpdates,

    required this.productAnnouncements,

    required this.pushEnabled,

    required this.emailEnabled,

    this.quietHoursStart,

    this.quietHoursEnd,
  });

  // minimum: 0
  @JsonKey(name: r'expectedVersion', required: true, includeIfNull: false)
  final int expectedVersion;

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

  @JsonKey(name: r'quietHoursStart', required: false, includeIfNull: false)
  final String? quietHoursStart;

  @JsonKey(name: r'quietHoursEnd', required: false, includeIfNull: false)
  final String? quietHoursEnd;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateNotificationPreferenceRequest &&
          other.expectedVersion == expectedVersion &&
          other.learningReminders == learningReminders &&
          other.courseUpdates == courseUpdates &&
          other.productAnnouncements == productAnnouncements &&
          other.pushEnabled == pushEnabled &&
          other.emailEnabled == emailEnabled &&
          other.quietHoursStart == quietHoursStart &&
          other.quietHoursEnd == quietHoursEnd;

  @override
  int get hashCode =>
      expectedVersion.hashCode +
      learningReminders.hashCode +
      courseUpdates.hashCode +
      productAnnouncements.hashCode +
      pushEnabled.hashCode +
      emailEnabled.hashCode +
      (quietHoursStart == null ? 0 : quietHoursStart.hashCode) +
      (quietHoursEnd == null ? 0 : quietHoursEnd.hashCode);

  factory UpdateNotificationPreferenceRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$UpdateNotificationPreferenceRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$UpdateNotificationPreferenceRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
