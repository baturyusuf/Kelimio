import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/domain/learning/learning.dart';
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

  testWidgets('cloze direction follows its content and announces one blank', (
    tester,
  ) async {
    final question = fixtureClozeQuestion(prompt: 'أنا أشرب --- كل صباح.');
    await _pumpQuestion(tester, question: question, locale: const Locale('en'));

    final prompt = tester.widget<Text>(
      find.byKey(const Key('attempt-cloze-prompt')),
    );
    expect(prompt.textDirection, TextDirection.rtl);
    expect(prompt.textSpan!.toPlainText(), isNot(contains('---')));
    expect(find.bySemanticsLabel('أنا أشرب blank كل صباح.'), findsOneWidget);
  });

  testWidgets('Latin cloze remains LTR inside an Arabic application', (
    tester,
  ) async {
    final question = fixtureClozeQuestion(prompt: 'I drink --- every morning.');
    await _pumpQuestion(tester, question: question, locale: const Locale('ar'));

    final prompt = tester.widget<Text>(
      find.byKey(const Key('attempt-cloze-prompt')),
    );
    expect(prompt.textDirection, TextDirection.ltr);
    expect(
      find.bySemanticsLabel('I drink فراغ every morning.'),
      findsOneWidget,
    );
  });

  testWidgets('long mixed-direction cloze wraps at large text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final question = fixtureClozeQuestion(
      prompt:
          'Bu uzun Türkçe cümlede الصباح erken saatlerde herkes birlikte çok sıcak çay --- ve konuşmaya devam eder.',
    );
    await _pumpQuestion(
      tester,
      question: question,
      locale: const Locale('tr'),
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    for (final option in question.options) {
      final optionFinder = find.byKey(Key('answer-${option.id}'));
      await tester.scrollUntilVisible(
        optionFinder,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.getSize(optionFinder).height, greaterThanOrEqualTo(48));
    }
  });
}

Future<void> _pumpQuestion(
  WidgetTester tester, {
  required Question question,
  required Locale locale,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
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
}
