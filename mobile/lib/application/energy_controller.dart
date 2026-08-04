import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/energy/energy.dart';
import 'providers.dart';

final energyControllerProvider =
    AsyncNotifierProvider<EnergyController, Energy>(EnergyController.new);

final class EnergyController extends AsyncNotifier<Energy> {
  @override
  Future<Energy> build() => ref.watch(energyRepositoryProvider).getEnergy();

  Future<void> refresh() async {
    state = const AsyncLoading<Energy>();
    state = await AsyncValue.guard(
      ref.read(energyRepositoryProvider).getEnergy,
    );
  }
}
