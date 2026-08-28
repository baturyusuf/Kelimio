import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/teacher_course_controller.dart';
import '../../domain/teacher/teacher_course.dart';
import '../widgets/async_error_view.dart';

final class FullCourseEditorScreen extends ConsumerStatefulWidget {
  const FullCourseEditorScreen({required this.courseId, super.key});
  final String courseId;

  @override
  ConsumerState<FullCourseEditorScreen> createState() =>
      _FullCourseEditorScreenState();
}

final class _FullCourseEditorScreenState
    extends ConsumerState<FullCourseEditorScreen> {
  FullCourseEditorDocument? _draft;
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherCourseEditorProvider(widget.courseId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kurs düzenleyici'),
        actions: [
          IconButton(
            key: const Key('full-editor-save'),
            tooltip: 'Değişmez taslak oluştur',
            onPressed: _saving || (_draft ?? state.value) == null
                ? null
                : () => unawaited(_save()),
            icon: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: state.when(
        loading: () => _draft == null
            ? const Center(child: CircularProgressIndicator())
            : _EditorForm(document: _draft!, onChanged: _replace),
        error: (error, stackTrace) => AsyncErrorView(
          error: error,
          onRetry: () =>
              ref.invalidate(teacherCourseEditorProvider(widget.courseId)),
        ),
        data: (document) {
          _draft ??= document;
          return _EditorForm(document: _draft!, onChanged: _replace);
        },
      ),
    );
  }

  void _replace(FullCourseEditorDocument value) {
    setState(() => _draft = value);
    ref
        .read(teacherCourseEditorProvider(widget.courseId).notifier)
        .replace(value);
  }

  Future<void> _save() async {
    final value = _draft;
    if (value == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    final notifier = ref.read(
      teacherCourseEditorProvider(widget.courseId).notifier,
    );
    notifier.replace(value);
    final result = await notifier.save();
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) {
      final impact = await ref
          .read(courseAuthoringRepositoryProvider)
          .getReleaseImpact(
            courseId: result.courseId,
            releaseId: result.draftReleaseId,
          );
      if (!mounted) return;
      final publish = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Sürüm ${impact.releaseRevision} yayımlansın mı?'),
          content: Text(
            '${impact.changedQuestionCount} değişen, ${impact.addedQuestionCount} eklenen, ${impact.removedQuestionCount} kaldırılan soru; ${impact.affectedEnrollmentCount} öğrenci etkileniyor.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Daha sonra'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yayımla'),
            ),
          ],
        ),
      );
      if (publish == true) {
        final activation = await ref
            .read(courseAuthoringRepositoryProvider)
            .activateRelease(
              impact: impact,
              commandId: ref.read(identifierFactoryProvider).create(),
            );
        ref.invalidate(teacherCoursesProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sürüm ${activation.releaseRevision} yayımlandı.'),
            ),
          );
        }
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

final class _EditorForm extends StatelessWidget {
  const _EditorForm({required this.document, required this.onChanged});
  final FullCourseEditorDocument document;
  final ValueChanged<FullCourseEditorDocument> onChanged;

  FullCourseEditorDocument _copy({
    String? name,
    String? description,
    TeacherCourseVisibility? visibility,
    List<EditorLevel>? levels,
  }) => FullCourseEditorDocument(
    courseId: document.courseId,
    activeReleaseId: document.activeReleaseId,
    releaseRevision: document.releaseRevision,
    name: name ?? document.name,
    description: description ?? document.description,
    visibility: visibility ?? document.visibility,
    targetLanguage: document.targetLanguage,
    defaultSupportLanguage: document.defaultSupportLanguage,
    supportLanguages: document.supportLanguages,
    levels: levels ?? document.levels,
    entityTag: document.entityTag,
  );

