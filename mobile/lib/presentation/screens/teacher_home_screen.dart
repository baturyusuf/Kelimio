import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/providers.dart';
import '../../application/teacher_course_controller.dart';
import '../../domain/teacher/teacher_course.dart';
import '../widgets/async_error_view.dart';
import 'teacher_import_screen.dart';

final class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(teacherCoursesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kurslarım')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('teacher-new-course'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const TeacherImportScreen()),
        ),
        icon: const Icon(Icons.upload_file),
        label: const Text('Excel ile yeni kurs'),
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
                  children: const [
                    Icon(Icons.school_outlined, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Henüz bir kursunuz yok. İlk kursu Excel dosyanızdan oluşturabilirsiniz.',
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
                          '${course.targetLanguage.toUpperCase()} · sürüm ${course.activeReleaseRevision}'
                          '${course.hasOpenDraft ? ' · yayımlanmamış taslak var' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (course.visibility ==
                                TeacherCourseVisibility.private)
                              IconButton(
                                tooltip: 'Davet oluştur',
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
          title: const Text('Kurs daveti hazır'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bu tek kullanımlık kodu öğrencinizle güvenli biçimde paylaşın:',
              ),
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
              child: const Text('Kopyala'),
            ),
          ],
        ),
      );
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Davet oluşturulamadı: $error')));
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
          title: Text('Taslak sürüm ${impact.releaseRevision}'),
          content: Text(
            '${impact.changedQuestionCount} değişen, ${impact.addedQuestionCount} eklenen, ${impact.removedQuestionCount} kaldırılan soru; ${impact.affectedEnrollmentCount} öğrenci etkileniyor.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'close'),
              child: const Text('Kapat'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'abandon'),
              child: const Text('Taslağı terk et'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'publish'),
              child: const Text('Yayımla'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Taslak güvenle terk edildi.')),
          );
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
          const SnackBar(content: Text('Kursun yeni sürümü yayımlandı.')),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Taslak yayımlanamadı: $error')));
      }
    }
  }
}
