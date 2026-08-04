import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

// tests for CourseImportUploadInstructions
void main() {
  final CourseImportUploadInstructions?
  instance = /* CourseImportUploadInstructions(...) */ null;
  // TODO add properties to the entity

  group(CourseImportUploadInstructions, () {
    // Earliest exact expiry among the signed part-upload URLs in this response; no URL in the response remains valid after this instant. This can be earlier than the import session's uploadExpiresAt value.
    // DateTime expiresAt
    test('to test the property `expiresAt`', () async {
      // TODO
    });

    // List<CourseImportPresignedPart> parts
    test('to test the property `parts`', () async {
      // TODO
    });
  });
}