  @override
  Widget build(BuildContext context) => Form(
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          key: const Key('full-editor-name'),
          initialValue: document.name,
          maxLength: 160,
          decoration: const InputDecoration(labelText: 'Kurs adı'),
          onChanged: (value) => onChanged(_copy(name: value)),
        ),
        TextFormField(
          key: const Key('full-editor-description'),
          initialValue: document.description,
          maxLength: 2000,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Açıklama'),
          onChanged: (value) => onChanged(_copy(description: value)),
        ),
        DropdownButtonFormField<TeacherCourseVisibility>(
          initialValue: document.visibility,
          decoration: const InputDecoration(labelText: 'Görünürlük'),
          items: const [
            DropdownMenuItem(
              value: TeacherCourseVisibility.public,
              child: Text('Herkese açık'),
            ),
            DropdownMenuItem(
              value: TeacherCourseVisibility.private,
              child: Text('Özel'),
            ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(_copy(visibility: value));
          },
        ),
        const SizedBox(height: 16),
        Text(
          '${document.targetLanguage.toUpperCase()} · destek: ${document.supportLanguages.join(', ')}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (
          var levelIndex = 0;
          levelIndex < document.levels.length;
          levelIndex++
        )
          _LevelEditor(
            level: document.levels[levelIndex],
            supportLanguages: document.supportLanguages,
            defaultSupportLanguage: document.defaultSupportLanguage,
            canDelete: document.levels.length > 1,
            canMoveUp: levelIndex > 0,
            canMoveDown: levelIndex < document.levels.length - 1,
            onDelete: () {
              final levels = [...document.levels]..removeAt(levelIndex);
              onChanged(_copy(levels: levels));
            },
            onMoveUp: () => onChanged(
              _copy(levels: _moved(document.levels, levelIndex, -1)),
            ),
            onMoveDown: () => onChanged(
              _copy(levels: _moved(document.levels, levelIndex, 1)),
            ),
            onChanged: (level) {
              final levels = [...document.levels]..[levelIndex] = level;
              onChanged(_copy(levels: levels));
            },
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            onPressed: document.levels.length >= 100
                ? null
                : () => onChanged(
                    _copy(
                      levels: [
                        ...document.levels,
                        _newLevel(document, document.levels.length + 1),
                      ],
                    ),
                  ),
            icon: const Icon(Icons.add),
            label: const Text('Seviye ekle'),
          ),
        ),
        const SizedBox(height: 48),
      ],
    ),
  );
}

final class _LevelEditor extends StatelessWidget {
  const _LevelEditor({
    required this.level,
    required this.supportLanguages,
    required this.defaultSupportLanguage,
    required this.onChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.canDelete,
    required this.canMoveUp,
    required this.canMoveDown,
  });
  final EditorLevel level;
  final List<String> supportLanguages;
  final String defaultSupportLanguage;
  final ValueChanged<EditorLevel> onChanged;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final bool canDelete;
  final bool canMoveUp;
  final bool canMoveDown;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      initiallyExpanded: true,
      title: TextFormField(
        initialValue: level.title,
        decoration: const InputDecoration(labelText: 'Seviye'),
        onChanged: (value) => onChanged(
          EditorLevel(id: level.id, title: value, units: level.units),
        ),
      ),
      trailing: _EditorActions(
        canDelete: canDelete,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onDelete: onDelete,
        onMoveUp: onMoveUp,
        onMoveDown: onMoveDown,
      ),
      children: [
        for (var index = 0; index < level.units.length; index++)
          _UnitEditor(
            unit: level.units[index],
            supportLanguages: supportLanguages,
            defaultSupportLanguage: defaultSupportLanguage,
            canDelete: level.units.length > 1,
            canMoveUp: index > 0,
            canMoveDown: index < level.units.length - 1,
            onDelete: () {
              final units = [...level.units]..removeAt(index);
              onChanged(
                EditorLevel(id: level.id, title: level.title, units: units),
              );
            },
            onMoveUp: () => onChanged(
              EditorLevel(
                id: level.id,
                title: level.title,
                units: _moved(level.units, index, -1),
              ),
            ),
            onMoveDown: () => onChanged(
              EditorLevel(
                id: level.id,
                title: level.title,
                units: _moved(level.units, index, 1),
              ),
            ),
            onChanged: (unit) {
              final units = [...level.units]..[index] = unit;
              onChanged(
                EditorLevel(id: level.id, title: level.title, units: units),
              );
            },
          ),
        TextButton.icon(
          onPressed: level.units.length >= 100
              ? null
              : () => onChanged(
                  EditorLevel(
                    id: level.id,
                    title: level.title,
                    units: [
                      ...level.units,
                      _newUnit(
                        supportLanguages,
                        defaultSupportLanguage,
                        level.units.length + 1,
                      ),
                    ],
                  ),
                ),
          icon: const Icon(Icons.add),
          label: const Text('Ünite ekle'),
        ),
      ],
    ),
  );
}

