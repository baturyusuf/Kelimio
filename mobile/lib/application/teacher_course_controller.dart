import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/failures.dart';
import '../domain/teacher/teacher_course.dart';
import 'providers.dart';

final teacherCoursesProvider =
    AsyncNotifierProvider.autoDispose<
      TeacherCoursesController,
      TeacherCoursePage
    >(TeacherCoursesController.new);

final class TeacherCoursesController extends AsyncNotifier<TeacherCoursePage> {
  @override
  Future<TeacherCoursePage> build() =>
      ref.watch(teacherCourseRepositoryProvider).listCourses();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      ref.read(teacherCourseRepositoryProvider).listCourses,
    );
  }
}

final teacherCourseEditorProvider = AsyncNotifierProvider.autoDispose
    .family<TeacherCourseEditorController, FullCourseEditorDocument, String>(
      (courseId) => TeacherCourseEditorController(courseId),
    );

final class TeacherCourseEditorConflict {
  TeacherCourseEditorConflict({
    required this.base,
    required this.mine,
    required this.latest,
  }) : mineChanges = _changedFields(base, mine),
       latestChanges = _changedFields(base, latest);

  final FullCourseEditorDocument base;
  final FullCourseEditorDocument mine;
  final FullCourseEditorDocument latest;
  final List<String> mineChanges;
  final List<String> latestChanges;

  FullCourseEditorDocument reapplyMine() => FullCourseEditorDocument(
    courseId: latest.courseId,
    activeReleaseId: latest.activeReleaseId,
    releaseRevision: latest.releaseRevision,
    name: mine.name,
    description: mine.description,
    visibility: mine.visibility,
    targetLanguage: latest.targetLanguage,
    defaultSupportLanguage: latest.defaultSupportLanguage,
    supportLanguages: latest.supportLanguages,
    levels: mine.levels,
    entityTag: latest.entityTag,
  );
}

final class TeacherCourseEditorController
    extends AsyncNotifier<FullCourseEditorDocument> {
  TeacherCourseEditorController(this.courseId);

  final String courseId;
  FullCourseEditorDocument? _baseDocument;
  TeacherCourseEditorConflict? _conflict;

  TeacherCourseEditorConflict? get conflict => _conflict;

  @override
  Future<FullCourseEditorDocument> build() async {
    final document = await ref
        .watch(teacherCourseRepositoryProvider)
        .getEditor(courseId);
    _baseDocument = document;
    _conflict = null;
    return document;
  }

  void replace(FullCourseEditorDocument document) {
    if (_conflict != null) return;
    state = AsyncData(document);
  }

  Future<FullCourseDraft?> save() async {
    final current = state.value;
    if (current == null || state.isLoading || _conflict != null) return null;
    state = const AsyncLoading<FullCourseEditorDocument>();
    try {
      final result = await ref
          .read(teacherCourseRepositoryProvider)
          .saveDraft(
            document: current,
            commandId: ref.read(identifierFactoryProvider).create(),
          );
      state = AsyncData(current);
      ref.invalidate(teacherCoursesProvider);
      return result;
    } on ConflictFailure {
      try {
        final latest = await ref
            .read(teacherCourseRepositoryProvider)
            .getEditor(courseId);
        _conflict = TeacherCourseEditorConflict(
          base: _baseDocument ?? current,
          mine: current,
          latest: latest,
        );
        state = AsyncData(current);
      } on Object catch (reloadError, reloadStackTrace) {
        state = AsyncError<FullCourseEditorDocument>(
          reloadError,
          reloadStackTrace,
        );
      }
      return null;
    } on Object catch (error, stackTrace) {
      state = AsyncError<FullCourseEditorDocument>(error, stackTrace);
      return null;
    }
  }

  FullCourseEditorDocument? useLatest() {
    final conflict = _conflict;
    if (conflict == null || state.isLoading) return null;
    _baseDocument = conflict.latest;
    _conflict = null;
    state = AsyncData(conflict.latest);
    return conflict.latest;
  }

  FullCourseEditorDocument? reapplyMine() {
    final conflict = _conflict;
    if (conflict == null || state.isLoading) return null;
    final reapplied = conflict.reapplyMine();
    _baseDocument = conflict.latest;
    _conflict = null;
    state = AsyncData(reapplied);
    return reapplied;
  }
}

