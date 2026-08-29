import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/teacher_course_controller.dart';
import '../../domain/teacher/teacher_course.dart';
import '../widgets/async_error_view.dart';
import '../widgets/localization.dart';

final class TeacherCourseAnalyticsScreen extends ConsumerWidget {
  const TeacherCourseAnalyticsScreen({required this.courseId, super.key});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(teacherCourseAnalyticsProvider(courseId));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.teacherAnalyticsTitle)),
      body: analytics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => AsyncErrorView(
          error: error,
          onRetry: () => unawaited(
            ref
                .read(teacherCourseAnalyticsProvider(courseId).notifier)
                .refresh(),
          ),
        ),
        data: (value) => value.updating
            ? _UpdatingAnalytics(
                onRefresh: () => unawaited(
                  ref
                      .read(teacherCourseAnalyticsProvider(courseId).notifier)
                      .refresh(),
                ),
              )
            : _ReadyAnalytics(analytics: value),
      ),
    );
  }
}

final class _UpdatingAnalytics extends StatelessWidget {
  const _UpdatingAnalytics({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('teacher-analytics-updating'),
    padding: const EdgeInsets.all(24),
    children: [
      const Icon(Icons.sync_outlined, size: 56),
      const SizedBox(height: 16),
      Text(
        context.l10n.teacherAnalyticsUpdatingTitle,
        style: Theme.of(context).textTheme.headlineSmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Text(
        context.l10n.teacherAnalyticsUpdatingBody,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      Center(
        child: OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: Text(context.l10n.refresh),
        ),
      ),
    ],
  );
}

final class _ReadyAnalytics extends StatelessWidget {
  const _ReadyAnalytics({required this.analytics});

  final TeacherCourseAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final metrics = analytics.metrics!;
    final performance = metrics.performance;
    return ListView(
      key: const Key('teacher-analytics-ready'),
      padding: const EdgeInsets.all(16),
      children: [
        _MetricCard(
          icon: Icons.people_outline,
          text: context.l10n.teacherAnalyticsLearners(
            metrics.learnersWithRecordedActivity,
          ),
        ),
        const SizedBox(height: 12),
        if (performance == null)
          Card(
            key: const Key('teacher-analytics-small-cohort'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.teacherAnalyticsPrivacyTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(context.l10n.teacherAnalyticsPrivacyBody),
                ],
              ),
            ),
          )
        else ...[
          _MetricCard(
            icon: Icons.quiz_outlined,
            text: context.l10n.teacherAnalyticsAnswers(
              performance.answeredQuestions,
              performance.correctAnswers,
            ),
          ),
          const SizedBox(height: 12),
          _MetricCard(
            icon: Icons.fact_check_outlined,
            text: context.l10n.teacherAnalyticsAttempts(
              performance.completedAttempts,
              performance.passedAttempts,
            ),
          ),
          const SizedBox(height: 12),
          _MetricCard(
            icon: Icons.percent,
            text: context.l10n.teacherAnalyticsCorrectRate(
              _percentage(performance),
            ),
          ),
        ],
        if (analytics.updatedAt case final updatedAt?) ...[
          const SizedBox(height: 16),
          Text(
            context.l10n.teacherAnalyticsLastUpdated(
              _localizedDateTime(context, updatedAt),
            ),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  String _percentage(TeacherCoursePerformance performance) {
    if (performance.answeredQuestions == 0) return '0%';
    final percent =
        (performance.correctAnswers * 100 / performance.answeredQuestions)
            .round();
    return '$percent%';
  }

  String _localizedDateTime(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final material = MaterialLocalizations.of(context);
    return '${material.formatShortDate(local)} ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }
}

final class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
        ],
      ),
    ),
  );
}
