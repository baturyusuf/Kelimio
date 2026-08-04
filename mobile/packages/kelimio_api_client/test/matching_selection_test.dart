import 'package:test/test.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart';

// tests for MatchingSelection
void main() {
  final MatchingSelection? instance = /* MatchingSelection(...) */ null;
  // TODO add properties to the entity

  group(MatchingSelection, () {
    // Independently generated random UUIDv4 for one public matching-side item. It is unrelated to text, authored pair identity, insertion order, the opposite-side item ID, or any shared namespace.
    // String targetItemId
    test('to test the property `targetItemId`', () async {
      // TODO
    });

    // Independently generated random UUIDv4 for one public matching-side item. It is unrelated to text, authored pair identity, insertion order, the opposite-side item ID, or any shared namespace.
    // String supportItemId
    test('to test the property `supportItemId`', () async {
      // TODO
    });

    test('redacts both matching item identifiers from toString', () {
      const targetItemId = '6c02f4ea-3f74-481c-aaad-e842bda437e1';
      const supportItemId = 'b8f4a21e-d895-4f3c-850f-373dd329cbe8';
      final selection = MatchingSelection(
        targetItemId: targetItemId,
        supportItemId: supportItemId,
      );

      expect(selection.toString(), contains('[REDACTED]'));
      expect(selection.toString(), isNot(contains(targetItemId)));
      expect(selection.toString(), isNot(contains(supportItemId)));
      expect(selection.toJson()['targetItemId'], targetItemId);
      expect(selection.toJson()['supportItemId'], supportItemId);
    });
  });
}
