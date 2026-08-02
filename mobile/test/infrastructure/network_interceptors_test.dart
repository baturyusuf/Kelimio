import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/infrastructure/network/interceptors.dart';

void main() {
  test(
    'client capability interceptor advertises the matching renderer',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://kelimio.invalid'));
      final adapter = _RecordingAdapter();
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(ClientCapabilityInterceptor());

      await dio.get<void>(
        '/v1/catalog',
        options: Options(
          headers: const {'X-Kelimio-Client-Capabilities': 'stale.value'},
        ),
      );

      expect(adapter.request, isNotNull);
      expect(
        adapter.request!.headers['X-Kelimio-Client-Capabilities'],
        ClientCapabilityInterceptor.matchingV1,
      );
    },
  );
}

final class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: const {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
