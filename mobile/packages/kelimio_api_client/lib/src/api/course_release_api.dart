//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'dart:async';

// ignore: unused_import
import 'dart:convert';
import 'package:kelimio_api_client/src/deserialize.dart';
import 'package:dio/dio.dart';

import 'package:kelimio_api_client/src/model/activate_course_release_request.dart';
import 'package:kelimio_api_client/src/model/course_release_abandonment_response.dart';
import 'package:kelimio_api_client/src/model/course_release_activation_response.dart';
import 'package:kelimio_api_client/src/model/course_release_impact_response.dart';
import 'package:kelimio_api_client/src/model/problem.dart';

class CourseReleaseApi {
  final Dio _dio;

  const CourseReleaseApi(this._dio);

  /// Mark an inactive draft release as abandoned without deleting its facts
  /// Atomically changes only a DRAFT release to ABANDONED and appends an owner-scoped abandonment fact plus an outbox event. Active and historical releases cannot be abandoned.
  ///
  /// Parameters:
  /// * [courseId]
  /// * [releaseId]
  /// * [idempotencyKey] - Stable UUID generated once for the logical command.
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [CourseReleaseAbandonmentResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CourseReleaseAbandonmentResponse>> abandonCourseRelease({
    required String courseId,
    required String releaseId,
    required String idempotencyKey,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/courses/{courseId}/releases/{releaseId}/abandon'
        .replaceAll(
          '{'
          r'courseId'
          '}',
          courseId.toString(),
        )
        .replaceAll(
          '{'
          r'releaseId'
          '}',
          releaseId.toString(),
        );
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{
        r'Idempotency-Key': idempotencyKey,
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

    CourseReleaseAbandonmentResponse? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              CourseReleaseAbandonmentResponse,
              CourseReleaseAbandonmentResponse
            >(rawData, 'CourseReleaseAbandonmentResponse', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<CourseReleaseAbandonmentResponse>(
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

  /// Publish or roll back to an exact reviewed immutable release
  /// Atomically activates the reviewed release, appends the activation and outbox facts, and creates a cutoff-bound progress reprojection job. In production this endpoint additionally requires the server-side teacher feature gate, Cognito teacher-group eligibility, and current versioned authoring-terms acceptance.
  ///
  /// Parameters:
  /// * [courseId]
  /// * [releaseId]
  /// * [idempotencyKey] - Stable UUID generated once for the logical command.
  /// * [activateCourseReleaseRequest]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [CourseReleaseActivationResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CourseReleaseActivationResponse>> activateCourseRelease({
    required String courseId,
    required String releaseId,
    required String idempotencyKey,
    required ActivateCourseReleaseRequest activateCourseReleaseRequest,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/courses/{courseId}/releases/{releaseId}/activate'
        .replaceAll(
          '{'
          r'courseId'
          '}',
          courseId.toString(),
        )
        .replaceAll(
          '{'
          r'releaseId'
          '}',
          releaseId.toString(),
        );
    final _options = Options(
      method: r'POST',
      headers: <String, dynamic>{
        r'Idempotency-Key': idempotencyKey,
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
      _bodyData = jsonEncode(activateCourseReleaseRequest);
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

    CourseReleaseActivationResponse? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              CourseReleaseActivationResponse,
              CourseReleaseActivationResponse
            >(rawData, 'CourseReleaseActivationResponse', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<CourseReleaseActivationResponse>(
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

  /// Review the exact owner-scoped impact of activating an immutable release
  /// Returns a canonical binding digest over the locked release manifests and current active release. The enrollment count is advisory and deliberately excluded from the binding because projection membership is cutoff-bound at activation.
  ///
  /// Parameters:
  /// * [courseId]
  /// * [releaseId]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [CourseReleaseImpactResponse] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CourseReleaseImpactResponse>> getCourseReleaseImpact({
    required String courseId,
    required String releaseId,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/courses/{courseId}/releases/{releaseId}/impact'
        .replaceAll(
          '{'
          r'courseId'
          '}',
          courseId.toString(),
        )
        .replaceAll(
          '{'
          r'releaseId'
          '}',
          releaseId.toString(),
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

    CourseReleaseImpactResponse? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<
              CourseReleaseImpactResponse,
              CourseReleaseImpactResponse
            >(rawData, 'CourseReleaseImpactResponse', growable: true);
    } catch (error, stackTrace) {
      throw DioException(
        requestOptions: _response.requestOptions,
        response: _response,
        type: DioExceptionType.unknown,
        error: error,
        stackTrace: stackTrace,
      );
    }

    return Response<CourseReleaseImpactResponse>(
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
