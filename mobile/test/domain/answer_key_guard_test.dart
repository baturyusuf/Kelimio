import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/infrastructure/network/interceptors.dart';

void main() {
  test('rejects answer keys in attempt payloads', () {
    final leaked = <String, Object?>{
      'questions': <Object?>[
        <String, Object?>{
          'questionId': 'fixture',
          'correctOptionId': 'forbidden',
          'options': <Object?>[],
        },
      ],
    };
    final safe = <String, Object?>{
      'questions': <Object?>[
        <String, Object?>{
          'questionId': 'fixture',
          'options': <Object?>[
            <String, Object?>{'id': 'one', 'text': 'safe'},
          ],
        },
      ],
    };

    expect(containsAnswerKeyLeak(leaked), isTrue);
    expect(containsAnswerKeyLeak(safe), isFalse);
  });
}
