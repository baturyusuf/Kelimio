import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/auth_controller.dart';
import '../../application/catalog_controller.dart';
import '../../application/providers.dart';
import '../../domain/catalog/catalog.dart';
import '../widgets/async_error_view.dart';
import '../widgets/localization.dart';

final class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.catalog),
        actions: [
          IconButton(
            tooltip: context.l10n.signOut,
            onPressed: () =>
                unawaited(ref.read(authControllerProvider.notifier).signOut()),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => AsyncErrorView(
          error: error,
          onRetry: () =>
              unawaited(ref.read(catalogControllerProvider.notifier).refresh()),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            final localToolsEnabled = ref
                .watch(appConfigProvider)
                .localDevelopmentToolsEnabled;
            return RefreshIndicator(
              onRefresh: ref.read(catalogControllerProvider.notifier).refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.6,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n.emptyCatalog,
                              textAlign: TextAlign.center,
                            ),
                            if (localToolsEnabled) ...[
                              const SizedBox(height: 16),
                              Text(
                                context.l10n.localStarterCourseBody,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () => unawaited(
                                  ref
                                      .read(catalogControllerProvider.notifier)
                                      .installLocalStarterCourse(),
                                ),
                                icon: const Icon(Icons.add_circle_outline),
                                label: Text(
                                  context.l10n.installLocalStarterCourse,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: ref.read(catalogControllerProvider.notifier).refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: page.items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final course = page.items[index];
                return _CourseCard(
                  course: course,
                  onTap: () => context.push('/catalog/course/${course.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

final class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.onTap});

  final CourseSummary course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final description = course.description;
    final access = course.accessType == CourseAccessType.free
        ? context.l10n.free
        : context.l10n.paid;
    final enrollment = course.enrolled ? context.l10n.enrolled : '';
    return Semantics(
      button: true,
      label:
          '${course.name}, $access${enrollment.isEmpty ? '' : ', $enrollment'}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(child: Text(course.targetLanguage.toUpperCase())),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Chip(label: Text(access)),
                          if (course.enrolled)
                            Chip(
                              avatar: const Icon(Icons.check, size: 18),
                              label: Text(context.l10n.enrolled),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