final class _UnitEditor extends StatelessWidget {
  const _UnitEditor({
    required this.unit,
    required this.supportLanguages,
    required this.defaultSupportLanguage,
    required this.onChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.canDelete,
    required this.canMoveUp,
    required this.canMoveDown,
  });
  final EditorUnit unit;
  final List<String> supportLanguages;
  final String defaultSupportLanguage;
  final ValueChanged<EditorUnit> onChanged;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final bool canDelete;
  final bool canMoveUp;
  final bool canMoveDown;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 12, right: 8, bottom: 8),
    child: ExpansionTile(
      title: TextFormField(
        initialValue: unit.title,
        decoration: const InputDecoration(labelText: 'Ünite'),
        onChanged: (value) => onChanged(
          EditorUnit(id: unit.id, title: value, topics: unit.topics),
        ),
      ),
      trailing: _EditorActions(
        canDelete: canDelete,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onDelete: onDelete,
        onMoveUp: onMoveUp,
        onMoveDown: onMoveDown,
      ),
      children: [
        for (var index = 0; index < unit.topics.length; index++)
          _TopicEditor(
            topic: unit.topics[index],
            supportLanguages: supportLanguages,
            defaultSupportLanguage: defaultSupportLanguage,
            canDelete: unit.topics.length > 1,
            canMoveUp: index > 0,
            canMoveDown: index < unit.topics.length - 1,
            onDelete: () {
              final topics = [...unit.topics]..removeAt(index);
              onChanged(
                EditorUnit(id: unit.id, title: unit.title, topics: topics),
              );
            },
            onMoveUp: () => onChanged(
              EditorUnit(
                id: unit.id,
                title: unit.title,
                topics: _moved(unit.topics, index, -1),
              ),
            ),
            onMoveDown: () => onChanged(
              EditorUnit(
                id: unit.id,
                title: unit.title,
                topics: _moved(unit.topics, index, 1),
              ),
            ),
            onChanged: (topic) {
              final topics = [...unit.topics]..[index] = topic;
              onChanged(
                EditorUnit(id: unit.id, title: unit.title, topics: topics),
              );
            },
          ),
        TextButton.icon(
          onPressed: unit.topics.length >= 100
              ? null
              : () => onChanged(
                  EditorUnit(
                    id: unit.id,
                    title: unit.title,
                    topics: [
                      ...unit.topics,
                      _newTopic(
                        supportLanguages,
                        defaultSupportLanguage,
                        unit.topics.length + 1,
                      ),
                    ],
                  ),
                ),
          icon: const Icon(Icons.add),
          label: const Text('Konu ekle'),
        ),
      ],
    ),
  );
}

final class _TopicEditor extends StatelessWidget {
  const _TopicEditor({
    required this.topic,
    required this.supportLanguages,
    required this.defaultSupportLanguage,
    required this.onChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.canDelete,
    required this.canMoveUp,
    required this.canMoveDown,
  });
  final EditorTopic topic;
  final List<String> supportLanguages;
  final String defaultSupportLanguage;
  final ValueChanged<EditorTopic> onChanged;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final bool canDelete;
  final bool canMoveUp;
  final bool canMoveDown;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 12, right: 8, bottom: 8),
    child: ExpansionTile(
      title: TextFormField(
        initialValue: topic.title,
        decoration: const InputDecoration(labelText: 'Konu'),
        onChanged: (value) => onChanged(
          EditorTopic(id: topic.id, title: value, tests: topic.tests),
        ),
      ),
      trailing: _EditorActions(
        canDelete: canDelete,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onDelete: onDelete,
        onMoveUp: onMoveUp,
        onMoveDown: onMoveDown,
      ),
      children: [
        for (var index = 0; index < topic.tests.length; index++)
          _TestEditor(
            test: topic.tests[index],
            supportLanguages: supportLanguages,
            defaultSupportLanguage: defaultSupportLanguage,
            canDelete: topic.tests.length > 1,
            canMoveUp: index > 0,
            canMoveDown: index < topic.tests.length - 1,
            onDelete: () {
              final tests = [...topic.tests]..removeAt(index);
              onChanged(
                EditorTopic(id: topic.id, title: topic.title, tests: tests),
              );
            },
            onMoveUp: () => onChanged(
              EditorTopic(
                id: topic.id,
                title: topic.title,
                tests: _moved(topic.tests, index, -1),
              ),
            ),
            onMoveDown: () => onChanged(
              EditorTopic(
                id: topic.id,
                title: topic.title,
                tests: _moved(topic.tests, index, 1),
              ),
            ),
            onChanged: (test) {
              final tests = [...topic.tests]..[index] = test;
              onChanged(
                EditorTopic(id: topic.id, title: topic.title, tests: tests),
              );
            },
          ),
        TextButton.icon(
          onPressed: topic.tests.length >= 100
              ? null
              : () => onChanged(
                  EditorTopic(
                    id: topic.id,
                    title: topic.title,
                    tests: [
                      ...topic.tests,
                      _newTest(
                        supportLanguages,
                        defaultSupportLanguage,
                        topic.tests.length + 1,
                      ),
                    ],
                  ),
                ),
          icon: const Icon(Icons.add),
          label: const Text('Test ekle'),
        ),
      ],
    ),
  );
}

