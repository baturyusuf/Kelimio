import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

/// tests for CatalogApi
void main() {
  final instance = KelimioApiClient().getCatalogApi();

  group(CatalogApi, () {
    // Return course details visible to the authenticated user
    //
    //Future<CourseDetail> getCourse(String courseId, { String xKelimioClientCapabilities }) async
    test('test getCourse', () async {
      // TODO
    });

    // List public, published courses
    //
    //Future<CoursePage> listCatalogCourses({ String xKelimioClientCapabilities, String cursor, int limit, String targetLanguage, String supportLanguage, String q, String accessType }) async
    test('test listCatalogCourses', () async {
      // TODO
    });
  });
}
