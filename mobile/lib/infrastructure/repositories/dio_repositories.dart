import 'package:dio/dio.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart' as api;

import '../../domain/catalog/catalog.dart';
import '../../domain/development/development.dart';
import '../../domain/energy/energy.dart';
import '../../domain/failures.dart';
import '../../domain/learning/learning.dart';
import '../../domain/profile/profile.dart';
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
    required AnswerInput answer,
    required String submissionId,
  }) => _guard(() async {
    final response = await _api.submitAnswer(
      attemptId: attemptId,
      idempotencyKey: submissionId,
      submitAnswerRequest: api.SubmitAnswerRequest(
        submissionId: submissionId,
        questionRevisionId: questionRevisionId,
        selectedOptionId: switch (answer) {
          final OptionAnswerInput option => option.selectedOptionId,
          TypedAnswerInput() => null,
        },
        typedAnswer: switch (answer) {
          OptionAnswerInput() => null,
          final TypedAnswerInput typed => typed.rawValueForSubmission,
        },
      ),
      extra: {RequestMetadata.idempotencyKey: submissionId},
    );
    _discardRequestBody(response.requestOptions);
    final data = response.data;
    if (data == null) {
      throw const ProtocolFailure('Answer response body was empty');
    }
    return mapAnswerFeedback(data);
  }, redactRequestBodyOnError: true);

  @override
  Future<AnswerFeedback?> getRecordedAnswer({
    required String attemptId,
    required String submissionId,
  }) async {
    try {
      final response = await _api.getRecordedAnswer(
        attemptId: attemptId,
        submissionId: submissionId,
      );
      final data = response.data;
      if (data == null) {
        throw const ProtocolFailure('Recorded-answer response body was empty');
      }
      return mapAnswerFeedback(data);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      throw _failures.map(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw UnknownFailure(cause: error);
    }
  }

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

  Future<T> _guard<T>(
    Future<T> Function() request, {
    bool redactRequestBodyOnError = false,
  }) async {
    try {
      return await request();
    } on DioException catch (error) {
      var mappedError = error;
      if (redactRequestBodyOnError) {
        _discardRequestBody(error.requestOptions);
        final responseOptions = error.response?.requestOptions;
        if (responseOptions != null &&
            !identical(responseOptions, error.requestOptions)) {
          _discardRequestBody(responseOptions);
        }
        mappedError = _redactedAnswerFailure(error);
      }
      throw _failures.map(mappedError);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw UnknownFailure(cause: error);
    }
  }

  void _discardRequestBody(RequestOptions options) {
    options.data = null;
  }

  DioException _redactedAnswerFailure(DioException error) {
    final response = error.response;
    final rawCode = response?.data is Map<Object?, Object?>
        ? (response!.data as Map<Object?, Object?>)['code']
        : null;
    final normalizedCode = rawCode is String ? rawCode.toUpperCase() : null;
    final safeCode = _answerFailureCodes.contains(normalizedCode)
        ? normalizedCode
        : null;
    final safeResponse = response == null
        ? null
        : Response<Object?>(
            requestOptions: error.requestOptions,
            data: safeCode == null ? null : <String, Object?>{'code': safeCode},
            headers: response.headers,
            statusCode: response.statusCode,
            isRedirect: response.isRedirect,
            redirects: response.redirects,
          );
    return DioException(
      requestOptions: error.requestOptions,
      response: safeResponse,
      type: error.type,
      message: 'Answer submission failed',
    );
  }

  static const _answerFailureCodes = {
    'CONTENT_CHANGED',
    'TEST_CONTENT_CHANGED',
    'QUESTION_REVISION_MISMATCH',
    'ENERGY_DEPLETED',
    'INSUFFICIENT_ENERGY',
  };
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

final class GeneratedProfileRepository implements ProfileRepository {
  const GeneratedProfileRepository(this._api, this._failures);

  final api.ProfileApi _api;
  final DioFailureMapper _failures;

  @override
  Future<UserProfile> getMe() => _guard(() async {
    final response = await _api.getMe();
    final data = response.data;
    if (data == null) {
      throw const ProtocolFailure('Profile response body was empty');
    }
    return _mapProfile(data);
  });

  @override
  Future<UserProfile> completeSetup({
    required ProfileSetupInput input,
    required String commandId,
  }) => _guard(() async {
    final appLocale = api.ProfileSetupRequestAppLocaleEnum.values.firstWhere(
      (value) => value.value == input.appLocale,
      orElse: () => throw const ProtocolFailure(
        'Unsupported application locale reached the profile repository',
      ),
    );
    final response = await _api.completeProfileSetup(
      idempotencyKey: commandId,
      profileSetupRequest: api.ProfileSetupRequest(
        displayName: input.displayName,
        appLocale: appLocale,
        activeTargetLanguage: input.activeTargetLanguage,
        preferredSupportLanguage: input.preferredSupportLanguage,
        timeZone: input.timeZone,
      ),
      extra: {RequestMetadata.idempotencyKey: commandId},
    );
    final data = response.data;
    if (data == null) {
      throw const ProtocolFailure('Profile setup response body was empty');
    }
    return _mapProfile(data);
  });

  UserProfile _mapProfile(api.MeResponse value) => UserProfile(
    id: value.id,
    displayName: value.displayName,
    appLocale: value.appLocale,
    activeTargetLanguage: value.activeTargetLanguage,
    preferredSupportLanguage: value.preferredSupportLanguage,
    timeZone: value.timeZone,
    profileVersion: value.profileVersion,
    setupStatus:
        value.profileSetupStatus ==
            api.MeResponseProfileSetupStatusEnum.COMPLETE
        ? ProfileSetupStatus.complete
        : ProfileSetupStatus.required,
  );

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