final class _TestEditor extends StatelessWidget {
  const _TestEditor({
    required this.test,
    required this.supportLanguages,
    required this.defaultSupportLanguage,
    required this.onChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.canDelete,
    required this.canMoveUp,
    required this.canMoveDown,
  });
  final EditorTest test;
  final List<String> supportLanguages;
  final String defaultSupportLanguage;
  final ValueChanged<EditorTest> onChanged;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final bool canDelete;
  final bool canMoveUp;
  final bool canMoveDown;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 12, right: 8, bottom: 8),
    child: ExpansionTile(
      title: TextFormField(
        initialValue: test.title,
        decoration: const InputDecoration(labelText: 'Test'),
        onChanged: (value) => onChanged(
          EditorTest(
            id: test.id,
            title: value,
            passThreshold: test.passThreshold,
            questions: test.questions,
          ),
        ),
      ),
      trailing: _EditorActions(
        canDelete: canDelete,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onDelete: onDelete,
        onMoveUp: onMoveUp,
        onMoveDown: onMoveDown,
      ),
      children: [
        Slider(
          value: test.passThreshold,
          min: .5,
          max: 1,
          divisions: 10,
          label: '%${(test.passThreshold * 100).round()}',
          onChanged: (value) => onChanged(
            EditorTest(
              id: test.id,
              title: test.title,
              passThreshold: value,
              questions: test.questions,
            ),
          ),
        ),
        for (var index = 0; index < test.questions.length; index++)
          _QuestionEditor(
            question: test.questions[index],
            supportLanguages: supportLanguages,
            defaultSupportLanguage: defaultSupportLanguage,
            canDelete: test.questions.length > 1,
            canMoveUp: index > 0,
            canMoveDown: index < test.questions.length - 1,
            onDelete: () {
              final questions = [...test.questions]..removeAt(index);
              onChanged(
                EditorTest(
                  id: test.id,
                  title: test.title,
                  passThreshold: test.passThreshold,
                  questions: questions,
                ),
              );
            },
            onMoveUp: () => onChanged(
              EditorTest(
                id: test.id,
                title: test.title,
                passThreshold: test.passThreshold,
                questions: _moved(test.questions, index, -1),
              ),
            ),
            onMoveDown: () => onChanged(
              EditorTest(
                id: test.id,
                title: test.title,
                passThreshold: test.passThreshold,
                questions: _moved(test.questions, index, 1),
              ),
            ),
            onChanged: (question) {
              final questions = [...test.questions]..[index] = question;
              onChanged(
                EditorTest(
                  id: test.id,
                  title: test.title,
                  passThreshold: test.passThreshold,
                  questions: questions,
                ),
              );
            },
          ),
        PopupMenuButton<EditorQuestionType>(
          enabled: test.questions.length < 500,
          tooltip: 'Soru ekle',
          onSelected: (type) => onChanged(
            EditorTest(
              id: test.id,
              title: test.title,
              passThreshold: test.passThreshold,
              questions: [
                ...test.questions,
                _newQuestion(
                  type,
                  supportLanguages,
                  defaultSupportLanguage,
                  test.questions.length + 1,
                ),
              ],
            ),
          ),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: EditorQuestionType.wordMultipleChoice,
              child: Text('Kelime çoktan seçmeli'),
            ),
            PopupMenuItem(
              value: EditorQuestionType.multipleChoiceCloze,
              child: Text('Boşluk doldurma · seçenekli'),
            ),
            PopupMenuItem(
              value: EditorQuestionType.typedCloze,
              child: Text('Boşluk doldurma · yazılı'),
            ),
            PopupMenuItem(
              value: EditorQuestionType.matching,
              child: Text('Eşleştirme'),
            ),
          ],
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add),
                SizedBox(width: 8),
                Text('Soru ekle'),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

