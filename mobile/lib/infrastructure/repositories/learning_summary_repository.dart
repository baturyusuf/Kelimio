import 'package:dio/dio.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart' as api;

import '../../domain/failures.dart';
import '../../domain/learning/learning_summary.dart';
import '../network/failure_mapper.dart';

final class GeneratedLearningSummaryRepository
    implements LearningSummaryRepository {
  const GeneratedLearningSummaryRepository(this._api, this._failures);
  final api.LearningApi _api;
  final DioFailureMapper _failures;
  @override
  Future<LearningSummary> get() async {
    try {
      final value = (await _api.getLearningSummary()).data;
      if (value == null) {
        throw const ProtocolFailure('Learning summary body was empty');
      }
      return LearningSummary(
        lifetimeScore: value.lifetimeScore,
        completedAttempts: value.completedAttempts,
        passedAttempts: value.passedAttempts,
        enrolledCourses: value.enrolledCourses,
        completedCourses: value.completedCourses,
        currentStreakDays: value.currentStreakDays,
        history: value.history
            .map(
              (item) => LearningHistoryItem(
                courseName: item.courseName,
                testTitle: item.testTitle,
                passed: item.status.value == 'COMPLETED_PASS',
                correctCount: item.correctCount,
                totalQuestions: item.totalQuestions,
                finishedAt: item.finishedAt,
              ),
            )
            .toList(growable: false),
      );
    } on DioException catch (error) {
      throw _failures.map(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw UnknownFailure(cause: error);
    }
  }
}
