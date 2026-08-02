import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show Bidi;

import '../../application/attempt_controller.dart';
import '../../domain/learning/attempt_machine.dart';
import '../../domain/learning/learning.dart';
import '../widgets/localization.dart';

final class AttemptScreen extends ConsumerStatefulWidget {
  const AttemptScreen({required this.testId, super.key});

  final String testId;

  @override
  ConsumerState<AttemptScreen> createState() => _AttemptScreenState();
}

final class _AttemptScreenState extends ConsumerState<AttemptScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(attemptControllerProvider.notifier)
            .recoverOrStart(widget.testId),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attemptControllerProvider);
    final controller = ref.read(attemptControllerProvider.notifier);
    if (state.testId != widget.testId) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: switch (state) {
          AttemptLoading() => const Center(child: CircularProgressIndicator()),
          final AttemptPresenting presenting => AttemptQuestionView(
            question: presenting.question,
            questionIndex: presenting.questionIndex,
            questionCount: presenting.context.session.questions.length,
            selectedOptionId: presenting.selectedOptionId,
            matchingDraft: presenting.matchingDraft,
            locked: false,
            onOptionSelected: controller.selectOption,
            onTypedSubmitted: controller.submitTyped,
            onMatchingTargetSelected: controller.selectMatchingTarget,
            onMatchingSupportSelected: controller.selectMatchingSupport,
            onMatchingPairRemoved: controller.removeMatchingPair,
            typedAnswerNeedsReentry: presenting.resumeSubmissionId != null,
            onPrimary: switch (presenting.question.answerKind) {
              AnswerKind.option =>
                presenting.selectedOptionId == null
                    ? null
                    : () => unawaited(controller.submitSelected()),
              AnswerKind.typed => null,
              AnswerKind.matching =>
                presenting.matchingDraft.isCompleteFor(presenting.question)
                    ? () => unawaited(controller.submitMatching())
                    : null,
            },
          ),
          final AttemptSubmitting submitting => AttemptQuestionView(
            question: submitting.question,
            questionIndex: submitting.questionIndex,
            questionCount: submitting.context.session.questions.length,
            selectedOptionId: switch (submitting.pending.input) {
              final OptionAnswerInput option => option.selectedOptionId,
              TypedAnswerInput() || MatchingAnswerInput() => null,
            },
            submittedMatches: switch (submitting.pending.input) {
              final MatchingAnswerInput matching => matching,
              _ => null,
            },
            locked: true,
            onOptionSelected: null,
            onTypedSubmitted: null,
            onPrimary: null,
          ),
          final AttemptReconciling reconciling => AttemptQuestionView(
            question: reconciling.question,
            questionIndex: reconciling.questionIndex,
            questionCount: reconciling.context.session.questions.length,
            selectedOptionId: switch (reconciling.pending?.input) {
              final OptionAnswerInput option => option.selectedOptionId,
              _ => null,
            },
            submittedMatches: switch (reconciling.pending?.input) {
              final MatchingAnswerInput matching => matching,
              _ => null,
            },
            locked: true,
            onOptionSelected: null,
            onTypedSubmitted: null,
            onPrimary: null,
          ),
          final AttemptFeedback feedback => AttemptQuestionView(
            question: feedback.question,
            questionIndex: feedback.questionIndex,
            questionCount: feedback.context.session.questions.length,
            selectedOptionId: feedback.selectedOptionId,
            submittedMatches: feedback.submittedMatches,
            locked: true,
            feedback: feedback.feedback,
            onOptionSelected: null,
            onTypedSubmitted: null,
            onPrimary: () => unawaited(controller.advance()),
          ),
          AttemptFinishing() => _StatusPanel(
            icon: Icons.hourglass_top,
            title: context.l10n.finishing,
            showProgress: true,
          ),
          final AttemptPassed passed => AttemptResultView(
            passed: true,
            result: passed.result,
            onDone: context.pop,
          ),
          final AttemptFailed failed => AttemptResultView(
            passed: false,
            result: failed.result,
            onDone: context.pop,
          ),
          AttemptInterrupted() => _StatusPanel(
            icon: Icons.battery_alert_outlined,
            title: context.l10n.attemptInterrupted,
            body: context.l10n.energyDepleted,
            primaryLabel: context.l10n.energy,
            onPrimary: () => context.go('/energy'),
            secondaryLabel: context.l10n.backToCourse,
            onSecondary: context.pop,
          ),
          AttemptContentChanged() => _StatusPanel(
            icon: Icons.sync_problem,
            title: context.l10n.contentChanged,
            primaryLabel: context.l10n.backToCourse,
            onPrimary: context.pop,
          ),
          AttemptRecovery() => _StatusPanel(
            icon: Icons.cloud_off,
            title: context.l10n.recoverAttempt,
            body: context.l10n.recoverableError,
            primaryLabel: context.l10n.retry,
            onPrimary: () => unawaited(controller.retry()),
            secondaryLabel: context.l10n.backToCourse,
            onSecondary: context.pop,
          ),
          AttemptFatal() => _StatusPanel(
            icon: Icons.error_outline,
            title: context.l10n.fatalAttemptError,
            primaryLabel: context.l10n.backToCourse,
            onPrimary: context.pop,
          ),
        },
      ),
    );
  }
}

