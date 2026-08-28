import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../application/teacher_course_controller.dart';
import '../../domain/teacher/teacher_course.dart';
import '../widgets/async_error_view.dart';
import '../widgets/localization.dart';
import 'teacher_import_screen.dart';

final class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(teacherCoursesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.myCourses)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('teacher-new-course'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const TeacherImportScreen()),
        ),
        icon: const Icon(Icons.upload_file),
        label: Text(context.l10n.newCourseFromExcel),
      ),
      body: courses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => AsyncErrorView(
          error: error,
          onRetry: () =>
              unawaited(ref.read(teacherCoursesProvider.notifier).refresh()),
        ),
        data: (page) => RefreshIndicator(
          onRefresh: ref.read(teacherCoursesProvider.notifier).refresh,
          child: page.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(32),
                  children: [
                    const Icon(Icons.school_outlined, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.noTeacherCourses,
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: page.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final course = page.items[index];
                    return Card(
                      child: ListTile(
                        key: Key('teacher-course-${course.id}'),
                        title: Text(course.name),
                        subtitle: Text(
                          '${context.l10n.courseRevision(course.targetLanguage.toUpperCase(), course.activeReleaseRevision)}'
                          '${course.hasOpenDraft ? ' · ${context.l10n.unpublishedDraftAvailable}' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (course.visibility ==
                                TeacherCourseVisibility.private)
                              IconButton(
                                tooltip: context.l10n.createInvitation,
                                onPressed: () =>
                                    unawaited(_invite(context, ref, course.id)),
                                icon: const Icon(
                                  Icons.person_add_alt_1_outlined,
                                ),
                              ),
                            const Icon(Icons.edit_outlined),
                          ],
                        ),
                        onTap: course.hasOpenDraft
                            ? () =>
                                  unawaited(_publishDraft(context, ref, course))
                            : () =>
                                  context.push('/teacher/course/${course.id}'),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _invite(
    BuildContext context,
    WidgetRef ref,
    String courseId,
  ) async {
    try {
      final token = await ref
          .read(teacherCourseRepositoryProvider)
          .createInvitation(courseId);
      if (!context.mounted) return;
      final link = token;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.courseInvitationReady),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.courseInvitationShare),
              const SizedBox(height: 8),
              SelectableText(link),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text(context.l10n.copy),
            ),
          ],
        ),
      );
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.invitationCreateFailed('$error')),
          ),
        );
      }
    }
  }

  Future<void> _publishDraft(
    BuildContext context,
    WidgetRef ref,
    TeacherCourseSummary course,
  ) async {
    final releaseId = course.openDraftReleaseId;
    if (releaseId == null) {
      return;
    }
    try {
      final impact = await ref
          .read(courseAuthoringRepositoryProvider)
          .getReleaseImpact(courseId: course.id, releaseId: releaseId);
      if (!context.mounted) {
        return;
      }
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.draftReleaseTitle(impact.releaseRevision)),
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
              onPressed: () => Navigator.pop(context, 'close'),
              child: Text(context.l10n.close),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'abandon'),
              child: Text(context.l10n.abandonDraft),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'publish'),
              child: Text(context.l10n.publishCourse),
            ),
          ],
        ),
      );
      if (action == 'abandon') {
        await ref
            .read(courseAuthoringRepositoryProvider)
            .abandonRelease(
              courseId: course.id,
              releaseId: releaseId,
              commandId: ref.read(identifierFactoryProvider).create(),
            );
        ref.invalidate(teacherCoursesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.draftAbandoned)));
        }
        return;
      }
      if (action != 'publish') {
        return;
      }
      await ref
          .read(courseAuthoringRepositoryProvider)
          .activateRelease(
            impact: impact,
            commandId: ref.read(identifierFactoryProvider).create(),
          );
      ref.invalidate(teacherCoursesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.courseRevisionPublished)),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.draftPublishFailed('$error'))),
        );
      }
    }
  }
}
