import 'package:dio/dio.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart' as api;

import '../../domain/catalog/catalog.dart';
import '../../domain/development/development.dart';
import '../../domain/energy/energy.dart';
import '../../domain/failures.dart';
import '../../domain/learning/learning.dart';
import '../network/failure_mapper.dart';
import '../network/request_metadata.dart';
import 'api_decoders.dart';

final class GeneratedCatalogRepository implements CatalogRepository {
  const GeneratedCatalogRepository(
    this._catalog,
    this._enrollment,
    this._learning,
    this._failures,
  );

  final api.CatalogApi _catalog;
  final api.EnrollmentApi _enrollment;
  final api.LearningApi _learning;
  final DioFailureMapper _failures;

  @override
  Future<CatalogPage> listCourses({String? cursor, int limit = 20}) =>
      _guard(() async {
        final response = await _catalog.listCatalogCourses(
          cursor: cursor,
          limit: limit,
        );
        final data = response.data;
        if (data == null) {
          throw const ProtocolFailure('Catalog response body was empty');
        }
        return mapCatalogPage(data);
      });

  @override
  Future<CourseDetail> getCourse(String courseId) => _guard(() async {
    final response = await _catalog.getCourse(courseId: courseId);
    final data = response.data;
    if (data == null) {
      throw const ProtocolFailure('Course response body was empty');
    }
    return mapCourseDetail(data);
  });

  @override
  Future<CourseProgress> getProgress(String courseId) => _guard(() async {
    final response = await _learning.getCourseProgress(courseId: courseId);
    final data = response.data;
    if (data == null) {
      throw const ProtocolFailure('Course progress response body was empty');
    }
    return CourseProgress(
      courseId: data.courseId,
      answeredQuestions: data.answeredQuestions,
      correctAnswers: data.correctAnswers,
      completedAttempts: data.completedAttempts,
      passedAttempts: data.passedAttempts,
      activeScore: data.activeScore,
      lifetimeScore: data.lifetimeScore,
      projectionVersion: data.projectionVersion,
      updating: data.updating,
      updatedAt: data.updatedAt,
    );
  });

  @override
  Future<Enrollment> enroll({
    required String courseId,
    required String supportLanguage,
    required String commandId,
  }) => _guard(() async {
    final response = await _enrollment.enrollInCourse(
      courseId: courseId,
      idempotencyKey: commandId,
      createEnrollmentRequest: api.CreateEnrollmentRequest(
        supportLanguage: supportLanguage,
      ),
      extra: {RequestMetadata.idempotencyKey: commandId},
    );
    final data = response.data;
    if (data == null) {
      throw const ProtocolFailure('Enrollment response body was empty');
    }
    return mapEnrollment(data);
  });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw _failures.map(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw UnknownFailure(cause: error);
    }
  }
}

final class GeneratedLearningRepository implements LearningRepository {
  const GeneratedLearningRepository(this._api, this._failures);

  final api.LearningApi _api;
  final DioFailureMapper _failures;

  @override
  Future<AttemptSession> startAttempt({
    required String testId,
    required String commandId,
  }) => _guard(() async {
    final response = await _api.startAttempt(
      testId: testId,
      idempotencyKey: commandId,
      extra: {RequestMetadata.idempotencyKey: commandId},
    );
    final data = response.data;
    if (data == null) {
      throw const ProtocolFailure('Attempt response body was empty');
    }
    return mapAttempt(data);
  });

  @override
  Future<AnswerFeedback> submitAnswer({
    required String attemptId,
    required String questionRevisionId,
    required String selectedOptionId,
    required String submissionId,
  }) => _guard(() async {
    final response = await _api.submitAnswer(
      attemptId: attemptId,
      idempotencyKey: submissionId,
      submitAnswerRequest: api.SubmitAnswerRequest(
        submissionId: submissionId,
        questionRevisionId: questionRevisionId,
        selectedOptionId: selectedOptionId,
      ),
      extra: {RequestMetadata.idempotencyKey: submissionId},
    );
    final data = response.data;
    if (data == null) {
      throw const ProtocolFailure('Answer response body was empty');
    }
    return mapAnswerFeedback(data);
  });

  @override
  Future<AttemptResult> finishAttempt({
    required String attemptId,
    required String commandId,
  }) => _guard(() async {
    final response = await _api.finishAttempt(
      attemptId: attemptId,
      idempotencyKey: commandId,
      extra: {RequestMetadata.idempotencyKey: commandId},
    );
    final data = response.data;
    if (data == null) {
      throw const ProtocolFailure('Finish response body was empty');
    }
    return mapAttemptResult(data);
  });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw _failures.map(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw UnknownFailure(cause: error);
    }
  }
}

final class GeneratedDevelopmentRepository implements DevelopmentRepository {
  const GeneratedDevelopmentRepository(this._api, this._failures);

  final api.DevelopmentApi _api;
  final DioFailureMapper _failures;

  @override
  Future<LocalStarterCourseInstall> installStarterCourse({
    required String commandId,
  }) => _guard(() async {
    final response = await _api.installLocalStarterCourse(
      idempotencyKey: commandId,
      extra: {RequestMetadata.idempotencyKey: commandId},
    );
    final data = response.data;
    if (data == null) {
      throw const ProtocolFailure('Starter-course response body was empty');
    }
    return LocalStarterCourseInstall(
      courseId: data.courseId,
      created: data.created,
      sourceWorkbookSha256: data.sourceWorkbookSha256,
    );
  });

  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw _failures.map(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw UnknownFailure(cause: error);
    }
  }
}

final class GeneratedEnergyRepository implements EnergyRepository {
  const GeneratedEnergyRepository(this._api, this._failures);

  final api.EnergyApi _api;
  final DioFailureMapper _failures;

  @override
  Future<Energy> getEnergy() async {
    try {
      final response = await _api.getEnergy();
      final data = response.data;
      if (data == null) {
        throw const ProtocolFailure('Energy response body was empty');
      }
      return mapEnergy(data);
    } on DioException catch (error) {
      throw _failures.map(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw UnknownFailure(cause: error);
    }
  }
}