final class AttemptQuestionView extends StatelessWidget {
  const AttemptQuestionView({
    required this.question,
    required this.questionIndex,
    required this.questionCount,
    required this.selectedOptionId,
    required this.locked,
    required this.onOptionSelected,
    required this.onPrimary,
    this.onTypedSubmitted,
    this.matchingDraft = const MatchingDraft.empty(),
    this.submittedMatches,
    this.onMatchingTargetSelected,
    this.onMatchingSupportSelected,
    this.onMatchingPairRemoved,
    this.typedAnswerNeedsReentry = false,
    this.feedback,
    super.key,
  });

  final Question question;
  final int questionIndex;
  final int questionCount;
  final String? selectedOptionId;
  final bool locked;
  final ValueChanged<String>? onOptionSelected;
  final ValueChanged<String>? onTypedSubmitted;
  final MatchingDraft matchingDraft;
  final MatchingAnswerInput? submittedMatches;
  final ValueChanged<String>? onMatchingTargetSelected;
  final ValueChanged<String>? onMatchingSupportSelected;
  final ValueChanged<String>? onMatchingPairRemoved;
  final VoidCallback? onPrimary;
  final bool typedAnswerNeedsReentry;
  final AnswerFeedback? feedback;

  @override
  Widget build(BuildContext context) {
    final result = feedback;
    final progressLabel = context.l10n.questionProgress(
      questionIndex + 1,
      questionCount,
    );
    return ListView(
      key: ValueKey('attempt-question-${question.revisionId}'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Semantics(
          label: progressLabel,
          value: '${questionIndex + 1}/$questionCount',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(progressLabel),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (questionIndex + 1) / questionCount,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _QuestionPrompt(question: question),
        const SizedBox(height: 24),
        if (question.answerKind == AnswerKind.option)
          for (final option in question.options) ...[
            _AnswerOptionButton(
              option: option,
              selected: selectedOptionId == option.id,
              locked: locked,
              feedback: feedback,
              onPressed: onOptionSelected == null
                  ? null
                  : () => onOptionSelected!(option.id),
            ),
            const SizedBox(height: 10),
          ]
        else if (question.answerKind == AnswerKind.typed && result == null)
          _TypedAnswerComposer(
            locked: locked,
            needsReentry: typedAnswerNeedsReentry,
            promptDirection: _firstStrongDirection(
              question.prompt!,
              Directionality.of(context),
            ),
            onSubmitted: onTypedSubmitted,
          )
        else if (question.answerKind == AnswerKind.matching)
          _MatchingQuestionComposer(
            question: question,
            draft: matchingDraft,
            submittedMatches: submittedMatches,
            locked: locked,
            feedback: result,
            onTargetSelected: onMatchingTargetSelected,
            onSupportSelected: onMatchingSupportSelected,
            onPairRemoved: onMatchingPairRemoved,
          ),
        if (result != null) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            label: result.correct
                ? context.l10n.correct
                : context.l10n.incorrect,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  result.correct ? Icons.check_circle : Icons.cancel,
                  color: result.correct
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  result.correct
                      ? context.l10n.correct
                      : context.l10n.incorrect,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
        if (result?.correctAnswerText case final String correctAnswer) ...[
          const SizedBox(height: 12),
          _AuthoritativeTypedAnswer(answer: correctAnswer),
        ],
        const SizedBox(height: 20),
        if (question.answerKind != AnswerKind.typed || feedback != null)
          FilledButton(
            key: const Key('attempt-primary-button'),
            onPressed:
                question.answerKind == AnswerKind.matching && feedback == null
                ? matchingDraft.isCompleteFor(question) && !locked
                      ? onPrimary
                      : null
                : onPrimary,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: locked && feedback == null
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    feedback == null
                        ? context.l10n.submitAnswer
                        : context.l10n.continueLabel,
                  ),
          ),
      ],
    );
  }
}

