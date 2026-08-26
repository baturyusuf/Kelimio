import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/teacher/teacher_access.dart';
import 'providers.dart';

final teacherAccessControllerProvider =
    AsyncNotifierProvider<TeacherAccessController, TeacherAccess>(
      TeacherAccessController.new,
    );

final class TeacherAccessController extends AsyncNotifier<TeacherAccess> {
  @override
  Future<TeacherAccess> build() {
    return ref.watch(teacherAccessRepositoryProvider).getAccess();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<TeacherAccess>();
    state = await AsyncValue.guard(
      ref.read(teacherAccessRepositoryProvider).getAccess,
    );
  }

  Future<void> acceptRequiredTerms() async {
    final access = state.requireValue;
    state = const AsyncLoading<TeacherAccess>();
    state = await AsyncValue.guard(
      () => ref
          .read(teacherAccessRepositoryProvider)
          .acceptTerms(access.requiredTermsVersion),
    );
  }
}
