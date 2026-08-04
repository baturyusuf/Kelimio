import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kelimio_mobile/application/auth_controller.dart';
import 'package:kelimio_mobile/application/providers.dart';
import 'package:kelimio_mobile/core/config/app_config.dart';
import 'package:kelimio_mobile/infrastructure/auth/app_auth_gateway.dart';
import 'package:kelimio_mobile/infrastructure/storage/drift_attempt_recovery_store.dart';

final _config = AppConfig(
  apiBaseUri: Uri.parse('http://localhost:8080'),
  oidcIssuer: Uri.parse('http://localhost:8081/realms/kelimio'),
  oidcClientId: 'kelimio-mobile',
  redirectUri: 'com.kelimio.app.smoke:/oauthredirect',
  postLogoutRedirectUri: 'com.kelimio.app.smoke:/logout',
  isProduction: false,
);

const _isolatedDeviceTestStorage = bool.fromEnvironment(
  'KELIMIO_ISOLATED_DEVICE_TEST_STORAGE',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!_isolatedDeviceTestStorage || appFlavor != 'smoke') {
      throw StateError(
        'Device smoke tests require an isolated application package.',
      );
    }
    await const FlutterSecureStorage().deleteAll().timeout(
      const Duration(seconds: 10),
    );
  });

  testWidgets('the authentication gateway restores an empty session', (
    tester,
  ) async {
    expect(
      await AppAuthGateway(
        config: _config,
      ).restore().timeout(const Duration(seconds: 10)),
      isNull,
    );
  });

  testWidgets('the recovery database opens and clears', (tester) async {
    final store = DriftAttemptRecoveryStore();
    addTearDown(store.close);

    await store.open().timeout(const Duration(seconds: 10));
    await store.clear().timeout(const Duration(seconds: 10));
  });

  testWidgets('an empty installation restores a signed-out session', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [appConfigProvider.overrideWithValue(_config)],
    );
    addTearDown(container.dispose);

    expect(
      await container
          .read(authControllerProvider.future)
          .timeout(const Duration(seconds: 10)),
      isNull,
    );
  });
}