final class _QuestionPrompt extends StatelessWidget {
  const _QuestionPrompt({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) => switch (question.type) {
    QuestionType.wordMultipleChoice => Text(
      question.prompt!,
      key: const Key('attempt-word-prompt'),
      style: Theme.of(context).textTheme.headlineSmall,
      textAlign: TextAlign.center,
    ),
    QuestionType.multipleChoiceCloze ||
    QuestionType.typedCloze => _ClozePrompt(question: question),
    QuestionType.matching => Text(
      context.l10n.matchingInstructions,
      key: const Key('attempt-matching-prompt'),
      style: Theme.of(context).textTheme.titleLarge,
      textAlign: TextAlign.start,
    ),
  };
}

final class _ClozePrompt extends StatelessWidget {
  const _ClozePrompt({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    final segments = question.clozePromptSegments;
    final textDirection = _firstStrongDirection(
      question.prompt!,
      Directionality.of(context),
    );
    final blankLabel = context.l10n.accessibilityBlank;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: segments.before),
          const TextSpan(
            text: '\u00a0\u00a0\u00a0\u00a0',
            style: TextStyle(
              decoration: TextDecoration.underline,
              decorationThickness: 2,
            ),
          ),
          TextSpan(text: segments.after),
        ],
      ),
      key: const Key('attempt-cloze-prompt'),
      style: Theme.of(context).textTheme.headlineSmall,
      textAlign: TextAlign.center,
      textDirection: textDirection,
      softWrap: true,
      semanticsLabel: '${segments.before}$blankLabel${segments.after}',
    );
  }
}

final class _MatchingQuestionComposer extends StatelessWidget {
  const _MatchingQuestionComposer({
    required this.question,
    required this.draft,
    required this.submittedMatches,
    required this.locked,
    required this.feedback,
    required this.onTargetSelected,
    required this.onSupportSelected,
    required this.onPairRemoved,
  });

  final Question question;
  final MatchingDraft draft;
  final MatchingAnswerInput? submittedMatches;
  final bool locked;
  final AnswerFeedback? feedback;
  final ValueChanged<String>? onTargetSelected;
  final ValueChanged<String>? onSupportSelected;
  final ValueChanged<String>? onPairRemoved;