List<String> _changedFields(
  FullCourseEditorDocument base,
  FullCourseEditorDocument changed,
) {
  final baseFields = _flattenDocument(base);
  final changedFields = _flattenDocument(changed);
  final paths = {...baseFields.keys, ...changedFields.keys}.toList()..sort();
  return List.unmodifiable(
    paths.where((path) => baseFields[path] != changedFields[path]),
  );
}

Map<String, Object?> _flattenDocument(FullCourseEditorDocument document) {
  final fields = <String, Object?>{
    'Kurs / ad': document.name,
    'Kurs / açıklama': document.description,
    'Kurs / görünürlük': document.visibility.name,
    'Kurs / seviye sırası': document.levels
        .map((level) => level.id ?? level.title)
        .join('|'),
  };
  for (var levelIndex = 0; levelIndex < document.levels.length; levelIndex++) {
    final level = document.levels[levelIndex];
    final levelPath = 'Seviye ${levelIndex + 1}';
    fields['$levelPath / kimlik'] = level.id;
    fields['$levelPath / başlık'] = level.title;
    fields['$levelPath / ünite sırası'] = level.units
        .map((unit) => unit.id ?? unit.title)
        .join('|');
    for (var unitIndex = 0; unitIndex < level.units.length; unitIndex++) {
      final unit = level.units[unitIndex];
      final unitPath = '$levelPath / Ünite ${unitIndex + 1}';
      fields['$unitPath / kimlik'] = unit.id;
      fields['$unitPath / başlık'] = unit.title;
      fields['$unitPath / konu sırası'] = unit.topics
          .map((topic) => topic.id ?? topic.title)
          .join('|');
      for (var topicIndex = 0; topicIndex < unit.topics.length; topicIndex++) {
        final topic = unit.topics[topicIndex];
        final topicPath = '$unitPath / Konu ${topicIndex + 1}';
        fields['$topicPath / kimlik'] = topic.id;
        fields['$topicPath / başlık'] = topic.title;
        fields['$topicPath / test sırası'] = topic.tests
            .map((test) => test.id ?? test.title)
            .join('|');
        for (var testIndex = 0; testIndex < topic.tests.length; testIndex++) {
          final test = topic.tests[testIndex];
          final testPath = '$topicPath / Test ${testIndex + 1}';
          fields['$testPath / kimlik'] = test.id;
          fields['$testPath / başlık'] = test.title;
          fields['$testPath / geçme eşiği'] = test.passThreshold;
          fields['$testPath / soru sırası'] = test.questions
              .map(
                (question) =>
                    question.id ?? question.prompt ?? question.type.name,
              )
              .join('|');
          for (
            var questionIndex = 0;
            questionIndex < test.questions.length;
            questionIndex++
          ) {
            final question = test.questions[questionIndex];
            final questionPath = '$testPath / Soru ${questionIndex + 1}';
            fields['$questionPath / kimlik'] = question.id;
            fields['$questionPath / tür'] = question.type.name;
            fields['$questionPath / istem'] = question.prompt;
            fields['$questionPath / doğru cevap'] = question.correctAnswer;
            fields['$questionPath / alternatif cevap'] =
                question.alternativeCorrectAnswer;
            for (final translation in question.translations.entries) {
              fields['$questionPath / çeviri ${translation.key}'] =
                  translation.value;
            }
            for (
              var optionIndex = 0;
              optionIndex < question.options.length;
              optionIndex++
            ) {
              final option = question.options[optionIndex];
              final optionPath = '$questionPath / Seçenek ${optionIndex + 1}';
              fields['$optionPath / metin'] = option.text;
              fields['$optionPath / doğru'] = option.correct;
              for (final translation in option.translations.entries) {
                fields['$optionPath / çeviri ${translation.key}'] =
                    translation.value;
              }
            }
            for (
              var pairIndex = 0;
              pairIndex < question.matchingPairs.length;
              pairIndex++
            ) {
              final pair = question.matchingPairs[pairIndex];
              final pairPath = '$questionPath / Eşleşme ${pairIndex + 1}';
              fields['$pairPath / hedef'] = pair.targetText;
              for (final translation in pair.translations.entries) {
                fields['$pairPath / çeviri ${translation.key}'] =
                    translation.value;
              }
            }
          }
        }
      }
    }
  }
  return fields;
}
