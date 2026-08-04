import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/profile/profile.dart';
import 'auth_controller.dart';
import 'providers.dart';

final profileControllerProvider =
    AsyncNotifierProvider<ProfileController, UserProfile?>(
      ProfileController.new,
    );

final class ProfileController extends AsyncNotifier<UserProfile?> {
  String? _pendingCommandId;
  ProfileSetupInput? _pendingInput;

  @override
  Future<UserProfile?> build() async {
    final session = await ref.watch(authControllerProvider.future);
    if (session == null) {
      _pendingCommandId = null;
      _pendingInput = null;
      return null;
    }
    return ref.watch(profileRepositoryProvider).getMe();
  }

  Future<void> retryLoad() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> completeSetup(ProfileSetupInput input) async {
    if (_pendingInput != input || _pendingCommandId == null) {
      _pendingInput = input;
      _pendingCommandId = ref.read(identifierFactoryProvider).create();
    }
    final commandId = _pendingCommandId!;
    state = const AsyncLoading<UserProfile?>();
    state = await AsyncValue.guard(() async {
      final profile = await ref
          .read(profileRepositoryProvider)
          .completeSetup(input: input, commandId: commandId);
      _pendingInput = null;
      _pendingCommandId = null;
      return profile;
    });
  }
}
