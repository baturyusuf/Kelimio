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

  testWidgets('typed cloze uses a private accessible IME-done field', (
    tester,
  ) async {
    String? submitted;
    await _pumpTypedQuestion(
      tester,
      onTypedSubmitted: (value) => submitted = value,
    );

    final fieldFinder = find.byKey(const Key('attempt-typed-answer'));
    final field = tester.widget<TextField>(fieldFinder);
    expect(field.decoration?.labelText, isNotEmpty);
    expect(find.bySemanticsLabel(RegExp('Your answer')), findsOneWidget);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    expect(field.textInputAction, TextInputAction.done);
    expect(field.maxLines, 2);
    expect(field.maxLength, TypedAnswerInput.maxLength);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('attempt-primary-button')))
          .onPressed,
      isNull,
    );

    await tester.enterText(fieldFinder, 'private typed answer');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('attempt-primary-button')))
          .onPressed,
      isNotNull,
    );

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(submitted, 'private typed answer');
    expect(tester.widget<TextField>(fieldFinder).controller?.text, isEmpty);
  });

  testWidgets('typed input direction follows its first strong character', (
    tester,
  ) async {
    await _pumpTypedQuestion(tester, onTypedSubmitted: (_) {});
    final fieldFinder = find.byKey(const Key('attempt-typed-answer'));

    await tester.enterText(fieldFinder, '\u0645\u0631\u062d\u0628\u0627');
    await tester.pump();

    expect(
      tester.widget<TextField>(fieldFinder).textDirection,
      TextDirection.rtl,
    );
  });

  testWidgets('typed submit limit counts astral Unicode code points', (
    tester,
  ) async {
    await _pumpTypedQuestion(tester, onTypedSubmitted: (_) {});
    final fieldFinder = find.byKey(const Key('attempt-typed-answer'));
    final exactlyAtLimit = List.filled(
      TypedAnswerInput.maxLength,
      _astralCharacter,
    ).join();

    await tester.enterText(fieldFinder, exactlyAtLimit);
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('attempt-primary-button')))
          .onPressed,
      isNotNull,
    );

    tester.widget<TextField>(fieldFinder).controller!.text =
        '$exactlyAtLimit$_astralCharacter';
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('attempt-primary-button')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('typed feedback shows only the authoritative server answer', (
    tester,
  ) async {
    const privateRaw = 'never render this raw value';
    await _pumpTypedQuestion(
      tester,
      feedback: fixtureTypedFeedback(correct: false),
      locked: true,
    );

    expect(find.byKey(const Key('attempt-typed-answer')), findsNothing);
    expect(find.text(privateRaw), findsNothing);
    expect(
      find.byKey(const Key('attempt-correct-answer-text')),
      findsOneWidget,
    );
    expect(find.text('Incorrect'), findsOneWidget);
  });

  testWidgets('typed process-recovery state requests blank re-entry', (
    tester,
  ) async {
    await _pumpTypedQuestion(
      tester,
      onTypedSubmitted: (_) {},
      needsReentry: true,
    );

    final field = tester.widget<TextField>(
      find.byKey(const Key('attempt-typed-answer')),
    );
    expect(field.controller?.text, isEmpty);
    expect(field.decoration?.helperText, isNotEmpty);
  });

  testWidgets('typed cloze has no overflow at 2x text scale', (tester) async {
    await tester.binding.setSurfaceSize(const Size(280, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpTypedQuestion(
      tester,
      onTypedSubmitted: (_) {},
      textScaler: const TextScaler.linear(2),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -320));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('attempt-typed-answer')), findsOneWidget);
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

Future<void> _pumpTypedQuestion(
  WidgetTester tester, {
  ValueChanged<String>? onTypedSubmitted,
  AnswerFeedback? feedback,
  bool locked = false,
  bool needsReentry = false,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: AttemptQuestionView(
          question: fixtureTypedClozeQuestion(
            prompt: 'They --- every morning before work.',
          ),
          questionIndex: 0,
          questionCount: 1,
          selectedOptionId: null,
          locked: locked,
          feedback: feedback,
          onOptionSelected: null,
          onTypedSubmitted: onTypedSubmitted,
          typedAnswerNeedsReentry: needsReentry,
          onPrimary: feedback == null ? null : () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _astralCharacter = '\u{1F642}';
