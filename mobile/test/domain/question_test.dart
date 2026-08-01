import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/domain/learning/learning.dart';

void main() {
  test('multiple-choice cloze exposes the text around its single marker', () {
    final question = _question(
      type: QuestionType.multipleChoiceCloze,
      prompt: 'Ben her sabah çay ---.',
    );

    expect(question.clozePromptSegments.before, 'Ben her sabah çay ');
    expect(question.clozePromptSegments.after, '.');
  });

  test(
    'multiple-choice cloze rejects missing, repeated, and overlapping markers',
    () {
      for (final prompt in [
        'Ben her sabah çay içerim.',
        '--- Ben her sabah çay ---.',
        'Ben her sabah çay ----.',
        'Ben her sabah çay ------.',
      ]) {
        expect(
          () =>
              _question(type: QuestionType.multipleChoiceCloze, prompt: prompt),
          throwsArgumentError,
          reason: prompt,
        );
      }
    },
  );

  test('both supported multiple-choice types require exactly four options', () {
    for (final type in QuestionType.values) {
      expect(
        () => Question(
          id: 'question',
          revisionId: 'revision',
          type: type,
          position: 1,
          prompt: type == QuestionType.multipleChoiceCloze ? 'Bir ---.' : 'Bir',
          options: _options.take(3).toList(),
        ),
        throwsArgumentError,
      );
    }
  });
}

Question _question({required QuestionType type, required String prompt}) =>
    Question(
      id: 'question',
      revisionId: 'revision',
      type: type,
      position: 1,
      prompt: prompt,
      options: _options,
    );

const _options = [
  AnswerOption(id: 'one', text: 'içerim'),
  AnswerOption(id: 'two', text: 'yerim'),
  AnswerOption(id: 'three', text: 'koşarım'),
  AnswerOption(id: 'four', text: 'yazarım'),
];
