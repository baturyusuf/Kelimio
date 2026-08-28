import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/teacher_course_controller.dart';
import '../../domain/teacher/teacher_course.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/async_error_view.dart';
import '../widgets/localization.dart';

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
    final provider = teacherCourseEditorProvider(widget.courseId);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);
    final conflict = notifier.conflict;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.fullCourseEditorTitle),
        actions: [
          IconButton(
            key: const Key('full-editor-save'),
            tooltip: context.l10n.saveEditorDraft,
            onPressed:
                _saving || conflict != null || (_draft ?? state.value) == null
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
          if (conflict != null) {
            return _EditorConflictView(
              conflict: conflict,
              onUseLatest: () {
                final resolved = notifier.useLatest();
                if (resolved != null) setState(() => _draft = resolved);
              },
              onReapplyMine: () {
                final resolved = notifier.reapplyMine();
                if (resolved != null) setState(() => _draft = resolved);
              },
            );
          }
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
          title: Text(
            context.l10n.publishRevisionTitle(impact.releaseRevision),
          ),
          content: Text(
            context.l10n.releaseImpactSummary(
              impact.addedQuestionCount,
              impact.changedQuestionCount,
              impact.affectedEnrollmentCount,
              impact.targetQuestionCount,
              impact.removedQuestionCount,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.later),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.publishCourse),
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
              content: Text(
                context.l10n.revisionPublished(activation.releaseRevision),
              ),
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

final class _EditorConflictView extends StatelessWidget {
  const _EditorConflictView({
    required this.conflict,
    required this.onUseLatest,
    required this.onReapplyMine,
  });

  final TeacherCourseEditorConflict conflict;
  final VoidCallback onUseLatest;
  final VoidCallback onReapplyMine;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('full-editor-conflict'),
    padding: const EdgeInsets.all(16),
    children: [
      Icon(
        Icons.sync_problem_outlined,
        size: 48,
        color: Theme.of(context).colorScheme.error,
      ),
      const SizedBox(height: 12),
      Text(
        context.l10n.fullEditorConflictHeading,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 8),
      Text(context.l10n.fullEditorConflictBody, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      _ConflictVersionCard(
        title: context.l10n.fullEditorBaseVersion,
        document: conflict.base,
        changes: const [],
      ),
      _ConflictVersionCard(
        title: context.l10n.fullEditorMineVersion,
        document: conflict.mine,
        changes: conflict.mineChanges,
      ),
      _ConflictVersionCard(
        title: context.l10n.fullEditorLatestVersion,
        document: conflict.latest,
        changes: conflict.latestChanges,
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        key: const Key('full-editor-use-latest'),
        onPressed: onUseLatest,
        child: Text(context.l10n.fullEditorUseLatest),
      ),
      const SizedBox(height: 8),
      FilledButton(
        key: const Key('full-editor-reapply-mine'),
        onPressed: onReapplyMine,
        child: Text(context.l10n.fullEditorReapplyMine),
      ),
    ],
  );
}

final class _ConflictVersionCard extends StatelessWidget {
  const _ConflictVersionCard({
    required this.title,
    required this.document,
    required this.changes,
  });

  final String title;
  final FullCourseEditorDocument document;
  final List<String> changes;

  @override
  Widget build(BuildContext context) {
    final questionCount = document.levels.fold<int>(
      0,
      (levelTotal, level) =>
          levelTotal +
          level.units.fold<int>(
            0,
            (unitTotal, unit) =>
                unitTotal +
                unit.topics.fold<int>(
                  0,
                  (topicTotal, topic) =>
                      topicTotal +
                      topic.tests.fold<int>(
                        0,
                        (testTotal, test) => testTotal + test.questions.length,
                      ),
                ),
          ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              context.l10n.fullEditorVersionSummary(
                document.levels.length,
                document.name,
                questionCount,
                document.releaseRevision,
              ),
            ),
            if (changes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(context.l10n.editorChanges(changes.length)),
              for (final path in changes.take(12))
                Text('• ${_localizedChangePath(context, path)}'),
              if (changes.length > 12)
                Text(
                  '• ${context.l10n.editorMoreChanges(changes.length - 12)}',
                ),
            ],
          ],
        ),
      ),
    );
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
          decoration: InputDecoration(labelText: context.l10n.courseName),
          onChanged: (value) => onChanged(_copy(name: value)),
        ),
        TextFormField(
          key: const Key('full-editor-description'),
          initialValue: document.description,
          maxLength: 2000,
          maxLines: 3,
          decoration: InputDecoration(labelText: context.l10n.description),
          onChanged: (value) => onChanged(_copy(description: value)),
        ),
        DropdownButtonFormField<TeacherCourseVisibility>(
          initialValue: document.visibility,
          decoration: InputDecoration(labelText: context.l10n.visibility),
          items: [
            DropdownMenuItem(
              value: TeacherCourseVisibility.public,
              child: Text(context.l10n.publicVisibility),
            ),
            DropdownMenuItem(
              value: TeacherCourseVisibility.private,
              child: Text(context.l10n.privateVisibility),
            ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(_copy(visibility: value));
          },
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.targetAndSupportLanguages(
            document.supportLanguages.join(', '),
            document.targetLanguage.toUpperCase(),
          ),
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
                        _newLevel(
                          document,
                          document.levels.length + 1,
                          context.l10n,
                        ),
                      ],
                    ),
                  ),
            icon: const Icon(Icons.add),
            label: Text(context.l10n.addLevel),
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
        decoration: InputDecoration(labelText: context.l10n.level),
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
                        context.l10n,
                      ),
                    ],
                  ),
                ),
          icon: const Icon(Icons.add),
          label: Text(context.l10n.addUnit),
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
        decoration: InputDecoration(labelText: context.l10n.unit),
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
                        context.l10n,
                      ),
                    ],
                  ),
                ),
          icon: const Icon(Icons.add),
          label: Text(context.l10n.addTopic),
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
        decoration: InputDecoration(labelText: context.l10n.topic),
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
                        context.l10n,
                      ),
                    ],
                  ),
                ),
          icon: const Icon(Icons.add),
          label: Text(context.l10n.addTest),
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
        decoration: InputDecoration(labelText: context.l10n.test),
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
          tooltip: context.l10n.addQuestion,
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
                  context.l10n,
                ),
              ],
            ),
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: EditorQuestionType.wordMultipleChoice,
              child: Text(context.l10n.questionTypeWordMultipleChoice),
            ),
            PopupMenuItem(
              value: EditorQuestionType.multipleChoiceCloze,
              child: Text(context.l10n.questionTypeMultipleChoiceCloze),
            ),
            PopupMenuItem(
              value: EditorQuestionType.typedCloze,
              child: Text(context.l10n.questionTypeTypedCloze),
            ),
            PopupMenuItem(
              value: EditorQuestionType.matching,
              child: Text(context.l10n.questionTypeMatching),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add),
                const SizedBox(width: 8),
                Text(context.l10n.addQuestion),
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
      title: Text(
        context.l10n.questionTitle(_questionTypeLabel(context, question.type)),
      ),
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
            decoration: InputDecoration(labelText: context.l10n.questionPrompt),
            onChanged: (value) => onChanged(_copy(prompt: value)),
          ),
        if (question.type == EditorQuestionType.typedCloze)
          TextFormField(
            initialValue: question.correctAnswer,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: context.l10n.correctAnswerLabel,
            ),
            onChanged: (value) => onChanged(_copy(correctAnswer: value)),
          ),
        if (question.alternativeCorrectAnswer != null)
          TextFormField(
            initialValue: question.alternativeCorrectAnswer,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: context.l10n.alternativeCorrectAnswer,
            ),
            onChanged: (value) =>
                onChanged(_copy(alternativeCorrectAnswer: value)),
          ),
        for (final language in supportLanguages)
          if (question.translations.containsKey(language))
            TextFormField(
              initialValue: question.translations[language],
              decoration: InputDecoration(
                labelText: context.l10n.translationLanguage(language),
              ),
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
                            targetText: context.l10n.newTarget(ordinal),
                            translations: {
                              for (final language in supportLanguages)
                                language: context.l10n.newMatch(
                                  language,
                                  ordinal,
                                ),
                            },
                          ),
                        ],
                      ),
                    );
                  },
            icon: const Icon(Icons.add),
            label: Text(context.l10n.addMatchingPair),
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
            tooltip: context.l10n.moveOptionUp,
            onPressed: canMoveUp ? onMoveUp : null,
            icon: const Icon(Icons.arrow_upward, size: 18),
          ),
          IconButton(
            tooltip: context.l10n.moveOptionDown,
            onPressed: canMoveDown ? onMoveDown : null,
            icon: const Icon(Icons.arrow_downward, size: 18),
          ),
        ],
      ),
      TextFormField(
        initialValue: option.text,
        decoration: InputDecoration(
          labelText: option.correct
              ? context.l10n.correctOption
              : context.l10n.option,
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
              labelText: context.l10n.optionTranslation(language),
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
        decoration: InputDecoration(labelText: context.l10n.matchingTarget),
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
          decoration: InputDecoration(
            labelText: context.l10n.matchingText(language),
          ),
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
        tooltip: context.l10n.moveUp,
        onPressed: canMoveUp ? onMoveUp : null,
        icon: const Icon(Icons.arrow_upward, size: 18),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: context.l10n.moveDown,
        onPressed: canMoveDown ? onMoveDown : null,
        icon: const Icon(Icons.arrow_downward, size: 18),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: context.l10n.delete,
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

EditorLevel _newLevel(
  FullCourseEditorDocument document,
  int ordinal,
  AppLocalizations l10n,
) => EditorLevel(
  title: l10n.newLevel(ordinal),
  units: [
    _newUnit(
      document.supportLanguages,
      document.defaultSupportLanguage,
      1,
      l10n,
    ),
  ],
);

EditorUnit _newUnit(
  List<String> supportLanguages,
  String defaultSupportLanguage,
  int ordinal,
  AppLocalizations l10n,
) => EditorUnit(
  title: l10n.newUnit(ordinal),
  topics: [_newTopic(supportLanguages, defaultSupportLanguage, 1, l10n)],
);

EditorTopic _newTopic(
  List<String> supportLanguages,
  String defaultSupportLanguage,
  int ordinal,
  AppLocalizations l10n,
) => EditorTopic(
  title: l10n.newTopic(ordinal),
  tests: [_newTest(supportLanguages, defaultSupportLanguage, 1, l10n)],
);

EditorTest _newTest(
  List<String> supportLanguages,
  String defaultSupportLanguage,
  int ordinal,
  AppLocalizations l10n,
) => EditorTest(
  title: l10n.newTest(ordinal),
  passThreshold: .7,
  questions: [
    _newQuestion(
      EditorQuestionType.typedCloze,
      supportLanguages,
      defaultSupportLanguage,
      1,
      l10n,
    ),
  ],
);

EditorQuestion _newQuestion(
  EditorQuestionType type,
  List<String> supportLanguages,
  String defaultSupportLanguage,
  int ordinal,
  AppLocalizations l10n,
) {
  Map<String, String> translated(String label) => {
    for (final language in supportLanguages) language: '$label $language',
  };

  return switch (type) {
    EditorQuestionType.wordMultipleChoice => () {
      final correctTranslations = translated(l10n.newTranslation(ordinal));
      final correct = correctTranslations[defaultSupportLanguage]!;
      return EditorQuestion(
        type: type,
        prompt: l10n.newWord(ordinal),
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
              final translations = translated(l10n.newOption(option, ordinal));
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
      prompt: l10n.newSentence(ordinal),
      correctAnswer: l10n.newAnswer(ordinal),
      translations: const {},
      options: [
        EditorOption(
          text: l10n.newAnswer(ordinal),
          correct: true,
          translations: const {},
        ),
        for (var option = 1; option <= 3; option++)
          EditorOption(
            text: l10n.newWrongAnswer(option, ordinal),
            correct: false,
            translations: const {},
          ),
      ],
      matchingPairs: const [],
    ),
    EditorQuestionType.typedCloze => EditorQuestion(
      type: type,
      prompt: l10n.newSentence(ordinal),
      correctAnswer: l10n.newAnswer(ordinal),
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
          targetText: l10n.newTarget('$ordinal.1'),
          translations: translated(l10n.newMatch('', '$ordinal.1').trim()),
        ),
        EditorMatchingPair(
          targetText: l10n.newTarget('$ordinal.2'),
          translations: translated(l10n.newMatch('', '$ordinal.2').trim()),
        ),
      ],
    ),
  };
}

String _questionTypeLabel(BuildContext context, EditorQuestionType type) =>
    switch (type) {
      EditorQuestionType.wordMultipleChoice =>
        context.l10n.questionTypeWordMultipleChoice,
      EditorQuestionType.multipleChoiceCloze =>
        context.l10n.questionTypeMultipleChoiceCloze,
      EditorQuestionType.typedCloze => context.l10n.questionTypeTypedCloze,
      EditorQuestionType.matching => context.l10n.questionTypeMatching,
    };

String _localizedChangePath(BuildContext context, String path) => path
    .split(' / ')
    .map((segment) => _localizedPathSegment(context, segment))
    .join(' / ');

String _localizedPathSegment(BuildContext context, String segment) {
  final l10n = context.l10n;
  final numbered = RegExp(
    r'^(Seviye|Ünite|Konu|Test|Soru|Seçenek|Eşleşme) (\d+)$',
  ).firstMatch(segment);
  if (numbered != null) {
    final label = switch (numbered.group(1)) {
      'Seviye' => l10n.level,
      'Ünite' => l10n.unit,
      'Konu' => l10n.topic,
      'Test' => l10n.test,
      'Soru' => l10n.question,
      'Seçenek' => l10n.option,
      _ => l10n.matching,
    };
    return '$label ${numbered.group(2)}';
  }
  if (segment.startsWith('çeviri ')) {
    return l10n.translationLanguage(segment.substring('çeviri '.length));
  }
  return switch (segment) {
    'Kurs' => l10n.course,
    'ad' => l10n.courseName,
    'açıklama' => l10n.description,
    'görünürlük' => l10n.visibility,
    'seviye sırası' => '${l10n.level} ${l10n.order}',
    'ünite sırası' => '${l10n.unit} ${l10n.order}',
    'konu sırası' => '${l10n.topic} ${l10n.order}',
    'test sırası' => '${l10n.test} ${l10n.order}',
    'soru sırası' => '${l10n.question} ${l10n.order}',
    'kimlik' => l10n.identifier,
    'başlık' => l10n.title,
    'geçme eşiği' => l10n.passThreshold,
    'tür' => l10n.type,
    'istem' => l10n.questionPrompt,
    'doğru cevap' => l10n.correctAnswerLabel,
    'alternatif cevap' => l10n.alternativeCorrectAnswer,
    'metin' => l10n.text,
    'doğru' => l10n.correctValue,
    'hedef' => l10n.matchingTarget,
    _ => segment,
  };
}
