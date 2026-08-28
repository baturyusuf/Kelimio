import 'package:dio/dio.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart' as api;

import '../../domain/account/account.dart';
import '../../domain/failures.dart';
import '../network/failure_mapper.dart';
import '../network/request_metadata.dart';

final class GeneratedAccountRepository implements AccountRepository {
  const GeneratedAccountRepository(this._api, this._failures);
  final api.AccountApi _api;
  final DioFailureMapper _failures;

  @override
  Future<NotificationPreferences> notificationPreferences() => _guard(
    () async => _mapPreferences(_body(await _api.getNotificationPreferences())),
  );

  @override
  Future<NotificationPreferences> updateNotifications(
    NotificationPreferences value,
  ) => _guard(
    () async => _mapPreferences(
      _body(
        await _api.updateNotificationPreferences(
          updateNotificationPreferenceRequest:
              api.UpdateNotificationPreferenceRequest(
                expectedVersion: value.version,
                learningReminders: value.learningReminders,
                courseUpdates: value.courseUpdates,
                productAnnouncements: value.productAnnouncements,
                pushEnabled: value.pushEnabled,
                emailEnabled: value.emailEnabled,
                quietHoursStart: value.quietHoursStart,
                quietHoursEnd: value.quietHoursEnd,
              ),
        ),
      ),
    ),
  );

  @override
  Future<Map<String, Object?>> export() =>
      _guard(() async => _body(await _api.exportOwnAccount()).toJson());

  @override
  Future<AccountDeletion> requestDeletion(String commandId) => _guard(() async {
    final value = _body(
      await _api.requestAccountDeletion(
        idempotencyKey: commandId,
        extra: {RequestMetadata.idempotencyKey: commandId},
      ),
    );
    return _mapDeletion(value);
  });

  @override
  Future<List<AccountDeletion>> deletionRequests() => _guard(() async {
    final values = _body(await _api.listAccountDeletionRequests());
    return values.map(_mapDeletion).toList(growable: false);
  });

  @override
  Future<AccountDeletion> cancelDeletion({
    required String requestId,
    required String commandId,
  }) => _guard(() async {
    final value = _body(
      await _api.cancelAccountDeletion(
        requestId: requestId,
        idempotencyKey: commandId,
        extra: {RequestMetadata.idempotencyKey: commandId},
      ),
    );
    return _mapDeletion(value);
  });

  @override
  Future<void> revokeAllSessions() => _guard(() async {
    final response = await _api.revokeAllSessions();
    if (response.data == null) {
      throw const ProtocolFailure('Session revocation response body was empty');
    }
  });

  T _body<T>(Response<T> response) {
    final data = response.data;
    if (data == null) throw const ProtocolFailure('Response body was empty');
    return data;
  }

  NotificationPreferences _mapPreferences(api.NotificationPreference value) =>
      NotificationPreferences(
        learningReminders: value.learningReminders,
        courseUpdates: value.courseUpdates,
        productAnnouncements: value.productAnnouncements,
        pushEnabled: value.pushEnabled,
        emailEnabled: value.emailEnabled,
        pushAvailable: value.pushAvailable,
        emailAvailable: value.emailAvailable,
        quietHoursStart: value.quietHoursStart,
        quietHoursEnd: value.quietHoursEnd,
        version: value.version,
      );

  AccountDeletion _mapDeletion(api.AccountDeletionRequest value) =>
      AccountDeletion(
        id: value.id,
        status: value.status.value,
        requestedAt: value.requestedAt,
        scheduledFor: value.scheduledFor,
      );

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw _failures.map(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw UnknownFailure(cause: error);
    }
  }
}
