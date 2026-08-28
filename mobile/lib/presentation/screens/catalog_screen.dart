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
    final starterCourseInstallerEnabled = ref
        .watch(appConfigProvider)
        .starterCourseInstallerEnabled;
    final hasCatalogItems = switch (catalog) {
      AsyncData(:final value) => value.items.isNotEmpty,
      _ => false,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.catalog),
        actions: [
          IconButton(
            tooltip: 'Kurs daveti kullan',
            onPressed: () => unawaited(_openInvitation(context)),
            icon: const Icon(Icons.mark_email_unread_outlined),
          ),
          if (starterCourseInstallerEnabled && hasCatalogItems)
            IconButton(
              key: const Key('catalog-install-starter'),
              tooltip: context.l10n.installLocalStarterCourse,
              onPressed: () => unawaited(
                ref
                    .read(catalogControllerProvider.notifier)
                    .installLocalStarterCourse(),
              ),
              icon: const Icon(Icons.add_circle_outline),
            ),
          IconButton(
            key: const Key('catalog-sign-out'),
            tooltip: context.l10n.signOut,
            onPressed: () =>
                unawaited(ref.read(authControllerProvider.notifier).signOut()),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          const _CatalogFilters(),
          Expanded(
            child: catalog.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => AsyncErrorView(
                error: error,
                onRetry: () => unawaited(
                  ref.read(catalogControllerProvider.notifier).refresh(),
                ),
              ),
              data: (page) {
                if (page.items.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: ref
                        .read(catalogControllerProvider.notifier)
                        .refresh,
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
                                  if (starterCourseInstallerEnabled) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      context.l10n.localStarterCourseBody,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    FilledButton.icon(
                                      key: const Key('catalog-install-starter'),
                                      onPressed: () => unawaited(
                                        ref
                                            .read(
                                              catalogControllerProvider
                                                  .notifier,
                                            )
                                            .installLocalStarterCourse(),
                                      ),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
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
                  onRefresh: ref
                      .read(catalogControllerProvider.notifier)
                      .refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: page.items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final course = page.items[index];
                      return _CourseCard(
                        course: course,
                        onTap: () =>
                            context.push('/catalog/course/${course.id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInvitation(BuildContext context) async {
    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kurs daveti'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Davet kodu'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Devam et'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (token != null && token.isNotEmpty && context.mounted) {
      unawaited(context.push('/course-invitation/$token'));
    }
  }
}

final class _CatalogFilters extends ConsumerStatefulWidget {
  const _CatalogFilters();

  @override
  ConsumerState<_CatalogFilters> createState() => _CatalogFiltersState();
}

final class _CatalogFiltersState extends ConsumerState<_CatalogFilters> {
  final _query = TextEditingController();
  CourseAccessType? _accessType;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Row(
      children: [
        Expanded(
          child: SearchBar(
            controller: _query,
            hintText: 'Kurs ara',
            leading: const Icon(Icons.search),
            trailing: [
              if (_query.text.isNotEmpty)
                IconButton(
                  onPressed: () {
                    _query.clear();
                    _apply();
                  },
                  icon: const Icon(Icons.clear),
                ),
            ],
            onSubmitted: (_) => _apply(),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<CourseAccessType?>(
          tooltip: 'Erişim filtresi',
          initialValue: _accessType,
          onSelected: (value) {
            setState(() => _accessType = value);
            _apply();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: null, child: Text('Tüm kurslar')),
            PopupMenuItem(
              value: CourseAccessType.free,
              child: Text('Ücretsiz'),
            ),
            PopupMenuItem(value: CourseAccessType.paid, child: Text('Ücretli')),
          ],
          icon: const Icon(Icons.filter_list),
        ),
      ],
    ),
  );

  void _apply() => unawaited(
    ref
        .read(catalogControllerProvider.notifier)
        .search(_query.text, _accessType),
  );
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
      key: Key('catalog-course-${course.id}'),
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
