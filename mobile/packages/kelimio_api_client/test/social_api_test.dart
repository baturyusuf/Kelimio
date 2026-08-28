import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

/// tests for SocialApi
void main() {
  final instance = KelimioApiClient().getSocialApi();

  group(SocialApi, () {
    // List only users who explicitly opted in to public ranking
    //
    //Future<Leaderboard> getGlobalLeaderboard({ int limit }) async
    test('test getGlobalLeaderboard', () async {
      // TODO
    });

    // Read private settings and public-profile projection for the current user
    //
    //Future<OwnPublicProfile> getOwnPublicProfile() async
    test('test getOwnPublicProfile', () async {
      // TODO
    });

    // Read an explicitly enabled public profile
    //
    //Future<PublicProfile> getPublicProfile(String username) async
    test('test getPublicProfile', () async {
      // TODO
    });

    // Update public-profile fields and explicit visibility choices
    //
    //Future<OwnPublicProfile> updateOwnPublicProfile(UpdatePublicProfileRequest updatePublicProfileRequest) async
    test('test updateOwnPublicProfile', () async {
      // TODO
    });
  });
}
