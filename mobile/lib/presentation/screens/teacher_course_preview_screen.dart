import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/teacher_course_controller.dart';
import '../../domain/teacher/teacher_course.dart';
import '../widgets/async_error_view.dart';
import '../widgets/localization.dart';

final class TeacherCoursePreviewScreen extends ConsumerWidget {
  const TeacherCoursePreviewScreen({required this.courseId, super.key});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = ref.watch(teacherCourseEditorProvider(courseId));
    return Scaffold(
      key: const Key('teacher-course-preview'),
      appBar: AppBar(title: Text(context.l10n.studentPreviewTitle)),
      body: document.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(teacherCourseEditorProvider(courseId)),
        ),
        data: (value) => _CoursePreview(document: value),
      ),
    );
  }
}

final class _CoursePreview extends StatelessWidget {
  const _CoursePreview({required this.document});

  final FullCourseEditorDocument document;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card.filled(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.visibility_outlined),
              const SizedBox(width: 12),
              Expanded(child: Text(context.l10n.studentPreviewNotice)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(document.name, style: Theme.of(context).textTheme.headlineMedium),
      if (document.description case final description?) ...[
        const SizedBox(height: 8),
        Text(description),
      ],
      const SizedBox(height: 8),
      Text(
        context.l10n.studentPreviewActiveRevision(document.releaseRevision),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      Text(
        context.l10n.targetAndSupportLanguages(
          document.supportLanguages.join(', ').toUpperCase(),
          document.targetLanguage.toUpperCase(),
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 16),
      for (
        var levelIndex = 0;
        levelIndex < document.levels.length;
        levelIndex++
      )
        _LevelPreview(
          level: document.levels[levelIndex],
          levelIndex: levelIndex,
          defaultSupportLanguage: document.defaultSupportLanguage,
        ),
    ],
  );
}

final class _LevelPreview extends StatelessWidget {
  const _LevelPreview({
    required this.level,
    required this.levelIndex,
    required this.defaultSupportLanguage,
  });

  final EditorLevel level;
  final int levelIndex;
  final String defaultSupportLanguage;

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: ExpansionTile(
      initiallyExpanded: levelIndex == 0,
      title: Text(level.title),
      childrenPadding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12),
      children: [
        for (var unitIndex = 0; unitIndex < level.units.length; unitIndex++)
          _UnitPreview(
            unit: level.units[unitIndex],
            initiallyExpanded: levelIndex == 0 && unitIndex == 0,
            defaultSupportLanguage: defaultSupportLanguage,
          ),
      ],
    ),
  );
}

final class _UnitPreview extends StatelessWidget {
  const _UnitPreview({
    required this.unit,
    required this.initiallyExpanded,
    required this.defaultSupportLanguage,
  });

  final EditorUnit unit;
  final bool initiallyExpanded;
  final String defaultSupportLanguage;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: initiallyExpanded,
    title: Text(unit.title),
    childrenPadding: const EdgeInsetsDirectional.only(start: 12),
    children: [
      for (var topicIndex = 0; topicIndex < unit.topics.length; topicIndex++)
        _TopicPreview(
          topic: unit.topics[topicIndex],
          initiallyExpanded: initiallyExpanded && topicIndex == 0,
          defaultSupportLanguage: defaultSupportLanguage,
        ),
    ],
  );
}

final class _TopicPreview extends StatelessWidget {
  const _TopicPreview({
    required this.topic,
    required this.initiallyExpanded,
    required this.defaultSupportLanguage,
  });

  final EditorTopic topic;
  final bool initiallyExpanded;
  final String defaultSupportLanguage;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: initiallyExpanded,
    title: Text(topic.title),
    childrenPadding: const EdgeInsetsDirectional.only(start: 12),
    children: [
      for (var testIndex = 0; testIndex < topic.tests.length; testIndex++)
        _TestPreview(
          test: topic.tests[testIndex],
          initiallyExpanded: initiallyExpanded && testIndex == 0,
          defaultSupportLanguage: defaultSupportLanguage,
        ),
    ],
  );
}

final class _TestPreview extends StatelessWidget {
  const _TestPreview({
    required this.test,
    required this.initiallyExpanded,
    required this.defaultSupportLanguage,
  });

  final EditorTest test;
  final bool initiallyExpanded;
  final String defaultSupportLanguage;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: initiallyExpanded,
    title: Text(test.title),
    subtitle: Text(context.l10n.questionCount(test.questions.length)),
    childrenPadding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 12),
    children: test.questions.isEmpty
        ? [ListTile(title: Text(context.l10n.studentPreviewNoQuestions))]
        : [
            for (var index = 0; index < test.questions.length; index++)
              _QuestionPreview(
                question: test.questions[index],
                ordinal: index + 1,
                defaultSupportLanguage: defaultSupportLanguage,
              ),
          ],
  );
}

final class _QuestionPreview extends StatelessWidget {
  const _QuestionPreview({
    required this.question,
    required this.ordinal,
    required this.defaultSupportLanguage,
  });

  final EditorQuestion question;
  final int ordinal;
  final String defaultSupportLanguage;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('teacher-preview-question-$ordinal'),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$ordinal. ${_questionTypeLabel(context, question.type)}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          if (question.prompt case final prompt?) ...[
            const SizedBox(height: 12),
            Text(prompt, style: Theme.of(context).textTheme.titleMedium),
          ],
          const SizedBox(height: 12),
          switch (question.type) {
            EditorQuestionType.wordMultipleChoice ||
            EditorQuestionType.multipleChoiceCloze => _OptionPreview(
              question: question,
            ),
            EditorQuestionType.typedCloze => const _TypedPreview(),
            EditorQuestionType.matching => _MatchingPreview(
              question: question,
              defaultSupportLanguage: defaultSupportLanguage,
            ),
          },
        ],
      ),
    ),
  );
}

final class _OptionPreview extends StatelessWidget {
  const _OptionPreview({required this.question});

  final EditorQuestion question;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(context.l10n.studentPreviewChooseOption),
      const SizedBox(height: 8),
      for (final option in question.options)
        Semantics(
          enabled: false,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.radio_button_unchecked),
            title: Text(option.text),
          ),
        ),
    ],
  );
}

final class _TypedPreview extends StatelessWidget {
  const _TypedPreview();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(context.l10n.studentPreviewTypeAnswer),
      const SizedBox(height: 8),
      TextField(
        enabled: false,
        decoration: InputDecoration(labelText: context.l10n.yourAnswer),
      ),
    ],
  );
}

final class _MatchingPreview extends StatelessWidget {
  const _MatchingPreview({
    required this.question,
    required this.defaultSupportLanguage,
  });

  final EditorQuestion question;
  final String defaultSupportLanguage;

  @override
  Widget build(BuildContext context) {
    final supportItems = question.matchingPairs
        .map((pair) => pair.translations[defaultSupportLanguage] ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false)
        .reversed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.studentPreviewMatchItems),
        const SizedBox(height: 12),
        Text(
          context.l10n.matchingTargetsHeading,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        for (final pair in question.matchingPairs)
          ListTile(
            dense: true,
            leading: const Icon(Icons.drag_indicator),
            title: Text(pair.targetText),
          ),
        const Divider(),
        Text(
          context.l10n.matchingSupportsHeading,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        for (final item in supportItems)
          ListTile(
            dense: true,
            leading: const Icon(Icons.drag_indicator),
            title: Text(item),
          ),
      ],
    );
  }
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
