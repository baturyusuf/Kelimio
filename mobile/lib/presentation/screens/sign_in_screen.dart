import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_controller.dart';
import '../../domain/failures.dart';
import '../widgets/localization.dart';

final class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final error = auth.hasError ? auth.error : null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.school_rounded,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.signInTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(context.l10n.signInBody, textAlign: TextAlign.center),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      error is AuthenticationCancelledFailure
                          ? context.l10n.authenticationCancelled
                          : context.l10n.genericError,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('sign-in-submit'),
                      onPressed: auth.isLoading
                          ? null
                          : ref.read(authControllerProvider.notifier).signIn,
                      icon: auth.isLoading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(context.l10n.signIn),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
