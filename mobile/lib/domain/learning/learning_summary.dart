final class LearningHistoryItem {
  const LearningHistoryItem({
    required this.courseName,
    required this.testTitle,
    required this.passed,
    required this.correctCount,
    required this.totalQuestions,
    required this.finishedAt,
  });
  final String courseName;
  final String testTitle;
  final bool passed;
  final int correctCount;
  final int totalQuestions;
  final DateTime finishedAt;
}

final class LearningSummary {
  LearningSummary({
    required this.lifetimeScore,
    required this.completedAttempts,
    required this.passedAttempts,
    required this.enrolledCourses,
    required this.completedCourses,
    required this.currentStreakDays,
    required List<LearningHistoryItem> history,
  }) : history = List.unmodifiable(history);
  final int lifetimeScore;
  final int completedAttempts;
  final int passedAttempts;
  final int enrolledCourses;
  final int completedCourses;
  final int currentStreakDays;
  final List<LearningHistoryItem> history;
}

abstract interface class LearningSummaryRepository {
  Future<LearningSummary> get();
}
