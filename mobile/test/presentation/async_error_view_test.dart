import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/domain/failures.dart';
import 'package:kelimio_mobile/l10n/generated/app_localizations.dart';
import 'package:kelimio_mobile/presentation/widgets/async_error_view.dart';

void main() {
  testWidgets('user-facing failures never render provider detail or cause', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AsyncErrorView(
            error: const ValidationFailure(
              detail: 'private provider detail',
              cause: 'authorization=secret-token',
            ),
            onRetry: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Check the information and try again.'), findsOneWidget);
    expect(find.textContaining('private provider detail'), findsNothing);
    expect(find.textContaining('secret-token'), findsNothing);
  });

  testWidgets('operating mode keeps its localized actionable message', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AsyncErrorView(
            error: const OperatingModeFailure(
              mode: ServiceOperatingMode.suspended,
            ),
            onRetry: _noop,
          ),
        ),
      ),
    );

    expect(
      find.text(
        'Hizmet harcama güvenliği nedeniyle geçici olarak durduruldu. Lütfen daha sonra tekrar deneyin.',
      ),
      findsOneWidget,
    );
  });
}

void _noop() {}
