import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/domain/failures.dart';
import 'package:kelimio_mobile/infrastructure/network/failure_mapper.dart';

void main() {
  const mapper = DioFailureMapper();

  test('maps 401 to an authentication failure', () {
    final failure = mapper.map(_responseError(401));

    expect(failure, isA<AuthenticationRequiredFailure>());
  });

  test('keeps authenticated 403 responses distinct from authentication', () {
    final failure = mapper.map(
      _responseError(
        403,
        data: {'detail': 'An active course enrollment is required.'},
      ),
    );

    expect(failure, isA<ForbiddenFailure>());
    expect((failure as ForbiddenFailure).detail, contains('enrollment'));
  });

  test('maps oversized HTTP 413 answer payloads to validation', () {
    final failure = mapper.map(_responseError(413));

    expect(failure, isA<ValidationFailure>());
  });
}

DioException _responseError(int status, {Object? data}) {
  final request = RequestOptions(path: '/test');
  return DioException.badResponse(
    statusCode: status,
    requestOptions: request,
    response: Response<Object?>(
      requestOptions: request,
      statusCode: status,
      data: data,
    ),
  );
}
