final class OfflineCoursePackage {
  const OfflineCoursePackage({
    required this.courseId,
    required this.courseReleaseId,
    required this.supportLanguage,
    required this.sha256,
    required this.localPath,
  });
  final String courseId;
  final String courseReleaseId;
  final String supportLanguage;
  final String sha256;
  final String localPath;
}

final class OfflinePracticeQuestion {
  OfflinePracticeQuestion({
    required this.type,
    required this.prompt,
    required this.correctAnswer,
    required List<String> options,
    required Map<String, String> matchingPairs,
  }) : options = List.unmodifiable(options),
       matchingPairs = Map.unmodifiable(matchingPairs);
  final String type;
  final String prompt;
  final String correctAnswer;
  final List<String> options;
  final Map<String, String> matchingPairs;
}

abstract interface class OfflinePackageRepository {
  Future<void> clearPrivateData();
  Future<OfflineCoursePackage> download({
    required String courseId,
    required String supportLanguage,
  });
  Future<void> recordPractice({
    required OfflineCoursePackage package,
    required int answered,
    required int correct,
  });
  Future<List<OfflinePracticeQuestion>> loadQuestions(
    OfflineCoursePackage package,
  );
}
