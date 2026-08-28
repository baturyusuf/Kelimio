final class OwnPublicProfile {
  const OwnPublicProfile({
    required this.displayName,
    required this.targetLanguage,
    required this.publicProfileEnabled,
    required this.leaderboardOptIn,
    required this.lifetimeScore,
    required this.completedAttempts,
    this.username,
    this.bio,
    this.avatarSeed,
  });
  final String? username;
  final String displayName;
  final String? bio;
  final String? avatarSeed;
  final String targetLanguage;
  final bool publicProfileEnabled;
  final bool leaderboardOptIn;
  final int lifetimeScore;
  final int completedAttempts;
}

final class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.username,
    required this.displayName,
    required this.targetLanguage,
    required this.lifetimeScore,
    required this.completedAttempts,
    this.avatarSeed,
  });
  final int rank;
  final String username;
  final String displayName;
  final String? avatarSeed;
  final String targetLanguage;
  final int lifetimeScore;
  final int completedAttempts;
}

abstract interface class SocialRepository {
  Future<OwnPublicProfile> own();
  Future<OwnPublicProfile> update({
    required String? username,
    required String displayName,
    required String? bio,
    required String? avatarSeed,
    required bool publicProfileEnabled,
    required bool leaderboardOptIn,
  });
  Future<List<LeaderboardEntry>> leaderboard({int limit = 50});
}
