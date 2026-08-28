enum TeacherCourseVisibility { public, private }

final class TeacherCourseSummary {
  const TeacherCourseSummary({
    required this.id,
    required this.name,
    required this.targetLanguage,
    required this.defaultSupportLanguage,
    required this.visibility,
    required this.publicationStatus,
    required this.activeReleaseId,
    required this.activeReleaseRevision,
    required this.hasOpenDraft,
    required this.createdAt,
    this.description,
    this.openDraftReleaseId,
  });

  final String id;
  final String name;
  final String? description;
  final String targetLanguage;
  final String defaultSupportLanguage;
  final TeacherCourseVisibility visibility;
  final String publicationStatus;
  final String activeReleaseId;
  final int activeReleaseRevision;
  final bool hasOpenDraft;
  final String? openDraftReleaseId;
  final DateTime createdAt;
}

final class TeacherCoursePage {
  TeacherCoursePage({
    required List<TeacherCourseSummary> items,
    this.nextCursor,
  }) : items = List.unmodifiable(items);

  final List<TeacherCourseSummary> items;
  final String? nextCursor;
}

final class FullCourseEditorDocument {
  FullCourseEditorDocument({
    required this.courseId,
    required this.activeReleaseId,
    required this.releaseRevision,
    required this.name,
    required this.visibility,
    required this.targetLanguage,
    required this.defaultSupportLanguage,
    required List<String> supportLanguages,
    required List<EditorLevel> levels,
    required this.entityTag,
    this.description,
  }) : supportLanguages = List.unmodifiable(supportLanguages),
       levels = List.unmodifiable(levels);

  final String courseId;
  final String activeReleaseId;
  final int releaseRevision;
  final String name;
  final String? description;
  final TeacherCourseVisibility visibility;
  final String targetLanguage;
  final String defaultSupportLanguage;
  final List<String> supportLanguages;
  final List<EditorLevel> levels;
  final String entityTag;
}

final class EditorLevel {
  EditorLevel({required this.title, required List<EditorUnit> units, this.id})
    : units = List.unmodifiable(units);
  final String? id;
  final String title;
  final List<EditorUnit> units;
}

final class EditorUnit {
  EditorUnit({required this.title, required List<EditorTopic> topics, this.id})
    : topics = List.unmodifiable(topics);
  final String? id;
  final String title;
  final List<EditorTopic> topics;
}

final class EditorTopic {
  EditorTopic({required this.title, required List<EditorTest> tests, this.id})
    : tests = List.unmodifiable(tests);
  final String? id;
  final String title;
  final List<EditorTest> tests;
}

final class EditorTest {
  EditorTest({
    required this.title,
    required this.passThreshold,
    required List<EditorQuestion> questions,
    this.id,
  }) : questions = List.unmodifiable(questions);
  final String? id;
  final String title;
  final double passThreshold;
  final List<EditorQuestion> questions;
}

enum EditorQuestionType {
  wordMultipleChoice,
  multipleChoiceCloze,
  typedCloze,
  matching,
}

final class EditorQuestion {
  EditorQuestion({
    required this.type,
    required Map<String, String> translations,
    required List<EditorOption> options,
    required List<EditorMatchingPair> matchingPairs,
    this.id,
    this.prompt,
    this.correctAnswer,
    this.alternativeCorrectAnswer,
  }) : translations = Map.unmodifiable(translations),
       options = List.unmodifiable(options),
       matchingPairs = List.unmodifiable(matchingPairs);
  final String? id;
  final EditorQuestionType type;
  final String? prompt;
  final String? correctAnswer;
  final String? alternativeCorrectAnswer;
  final Map<String, String> translations;
  final List<EditorOption> options;
  final List<EditorMatchingPair> matchingPairs;
}

final class EditorOption {
  EditorOption({
    required this.text,
    required this.correct,
    required Map<String, String> translations,
  }) : translations = Map.unmodifiable(translations);
  final String text;
  final bool correct;
  final Map<String, String> translations;
}

final class EditorMatchingPair {
  EditorMatchingPair({
    required this.targetText,
    required Map<String, String> translations,
  }) : translations = Map.unmodifiable(translations);
  final String targetText;
  final Map<String, String> translations;
}

final class FullCourseDraft {
  const FullCourseDraft({
    required this.courseId,
    required this.baseReleaseId,
    required this.draftReleaseId,
    required this.releaseRevision,
    required this.questionCount,
  });
  final String courseId;
  final String baseReleaseId;
  final String draftReleaseId;
  final int releaseRevision;
  final int questionCount;
}

abstract interface class TeacherCourseRepository {
  Future<TeacherCoursePage> listCourses({String? cursor, int limit = 20});
  Future<FullCourseEditorDocument> getEditor(String courseId);
  Future<FullCourseDraft> saveDraft({
    required FullCourseEditorDocument document,
    required String commandId,
  });
  Future<String> createInvitation(String courseId);
}
