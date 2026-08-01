enum ProfileSetupStatus { required, complete }

final class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.appLocale,
    required this.activeTargetLanguage,
    required this.preferredSupportLanguage,
    required this.timeZone,
    required this.profileVersion,
    required this.setupStatus,
  });

  final String id;
  final String displayName;
  final String appLocale;
  final String activeTargetLanguage;
  final String? preferredSupportLanguage;
  final String timeZone;
  final int profileVersion;
  final ProfileSetupStatus setupStatus;

  bool get setupComplete => setupStatus == ProfileSetupStatus.complete;
}

final class ProfileSetupInput {
  const ProfileSetupInput({
    required this.displayName,
    required this.appLocale,
    required this.activeTargetLanguage,
    required this.preferredSupportLanguage,
    required this.timeZone,
  });

  final String displayName;
  final String appLocale;
  final String activeTargetLanguage;
  final String preferredSupportLanguage;
  final String timeZone;

  @override
  bool operator ==(Object other) =>
      other is ProfileSetupInput &&
      other.displayName == displayName &&
      other.appLocale == appLocale &&
      other.activeTargetLanguage == activeTargetLanguage &&
      other.preferredSupportLanguage == preferredSupportLanguage &&
      other.timeZone == timeZone;

  @override
  int get hashCode => Object.hash(
    displayName,
    appLocale,
    activeTargetLanguage,
    preferredSupportLanguage,
    timeZone,
  );
}

abstract interface class ProfileRepository {
  Future<UserProfile> getMe();

  Future<UserProfile> completeSetup({
    required ProfileSetupInput input,
    required String commandId,
  });
}
