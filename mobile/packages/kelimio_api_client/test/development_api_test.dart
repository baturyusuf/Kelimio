import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

/// tests for DevelopmentApi
void main() {
  final instance = KelimioApiClient().getDevelopmentApi();

  group(DevelopmentApi, () {
    // Install the authenticated owner's local starter course idempotently
    //
    // Available only when the backend is explicitly running in the local environment with starter-course installation enabled. It creates one immutable Type-A/Type-B/Type-C English-support release derived from the reviewed workbook subset and never creates users or learning results.
    //
    //Future<LocalStarterCourseResponse> installLocalStarterCourse(String idempotencyKey) async
    test('test installLocalStarterCourse', () async {
      // TODO
    });
  });
}
