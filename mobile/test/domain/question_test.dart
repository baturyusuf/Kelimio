import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/domain/energy/energy.dart';
import 'package:kelimio_mobile/domain/learning/learning.dart';

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
}) => AnswerFeedback(
  submissionId: 'submission',
  correct: true,
  correctOptionId: correctOptionId,
  correctAnswerText: correctAnswerText,
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
