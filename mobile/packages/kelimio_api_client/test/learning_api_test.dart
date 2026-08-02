import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

/// tests for LearningApi
void main() {
  final instance = KelimioApiClient().getLearningApi();

  group(LearningApi, () {
    // Finish an attempt after all planned questions are answered
    //
    //Future<FinishAttemptResponse> finishAttempt(String attemptId, String idempotencyKey, { String xKelimioClientCapabilities }) async
    test('test finishAttempt', () async {
      // TODO
    });

    // Return the authenticated learner's rebuildable course progress projection
    //
    // Counts and scores are projected only from server-authoritative PostgreSQL facts. When updating is true, the last completed projection is returned while unresolved outbox facts remain, including a delivery awaiting operational replay after exhausting worker retries. Clients must use bounded polling and expose a retry state instead of an endless spinner.
    //
    //Future<CourseProgressResponse> getCourseProgress(String courseId) async
    test('test getCourseProgress', () async {
      // TODO
    });

    // Reconcile one previously committed answer owned by the current user
    //
    // Returns the immutable committed result only when both the attempt and submission belong to the authenticated user. Missing or non-owned records are indistinguishable and return not found.
    //
    //Future<AnswerRecordedResponse> getRecordedAnswer(String attemptId, String submissionId, { String xKelimioClientCapabilities }) async
    test('test getRecordedAnswer', () async {
      // TODO
    });

    // Start an online attempt for the current test revision
    //
    //Future<AttemptResponse> startAttempt(String testId, String idempotencyKey, { String xKelimioClientCapabilities }) async
    test('test startAttempt', () async {
      // TODO
    });

    // Record and evaluate one online answer exactly once
    //
    // Reusing submissionId returns the previously committed response and never creates a second attempt fact, score event, energy event, or outbox event. The complete request body is limited to 8192 bytes and is rejected before JSON allocation or transactional command handling when that limit is exceeded.
    //
    //Future<AnswerRecordedResponse> submitAnswer(String attemptId, String idempotencyKey, SubmitAnswerRequest submitAnswerRequest, { String xKelimioClientCapabilities }) async
    test('test submitAnswer', () async {
      // TODO
    });
  });
}
