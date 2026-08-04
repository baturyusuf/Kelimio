import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/domain/learning/attempt_machine.dart';
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

  testWidgets(
    'matching requires target then support, preserves selection, and removes explicitly',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 520));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final question = fixtureMatchingQuestion();
      var submissionCount = 0;
      await _pumpMatchingQuestion(
        tester,
        question: question,
        onPrimary: () => submissionCount += 1,
      );

      for (final item in question.targetItems) {
        final finder = find.byKey(Key('matching-target-${item.id}'));
        expect(finder, findsOneWidget);
        expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
      }
      for (final item in question.supportItems) {
        final finder = find.byKey(Key('matching-support-${item.id}'));
        expect(finder, findsOneWidget);
        expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
        expect(tester.widget<OutlinedButton>(finder).onPressed, isNull);
      }
      await _reveal(tester, find.byKey(const Key('attempt-primary-button')));
      expect(_primaryButton(tester).onPressed, isNull);

      final firstTarget = find.byKey(
        const Key('matching-target-$targetItemOneId'),
      );
      await _reveal(tester, firstTarget, scrollAmount: -100);
      await tester.tap(firstTarget);
      await tester.pump();
      expect(
        find.bySemanticsLabel('Word: elma, Selected word'),
        findsOneWidget,
      );
      final firstSupport = find.byKey(
        const Key('matching-support-$supportItemOneId'),
      );
      await tester.scrollUntilVisible(
        firstSupport,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<OutlinedButton>(firstSupport).onPressed, isNotNull);

      await tester.tap(firstSupport);
      await tester.pump();
      await _reveal(
        tester,
        find.byKey(const Key('matching-progress')),
        scrollAmount: -100,
      );
      expect(find.bySemanticsLabel('1 of 2 pairs matched'), findsOneWidget);
      final firstPair = find.byKey(const Key('matching-pair-$targetItemOneId'));
      await _reveal(tester, firstPair);
      expect(
        tester
            .getSemantics(
              find.byKey(const Key('matching-pair-semantics-$targetItemOneId')),
            )
            .label,
        'elma matches apple, Tentative match',
      );
      final pairDecoration =
          tester.widget<DecoratedBox>(firstPair).decoration as BoxDecoration;
      expect(
        pairDecoration.color,
        Theme.of(tester.element(firstPair)).colorScheme.surfaceContainerHighest,
      );
      final remove = find.byKey(const Key('matching-remove-$targetItemOneId'));
      await tester.scrollUntilVisible(
        remove,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.getSize(remove), const Size(48, 48));
      final removeSemantics = tester.getSemantics(remove);
      expect(removeSemantics.label, 'Remove match for elma');
      expect(
        removeSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      await _reveal(tester, find.byKey(const Key('attempt-primary-button')));
      expect(_primaryButton(tester).onPressed, isNull);

      final secondTarget = find.byKey(
        const Key('matching-target-$targetItemTwoId'),
      );
      await tester.scrollUntilVisible(
        secondTarget,
        -100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(secondTarget);
      await tester.pump();
      final secondSupport = find.byKey(
        const Key('matching-support-$supportItemTwoId'),
      );
      await tester.scrollUntilVisible(
        secondSupport,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(secondSupport);
      await tester.pump();
      await _reveal(
        tester,
        find.byKey(const Key('matching-progress')),
        scrollAmount: -100,
      );
      expect(find.bySemanticsLabel('2 of 2 pairs matched'), findsOneWidget);
      await _reveal(tester, find.byKey(const Key('attempt-primary-button')));
      expect(_primaryButton(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('attempt-primary-button')));
      expect(submissionCount, 1);

      await tester.scrollUntilVisible(
        remove,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(remove);
      await tester.pump();
      await _reveal(
        tester,
        find.byKey(const Key('matching-progress')),
        scrollAmount: -100,
      );
      expect(find.bySemanticsLabel('1 of 2 pairs matched'), findsOneWidget);
      await _reveal(tester, find.byKey(const Key('attempt-primary-button')));
      expect(_primaryButton(tester).onPressed, isNull);
    },
  );

  testWidgets('matching controls support keyboard focus and activation', (
    tester,
  ) async {
    await _pumpMatchingQuestion(tester, question: fixtureMatchingQuestion());

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('matching-support-$supportItemOneId')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('matching guidance is localized in English, Turkish, and Arabic', (
    tester,
  ) async {
    final cases = [
      (
        locale: const Locale('en'),
        instructions:
            'Match each word in two steps: choose a learning-language word, then choose its meaning.',
        targets: 'Words to match',
        supports: 'Meanings',
      ),
      (
        locale: const Locale('tr'),
        instructions:
            'Her kelimeyi iki adımda eşleştir: önce öğrenilen dildeki kelimeyi, sonra anlamını seç.',
        targets: 'Eşleştirilecek kelimeler',
        supports: 'Anlamlar',
      ),
      (
        locale: const Locale('ar'),
        instructions:
            'طابق كل كلمة في خطوتين: اختر أولًا كلمة لغة التعلّم، ثم اختر معناها.',
        targets: 'الكلمات المطلوب مطابقتها',
        supports: 'المعاني',
      ),
    ];

    for (final testCase in cases) {
      await _pumpMatchingQuestion(
        tester,
        question: fixtureMatchingQuestion(),
        locale: testCase.locale,
      );
      expect(find.text(testCase.instructions), findsOneWidget);
      expect(find.text(testCase.targets), findsOneWidget);
      expect(find.text(testCase.supports), findsOneWidget);
    }
  });

  testWidgets(
    'matching reveals pair correctness only after authoritative live feedback',
    (tester) async {
      await _pumpMatchingQuestion(
        tester,
        question: fixtureMatchingQuestion(),
        locked: true,
        submittedMatches: MatchingAnswerInput(fixtureIncorrectMatches()),
        feedback: fixtureMatchingFeedback(correct: false),
      );

      final firstSubmittedPair = find.byKey(
        const Key('matching-pair-$targetItemOneId'),
      );
      await _reveal(tester, firstSubmittedPair);
      expect(
        tester
            .getSemantics(
              find.byKey(const Key('matching-pair-semantics-$targetItemOneId')),
            )
            .label,
        'elma matches pear, Incorrect match',
      );
      await _reveal(
        tester,
        find.byKey(const Key('matching-pair-$targetItemTwoId')),
      );
      expect(
        tester
            .getSemantics(
              find.byKey(const Key('matching-pair-semantics-$targetItemTwoId')),
            )
            .label,
        'armut matches apple, Incorrect match',
      );
      expect(
        find.byKey(const Key('matching-feedback-unavailable')),
        findsNothing,
      );
      await _reveal(
        tester,
        find.byKey(const Key('matching-correct-pair-$targetItemOneId')),
      );
      expect(
        find.byKey(const Key('matching-correct-pair-$targetItemOneId')),
        findsOneWidget,
      );
      await _reveal(tester, find.text('Incorrect'));
      expect(find.text('Incorrect'), findsOneWidget);
      await _reveal(
        tester,
        find.byKey(const Key('matching-target-$targetItemOneId')),
        scrollAmount: -100,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('matching-target-$targetItemOneId')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(const Key('matching-remove-$targetItemOneId')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'cold matching feedback never reconstructs unavailable learner pairs',
    (tester) async {
      await _pumpMatchingQuestion(
        tester,
        question: fixtureMatchingQuestion(),
        locked: true,
        feedback: fixtureMatchingFeedback(correct: false),
      );

      await _reveal(
        tester,
        find.byKey(const Key('matching-feedback-unavailable')),
      );
      expect(
        find.byKey(const Key('matching-feedback-unavailable')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('matching-pairs-heading')), findsNothing);
      expect(
        find.byKey(const Key('matching-pair-$targetItemOneId')),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel('elma matches pear, Incorrect match'),
        findsNothing,
      );
      expect(
        find.byKey(const Key('matching-correct-target-$targetItemOneId')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('matching-correct-support-$supportItemOneId')),
        findsOneWidget,
      );
      await _reveal(tester, find.text('Incorrect'));
      expect(find.text('Incorrect'), findsOneWidget);
    },
  );

  testWidgets('matching keeps each item direction inside an Arabic layout', (
    tester,
  ) async {
    final question = fixtureMatchingQuestion(
      targetItems: [
        MatchingItem(id: targetItemOneId, text: 'نافذة'),
        MatchingItem(id: targetItemTwoId, text: 'door'),
      ],
      supportItems: [
        MatchingItem(id: supportItemOneId, text: 'window'),
        MatchingItem(id: supportItemTwoId, text: 'باب'),
      ],
    );
    await _pumpMatchingQuestion(
      tester,
      question: question,
      locale: const Locale('ar'),
    );

    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.rtl,
    );
    expect(
      _choiceText(
        tester,
        const Key('matching-target-$targetItemOneId'),
      ).textDirection,
      TextDirection.rtl,
    );
    expect(
      _choiceText(
        tester,
        const Key('matching-target-$targetItemTwoId'),
      ).textDirection,
      TextDirection.ltr,
    );
    expect(
      _choiceText(
        tester,
        const Key('matching-support-$supportItemOneId'),
      ).textDirection,
      TextDirection.ltr,
    );
    expect(
      _choiceText(
        tester,
        const Key('matching-support-$supportItemTwoId'),
      ).textDirection,
      TextDirection.rtl,
    );
  });

  testWidgets(
    'matching remains usable at 200 percent text on a narrow screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(280, 520));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final question = fixtureMatchingQuestion(
        targetItems: [
          MatchingItem(
            id: targetItemOneId,
            text: 'öğrenilen dildeki oldukça uzun bir pencere ifadesi',
          ),
          MatchingItem(
            id: targetItemTwoId,
            text: 'öğrenilen dildeki oldukça uzun bir kapı ifadesi',
          ),
        ],
        supportItems: [
          MatchingItem(
            id: supportItemOneId,
            text: 'a very long explanatory meaning for window',
          ),
          MatchingItem(
            id: supportItemTwoId,
            text: 'a very long explanatory meaning for door',
          ),
        ],
      );
      await _pumpMatchingQuestion(
        tester,
        question: question,
        textScaler: const TextScaler.linear(2),
      );

      final target = find.byKey(const Key('matching-target-$targetItemOneId'));
      await _reveal(tester, target);
      await tester.tap(target);
      await tester.pump();
      final support = find.byKey(
        const Key('matching-support-$supportItemOneId'),
      );
      await _reveal(tester, support, scrollAmount: 160);
      await tester.tap(support);
      await tester.pump();
      final remove = find.byKey(const Key('matching-remove-$targetItemOneId'));
      await _reveal(tester, remove, scrollAmount: 160);

      expect(tester.getSize(support).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(remove), const Size(48, 48));
      expect(tester.takeException(), isNull);
    },
  );
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

Future<void> _pumpMatchingQuestion(
  WidgetTester tester, {
  required Question question,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
  MatchingDraft initialDraft = const MatchingDraft.empty(),
  MatchingAnswerInput? submittedMatches,
  AnswerFeedback? feedback,
  bool locked = false,
  VoidCallback? onPrimary,
}) async {
  var draft = initialDraft;
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
        body: StatefulBuilder(
          builder: (context, setState) => AttemptQuestionView(
            question: question,
            questionIndex: 0,
            questionCount: 1,
            selectedOptionId: null,
            matchingDraft: draft,
            submittedMatches: submittedMatches,
            locked: locked,
            feedback: feedback,
            onOptionSelected: null,
            onMatchingTargetSelected: locked
                ? null
                : (itemId) => setState(() {
                    draft = draft.selectTarget(question, itemId);
                  }),
            onMatchingSupportSelected: locked
                ? null
                : (itemId) => setState(() {
                    draft = draft.selectSupport(question, itemId);
                  }),
            onMatchingPairRemoved: locked
                ? null
                : (itemId) => setState(() {
                    draft = draft.removePair(question, itemId);
                  }),
            onPrimary: feedback == null ? onPrimary : onPrimary ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _reveal(
  WidgetTester tester,
  Finder finder, {
  double scrollAmount = 120,
}) async {
  final scrollable = find.byType(Scrollable).first;
  for (var dragCount = 0; dragCount < 30; dragCount += 1) {
    if (finder.hitTestable().evaluate().isNotEmpty) {
      return;
    }
    await tester.drag(scrollable, Offset(0, -scrollAmount));
    await tester.pumpAndSettle();
  }
  expect(finder.hitTestable(), findsWidgets);
}

FilledButton _primaryButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.byKey(const Key('attempt-primary-button')),
);

Text _choiceText(WidgetTester tester, Key choiceKey) => tester.widget<Text>(
  find.descendant(of: find.byKey(choiceKey), matching: find.byType(Text)),
);

const _astralCharacter = '\u{1F642}';
