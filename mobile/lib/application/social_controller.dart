import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/social/social.dart';
import 'providers.dart';

final ownPublicProfileProvider =
    AsyncNotifierProvider.autoDispose<
      OwnPublicProfileController,
      OwnPublicProfile
    >(OwnPublicProfileController.new);

final class OwnPublicProfileController extends AsyncNotifier<OwnPublicProfile> {
  @override
  Future<OwnPublicProfile> build() => ref.watch(socialRepositoryProvider).own();

  Future<bool> save({
    required String? username,
    required String displayName,
    required String? bio,
    required bool publicProfileEnabled,
    required bool leaderboardOptIn,
  }) async {
    final previous = state.value;
    state = const AsyncLoading();
    try {
      state = AsyncData(
        await ref
            .read(socialRepositoryProvider)
            .update(
              username: username,
              displayName: displayName,
              bio: bio,
              avatarSeed: previous?.avatarSeed,
              publicProfileEnabled: publicProfileEnabled,
              leaderboardOptIn: leaderboardOptIn,
            ),
      );
      ref.invalidate(leaderboardProvider);
      return true;
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }
}

final leaderboardProvider = FutureProvider.autoDispose<List<LeaderboardEntry>>(
  (ref) => ref.watch(socialRepositoryProvider).leaderboard(),
);
