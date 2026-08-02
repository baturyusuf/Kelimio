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

    test('redacts sensitive values from toString', () {
      const sensitiveAnswer = 'private-typed-answer';
      final request = SubmitAnswerRequest(
        submissionId: '00000000-0000-4000-8000-000000000001',
        questionRevisionId: '00000000-0000-4000-8000-000000000002',
        typedAnswer: sensitiveAnswer,
      );

      expect(request.toString(), contains('[REDACTED]'));
      expect(request.toString(), isNot(contains(sensitiveAnswer)));
      expect(request.toJson()['typedAnswer'], sensitiveAnswer);
    });
  });
}
