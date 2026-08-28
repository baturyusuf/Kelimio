import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/catalog/catalog.dart';
import 'providers.dart';

final catalogControllerProvider =
    AsyncNotifierProvider<CatalogController, CatalogPage>(
      CatalogController.new,
    );

final class CatalogController extends AsyncNotifier<CatalogPage> {
  String? _query;
  CourseAccessType? _accessType;

  @override
  Future<CatalogPage> build() {
    return ref
        .watch(catalogRepositoryProvider)
        .listCourses(query: _query, accessType: _accessType);
  }

  Future<void> search(String query, CourseAccessType? accessType) async {
    _query = query.trim().isEmpty ? null : query.trim();
    _accessType = accessType;
    await refresh();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<CatalogPage>();
    state = await AsyncValue.guard(
      () => ref
          .read(catalogRepositoryProvider)
          .listCourses(query: _query, accessType: _accessType),
    );
  }

  Future<void> installLocalStarterCourse() async {
    if (!ref.read(appConfigProvider).starterCourseInstallerEnabled) {
      throw StateError('Starter-course installation is disabled');
    }
    state = const AsyncLoading<CatalogPage>();
    state = await AsyncValue.guard(() async {
      await ref
          .read(developmentRepositoryProvider)
          .installStarterCourse(
            commandId: ref.read(identifierFactoryProvider).create(),
          );
      return ref
          .read(catalogRepositoryProvider)
          .listCourses(query: _query, accessType: _accessType);
    });
  }
}
