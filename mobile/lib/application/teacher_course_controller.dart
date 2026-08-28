import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final class TeacherCourseEditorController
    extends AsyncNotifier<FullCourseEditorDocument> {
  TeacherCourseEditorController(this.courseId);

  final String courseId;

  @override
  Future<FullCourseEditorDocument> build() =>
      ref.watch(teacherCourseRepositoryProvider).getEditor(courseId);

  void replace(FullCourseEditorDocument document) {
    state = AsyncData(document);
  }

  Future<FullCourseDraft?> save() async {
    final current = state.value;
    if (current == null || state.isLoading) return null;
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
    } on Object catch (error, stackTrace) {
      state = AsyncError<FullCourseEditorDocument>(error, stackTrace);
      return null;
    }
  }
}
