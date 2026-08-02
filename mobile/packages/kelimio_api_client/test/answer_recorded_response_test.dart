import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

// tests for AnswerRecordedResponse
void main() {
  final AnswerRecordedResponse? instance = /* AnswerRecordedResponse(...) */
      null;
  // TODO add properties to the entity

  group(AnswerRecordedResponse, () {
    // String submissionId
    test('to test the property `submissionId`', () async {
      // TODO
    });

    // bool correct
    test('to test the property `correct`', () async {
      // TODO
    });

    // String correctOptionId
    test('to test the property `correctOptionId`', () async {
      // TODO
    });

    // String correctAnswerText
    test('to test the property `correctAnswerText`', () async {
      // TODO
    });

    // int activeScoreDelta
    test('to test the property `activeScoreDelta`', () async {
      // TODO
    });

    // int lifetimeScoreDelta
    test('to test the property `lifetimeScoreDelta`', () async {
      // TODO
    });

    // int activeQuestionScore
    test('to test the property `activeQuestionScore`', () async {
      // TODO
    });

    // int lifetimeScore
    test('to test the property `lifetimeScore`', () async {
      // TODO
    });

    // EnergyResponse energy
    test('to test the property `energy`', () async {
      // TODO
    });

    // AttemptState attemptState
    test('to test the property `attemptState`', () async {
      // TODO
    });

    test('redacts answer-key values from toString', () {
      const optionAnswerKey = '00000000-0000-4000-8000-000000000099';
      const typedAnswerKey = 'private-authored-answer-key';
      final response = AnswerRecordedResponse(
        submissionId: '00000000-0000-4000-8000-000000000001',
        correct: true,
        correctOptionId: optionAnswerKey,
        correctAnswerText: typedAnswerKey,
        activeScoreDelta: 60,
        lifetimeScoreDelta: 60,
        activeQuestionScore: 60,
        lifetimeScore: 60,
        energy: EnergyResponse(
          balance: 5,
          maximum: EnergyResponseMaximumEnum.number5,
          unlimited: false,
          asOf: DateTime.utc(2026, 8, 2),
        ),
        attemptState: AttemptState.IN_PROGRESS,
      );

      expect(response.toString(), contains('[REDACTED]'));
      expect(response.toString(), isNot(contains(optionAnswerKey)));
      expect(response.toString(), isNot(contains(typedAnswerKey)));
      expect(response.toJson()['correctOptionId'], optionAnswerKey);
      expect(response.toJson()['correctAnswerText'], typedAnswerKey);
    });
  });
}
