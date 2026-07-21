import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth/auth.dart';
import 'attempt_controller.dart';
import 'catalog_controller.dart';
import 'energy_controller.dart';
import 'providers.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

final class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final session = await ref.watch(authRepositoryProvider).restore();
    if (session == null) {
      await _purgePrivateState();
    }
    return session;
  }

  Future<void> signIn() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _purgePrivateState();
      return ref.read(authRepositoryProvider).signIn();
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    Object? failure;
    StackTrace? failureStackTrace;
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on Object catch (error, stackTrace) {
      failure = error;
      failureStackTrace = stackTrace;
    }
    try {
      await _purgePrivateState();
    } on Object catch (error, stackTrace) {
      failure ??= error;
      failureStackTrace ??= stackTrace;
    }
    if (failure == null) {
      state = const AsyncData(null);
    } else {
      state = AsyncError(failure, failureStackTrace ?? StackTrace.current);
    }
  }

  Future<void> _purgePrivateState() async {
    try {
      final store = await ref.read(recoveryStoreProvider.future);
      await store.clear();
    } finally {
      ref.invalidate(attemptControllerProvider);
      ref.invalidate(catalogControllerProvider);
      ref.invalidate(energyControllerProvider);
      ref.invalidate(courseDetailProvider);
      ref.invalidate(dioProvider);
      ref.invalidate(recoveryStoreProvider);
    }
  }
}
