import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/energy_controller.dart';
import '../../domain/energy/energy.dart';
import '../widgets/async_error_view.dart';
import '../widgets/localization.dart';

final class EnergyScreen extends ConsumerWidget {
  const EnergyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final energy = ref.watch(energyControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.energy),
        actions: [
          IconButton(
            tooltip: context.l10n.refresh,
            onPressed: () => unawaited(
              ref.read(energyControllerProvider.notifier).refresh(),
            ),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: energy.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => AsyncErrorView(
          error: error,
          onRetry: () =>
              unawaited(ref.read(energyControllerProvider.notifier).refresh()),
        ),
        data: (value) => _EnergyBody(energy: value),
      ),
    );
  }
}

final class _EnergyBody extends StatelessWidget {
  const _EnergyBody({required this.energy});

  final Energy energy;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateFormat = DateFormat.yMMMd(locale).add_Hm();
    final title = energy.unlimited
        ? context.l10n.energyUnlimited
        : context.l10n.energyBalance(energy.balance, energy.maximum);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Semantics(
            liveRegion: true,
            label: title,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (energy.nextRegenerationAt != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.nextRegeneration(
                          dateFormat.format(energy.nextRegenerationAt!),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.energyCurrentAsOf(
                        dateFormat.format(energy.asOf),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
