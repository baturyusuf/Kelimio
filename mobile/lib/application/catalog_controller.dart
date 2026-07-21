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
}