final class _QuestionEditor extends StatelessWidget {
  const _QuestionEditor({
    required this.question,
    required this.supportLanguages,
    required this.defaultSupportLanguage,
    required this.onChanged,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.canDelete,
    required this.canMoveUp,
    required this.canMoveDown,
  });
  final EditorQuestion question;
  final List<String> supportLanguages;
  final String defaultSupportLanguage;
  final ValueChanged<EditorQuestion> onChanged;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final bool canDelete;
  final bool canMoveUp;
  final bool canMoveDown;

  EditorQuestion _copy({
    String? prompt,
    String? correctAnswer,
    String? alternativeCorrectAnswer,
    Map<String, String>? translations,
    List<EditorOption>? options,
    List<EditorMatchingPair>? matchingPairs,
  }) => EditorQuestion(
    id: question.id,
    type: question.type,
    prompt: prompt ?? question.prompt,
    correctAnswer: correctAnswer ?? question.correctAnswer,
    alternativeCorrectAnswer:
        alternativeCorrectAnswer ?? question.alternativeCorrectAnswer,
    translations: translations ?? question.translations,
    options: options ?? question.options,
    matchingPairs: matchingPairs ?? question.matchingPairs,
  );

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: ExpansionTile(
      title: Text('Soru · ${question.type.name}'),
      trailing: _EditorActions(
        canDelete: canDelete,
        canMoveUp: canMoveUp,
        canMoveDown: canMoveDown,
        onDelete: onDelete,
        onMoveUp: onMoveUp,
        onMoveDown: onMoveDown,
      ),
      childrenPadding: const EdgeInsets.all(12),
      children: [
        if (question.prompt != null)
          TextFormField(
            initialValue: question.prompt,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Soru metni'),
            onChanged: (value) => onChanged(_copy(prompt: value)),
          ),
        if (question.type == EditorQuestionType.typedCloze)
          TextFormField(
            initialValue: question.correctAnswer,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Doğru cevap'),
            onChanged: (value) => onChanged(_copy(correctAnswer: value)),
          ),
        if (question.alternativeCorrectAnswer != null)
          TextFormField(
            initialValue: question.alternativeCorrectAnswer,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Alternatif doğru cevap',
            ),
            onChanged: (value) =>
                onChanged(_copy(alternativeCorrectAnswer: value)),
          ),
        for (final language in supportLanguages)
          if (question.translations.containsKey(language))
            TextFormField(
              initialValue: question.translations[language],
              decoration: InputDecoration(labelText: 'Çeviri ($language)'),
              onChanged: (value) {
                final translations = {
                  ...question.translations,
                  language: value,
                };
                final options = question.options
                    .map(
                      (option) => option.correct
                          ? EditorOption(
                              text: language == defaultSupportLanguage
                                  ? value
                                  : option.text,
                              correct: true,
                              translations: translations,
                            )
                          : option,
                    )
                    .toList(growable: false);
                onChanged(
                  _copy(
                    correctAnswer: options
                        .singleWhere((item) => item.correct)
                        .text,
                    translations: translations,
                    options: options,
                  ),
                );
              },
            ),
        for (var index = 0; index < question.options.length; index++)
          _OptionEditor(
            option: question.options[index],
            supportLanguages: supportLanguages,
            defaultSupportLanguage: defaultSupportLanguage,
            isWordQuestion:
                question.type == EditorQuestionType.wordMultipleChoice,
            canMoveUp: index > 0,
            canMoveDown: index < question.options.length - 1,
            onMoveUp: () =>
                onChanged(_copy(options: _moved(question.options, index, -1))),
            onMoveDown: () =>
                onChanged(_copy(options: _moved(question.options, index, 1))),
            onChanged: (option) {
              final options = [...question.options]..[index] = option;
              if (option.correct) {
                onChanged(
                  _copy(
                    options: options,
                    correctAnswer: option.text,
                    translations:
                        question.type == EditorQuestionType.wordMultipleChoice
                        ? option.translations
                        : question.translations,
                  ),
                );
              } else {
                onChanged(_copy(options: options));
              }
            },
          ),
        for (var index = 0; index < question.matchingPairs.length; index++)
          _MatchingEditor(
            pair: question.matchingPairs[index],
            supportLanguages: supportLanguages,
            canDelete: question.matchingPairs.length > 2,
            canMoveUp: index > 0,
            canMoveDown: index < question.matchingPairs.length - 1,
            onDelete: () {
              final pairs = [...question.matchingPairs]..removeAt(index);
              onChanged(_copy(matchingPairs: pairs));
            },
            onMoveUp: () => onChanged(
              _copy(matchingPairs: _moved(question.matchingPairs, index, -1)),
            ),
            onMoveDown: () => onChanged(
              _copy(matchingPairs: _moved(question.matchingPairs, index, 1)),
            ),
            onChanged: (pair) {
              final pairs = [...question.matchingPairs]..[index] = pair;
              onChanged(_copy(matchingPairs: pairs));
            },
          ),
        if (question.type == EditorQuestionType.matching)
          TextButton.icon(
            onPressed: question.matchingPairs.length >= 6
                ? null
                : () {
                    final ordinal = question.matchingPairs.length + 1;
                    onChanged(
                      _copy(
                        matchingPairs: [
                          ...question.matchingPairs,
                          EditorMatchingPair(
                            targetText: 'Hedef $ordinal',
                            translations: {
                              for (final language in supportLanguages)
                                language: 'Eşleşme $ordinal $language',
                            },
                          ),
                        ],
                      ),
                    );
                  },
            icon: const Icon(Icons.add),
            label: const Text('Eşleştirme çifti ekle'),
          ),
      ],
    ),
  );
}

