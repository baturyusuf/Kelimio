import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/catalog_controller.dart';
import '../../application/profile_controller.dart';
import '../../application/providers.dart';
import '../../domain/catalog/catalog.dart';
import '../widgets/async_error_view.dart';
import '../widgets/localization.dart';

final class CourseDetailScreen extends ConsumerStatefulWidget {
  const CourseDetailScreen({required this.courseId, super.key});

  final String courseId;

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

final class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  String? _supportLanguage;
  String? _enrollmentCommandId;
  bool _enrolling = false;
  Object? _enrollmentError;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(courseDetailProvider(widget.courseId));
    final progress = ref.watch(courseProgressProvider(widget.courseId));
    final profile = ref.watch(profileControllerProvider);
    final preferredSupportLanguage = profile.hasValue
        ? profile.requireValue?.preferredSupportLanguage
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.courseDetails)),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => AsyncErrorView(
          error: error,
          onRetry: () => ref.invalidate(courseDetailProvider(widget.courseId)),
        ),
        data: (course) =>
            _buildCourse(course, progress, preferredSupportLanguage),
      ),
    );
  }

  Widget _buildCourse(
    CourseDetail course,
    AsyncValue<CourseProgress> progress,
    String? preferredSupportLanguage,
  ) {
    final summary = course.summary;
    final description = summary.description;
    final languages = summary.supportLanguages;
    final selected =
        (_supportLanguage != null && languages.contains(_supportLanguage)
            ? _supportLanguage
            : null) ??
        (preferredSupportLanguage != null &&
                languages.contains(preferredSupportLanguage)
            ? preferredSupportLanguage
            : (languages.isEmpty ? null : languages.first));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(summary.name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          course.ownerDisplayName,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (description != null) ...[
          const SizedBox(height: 16),
          Text(description),
        ],
        const SizedBox(height: 20),
        if (!summary.enrolled) ...[
          if (languages.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: selected,
              decoration: InputDecoration(
                labelText: context.l10n.supportLanguage,
              ),
              items: [
                for (final language in languages)
                  DropdownMenuItem(
                    value: language,
                    child: Text(language.toUpperCase()),
                  ),
              ],
              onChanged: _enrolling
                  ? null
                  : (value) => setState(() => _supportLanguage = value),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  _enrolling ||
                      selected == null ||
                      summary.accessType == CourseAccessType.paid
                  ? null
                  : () => unawaited(_enroll(selected)),
              icon: _enrolling
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_circle_outline),
              label: Text(context.l10n.enroll),
            ),
          ),
          if (summary.accessType == CourseAccessType.paid) ...[
            const SizedBox(height: 8),
            Text(context.l10n.paidEnrollmentUnavailable),
          ],
          if (_enrollmentError != null) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.genericError,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
        ] else ...[
          Chip(
            avatar: const Icon(Icons.check, size: 18),
            label: Text(context.l10n.enrolled),
          ),
          const SizedBox(height: 20),
        ],
        if (summary.enrolled) ...[
          Text(
            context.l10n.yourProgress,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          progress.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => AsyncErrorView(
              error: error,
              onRetry: () =>
                  ref.invalidate(courseProgressProvider(widget.courseId)),
            ),
            data: (value) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.progressAnswers(
                        value.correctAnswers,
                        value.answeredQuestions,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.progressAttempts(
                        value.passedAttempts,
                        value.completedAttempts,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.progressScores(
                        value.activeScore,
                        value.lifetimeScore,
                      ),
                    ),
                    if (value.updating) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(context.l10n.progressUpdating)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Text(context.l10n.tests, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        for (final test in course.tests)
          Card(
            child: ListTile(
              title: Text(test.name),
              subtitle: Text(context.l10n.questionCount(test.questionCount)),
              trailing: FilledButton(
                onPressed: summary.enrolled
                    ? () => context.push('/attempt/${test.id}')
                    : null,
                child: Text(context.l10n.startTest),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _enroll(String supportLanguage) async {
    if (_enrolling) {
      return;
    }
    setState(() {
      _enrolling = true;
      _enrollmentError = null;
      _enrollmentCommandId ??= ref.read(identifierFactoryProvider).create();
    });
    try {
      await ref
          .read(catalogRepositoryProvider)
          .enroll(
            courseId: widget.courseId,
            supportLanguage: supportLanguage,
            commandId: _enrollmentCommandId!,
          );
      _enrollmentCommandId = null;
      ref.invalidate(courseDetailProvider(widget.courseId));
      ref.invalidate(catalogControllerProvider);
    } on Object catch (error) {
      if (mounted) {
        setState(() => _enrollmentError = error);
      }
    } finally {
      if (mounted) {
        setState(() => _enrolling = false);
      }
    }
  }
}
