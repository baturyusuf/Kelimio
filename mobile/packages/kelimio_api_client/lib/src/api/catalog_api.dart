//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'dart:async';

// ignore: unused_import
import 'dart:convert';
import 'package:kelimio_api_client/src/deserialize.dart';
import 'package:dio/dio.dart';

import 'package:kelimio_api_client/src/model/course_detail.dart';
import 'package:kelimio_api_client/src/model/course_page.dart';
import 'package:kelimio_api_client/src/model/problem.dart';

class CatalogApi {
  final Dio _dio;

  const CatalogApi(this._dio);

  /// Return course details visible to the authenticated user
  ///
  ///
  /// Parameters:
  /// * [courseId]
  /// * [xKelimioClientCapabilities] - Comma-separated bounded capability tokens implemented by the client. Missing means the empty set; this is a compatibility signal, not authorization.
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [CourseDetail] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CourseDetail>> getCourse({
    required String courseId,
    String? xKelimioClientCapabilities,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/courses/{courseId}'.replaceAll(
      '{'
      r'courseId'
      '}',
      courseId.toString(),
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

    CourseDetail? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<CourseDetail, CourseDetail>(
              rawData,
              'CourseDetail',
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

    return Response<CourseDetail>(
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

  /// List public, published courses
  ///
  ///
  /// Parameters:
  /// * [xKelimioClientCapabilities] - Comma-separated bounded capability tokens implemented by the client. Missing means the empty set; this is a compatibility signal, not authorization.
  /// * [cursor] - Opaque tamper-evident cursor bound to the authenticated owner, import, immutable preview/report identity, and position. It contains no workbook text or storage coordinates.
  /// * [limit]
  /// * [targetLanguage]
  /// * [supportLanguage]
  /// * [cancelToken] - A [CancelToken] that can be used to cancel the operation
  /// * [headers] - Can be used to add additional headers to the request
  /// * [extras] - Can be used to add flags to the request
  /// * [validateStatus] - A [ValidateStatus] callback that can be used to determine request success based on the HTTP status of the response
  /// * [onSendProgress] - A [ProgressCallback] that can be used to get the send progress
  /// * [onReceiveProgress] - A [ProgressCallback] that can be used to get the receive progress
  ///
  /// Returns a [Future] containing a [Response] with a [CoursePage] as data
  /// Throws [DioException] if API call or serialization fails
  Future<Response<CoursePage>> listCatalogCourses({
    String? xKelimioClientCapabilities,
    String? cursor,
    int? limit = 20,
    String? targetLanguage,
    String? supportLanguage,
    CancelToken? cancelToken,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? extra,
    ValidateStatus? validateStatus,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    final _path = r'/v1/catalog/courses';
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

    final _queryParameters = <String, dynamic>{
      if (cursor != null) r'cursor': cursor,
      if (limit != null) r'limit': limit,
      if (targetLanguage != null) r'targetLanguage': targetLanguage,
      if (supportLanguage != null) r'supportLanguage': supportLanguage,
    };

    final _response = await _dio.request<Object>(
      _path,
      options: _options,
      queryParameters: _queryParameters,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );

    CoursePage? _responseData;

    try {
      final rawData = _response.data;
      _responseData = rawData == null
          ? null
          : deserialize<CoursePage, CoursePage>(
              rawData,
              'CoursePage',
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

    return Response<CoursePage>(
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
