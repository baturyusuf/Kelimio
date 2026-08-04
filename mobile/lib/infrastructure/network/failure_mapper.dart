import 'package:dio/dio.dart';

import '../../domain/failures.dart';

final class DioFailureMapper {
  const DioFailureMapper();

  AppFailure map(DioException error) {
    final underlying = error.error;
    if (underlying is AppFailure) {
      return underlying;
    }
    final requestId = error.response?.headers.value('x-request-id');
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return TimeoutFailure(requestId: requestId, cause: error);
      case DioExceptionType.connectionError:
        return NetworkFailure(requestId: requestId, cause: error);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return UnknownFailure(requestId: requestId, cause: error);
      case DioExceptionType.badResponse:
        return _fromResponse(error, requestId);
    }
  }

  AppFailure _fromResponse(DioException error, String? headerRequestId) {
    final response = error.response;
    final status = response?.statusCode ?? 500;
    final problem = _problem(response?.data);
    final requestId = problem.requestId ?? headerRequestId;
    final normalizedCode = problem.code?.toUpperCase();

    if (status == 401) {
      return AuthenticationRequiredFailure(requestId: requestId, cause: error);
    }
    if (status == 403) {
      return ForbiddenFailure(
        code: problem.code,
        detail: problem.detail,
        requestId: requestId,
        cause: error,
      );
    }
    if (_contentChangedCodes.contains(normalizedCode)) {
      return ContentChangedFailure(
        detail: problem.detail,
        requestId: requestId,
        cause: error,
      );
    }
    if (_energyCodes.contains(normalizedCode)) {
      return EnergyDepletedFailure(
        detail: problem.detail,
        requestId: requestId,
        cause: error,
      );
    }
    final operatingMode = _operatingModeCodes[normalizedCode];
    if (status == 503 && operatingMode != null) {
      return OperatingModeFailure(
        mode: operatingMode,
        requestId: requestId,
        cause: error,
      );
    }
    if (status == 409) {
      return ConflictFailure(
        code: problem.code,
        detail: problem.detail,
        requestId: requestId,
        cause: error,
      );
    }
    if (status == 400 || status == 413 || status == 422) {
      return ValidationFailure(
        code: problem.code,
        detail: problem.detail,
        requestId: requestId,
        cause: error,
      );
    }
    return ServerFailure(
      status: status,
      code: problem.code,
      detail: problem.detail,
      requestId: requestId,
      cause: error,
    );
  }

  static const _contentChangedCodes = {
    'CONTENT_CHANGED',
    'TEST_CONTENT_CHANGED',
    'QUESTION_REVISION_MISMATCH',
  };
  static const _energyCodes = {'ENERGY_DEPLETED', 'INSUFFICIENT_ENERGY'};
  static const _operatingModeCodes = {
    'COST_CONSERVATION': ServiceOperatingMode.conserve,
    'COST_READ_ONLY': ServiceOperatingMode.readOnly,
    'COST_SUSPENDED': ServiceOperatingMode.suspended,
  };
}

({String? code, String? detail, String? requestId}) _problem(Object? data) {
  if (data is! Map<Object?, Object?>) {
    return (code: null, detail: null, requestId: null);
  }
  return (
    code: data['code'] is String ? data['code'] as String : null,
    detail: data['detail'] is String ? data['detail'] as String : null,
    requestId: data['requestId'] is String ? data['requestId'] as String : null,
  );
}