  @override
  Widget build(BuildContext context) {
    final visiblePairs = feedback != null && submittedMatches == null
        ? const <MatchingPair>[]
        : submittedMatches?.pairs ?? draft.pairs;
    final activeTargetItemId = locked ? null : draft.activeTargetItemId;
    final pairedTargetIds = visiblePairs
        .map((pair) => pair.targetItemId)
        .toSet();
    final pairedSupportIds = visiblePairs
        .map((pair) => pair.supportItemId)
        .toSet();
    final targetById = {for (final item in question.targetItems) item.id: item};
    final supportById = {
      for (final item in question.supportItems) item.id: item,
    };
    final correctSupportByTarget = {
      for (final pair in feedback?.correctMatches ?? const <MatchingPair>[])
        pair.targetItemId: pair.supportItemId,
    };
    final hasRecoverableLearnerPairs = submittedMatches != null;

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (feedback == null || hasRecoverableLearnerPairs) ...[
            _MatchingProgress(
              matchedCount: visiblePairs.length,
              totalCount: question.targetItems.length,
              announceChanges: !locked,
            ),
            const SizedBox(height: 20),
          ],
          Text(
            context.l10n.matchingTargetsHeading,
            key: const Key('matching-targets-heading'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final item in question.targetItems) ...[
            _MatchingChoiceButton(
              controlKey: Key('matching-target-${item.id}'),
              item: item,
              semanticPrefix: context.l10n.matchingTargetItemLabel(item.text),
              active: activeTargetItemId == item.id,
              paired: pairedTargetIds.contains(item.id),
              locked: locked,
              blockedStatus: null,
              onPressed:
                  !locked &&
                      !pairedTargetIds.contains(item.id) &&
                      onTargetSelected != null
                  ? () => onTargetSelected!(item.id)
                  : null,
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          Text(
            context.l10n.matchingSupportsHeading,
            key: const Key('matching-supports-heading'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final item in question.supportItems) ...[
            _MatchingChoiceButton(
              controlKey: Key('matching-support-${item.id}'),
              item: item,
              semanticPrefix: context.l10n.matchingSupportItemLabel(item.text),
              active: false,
              paired: pairedSupportIds.contains(item.id),
              locked: locked,
              blockedStatus:
                  !locked &&
                      activeTargetItemId == null &&
                      !pairedSupportIds.contains(item.id)
                  ? context.l10n.matchingChooseTargetFirst
                  : null,
              onPressed:
                  !locked &&
                      activeTargetItemId != null &&
                      !pairedSupportIds.contains(item.id) &&
                      onSupportSelected != null
                  ? () => onSupportSelected!(item.id)
                  : null,
            ),
            const SizedBox(height: 8),
          ],
          if (visiblePairs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              context.l10n.matchingPairsHeading,
              key: const Key('matching-pairs-heading'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final pair in visiblePairs) ...[
              _MatchingPairCard(
                pair: pair,
                target: targetById[pair.targetItemId]!,
                support: supportById[pair.supportItemId]!,
                correctness: feedback == null
                    ? null
                    : correctSupportByTarget[pair.targetItemId] ==
                          pair.supportItemId,
                onRemove: !locked && onPairRemoved != null
                    ? () => onPairRemoved!(pair.targetItemId)
                    : null,
              ),
              const SizedBox(height: 8),
            ],
          ],
          if (feedback != null && !hasRecoverableLearnerPairs) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              label: context.l10n.matchingFeedbackUnavailable,
              child: ExcludeSemantics(
                child: Text(
                  context.l10n.matchingFeedbackUnavailable,
                  key: const Key('matching-feedback-unavailable'),
                ),
              ),
            ),
          ],
          if (feedback?.correctMatches case final correctMatches?) ...[
            const SizedBox(height: 20),
            Text(
              context.l10n.matchingCorrectMappingHeading,
              key: const Key('matching-correct-mapping-heading'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final pair in correctMatches) ...[
              _MatchingPairCard(
                pair: pair,
                target: targetById[pair.targetItemId]!,
                support: supportById[pair.supportItemId]!,
                correctness: true,
                authoritative: true,
                onRemove: null,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

final class _MatchingProgress extends StatelessWidget {
  const _MatchingProgress({
    required this.matchedCount,
    required this.totalCount,
    required this.announceChanges,
  });

  final int matchedCount;
  final int totalCount;
  final bool announceChanges;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.matchingProgress(matchedCount, totalCount);
    return Semantics(
      container: true,
      liveRegion: announceChanges,
      label: label,
      value: '$matchedCount/$totalCount',
      child: ExcludeSemantics(
        child: Text(
          label,
          key: const Key('matching-progress'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

final class _MatchingChoiceButton extends StatelessWidget {
  const _MatchingChoiceButton({
    required this.controlKey,
    required this.item,
    required this.semanticPrefix,
    required this.active,
    required this.paired,
    required this.locked,
    required this.blockedStatus,
    required this.onPressed,
  });

  final Key controlKey;
  final MatchingItem item;
  final String semanticPrefix;
  final bool active;
  final bool paired;
  final bool locked;
  final String? blockedStatus;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final status = active
        ? context.l10n.matchingTargetSelected
        : paired
        ? context.l10n.matchingAlreadyPaired
        : blockedStatus;
    final colorScheme = Theme.of(context).colorScheme;
    final itemDirection = _firstStrongDirection(
      item.text,
      Directionality.of(context),
    );
    return Semantics(
      container: true,
      button: true,
      enabled: !locked && onPressed != null,
      selected: active || paired,
      label: '$semanticPrefix${status == null ? '' : ', $status'}',
      child: ExcludeSemantics(
        child: OutlinedButton(
          key: controlKey,
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            alignment: AlignmentDirectional.centerStart,
            minimumSize: const Size.fromHeight(56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            backgroundColor: active
                ? colorScheme.secondaryContainer
                : paired
                ? colorScheme.surfaceContainerHighest
                : null,
            side: BorderSide(
              color: active
                  ? colorScheme.secondary
                  : paired
                  ? colorScheme.outline
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.text,
                  textAlign: TextAlign.start,
                  textDirection: itemDirection,
                  softWrap: true,
                ),
              ),
              if (active || paired) ...[
                const SizedBox(width: 8),
                Icon(active ? Icons.touch_app_outlined : Icons.link),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _MatchingPairCard extends StatelessWidget {
  const _MatchingPairCard({
    required this.pair,
    required this.target,
    required this.support,
    required this.correctness,
    required this.onRemove,
    this.authoritative = false,
  });

  final MatchingPair pair;
  final MatchingItem target;
  final MatchingItem support;
  final bool? correctness;
  final VoidCallback? onRemove;
  final bool authoritative;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = switch (correctness) {
      true => context.l10n.matchingCorrectPair,
      false => context.l10n.matchingIncorrectPair,
      null => context.l10n.matchingTentativePair,
    };
    final background = switch (correctness) {
      true => Colors.green.withValues(alpha: 0.18),
      false => colorScheme.errorContainer,
      null => colorScheme.surfaceContainerHighest,
    };
    final border = switch (correctness) {
      true => Colors.green,
      false => colorScheme.error,
      null => colorScheme.outlineVariant,
    };
    final targetDirection = _firstStrongDirection(
      target.text,
      Directionality.of(context),
    );
    final supportDirection = _firstStrongDirection(
      support.text,
      Directionality.of(context),
    );
    // gen-l10n emits this message's parameters alphabetically: (support, target).
    final pairLabel = context.l10n.matchingPairLabel(support.text, target.text);
    return DecoratedBox(
      key: authoritative
          ? Key('matching-correct-pair-${pair.targetItemId}')
          : Key('matching-pair-${pair.targetItemId}'),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              key: authoritative
                  ? Key('matching-correct-pair-semantics-${pair.targetItemId}')
                  : Key('matching-pair-semantics-${pair.targetItemId}'),
              container: true,
              liveRegion: correctness != null,
              label: '$pairLabel, $status',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      target.text,
                      key: authoritative
                          ? Key('matching-correct-target-${pair.targetItemId}')
                          : null,
                      textAlign: TextAlign.start,
                      textDirection: targetDirection,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.arrow_downward, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      support.text,
                      key: authoritative
                          ? Key(
                              'matching-correct-support-${pair.supportItemId}',
                            )
                          : null,
                      textAlign: TextAlign.start,
                      textDirection: supportDirection,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(status, textAlign: TextAlign.start),
                  ],
                ),
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Semantics(
                  key: Key('matching-remove-${pair.targetItemId}'),
                  container: true,
                  button: true,
                  enabled: true,
                  label: context.l10n.matchingRemovePair(target.text),
                  onTap: onRemove,
                  child: ExcludeSemantics(
                    child: IconButton(
                      onPressed: onRemove,
                      tooltip: context.l10n.matchingRemovePair(target.text),
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      icon: const Icon(Icons.link_off),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _TypedAnswerComposer extends StatefulWidget {
  const _TypedAnswerComposer({
    required this.locked,
    required this.needsReentry,
    required this.promptDirection,
    required this.onSubmitted,
  });

  final bool locked;
  final bool needsReentry;
  final TextDirection promptDirection;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_TypedAnswerComposer> createState() => _TypedAnswerComposerState();
}

final class _TypedAnswerComposerState extends State<_TypedAnswerComposer> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(_TypedAnswerComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locked && !oldWidget.locked) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..clear()
      ..dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  bool get _canSubmit {
    final value = _controller.text;
    return !widget.locked &&
        widget.onSubmitted != null &&
        TypedAnswerInput.isValid(value);
  }

  void _submit() {
    if (!_canSubmit) {
      return;
    }
    final answer = _controller.text;
    widget.onSubmitted!(answer);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final inputDirection = _firstStrongDirection(
      _controller.text,
      widget.promptDirection,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('attempt-typed-answer'),
          controller: _controller,
          enabled: !widget.locked,
          textDirection: inputDirection,
          textInputAction: TextInputAction.done,
          keyboardType: TextInputType.text,
          minLines: 1,
          maxLines: 2,
          maxLength: TypedAnswerInput.maxLength,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          decoration: InputDecoration(
            labelText: context.l10n.typedAnswerLabel,
            helperText: widget.needsReentry
                ? context.l10n.typedAnswerReentry
                : null,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: _canSubmit ? (_) => _submit() : null,
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('attempt-primary-button'),
          onPressed: _canSubmit ? _submit : null,
          child: widget.locked
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.l10n.submitAnswer),
        ),
      ],
    );
  }
}

final class _AuthoritativeTypedAnswer extends StatelessWidget {
  const _AuthoritativeTypedAnswer({required this.answer});

  final String answer;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.correctAnswerLabel;
    final textDirection = _firstStrongDirection(
      answer,
      Directionality.of(context),
    );
    return Semantics(
      liveRegion: true,
      label: '$label: $answer',
      textDirection: textDirection,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              answer,
              key: const Key('attempt-correct-answer-text'),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
              textDirection: textDirection,
            ),
          ],
        ),
      ),
    );
  }
}

TextDirection _firstStrongDirection(String text, TextDirection fallback) =>
    Bidi.startsWithRtl(text)
    ? TextDirection.rtl
    : Bidi.startsWithLtr(text)
    ? TextDirection.ltr
    : fallback;

final class _AnswerOptionButton extends StatelessWidget {
  const _AnswerOptionButton({
    required this.option,
    required this.selected,
    required this.locked,
    required this.feedback,
    required this.onPressed,
  });

  final AnswerOption option;
  final bool selected;
  final bool locked;
  final AnswerFeedback? feedback;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isCorrect = feedback?.correctOptionId == option.id;
    final isIncorrectSelection = feedback != null && selected && !isCorrect;
    final status = isCorrect
        ? context.l10n.accessibilityCorrectAnswer
        : isIncorrectSelection
        ? context.l10n.accessibilityIncorrectAnswer
        : selected
        ? context.l10n.accessibilitySelectedAnswer
        : null;
    final colorScheme = Theme.of(context).colorScheme;
    final background = isCorrect
        ? Colors.green.withValues(alpha: 0.18)
        : isIncorrectSelection
        ? colorScheme.errorContainer
        : selected
        ? colorScheme.secondaryContainer
        : null;

    return Semantics(
      button: true,
      selected: selected,
      enabled: !locked,
      label: '${option.text}${status == null ? '' : ', $status'}',
      child: ExcludeSemantics(
        child: OutlinedButton(
          key: Key('answer-${option.id}'),
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            alignment: AlignmentDirectional.centerStart,
            minimumSize: const Size.fromHeight(56),
            backgroundColor: background,
            side: BorderSide(
              color: isCorrect
                  ? Colors.green
                  : isIncorrectSelection
                  ? colorScheme.error
                  : selected
                  ? colorScheme.secondary
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Text(option.text),
        ),
      ),
    );
  }
}

final class AttemptResultView extends StatelessWidget {
  const AttemptResultView({
    required this.passed,
    required this.result,
    required this.onDone,
    super.key,
  });

  final bool passed;
  final AttemptResult result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final percentage = (result.correctRatio * 100).round();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                passed ? Icons.emoji_events : Icons.school_outlined,
                size: 72,
                color: passed
                    ? Colors.amber.shade700
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                passed ? context.l10n.passed : context.l10n.failed,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.resultSummary(
                  result.correctCount,
                  result.questionCount,
                  percentage,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('attempt-result-done'),
                onPressed: onDone,
                child: Text(context.l10n.backToCourse),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.title,
    this.body,
    this.showProgress = false,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String? body;
  final bool showProgress;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Semantics(
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 60),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                if (body != null) ...[
                  const SizedBox(height: 12),
                  Text(body!, textAlign: TextAlign.center),
                ],
                if (showProgress) ...[
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                ],
                if (primaryLabel != null) ...[
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: onPrimary,
                    child: Text(primaryLabel!),
                  ),
                ],
                if (secondaryLabel != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
