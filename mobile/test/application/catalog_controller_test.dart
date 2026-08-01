import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/application/catalog_controller.dart';
import 'package:kelimio_mobile/application/providers.dart';
import 'package:kelimio_mobile/core/config/app_config.dart';

import '../support/test_doubles.dart';

void main() {
  test('local starter command refreshes an empty catalog', () async {
    final catalog = RecordingCatalogRepository();
    final development = RecordingDevelopmentRepository();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(
            apiBaseUri: Uri.parse('http://localhost:8080'),
            oidcIssuer: Uri.parse('http://localhost:8081/realms/kelimio'),
            oidcClientId: 'kelimio-mobile',
            redirectUri: 'com.kelimio.app:/oauthredirect',
            postLogoutRedirectUri: 'com.kelimio.app:/logout',
            isProduction: false,
            localDevelopmentToolsEnabled: true,
          ),
        ),
        catalogRepositoryProvider.overrideWithValue(catalog),
        developmentRepositoryProvider.overrideWithValue(development),
        identifierFactoryProvider.overrideWithValue(
          SequenceIdentifierFactory(['00000000-0000-4000-8000-000000000099']),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      (await container.read(catalogControllerProvider.future)).items,
      isEmpty,
    );
    await container
        .read(catalogControllerProvider.notifier)
        .installLocalStarterCourse();

    expect(development.commandIds, ['00000000-0000-4000-8000-000000000099']);
    expect(catalog.listCalls, 2);
    expect(
      container.read(catalogControllerProvider).requireValue.items,
      hasLength(1),
    );
  });
}
