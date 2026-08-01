final class LocalStarterCourseInstall {
  const LocalStarterCourseInstall({
    required this.courseId,
    required this.created,
    required this.sourceWorkbookSha256,
  });

  final String courseId;
  final bool created;
  final String sourceWorkbookSha256;
}

abstract interface class DevelopmentRepository {
  Future<LocalStarterCourseInstall> installStarterCourse({
    required String commandId,
  });
}
