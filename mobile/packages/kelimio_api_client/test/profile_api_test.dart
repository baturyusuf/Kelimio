import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

/// tests for ProfileApi
void main() {
  final instance = KelimioApiClient().getProfileApi();

  group(ProfileApi, () {
    // Complete the authenticated user's first-login profile setup
    //
    // Completes the provisional subject-bound profile exactly once. Repeating the same Idempotency-Key and canonical request returns the original result without duplicate facts. This is not legal-terms acceptance, and identity-provider subject, email, and username are neither accepted by this command nor exposed by the profile response.
    //
    //Future<MeResponse> completeProfileSetup(String idempotencyKey, ProfileSetupRequest profileSetupRequest) async
    test('test completeProfileSetup', () async {
      // TODO
    });

    // Return the authenticated user's profile and language preferences
    //
    //Future<MeResponse> getMe() async
    test('test getMe', () async {
      // TODO
    });
  });
}
