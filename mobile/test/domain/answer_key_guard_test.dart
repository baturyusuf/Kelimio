import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/infrastructure/network/interceptors.dart';

void main() {
  test('rejects every option and typed answer key spelling', () {
    for (final forbiddenKey in [
      'correctOptionId',
      'correct_option_id',
      'correctAnswer',
      'correct_answer',
      'correctAnswerText',
      'correct_answer_text',
      'answerKey',
      'answer_key',
      'isCorrect',
      'is_correct',
      'typedAnswer',
      'typed_answer',
    ]) {
      final leaked = <String, Object?>{
        'questions': <Object?>[
          <String, Object?>{
            'questionId': 'fixture',
            forbiddenKey: 'forbidden',
            'options': <Object?>[],
          },
        ],
      };

      expect(containsAnswerKeyLeak(leaked), isTrue, reason: forbiddenKey);
    }
  });

  test('accepts answer-free multiple-choice and typed attempt payloads', () {
    final safe = <String, Object?>{
      'questions': <Object?>[
        <String, Object?>{
          'questionId': 'fixture',
          'options': <Object?>[
            <String, Object?>{'id': 'one', 'text': 'safe'},
          ],
        },
        <String, Object?>{
          'questionId': 'typed-fixture',
          'type': 'TYPED_CLOZE',
          'options': <Object?>[],
        },
      ],
    };

    expect(containsAnswerKeyLeak(safe), isFalse);
  });

  test('guard is scoped away from submit and recorded-answer responses', () {
    expect(
      isAnswerKeyGuardedAttemptStartPath('/v1/attempts/a/answers'),
      isFalse,
    );
    expect(
      isAnswerKeyGuardedAttemptStartPath('/v1/attempts/a/answers/s'),
      isFalse,
    );
    expect(isAnswerKeyGuardedAttemptStartPath('/v1/tests/t/attempts'), isTrue);
  });
}
