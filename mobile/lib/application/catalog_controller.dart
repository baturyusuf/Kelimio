import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/catalog/catalog.dart';
import 'providers.dart';

final catalogControllerProvider =
    AsyncNotifierProvider<CatalogController, CatalogPage>(
      CatalogController.new,
    );

final class CatalogController extends AsyncNotifier<CatalogPage> {
  @override
  Future<CatalogPage> build() {
    return ref.watch(catalogRepositoryProvider).listCourses();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<CatalogPage>();
    state = await AsyncValue.guard(
      ref.read(catalogRepositoryProvider).listCourses,
    );
  }

  Future<void> installLocalStarterCourse() async {
    if (!ref.read(appConfigProvider).localDevelopmentToolsEnabled) {
      throw StateError('Local development tools are disabled');
    }
    state = const AsyncLoading<CatalogPage>();
    state = await AsyncValue.guard(() async {
      await ref
          .read(developmentRepositoryProvider)
          .installStarterCourse(
            commandId: ref.read(identifierFactoryProvider).create(),
          );
      return ref.read(catalogRepositoryProvider).listCourses();
    });
  }
}
