import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/application/providers.dart';
import 'package:kelimio_mobile/domain/teacher/teacher_course.dart';
import 'package:kelimio_mobile/l10n/generated/app_localizations.dart';
import 'package:kelimio_mobile/presentation/screens/teacher_course_preview_screen.dart';

void main() {
  testWidgets(
    'Arabic learner preview is RTL, non-interactive, and hides answers',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final document = _document();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teacherCourseRepositoryProvider.overrideWithValue(
              _TeacherRepository(document),
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: MaterialApp(
              locale: const Locale('ar'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: TeacherCoursePreviewScreen(courseId: document.courseId),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final directionality = tester.widget<Directionality>(
        find.byType(Directionality).first,
      );
      expect(directionality.textDirection, TextDirection.rtl);
      expect(find.text('معاينة المتعلم'), findsOneWidget);
      expect(find.byKey(const Key('teacher-preview-question-1')), findsOne);
      expect(find.text('الإجابة السرية'), findsNothing);
      expect(find.text('الخيار الصحيح السري'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_checked), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

FullCourseEditorDocument _document() => FullCourseEditorDocument(
  courseId: '00000000-0000-4000-8000-000000000001',
  activeReleaseId: '00000000-0000-4000-8000-000000000002',
  releaseRevision: 3,
  name: 'دورة تجريبية',
  description: 'وصف الدورة',
  visibility: TeacherCourseVisibility.private,
  targetLanguage: 'ar',
  defaultSupportLanguage: 'tr',
  supportLanguages: const ['tr'],
  entityTag: '"base"',
  levels: [
    EditorLevel(
      id: 'level-1',
      title: 'المستوى الأول',
      units: [
        EditorUnit(
          id: 'unit-1',
          title: 'الوحدة الأولى',
          topics: [
            EditorTopic(
              id: 'topic-1',
              title: 'الموضوع الأول',
              tests: [
                EditorTest(
                  id: 'test-1',
                  title: 'الاختبار الأول',
                  passThreshold: .8,
                  questions: [
                    EditorQuestion(
                      id: 'question-1',
                      type: EditorQuestionType.typedCloze,
                      prompt: 'أنا أذهب كل يوم ---.',
                      correctAnswer: 'الإجابة السرية',
                      translations: const {},
                      options: const [],
                      matchingPairs: const [],
                    ),
                    EditorQuestion(
                      id: 'question-2',
                      type: EditorQuestionType.multipleChoiceCloze,
                      prompt: 'أنا --- إلى المدرسة.',
                      correctAnswer: 'الخيار الصحيح السري',
                      translations: const {},
                      options: [
                        EditorOption(
                          text: 'الخيار الصحيح السري',
                          correct: true,
                          translations: const {},
                        ),
                        EditorOption(
                          text: 'خيار ظاهر',
                          correct: false,
                          translations: const {},
                        ),
                      ],
                      matchingPairs: const [],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

final class _TeacherRepository implements TeacherCourseRepository {
  const _TeacherRepository(this.document);

  final FullCourseEditorDocument document;

  @override
  Future<String> createInvitation(String courseId) =>
      throw UnimplementedError();

  @override
  Future<FullCourseEditorDocument> getEditor(String courseId) async => document;

  @override
  Future<TeacherCoursePage> listCourses({String? cursor, int limit = 20}) =>
      throw UnimplementedError();

  @override
  Future<FullCourseDraft> saveDraft({
    required FullCourseEditorDocument document,
    required String commandId,
  }) => throw UnimplementedError();
}
