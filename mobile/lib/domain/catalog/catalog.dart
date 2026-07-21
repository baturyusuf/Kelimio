enum CourseAccessType { free, paid }

enum CourseVisibility { public, private }

final class CourseSummary {
  CourseSummary({
    required this.id,
    required this.name,
    required this.targetLanguage,
    required List<String> supportLanguages,
    required this.accessType,
    required this.visibility,
    required this.enrolled,
    this.description,
  }) : supportLanguages = List.unmodifiable(supportLanguages);

  final String id;
  final String name;
  final String? description;
  final String targetLanguage;
  final List<String> supportLanguages;
  final CourseAccessType accessType;
  final CourseVisibility visibility;
  final bool enrolled;
}

final class TestSummary {
  const TestSummary({
    required this.id,
    required this.revisionId,
    required this.name,
    required this.position,
    required this.questionCount,
  });

  final String id;
  final String revisionId;
  final String name;
  final int position;
  final int questionCount;
}

final class CourseDetail {
  CourseDetail({
    required this.summary,
    required this.ownerDisplayName,
    required this.releaseId,
    required List<TestSummary> tests,
  }) : tests = List.unmodifiable(tests);

  final CourseSummary summary;
  final String ownerDisplayName;
  final String releaseId;
  final List<TestSummary> tests;
}

final class CatalogPage {
  CatalogPage({required List<CourseSummary> items, this.nextCursor})
    : items = List.unmodifiable(items);

  final List<CourseSummary> items;
  final String? nextCursor;
}

final class Enrollment {
  const Enrollment({
    required this.id,
    required this.courseId,
    required this.supportLanguage,
    required this.status,
    required this.enrolledAt,
  });

  final String id;
  final String courseId;
  final String supportLanguage;
  final EnrollmentStatus status;
  final DateTime enrolledAt;
}

enum EnrollmentStatus { active, archived }

abstract interface class CatalogRepository {
  Future<CatalogPage> listCourses({String? cursor, int limit = 20});

  Future<CourseDetail> getCourse(String courseId);

  Future<Enrollment> enroll({
    required String courseId,
    required String supportLanguage,
    required String commandId,
  });
}
