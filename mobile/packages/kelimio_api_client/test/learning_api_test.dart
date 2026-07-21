import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

/// tests for LearningApi
void main() {
  final instance = KelimioApiClient().getLearningApi();

  group(LearningApi, () {
    // Finish an attempt after all planned questions are answered
    //
    //Future<FinishAttemptResponse> finishAttempt(String attemptId, String idempotencyKey) async
    test('test finishAttempt', () async {
      // TODO
    });

    // Start an online attempt for the current test revision
    //
    //Future<AttemptResponse> startAttempt(String testId, String idempotencyKey) async
    test('test startAttempt', () async {
      // TODO
    });

    // Record and evaluate one online answer exactly once
    //
    // Reusing submissionId returns the previously committed response and never creates a second attempt fact, score event, energy event, or outbox event.
    //
    //Future<AnswerRecordedResponse> submitAnswer(String attemptId, String idempotencyKey, SubmitAnswerRequest submitAnswerRequest) async
    test('test submitAnswer', () async {
      // TODO
    });
  });
}
