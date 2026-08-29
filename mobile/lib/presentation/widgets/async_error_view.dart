import 'package:flutter/material.dart';

import '../../domain/failures.dart';
import 'localization.dart';

String userFacingFailureMessage(BuildContext context, Object error) =>
    switch (error) {
      NetworkFailure() || TimeoutFailure() => context.l10n.networkError,
      OperatingModeFailure(mode: ServiceOperatingMode.conserve) =>
        context.l10n.costConservationMessage,
      OperatingModeFailure(mode: ServiceOperatingMode.readOnly) =>
        context.l10n.costReadOnlyMessage,
      OperatingModeFailure(mode: ServiceOperatingMode.suspended) =>
        context.l10n.costSuspendedMessage,
      ConfigurationFailure() => context.l10n.configurationErrorBody,
      AuthenticationRequiredFailure() =>
        context.l10n.authenticationRequiredError,
      AuthenticationCancelledFailure() => context.l10n.authenticationCancelled,
      ForbiddenFailure() => context.l10n.permissionError,
      ValidationFailure() => context.l10n.validationError,
      ConflictFailure() => context.l10n.conflictError,
      ContentChangedFailure() => context.l10n.contentChanged,
      EnergyDepletedFailure() => context.l10n.energyDepleted,
      _ => context.l10n.genericError,
    };

final class AsyncErrorView extends StatelessWidget {
  const AsyncErrorView({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = userFacingFailureMessage(context, error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
