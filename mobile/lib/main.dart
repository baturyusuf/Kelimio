import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'application/providers.dart';
import 'core/config/app_config.dart';
import 'presentation/screens/configuration_error_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final result = AppConfig.fromEnvironment();
  switch (result) {
    case final AppConfigValid valid:
      runApp(
        ProviderScope(
          overrides: [appConfigProvider.overrideWithValue(valid.config)],
          child: const KelimioApp(),
        ),
      );
    case final AppConfigInvalid invalid:
      runApp(ConfigurationErrorApp(issues: invalid.issues));
  }
}