final class _OptionEditor extends StatelessWidget {
  const _OptionEditor({
    required this.option,
    required this.supportLanguages,
    required this.defaultSupportLanguage,
    required this.isWordQuestion,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onChanged,
  });
  final EditorOption option;
  final List<String> supportLanguages;
  final String defaultSupportLanguage;
  final bool isWordQuestion;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<EditorOption> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Seçeneği yukarı taşı',
            onPressed: canMoveUp ? onMoveUp : null,
            icon: const Icon(Icons.arrow_upward, size: 18),
          ),
          IconButton(
            tooltip: 'Seçeneği aşağı taşı',
            onPressed: canMoveDown ? onMoveDown : null,
            icon: const Icon(Icons.arrow_downward, size: 18),
          ),
        ],
      ),
      TextFormField(
        initialValue: option.text,
        decoration: InputDecoration(
          labelText: option.correct ? 'Doğru seçenek' : 'Seçenek',
        ),
        onChanged: (value) => onChanged(
          EditorOption(
            text: value,
            correct: option.correct,
            translations: isWordQuestion
                ? {...option.translations, defaultSupportLanguage: value}
                : option.translations,
          ),
        ),
      ),
      for (final language in supportLanguages)
        if (option.translations.containsKey(language))
          TextFormField(
            initialValue: option.translations[language],
            decoration: InputDecoration(
              labelText: 'Seçenek çevirisi ($language)',
            ),
            onChanged: (value) => onChanged(
              EditorOption(
                text: language == defaultSupportLanguage ? value : option.text,
                correct: option.correct,
                translations: {...option.translations, language: value},
              ),
            ),
          ),
    ],
  );
}

final class _MatchingEditor extends StatelessWidget {
  const _MatchingEditor({
    required this.pair,
    required this.supportLanguages,
    required this.canDelete,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onChanged,
  });
  final EditorMatchingPair pair;
  final List<String> supportLanguages;
  final bool canDelete;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<EditorMatchingPair> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: _EditorActions(
          canDelete: canDelete,
          canMoveUp: canMoveUp,
          canMoveDown: canMoveDown,
          onDelete: onDelete,
          onMoveUp: onMoveUp,
          onMoveDown: onMoveDown,
        ),
      ),
      TextFormField(
        initialValue: pair.targetText,
        decoration: const InputDecoration(labelText: 'Eşleştirme hedefi'),
        onChanged: (value) => onChanged(
          EditorMatchingPair(
            targetText: value,
            translations: pair.translations,
          ),
        ),
      ),
      for (final language in supportLanguages)
        TextFormField(
          initialValue: pair.translations[language],
          decoration: InputDecoration(labelText: 'Eşleşen metin ($language)'),
          onChanged: (value) => onChanged(
            EditorMatchingPair(
              targetText: pair.targetText,
              translations: {...pair.translations, language: value},
            ),
          ),
        ),
    ],
  );
}

