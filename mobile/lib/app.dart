import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/profile_controller.dart';
import 'l10n/generated/app_localizations.dart';
import 'presentation/router/app_router.dart';

final class KelimioApp extends ConsumerWidget {
  const KelimioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final profile = ref.watch(profileControllerProvider);
    final locale =
        profile.hasValue &&
            profile.requireValue != null &&
            profile.requireValue!.setupComplete
        ? Locale(profile.requireValue!.appLocale.split('-').first)
        : null;
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF245B85),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
        ),
      ),
    );
  }
}
