import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/application/providers.dart';
import 'package:kelimio_mobile/application/teacher_course_controller.dart';
import 'package:kelimio_mobile/domain/failures.dart';
import 'package:kelimio_mobile/domain/teacher/teacher_course.dart';
import 'package:kelimio_mobile/presentation/screens/full_course_editor_screen.dart';

import '../support/test_doubles.dart';

void main() {
  test(
    'stale full editor exposes base, mine, latest, and explicit reapply',
    () async {
      final base = _document(
        name: 'Temel kurs',
        prompt: 'Ben her gün ---.',
        entityTag: '"base"',
        revision: 1,
      );
      final latest = _document(
        name: 'Sunucudaki kurs',
        prompt: 'Ben her akşam ---.',
        entityTag: '"latest"',
        revision: 2,
      );
      final repository = _ConflictingTeacherCourseRepository(base, latest);
      final container = ProviderContainer(
        overrides: [
          teacherCourseRepositoryProvider.overrideWithValue(repository),
          identifierFactoryProvider.overrideWithValue(
            SequenceIdentifierFactory(['command-1', 'command-2']),
          ),
        ],
      );
      addTearDown(container.dispose);
      final provider = teacherCourseEditorProvider(base.courseId);
      final loaded = await container.read(provider.future);
      final controller = container.read(provider.notifier);
      final mine = _copy(
        loaded,
        name: 'Benim kursum',
        prompt: 'Ben her sabah ---.',
      );

      controller.replace(mine);
      expect(await controller.save(), isNull);

      final conflict = controller.conflict;
      expect(conflict, isNotNull);
      expect(conflict!.base.name, 'Temel kurs');
      expect(conflict.mine.name, 'Benim kursum');
      expect(conflict.latest.name, 'Sunucudaki kurs');
      expect(conflict.mineChanges, contains('Kurs / ad'));
      expect(
        conflict.mineChanges,
        contains('Seviye 1 / Ünite 1 / Konu 1 / Test 1 / Soru 1 / istem'),
      );
      expect(conflict.latestChanges, contains('Kurs / ad'));

      final reapplied = controller.reapplyMine();
      expect(reapplied?.entityTag, '"latest"');
      expect(reapplied?.releaseRevision, 2);
      expect(reapplied?.name, 'Benim kursum');
      expect(
        reapplied
            ?.levels
            .single
            .units
            .single
            .topics
            .single
            .tests
            .single
            .questions
            .single
            .prompt,
        'Ben her sabah ---.',
      );
      expect(controller.conflict, isNull);

      expect(await controller.save(), isNotNull);
      expect(repository.savedEntityTags, ['"base"', '"latest"']);
    },
  );

  test('using latest discards mine only after the explicit choice', () async {
    final base = _document(
      name: 'Temel kurs',
      prompt: 'Ben her gün ---.',
      entityTag: '"base"',
      revision: 1,
    );
    final latest = _document(
      name: 'Son kurs',
      prompt: 'Ben her gece ---.',
      entityTag: '"latest"',
      revision: 2,
    );
    final repository = _ConflictingTeacherCourseRepository(base, latest);
    final container = ProviderContainer(
      overrides: [
        teacherCourseRepositoryProvider.overrideWithValue(repository),
        identifierFactoryProvider.overrideWithValue(
          SequenceIdentifierFactory(['command-1']),
        ),
      ],
    );
    addTearDown(container.dispose);
    final provider = teacherCourseEditorProvider(base.courseId);
    final loaded = await container.read(provider.future);
    final controller = container.read(provider.notifier);

    controller.replace(_copy(loaded, name: 'Benim kursum'));
    await controller.save();
    final selected = controller.useLatest();

    expect(selected?.name, 'Son kurs');
    expect(selected?.entityTag, '"latest"');
    expect(container.read(provider).value?.name, 'Son kurs');
    expect(controller.conflict, isNull);
  });

  testWidgets('full editor blocks saving until a visible conflict choice', (
    tester,
  ) async {
    final base = _document(
      name: 'Temel kurs',
      prompt: 'Ben her gün ---.',
      entityTag: '"base"',
      revision: 1,
    );
    final latest = _document(
      name: 'Sunucudaki kurs',
      prompt: 'Ben her akşam ---.',
      entityTag: '"latest"',
      revision: 2,
    );
    final repository = _ConflictingTeacherCourseRepository(base, latest);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teacherCourseRepositoryProvider.overrideWithValue(repository),
          identifierFactoryProvider.overrideWithValue(
            SequenceIdentifierFactory(['command-1']),
          ),
        ],
        child: MaterialApp(
          home: FullCourseEditorScreen(courseId: base.courseId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('full-editor-name')),
      'Benim kursum',
    );
    await tester.tap(find.byKey(const Key('full-editor-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('full-editor-conflict')), findsOneWidget);
    expect(find.text('Düzenlemeye başladığın sürüm'), findsOneWidget);
    expect(find.text('Senin düzenlemelerin'), findsOneWidget);
    expect(find.text('Sunucudaki son sürüm'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('full-editor-save')))
          .onPressed,
      isNull,
    );

    final reapply = find.byKey(const Key('full-editor-reapply-mine'));
    await tester.scrollUntilVisible(reapply, 300);
    await tester.tap(reapply);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('full-editor-conflict')), findsNothing);
    expect(find.byKey(const Key('full-editor-name')), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('full-editor-save')))
          .onPressed,
      isNotNull,
    );
  });
}

