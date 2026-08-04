import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/domain/energy/energy.dart';
import 'package:kelimio_mobile/domain/learning/learning.dart';

import '../support/fixtures.dart';

void main() {
  group('Question', () {
    test('both cloze types expose text around their single marker', () {
      for (final type in [
        QuestionType.multipleChoiceCloze,
        QuestionType.typedCloze,
      ]) {
        final question = _question(type: type, prompt: 'Before --- after');

        expect(question.clozePromptSegments.before, 'Before ');
        expect(question.clozePromptSegments.after, ' after');
      }
    });

    test('both cloze types reject malformed markers', () {
      for (final type in [
        QuestionType.multipleChoiceCloze,
        QuestionType.typedCloze,
      ]) {
        for (final prompt in [
          'No marker',
          '--- first and second ---',
          'Overlapping ---- marker',
          'Overlapping ------ marker',
        ]) {
          expect(
            () => _question(type: type, prompt: prompt),
            throwsArgumentError,
          );
        }
      }
    });

    test('multiple-choice types require exactly four options', () {
      for (final type in [
        QuestionType.wordMultipleChoice,
        QuestionType.multipleChoiceCloze,
      ]) {
        expect(
          () => Question(
            id: 'question',
            revisionId: 'revision',
            type: type,
            position: 1,
            prompt: type.isMultipleChoiceCloze ? 'Before --- after' : 'Word',
            options: _options.take(3).toList(),
          ),
          throwsArgumentError,
        );
      }
    });

    test('typed cloze requires an empty options collection', () {
      expect(
        _question(
          type: QuestionType.typedCloze,
          prompt: 'Before --- after',
        ).options,
        isEmpty,
      );
      expect(
        () => Question(
          id: 'question',
          revisionId: 'revision',
          type: QuestionType.typedCloze,
          position: 1,
          prompt: 'Before --- after',
          options: _options,
        ),
        throwsArgumentError,
      );
    });

    test('matching questions expose only two answer-free item lists', () {
      final question = fixtureMatchingQuestion();

      expect(question.answerKind, AnswerKind.matching);
      expect(question.prompt, isNull);
      expect(question.options, isEmpty);
      expect(question.targetItems, hasLength(2));
      expect(question.supportItems, hasLength(2));
      expect(
        () => question.targetItems.add(MatchingItem(id: 'new', text: 'new')),
        throwsUnsupportedError,
      );
    });

    test('matching questions require equal groups of two to six items', () {
      final oneTarget = [MatchingItem(id: 't1', text: 'one')];
      final oneSupport = [MatchingItem(id: 's1', text: 'uno')];
      expect(
        () =>
            _matchingQuestion(targetItems: oneTarget, supportItems: oneSupport),
        throwsArgumentError,
      );

      expect(
        () => _matchingQuestion(
          targetItems: _matchingItems('t', 7),
          supportItems: _matchingItems('s', 7),
        ),
        throwsArgumentError,
      );

      expect(
        () => _matchingQuestion(
          targetItems: _matchingItems('t', 2),
          supportItems: _matchingItems('s', 3),
        ),
        throwsArgumentError,
      );
    });

    test(
      'matching questions reject prompt, options, and linked identifiers',
      () {
        expect(
          () => Question(
            id: 'question',
            revisionId: 'revision',
            type: QuestionType.matching,
            position: 1,
            prompt: 'answer-bearing prompt',
            options: const [],
            targetItems: _matchingItems('t', 2),
            supportItems: _matchingItems('s', 2),
          ),
          throwsArgumentError,
        );
        expect(
          () => Question(
            id: 'question',
            revisionId: 'revision',
            type: QuestionType.matching,
            position: 1,
            prompt: null,
            options: _options,
            targetItems: _matchingItems('t', 2),
            supportItems: _matchingItems('s', 2),
          ),
          throwsArgumentError,
        );
        expect(
          () => _matchingQuestion(
            targetItems: [
              MatchingItem(id: 'shared', text: 'one'),
              MatchingItem(id: 't2', text: 'two'),
            ],
            supportItems: [
              MatchingItem(id: 'shared', text: 'uno'),
              MatchingItem(id: 's2', text: 'dos'),
            ],
          ),
          throwsArgumentError,
        );
      },
    );

    test('matching question identifiers and labels are unique per side', () {
      expect(
        () => _matchingQuestion(
          targetItems: [
            MatchingItem(id: 't1', text: 'duplicate'),
            MatchingItem(id: 't1', text: 'other'),
          ],
          supportItems: _matchingItems('s', 2),
        ),
        throwsArgumentError,
      );
      expect(
        () => _matchingQuestion(
          targetItems: [
            MatchingItem(id: 't1', text: 'duplicate'),
            MatchingItem(id: 't2', text: 'duplicate'),
          ],
          supportItems: _matchingItems('s', 2),
        ),
        throwsArgumentError,
      );
    });

    test('non-matching questions reject matching item arrays', () {
      expect(
        () => Question(
          id: 'question',
          revisionId: 'revision',
          type: QuestionType.wordMultipleChoice,
          position: 1,
          prompt: 'Word',
          options: _options,
          targetItems: _matchingItems('t', 2),
          supportItems: _matchingItems('s', 2),
        ),
        throwsArgumentError,
      );
    });
  });

  group('MatchingAnswerInput privacy boundary', () {
    test('requires a complete one-to-one mapping for the question', () {
      final question = fixtureMatchingQuestion();
      final answer = MatchingAnswerInput(fixtureCorrectMatches());

      expect(answer.kind, AnswerKind.matching);
      expect(answer.hasExactCoverageOf(question), isTrue);
      expect(answer.hasSameMappingAs(fixtureCorrectMatches().reversed), isTrue);
      expect(answer.hasSameMappingAs(fixtureIncorrectMatches()), isFalse);
    });

    test('rejects duplicate target or support identifiers', () {
      expect(
        () => MatchingAnswerInput([
          MatchingPair(targetItemId: 't1', supportItemId: 's1'),
          MatchingPair(targetItemId: 't1', supportItemId: 's2'),
        ]),
        throwsArgumentError,
      );
      expect(
        () => MatchingPair(targetItemId: 'shared', supportItemId: 'shared'),
        throwsArgumentError,
      );
      expect(
        () => MatchingAnswerInput([
          MatchingPair(targetItemId: 't1', supportItemId: 's1'),
          MatchingPair(targetItemId: 't2', supportItemId: 's1'),
        ]),
        throwsArgumentError,
      );
    });

    test('does not expose selected relationships through toString', () {
      final answer = MatchingAnswerInput(fixtureCorrectMatches());

      expect(answer.toString(), isNot(contains(targetItemOneId)));
      expect(answer.toString(), isNot(contains(supportItemOneId)));
      expect(answer.pairs.first.toString(), isNot(contains(targetItemOneId)));
    });
  });

  group('AttemptSession', () {
    test('requires and pins a nonblank support language', () {
      expect(fixtureMatchingSession().supportLanguage, 'en');
      expect(
        () => AttemptSession(
          id: attemptId,
          testId: testId,
          testRevisionId: testRevisionId,
          supportLanguage: '   ',
          status: ServerAttemptStatus.inProgress,
          questions: [fixtureMatchingQuestion()],
          startedAt: DateTime.utc(2026),
        ),
        throwsArgumentError,
      );
    });
  });

  group('TypedAnswerInput privacy boundary', () {
    test('accepts up to 500 nonblank characters', () {
      final input = TypedAnswerInput(
        List.filled(TypedAnswerInput.maxLength, 'x').join(),
      );

      expect(input.kind, AnswerKind.typed);
      expect(input.rawValueForSubmission.length, TypedAnswerInput.maxLength);
    });

    test('counts astral characters as one Unicode code point', () {
      final exactlyAtLimit = List.filled(
        TypedAnswerInput.maxLength,
        _astralCharacter,
      ).join();
      final overLimit = '$exactlyAtLimit$_astralCharacter';

      expect(exactlyAtLimit.length, TypedAnswerInput.maxLength * 2);
      expect(TypedAnswerInput.codePointLength(exactlyAtLimit), 500);
      expect(
        TypedAnswerInput(exactlyAtLimit).rawValueForSubmission,
        exactlyAtLimit,
      );
      expect(() => TypedAnswerInput(overLimit), throwsArgumentError);
    });

    test('rejects empty, blank, and overlong text', () {
      for (final raw in [
        '',
        '   ',
        List.filled(TypedAnswerInput.maxLength + 1, 'x').join(),
      ]) {
        expect(() => TypedAnswerInput(raw), throwsArgumentError);
      }
    });

    test('does not expose the raw answer through toString', () {
      const secret = 'raw-private-answer';

      expect(TypedAnswerInput(secret).toString(), isNot(contains(secret)));
    });
  });

  group('AnswerFeedback', () {
    test('requires exactly one authoritative answer branch', () {
      expect(() => _feedback(), throwsArgumentError);
      expect(
        () => _feedback(correctOptionId: 'option', correctAnswerText: 'text'),
        throwsArgumentError,
      );
    });

    test('accepts the option and typed branches independently', () {
      expect(_feedback(correctOptionId: 'option').correctAnswerText, isNull);
      expect(_feedback(correctAnswerText: 'answer').correctOptionId, isNull);
      expect(
        _feedback(correctMatches: fixtureCorrectMatches()).correctMatches,
        hasLength(2),
      );
    });

    test('validates authoritative text by Unicode code points', () {
      final exactlyAtLimit = List.filled(
        TypedAnswerInput.maxLength,
        _astralCharacter,
      ).join();

      expect(
        _feedback(correctAnswerText: exactlyAtLimit).correctAnswerText,
        exactlyAtLimit,
      );
      expect(
        () => _feedback(correctAnswerText: '$exactlyAtLimit$_astralCharacter'),
        throwsArgumentError,
      );
    });

    test('redacts authoritative answer values from toString', () {
      const answerKey = 'private authoritative answer key';
      final feedback = _feedback(correctAnswerText: answerKey);

      expect(feedback.toString(), isNot(contains(answerKey)));

      final matchingFeedback = _feedback(
        correctMatches: fixtureCorrectMatches(),
      );
      expect(matchingFeedback.toString(), isNot(contains(targetItemOneId)));
      expect(matchingFeedback.toString(), isNot(contains(supportItemOneId)));
    });
  });
}

