import 'package:dio/dio.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart' as api;

import '../../domain/failures.dart';
import '../../domain/social/social.dart';
import '../network/failure_mapper.dart';

final class GeneratedSocialRepository implements SocialRepository {
  const GeneratedSocialRepository(this._api, this._failures);
  final api.SocialApi _api;
  final DioFailureMapper _failures;

  @override
  Future<OwnPublicProfile> own() => _guard(() async {
    final value = (await _api.getOwnPublicProfile()).data;
    if (value == null) throw const ProtocolFailure('Profile body was empty');
    return _mapOwn(value);
  });

  @override
  Future<OwnPublicProfile> update({
    required String? username,
    required String displayName,
    required String? bio,
    required String? avatarSeed,
    required bool publicProfileEnabled,
    required bool leaderboardOptIn,
  }) => _guard(() async {
    final value = (await _api.updateOwnPublicProfile(
      updatePublicProfileRequest: api.UpdatePublicProfileRequest(
        username: username,
        displayName: displayName,
        bio: bio,
        avatarSeed: avatarSeed,
        publicProfileEnabled: publicProfileEnabled,
        leaderboardOptIn: leaderboardOptIn,
      ),
    )).data;
    if (value == null) throw const ProtocolFailure('Profile body was empty');
    return _mapOwn(value);
  });

  @override
  Future<List<LeaderboardEntry>> leaderboard({int limit = 50}) =>
      _guard(() async {
        final value = (await _api.getGlobalLeaderboard(limit: limit)).data;
        if (value == null) {
          throw const ProtocolFailure('Leaderboard body was empty');
        }
        return value.entries
            .map(
              (entry) => LeaderboardEntry(
                rank: entry.rank,
                username: entry.username,
                displayName: entry.displayName,
                avatarSeed: entry.avatarSeed,
                targetLanguage: entry.targetLanguage,
                lifetimeScore: entry.lifetimeScore,
                completedAttempts: entry.completedAttempts,
              ),
            )
            .toList(growable: false);
      });

  OwnPublicProfile _mapOwn(api.OwnPublicProfile value) => OwnPublicProfile(
    username: value.username,
    displayName: value.displayName,
    bio: value.bio,
    avatarSeed: value.avatarSeed,
    targetLanguage: value.targetLanguage,
    publicProfileEnabled: value.publicProfileEnabled,
    leaderboardOptIn: value.leaderboardOptIn,
    lifetimeScore: value.lifetimeScore,
    completedAttempts: value.completedAttempts,
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