final class _ConflictingTeacherCourseRepository
    implements TeacherCourseRepository {
  _ConflictingTeacherCourseRepository(this.base, this.latest);

  final FullCourseEditorDocument base;
  final FullCourseEditorDocument latest;
  var getCalls = 0;
  var saveCalls = 0;
  final savedEntityTags = <String>[];

  @override
  Future<FullCourseEditorDocument> getEditor(String courseId) async =>
      getCalls++ == 0 ? base : latest;

  @override
  Future<FullCourseDraft> saveDraft({
    required FullCourseEditorDocument document,
    required String commandId,
  }) async {
    savedEntityTags.add(document.entityTag);
    if (saveCalls++ == 0) {
      throw const ConflictFailure(code: 'course-editor-stale');
    }
    return FullCourseDraft(
      courseId: document.courseId,
      baseReleaseId: document.activeReleaseId,
      draftReleaseId: '00000000-0000-4000-8000-000000000099',
      releaseRevision: document.releaseRevision + 1,
      questionCount: 1,
    );
  }

  @override
  Future<TeacherCoursePage> listCourses({
    String? cursor,
    int limit = 20,
  }) async => TeacherCoursePage(items: const []);

  @override
  Future<String> createInvitation(String courseId) =>
      throw UnimplementedError();
}

FullCourseEditorDocument _document({
  required String name,
  required String prompt,
  required String entityTag,
  required int revision,
}) => FullCourseEditorDocument(
  courseId: '00000000-0000-4000-8000-000000000001',
  activeReleaseId: '00000000-0000-4000-8000-000000000002',
  releaseRevision: revision,
  name: name,
  description: 'Açıklama',
  visibility: TeacherCourseVisibility.private,
  targetLanguage: 'tr',
  defaultSupportLanguage: 'en',
  supportLanguages: const ['en'],
  entityTag: entityTag,
  levels: [
    EditorLevel(
      id: 'level-1',
      title: 'Seviye 1',
      units: [
        EditorUnit(
          id: 'unit-1',
          title: 'Ünite 1',
          topics: [
            EditorTopic(
              id: 'topic-1',
              title: 'Konu 1',
              tests: [
                EditorTest(
                  id: 'test-1',
                  title: 'Test 1',
                  passThreshold: .8,
                  questions: [
                    EditorQuestion(
                      id: 'question-1',
                      type: EditorQuestionType.multipleChoiceCloze,
                      prompt: prompt,
                      translations: const {'en': 'I go every day.'},
                      options: [
                        EditorOption(
                          text: 'giderim',
                          correct: true,
                          translations: const {'en': 'go'},
                        ),
                        EditorOption(
                          text: 'gelirim',
                          correct: false,
                          translations: const {'en': 'come'},
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

FullCourseEditorDocument _copy(
  FullCourseEditorDocument source, {
  String? name,
  String? prompt,
}) {
  final level = source.levels.single;
  final unit = level.units.single;
  final topic = unit.topics.single;
  final test = topic.tests.single;
  final question = test.questions.single;
  return FullCourseEditorDocument(
    courseId: source.courseId,
    activeReleaseId: source.activeReleaseId,
    releaseRevision: source.releaseRevision,
    name: name ?? source.name,
    description: source.description,
    visibility: source.visibility,
    targetLanguage: source.targetLanguage,
    defaultSupportLanguage: source.defaultSupportLanguage,
    supportLanguages: source.supportLanguages,
    entityTag: source.entityTag,
    levels: [
      EditorLevel(
        id: level.id,
        title: level.title,
        units: [
          EditorUnit(
            id: unit.id,
            title: unit.title,
            topics: [
              EditorTopic(
                id: topic.id,
                title: topic.title,
                tests: [
                  EditorTest(
                    id: test.id,
                    title: test.title,
                    passThreshold: test.passThreshold,
                    questions: [
                      EditorQuestion(
                        id: question.id,
                        type: question.type,
                        prompt: prompt ?? question.prompt,
                        correctAnswer: question.correctAnswer,
                        alternativeCorrectAnswer:
                            question.alternativeCorrectAnswer,
                        translations: question.translations,
                        options: question.options,
                        matchingPairs: question.matchingPairs,
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
}
