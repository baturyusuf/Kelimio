//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'dart:async';

// ignore: unused_import
import 'dart:convert';
import 'package:kelimio_api_client/src/deserialize.dart';
import 'package:dio/dio.dart';

import 'package:kelimio_api_client/src/model/answer_recorded_response.dart';
import 'package:kelimio_api_client/src/model/attempt_response.dart';
import 'package:kelimio_api_client/src/model/course_progress_response.dart';
import 'package:kelimio_api_client/src/model/finish_attempt_response.dart';
import 'package:kelimio_api_client/src/model/learning_summary.dart';
import 'package:kelimio_api_client/src/model/offline_package.dart';
import 'package:kelimio_api_client/src/model/problem.dart';
import 'package:kelimio_api_client/src/model/submit_answer_request.dart';

class LearningApi {
  final Dio _dio;

  const LearningApi(this._dio);

  /// Finish an attempt after all planned questions are answered
  ///
  ///
  /// Parameters:
  /// * [attemptId]
  /// * [idempotencyKey] - Stable UUID generated once for the logical command.
  /// * [xKelimioClientCapabilities] - Comma-separated bounded capability tokens implemented by the client. Missing means the empty set; this is a compatibility signal, not authorization.
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [FinishAttemptResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<FinishAttemptResponse>> finishAttempt({
    required String attemptId,
    required String idempotencyKey,
    String? xKelimioClientCapabilities,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/attempts/{attemptId}/finish'.replaceAll(
      '{'
      r'attemptId'
      '}',
      attemptId.toString(),
    );
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{
        r'Idempotency-Key': idempotencyKey,
        if (xKelimioClientCapabilities != null)
          r'X-Kelimio-Client-Capabilities': xKelimioClientCapabilities,
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'http', 'scheme': 'bearer', 'name': 'bearerAuth'},
        ],
        ...?extra,
      },
      validateStatus: validateStatus,
    );

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    FinishAttemptResponse? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<FinishAttemptResponse, FinishAttemptResponse>(
              rawData,
              'FinishAttemptResponse',
              growable: true,
            );
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<FinishAttemptResponse>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// Return the authenticated learner&#39;s rebuildable course progress projection
  /// Counts and scores are projected only from server-authoritative PostgreSQL facts. When updating is true, the last completed projection is returned while unresolved outbox facts remain, including a delivery awaiting operational replay after exhausting worker retries. Clients must use bounded polling and expose a retry state instead of an endless spinner.
  ///
  /// Parameters:
  /// * [courseId]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [CourseProgressResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CourseProgressResponse>> getCourseProgress({
    required String courseId,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/courses/{courseId}/progress'.replaceAll(
      '{'
      r'courseId'
      '}',
      courseId.toString(),
    );
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{...?headers},
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'http', 'scheme': 'bearer', 'name': 'bearerAuth'},
        ],
        ...?extra,
      },
      validateStatus: validateStatus,
    );

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    CourseProgressResponse? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<CourseProgressResponse, CourseProgressResponse>(
              rawData,
              'CourseProgressResponse',
              growable: true,
            );
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<CourseProgressResponse>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// Return authoritative aggregate progress, current streak, and recent completed attempts
  ///
  ///
  /// Parameters:
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [LearningSummary] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<LearningSummary>> getLearningSummary({
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/me/learning-summary';
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{...?headers},
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'http', 'scheme': 'bearer', 'name': 'bearerAuth'},
        ],
        ...?extra,
      },
      validateStatus: validateStatus,
    );

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    LearningSummary? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<LearningSummary, LearningSummary>(
              rawData,
              'LearningSummary',
              growable: true,
            );
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<LearningSummary>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// Create or reuse an immutable scoreless-practice package and return a short-lived download URL
  ///
  ///
  /// Parameters:
  /// * [courseId]
  /// * [supportLanguage]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [OfflinePackage] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<OfflinePackage>> getOfflineCoursePackage({
    required String courseId,
    required String supportLanguage,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/courses/{courseId}/offline-package'.replaceAll(
      '{'
      r'courseId'
      '}',
      courseId.toString(),
    );
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{...?headers},
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'http', 'scheme': 'bearer', 'name': 'bearerAuth'},
        ],
        ...?extra,
      },
      validateStatus: validateStatus,
    );

    final _queryParameters = <String, dynamic>{
      r'supportLanguage': supportLanguage,
    };

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      queryParameters: _queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    OfflinePackage? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<OfflinePackage, OfflinePackage>(
              rawData,
              'OfflinePackage',
              growable: true,
            );
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<OfflinePackage>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// Reconcile one previously committed answer owned by the current user
  /// Returns the immutable committed result only when both the attempt and submission belong to the authenticated user. Missing or non-owned records are indistinguishable and return not found.
  ///
  /// Parameters:
  /// * [attemptId]
  /// * [submissionId]
  /// * [xKelimioClientCapabilities] - Comma-separated bounded capability tokens implemented by the client. Missing means the empty set; this is a compatibility signal, not authorization.
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [AnswerRecordedResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<AnswerRecordedResponse>> getRecordedAnswer({
    required String attemptId,
    required String submissionId,
    String? xKelimioClientCapabilities,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/attempts/{attemptId}/answers/{submissionId}'
        .replaceAll(
          '{'
          r'attemptId'
          '}',
          attemptId.toString(),
        )
        .replaceAll(
          '{'
          r'submissionId'
          '}',
          submissionId.toString(),
        );
    final _options = Options(
      method: r'GET',
      headers: <String, dynamic>{
        if (xKelimioClientCapabilities != null)
          r'X-Kelimio-Client-Capabilities': xKelimioClientCapabilities,
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'http', 'scheme': 'bearer', 'name': 'bearerAuth'},
        ],
        ...?extra,
      },
      validateStatus: validateStatus,
    );

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    AnswerRecordedResponse? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<AnswerRecordedResponse, AnswerRecordedResponse>(
              rawData,
              'AnswerRecordedResponse',
              growable: true,
            );
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<AnswerRecordedResponse>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// Start an online attempt for the current test revision
  ///
  ///
  /// Parameters:
  /// * [testId]
  /// * [idempotencyKey] - Stable UUID generated once for the logical command.
  /// * [xKelimioClientCapabilities] - Comma-separated bounded capability tokens implemented by the client. Missing means the empty set; this is a compatibility signal, not authorization.
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [AttemptResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<AttemptResponse>> startAttempt({
    required String testId,
    required String idempotencyKey,
    String? xKelimioClientCapabilities,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/tests/{testId}/attempts'.replaceAll(
      '{'
      r'testId'
      '}',
      testId.toString(),
    );
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{
        r'Idempotency-Key': idempotencyKey,
        if (xKelimioClientCapabilities != null)
          r'X-Kelimio-Client-Capabilities': xKelimioClientCapabilities,
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'http', 'scheme': 'bearer', 'name': 'bearerAuth'},
        ],
        ...?extra,
      },
      validateStatus: validateStatus,
    );

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    AttemptResponse? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<AttemptResponse, AttemptResponse>(
              rawData,
              'AttemptResponse',
              growable: true,
            );
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<AttemptResponse>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }

  /// Record and evaluate one online answer exactly once
  /// Reusing submissionId returns the previously committed response and never creates a second attempt fact, score event, energy event, or outbox event. The complete request body is limited to 8192 bytes and is rejected before JSON allocation or transactional command handling when that limit is exceeded.
  ///
  /// Parameters:
  /// * [attemptId]
  /// * [idempotencyKey] - Stable UUID generated once for the logical command.
  /// * [submitAnswerRequest]
  /// * [xKelimioClientCapabilities] - Comma-separated bounded capability tokens implemented by the client. Missing means the empty set; this is a compatibility signal, not authorization.
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [AnswerRecordedResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<AnswerRecordedResponse>> submitAnswer({
    required String attemptId,
    required String idempotencyKey,
    SubmitAnswerRequest? submitAnswerRequest,
    String? xKelimioClientCapabilities,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/attempts/{attemptId}/answers'.replaceAll(
      '{'
      r'attemptId'
      '}',
      attemptId.toString(),
    );
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{
        r'Idempotency-Key': idempotencyKey,
        if (xKelimioClientCapabilities != null)
          r'X-Kelimio-Client-Capabilities': xKelimioClientCapabilities,
        ...?headers,
      },
      extra: <String, dynamic>{
        'secure': <Map<String, String>>[
          {'type': 'http', 'scheme': 'bearer', 'name': 'bearerAuth'},
        ],
        ...?extra,
      },
      contentType: 'application/json',
      validateStatus: validateStatus,
    );

    dynamic _bodyData;

    try {
      _bodyData = jsonEncode(submitAnswerRequest);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _options.compose(_dio.options, _path),
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    final _response = await _dio.request<Object>(
      _path,
      data: _bodyData,
      options: _options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    AnswerRecordedResponse? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<AnswerRecordedResponse, AnswerRecordedResponse>(
              rawData,
              'AnswerRecordedResponse',
              growable: true,
            );
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<AnswerRecordedResponse>(
      data: _responseData,
      headers: _response.headers,
      isRedirect: _response.isRedirect,
      requestOptions: _response.requestOptions,
      redirects: _response.redirects,
      statusCode: _response.statusCode,
      statusMessage: _response.statusMessage,
      extra: _response.extra,
    );
  }
}
