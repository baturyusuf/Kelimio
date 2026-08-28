final class NotificationPreferences {
  const NotificationPreferences({
    required this.learningReminders,
    required this.courseUpdates,
    required this.productAnnouncements,
    required this.pushEnabled,
    required this.emailEnabled,
    required this.pushAvailable,
    required this.emailAvailable,
    required this.version,
    this.quietHoursStart,
    this.quietHoursEnd,
  });
  final bool learningReminders;
  final bool courseUpdates;
  final bool productAnnouncements;
  final bool pushEnabled;
  final bool emailEnabled;
  final bool pushAvailable;
  final bool emailAvailable;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final int version;
}

final class AccountDeletion {
  const AccountDeletion({
    required this.id,
    required this.status,
    required this.requestedAt,
    required this.scheduledFor,
  });
  final String id;
  final String status;
  final DateTime requestedAt;
  final DateTime scheduledFor;
}

abstract interface class AccountRepository {
  Future<NotificationPreferences> notificationPreferences();
  Future<NotificationPreferences> updateNotifications(
    NotificationPreferences value,
  );
  Future<Map<String, Object?>> export();
  Future<AccountDeletion> requestDeletion(String commandId);
  Future<List<AccountDeletion>> deletionRequests();
  Future<AccountDeletion> cancelDeletion({
    required String requestId,
    required String commandId,
  });
  Future<void> revokeAllSessions();
}
