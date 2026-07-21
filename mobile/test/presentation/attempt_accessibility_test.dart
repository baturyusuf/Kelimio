import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/l10n/generated/app_localizations.dart';
import 'package:kelimio_mobile/presentation/screens/attempt_screen.dart';

import '../support/fixtures.dart';

void main() {
  testWidgets('Arabic attempt UI is RTL and exposes answer semantics', (
    tester,
  ) async {
    final question = fixtureSession().questions.single;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AttemptQuestionView(
            question: question,
            questionIndex: 0,
            questionCount: 1,
            selectedOptionId: null,
            locked: false,
            onOptionSelected: (_) {},
            onPrimary: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
    expect(find.bySemanticsLabel('option one'), findsOneWidget);
    final submit = tester.widget<FilledButton>(
      find.byKey(const Key('attempt-primary-button')),
    );
    expect(submit.onPressed, isNull);
  });

  testWidgets('correct-answer semantics appear only with server feedback', (
    tester,
  ) async {
    final question = fixtureSession().questions.single;
    Future<void> pump({required bool withFeedback}) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AttemptQuestionView(
              question: question,
              questionIndex: 0,
              questionCount: 1,
              selectedOptionId: '00000000-0000-4000-8000-000000000010',
              locked: withFeedback,
              feedback: withFeedback ? fixtureFeedback() : null,
              onOptionSelected: withFeedback ? null : (_) {},
              onPrimary: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(withFeedback: false);
    expect(
      find.bySemanticsLabel('option one, Selected answer'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('option one, Correct answer'), findsNothing);

    await pump(withFeedback: true);
    expect(find.bySemanticsLabel('option one, Correct answer'), findsOneWidget);
  });
}
