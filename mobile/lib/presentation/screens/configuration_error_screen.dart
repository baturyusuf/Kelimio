import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../l10n/generated/app_localizations.dart';

final class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({required this.issues, super.key});

  final List<ConfigurationIssue> issues;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF245B85),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.settings_outlined, size: 56),
                      const SizedBox(height: 20),
                      Text(
                        AppLocalizations.of(context).configurationErrorTitle,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(AppLocalizations.of(context).configurationErrorBody),
                      const SizedBox(height: 16),
                      for (final issue in issues)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SelectableText(
                            '${issue.defineName}${issue.requiresHttps ? ' (HTTPS)' : ''}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
