import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

// tests for QuestionPayload
void main() {
  final QuestionPayload? instance = /* QuestionPayload(...) */ null;
  // TODO add properties to the entity

  group(QuestionPayload, () {
    // String questionId
    test('to test the property `questionId`', () async {
      // TODO
    });

    // String questionRevisionId
    test('to test the property `questionRevisionId`', () async {
      // TODO
    });

    // String type
    test('to test the property `type`', () async {
      // TODO
    });

    // int position
    test('to test the property `position`', () async {
      // TODO
    });

    // Required question prompt value. MATCHING carries an explicit null; every other question type carries nonblank target-language text.
    // String prompt
    test('to test the property `prompt`', () async {
      // TODO
    });

    // List<AnswerOption> options
    test('to test the property `options`', () async {
      // TODO
    });

    // List<MatchingItem> targetItems
    test('to test the property `targetItems`', () async {
      // TODO
    });

    // List<MatchingItem> supportItems
    test('to test the property `supportItems`', () async {
      // TODO
    });

    test('keeps the required matching prompt key with a null value', () {
      final payload = QuestionPayload(
        questionId: '00000000-0000-4000-8000-000000000071',
        questionRevisionId: '00000000-0000-4000-8000-000000000072',
        type: QuestionPayloadTypeEnum.MATCHING,
        position: 1,
        prompt: null,
        options: const [],
        targetItems: [
          MatchingItem(
            id: '53184dbf-a100-45ad-93bd-57b1c122fe07',
            text: 'Pencere',
          ),
          MatchingItem(
            id: 'bc4996c9-c410-4fc5-a92b-f25b1182a858',
            text: 'Kapı',
          ),
        ],
        supportItems: [
          MatchingItem(
            id: 'f222c9dc-d9a4-4f75-bc49-37454a2b62cd',
            text: 'Window',
          ),
          MatchingItem(
            id: '8a2d1ea7-3d79-4416-b514-7be383c91a22',
            text: 'Door',
          ),
        ],
      );

      expect(payload.prompt, isNull);
      expect(payload.toJson(), containsPair('prompt', null));
      expect(QuestionPayload.fromJson(payload.toJson()).prompt, isNull);
    });
  });
}
