final class TeacherAccess {
  const TeacherAccess({
    required this.eligible,
    required this.termsAccepted,
    required this.productionFeaturesEnabled,
    required this.requiredTermsVersion,
  });

  final bool eligible;
  final bool termsAccepted;
  final bool productionFeaturesEnabled;
  final String requiredTermsVersion;

  bool get authorized => eligible && termsAccepted && productionFeaturesEnabled;
}

abstract interface class TeacherAccessRepository {
  Future<TeacherAccess> getAccess();

  Future<TeacherAccess> acceptTerms(String termsVersion);
}
