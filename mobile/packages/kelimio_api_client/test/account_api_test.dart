import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

/// tests for AccountApi
void main() {
  final instance = KelimioApiClient().getAccountApi();

  group(AccountApi, () {
    // Cancel a pending deletion request during its recovery window
    //
    //Future<AccountDeletionRequest> cancelAccountDeletion(String requestId, String idempotencyKey) async
    test('test cancelAccountDeletion', () async {
      // TODO
    });

    // Export the authenticated user's portable account and learning facts
    //
    //Future<AccountExport> exportOwnAccount() async
    test('test exportOwnAccount', () async {
      // TODO
    });

    // Read notification choices and real provider availability
    //
    //Future<NotificationPreference> getNotificationPreferences() async
    test('test getNotificationPreferences', () async {
      // TODO
    });

    // List the current user's recent deletion requests
    //
    //Future<List<AccountDeletionRequest>> listAccountDeletionRequests() async
    test('test listAccountDeletionRequests', () async {
      // TODO
    });

    // List append-only legal-consent facts recorded for the current user
    //
    //Future<List<LegalConsent>> listLegalConsents() async
    test('test listLegalConsents', () async {
      // TODO
    });

    // Request audited account deletion after a seven-day recovery window
    //
    //Future<AccountDeletionRequest> requestAccountDeletion(String idempotencyKey) async
    test('test requestAccountDeletion', () async {
      // TODO
    });

    // Revoke all Cognito refresh sessions for the authenticated identity
    //
    // Calls Cognito AdminUserGlobalSignOut using the server-authenticated username, then appends an audit/outbox event. The current access token may remain valid until its short expiry and the client must clear its local session.
    //
    //Future<SessionRevocation> revokeAllSessions() async
    test('test revokeAllSessions', () async {
      // TODO
    });

    // Optimistically update notification preferences
    //
    //Future<NotificationPreference> updateNotificationPreferences(UpdateNotificationPreferenceRequest updateNotificationPreferenceRequest) async
    test('test updateNotificationPreferences', () async {
      // TODO
    });
  });
}
