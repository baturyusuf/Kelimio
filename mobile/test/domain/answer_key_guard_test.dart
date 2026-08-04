import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/infrastructure/network/interceptors.dart';

void main() {
  test('rejects every option, typed, and matching answer-key spelling', () {
    for (final forbiddenKey in [
      'correct',
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
      'correctMatches',
      'correct_matches',
      'matches',
      'matchingPairs',
      'matching_pairs',
      'pairId',
      'pair_id',
      'targetItemId',
      'target_item_id',
      'supportItemId',
      'support_item_id',
      'correctPairCount',
      'correct_pair_count',
      'matchingAnswerSalt',
      'matching_answer_salt',
      'matchingAnswerDigest',
      'matching_answer_digest',
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

  test('rejects matching relationship fields at any nested depth', () {
    final leaked = <String, Object?>{
      'questions': <Object?>[
        <String, Object?>{
          'questionId': 'matching-fixture',
          'targetItems': <Object?>[
            <String, Object?>{'id': 'target-one', 'text': 'elma'},
          ],
          'supportItems': <Object?>[
            <String, Object?>{
              'id': 'support-one',
              'text': 'apple',
              'metadata': <String, Object?>{'targetItemId': 'target-one'},
            },
          ],
        },
      ],
    };

    expect(containsAnswerKeyLeak(leaked), isTrue);
  });

  test('accepts answer-free option, typed, and matching attempt payloads', () {
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
        <String, Object?>{
          'questionId': 'matching-fixture',
          'type': 'MATCHING',
          'prompt': null,
          'options': <Object?>[],
          'targetItems': <Object?>[
            <String, Object?>{'id': 'target-one', 'text': 'elma'},
            <String, Object?>{'id': 'target-two', 'text': 'armut'},
          ],
          'supportItems': <Object?>[
            <String, Object?>{'id': 'support-one', 'text': 'apple'},
            <String, Object?>{'id': 'support-two', 'text': 'pear'},
          ],
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
