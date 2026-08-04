import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('secure token storage round-trips on Android', (tester) async {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(storageNamespace: 'kelimio-integration-test'),
    );
    const key = 'round_trip';

    await storage
        .write(key: key, value: 'ok')
        .timeout(const Duration(seconds: 10));
    expect(
      await storage.read(key: key).timeout(const Duration(seconds: 10)),
      'ok',
    );
    await storage.delete(key: key).timeout(const Duration(seconds: 10));
  });
}
