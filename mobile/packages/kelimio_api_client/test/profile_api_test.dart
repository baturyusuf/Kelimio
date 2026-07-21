import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

/// tests for ProfileApi
void main() {
  final instance = KelimioApiClient().getProfileApi();

  group(ProfileApi, () {
    // Return the authenticated user's profile and language preferences
    //
    //Future<MeResponse> getMe() async
    test('test getMe', () async {
      // TODO
    });
  });
}
