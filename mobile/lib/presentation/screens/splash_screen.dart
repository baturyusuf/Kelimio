import 'package:flutter/material.dart';

import '../widgets/localization.dart';

final class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: context.l10n.loading,
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