Question _question({required QuestionType type, required String prompt}) =>
    Question(
      id: 'question',
      revisionId: 'revision',
      type: type,
      position: 1,
      prompt: prompt,
      options: type == QuestionType.typedCloze ? const [] : _options,
    );

AnswerFeedback _feedback({
  String? correctOptionId,
  String? correctAnswerText,
  List<MatchingPair>? correctMatches,
}) => AnswerFeedback(
  submissionId: 'submission',
  correct: true,
  correctOptionId: correctOptionId,
  correctAnswerText: correctAnswerText,
  correctMatches: correctMatches,
  activeScoreDelta: 1,
  lifetimeScoreDelta: 1,
  activeQuestionScore: 1,
  lifetimeScore: 1,
  energy: Energy(
    balance: 5,
    maximum: 5,
    unlimited: false,
    asOf: DateTime.utc(2026),
  ),
  attemptStatus: ServerAttemptStatus.inProgress,
);

Question _matchingQuestion({
  required List<MatchingItem> targetItems,
  required List<MatchingItem> supportItems,
}) => Question(
  id: 'question',
  revisionId: 'revision',
  type: QuestionType.matching,
  position: 1,
  prompt: null,
  options: const [],
  targetItems: targetItems,
  supportItems: supportItems,
);

List<MatchingItem> _matchingItems(String prefix, int count) => [
  for (var index = 0; index < count; index++)
    MatchingItem(id: '$prefix$index', text: '$prefix-label-$index'),
];

const _options = [
  AnswerOption(id: 'one', text: 'one'),
  AnswerOption(id: 'two', text: 'two'),
  AnswerOption(id: 'three', text: 'three'),
  AnswerOption(id: 'four', text: 'four'),
];

const _astralCharacter = '\u{1F642}';

extension on QuestionType {
  bool get isMultipleChoiceCloze => this == QuestionType.multipleChoiceCloze;
}
