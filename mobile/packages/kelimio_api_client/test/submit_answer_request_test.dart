import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

// tests for SubmitAnswerRequest
void main() {
  final SubmitAnswerRequest? instance = /* SubmitAnswerRequest(...) */ null;
  // TODO add properties to the entity

  group(SubmitAnswerRequest, () {
    // String submissionId
    test('to test the property `submissionId`', () async {
      // TODO
    });

    // String questionRevisionId
    test('to test the property `questionRevisionId`', () async {
      // TODO
    });

    // String selectedOptionId
    test('to test the property `selectedOptionId`', () async {
      // TODO
    });

    // String typedAnswer
    test('to test the property `typedAnswer`', () async {
      // TODO
    });

    // List<MatchingSelection> matches
    test('to test the property `matches`', () async {
      // TODO
    });

    test('redacts sensitive values from toString', () {
      const sensitiveAnswer = 'private-typed-answer';
      const targetItemId = '7c3fb0e8-0fb2-4b4e-8d41-f6bf5ebec2a9';
      const supportItemId = 'dca8ed80-fcab-42a1-acd8-ff69cda41534';
      const secondTargetItemId = '294d18f5-1115-499d-a51a-a97635004e91';
      const secondSupportItemId = '5e83bf52-1ed2-41ef-ae24-09f704621f16';
      final request = SubmitAnswerRequest(
        submissionId: '00000000-0000-4000-8000-000000000001',
        questionRevisionId: '00000000-0000-4000-8000-000000000002',
        typedAnswer: sensitiveAnswer,
      );
      final matchingRequest = SubmitAnswerRequest(
        submissionId: '00000000-0000-4000-8000-000000000003',
        questionRevisionId: '00000000-0000-4000-8000-000000000004',
        matches: [
          MatchingSelection(
            targetItemId: targetItemId,
            supportItemId: supportItemId,
          ),
          MatchingSelection(
            targetItemId: secondTargetItemId,
            supportItemId: secondSupportItemId,
          ),
        ],
      );

      expect(request.toString(), contains('[REDACTED]'));
      expect(request.toString(), isNot(contains(sensitiveAnswer)));
      expect(request.toJson()['typedAnswer'], sensitiveAnswer);
      expect(matchingRequest.toString(), contains('[REDACTED]'));
      expect(matchingRequest.toString(), isNot(contains(targetItemId)));
      expect(matchingRequest.toString(), isNot(contains(supportItemId)));
      expect(matchingRequest.toString(), isNot(contains(secondTargetItemId)));
      expect(matchingRequest.toString(), isNot(contains(secondSupportItemId)));
      expect(matchingRequest.toJson()['matches'], isNotNull);
    });
  });
}