final class _EditorActions extends StatelessWidget {
  const _EditorActions({
    required this.canDelete,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final bool canDelete;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'Yukarı taşı',
        onPressed: canMoveUp ? onMoveUp : null,
        icon: const Icon(Icons.arrow_upward, size: 18),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'Aşağı taşı',
        onPressed: canMoveDown ? onMoveDown : null,
        icon: const Icon(Icons.arrow_downward, size: 18),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: 'Sil',
        onPressed: canDelete ? onDelete : null,
        icon: const Icon(Icons.delete_outline, size: 18),
      ),
    ],
  );
}

List<T> _moved<T>(List<T> values, int index, int offset) {
  final result = [...values];
  final value = result.removeAt(index);
  result.insert(index + offset, value);
  return result;
}

EditorLevel _newLevel(FullCourseEditorDocument document, int ordinal) =>
    EditorLevel(
      title: 'Yeni seviye $ordinal',
      units: [
        _newUnit(document.supportLanguages, document.defaultSupportLanguage, 1),
      ],
    );

EditorUnit _newUnit(
  List<String> supportLanguages,
  String defaultSupportLanguage,
  int ordinal,
) => EditorUnit(
  title: 'Yeni ünite $ordinal',
  topics: [_newTopic(supportLanguages, defaultSupportLanguage, 1)],
);

EditorTopic _newTopic(
  List<String> supportLanguages,
  String defaultSupportLanguage,
  int ordinal,
) => EditorTopic(
  title: 'Yeni konu $ordinal',
  tests: [_newTest(supportLanguages, defaultSupportLanguage, 1)],
);

EditorTest _newTest(
  List<String> supportLanguages,
  String defaultSupportLanguage,
  int ordinal,
) => EditorTest(
  title: 'Yeni test $ordinal',
  passThreshold: .7,
  questions: [
    _newQuestion(
      EditorQuestionType.typedCloze,
      supportLanguages,
      defaultSupportLanguage,
      1,
    ),
  ],
);

EditorQuestion _newQuestion(
  EditorQuestionType type,
  List<String> supportLanguages,
  String defaultSupportLanguage,
  int ordinal,
) {
  Map<String, String> translated(String label) => {
    for (final language in supportLanguages) language: '$label $language',
  };

  return switch (type) {
    EditorQuestionType.wordMultipleChoice => () {
      final correctTranslations = translated('Çeviri $ordinal');
      final correct = correctTranslations[defaultSupportLanguage]!;
      return EditorQuestion(
        type: type,
        prompt: 'Yeni kelime $ordinal',
        correctAnswer: correct,
        translations: correctTranslations,
        options: [
          EditorOption(
            text: correct,
            correct: true,
            translations: correctTranslations,
          ),
          for (var option = 1; option <= 3; option++)
            (() {
              final translations = translated('Seçenek $ordinal.$option');
              return EditorOption(
                text: translations[defaultSupportLanguage]!,
                correct: false,
                translations: translations,
              );
            })(),
        ],
        matchingPairs: const [],
      );
    }(),
    EditorQuestionType.multipleChoiceCloze => EditorQuestion(
      type: type,
      prompt: 'Yeni cümle --- $ordinal',
      correctAnswer: 'cevap$ordinal',
      translations: const {},
      options: [
        EditorOption(
          text: 'cevap$ordinal',
          correct: true,
          translations: const {},
        ),
        for (var option = 1; option <= 3; option++)
          EditorOption(
            text: 'yanlış$ordinal$option',
            correct: false,
            translations: const {},
          ),
      ],
      matchingPairs: const [],
    ),
    EditorQuestionType.typedCloze => EditorQuestion(
      type: type,
      prompt: 'Yeni cümle --- $ordinal',
      correctAnswer: 'cevap$ordinal',
      translations: const {},
      options: const [],
      matchingPairs: const [],
    ),
    EditorQuestionType.matching => EditorQuestion(
      type: type,
      translations: const {},
      options: const [],
      matchingPairs: [
        EditorMatchingPair(
          targetText: 'Hedef $ordinal.1',
          translations: translated('Eşleşme $ordinal.1'),
        ),
        EditorMatchingPair(
          targetText: 'Hedef $ordinal.2',
          translations: translated('Eşleşme $ordinal.2'),
        ),
      ],
    ),
  };
}
