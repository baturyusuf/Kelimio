import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/core/config/app_config.dart';

void main() {
  test('missing required dart-defines return an explicit invalid result', () {
    final result = AppConfig.fromEnvironment();

    expect(result, isA<AppConfigInvalid>());
    final issues = (result as AppConfigInvalid).issues;
    expect(
      issues.map((issue) => issue.defineName),
      containsAll(<String>{
        'KELIMIO_API_BASE_URL',
        'KELIMIO_OIDC_ISSUER',
        'KELIMIO_OIDC_CLIENT_ID',
      }),
    );
  });

  test('internal testing exposes the controlled starter and authoring gates', () {
    final config = AppConfig(
      apiBaseUri: Uri.parse('https://api.example.test'),
      oidcIssuer: Uri.parse('https://identity.example.test'),
      oidcClientId: 'mobile-client',
      redirectUri: 'com.kelimio.app:/oauthredirect',
      postLogoutRedirectUri: 'com.kelimio.app:/logout',
      isProduction: true,
      internalTestingEnabled: true,
    );

    expect(config.internalTestingEnabled, isTrue);
    expect(config.localDevelopmentToolsEnabled, isFalse);
    expect(config.starterCourseInstallerEnabled, isTrue);
    expect(config.courseAuthoringEnabled, isTrue);
  });

  test('normal production configuration keeps the installer closed', () {
    final config = AppConfig(
      apiBaseUri: Uri.parse('https://api.example.test'),
      oidcIssuer: Uri.parse('https://identity.example.test'),
      oidcClientId: 'mobile-client',
      redirectUri: 'com.kelimio.app:/oauthredirect',
      postLogoutRedirectUri: 'com.kelimio.app:/logout',
      isProduction: true,
    );

    expect(config.starterCourseInstallerEnabled, isFalse);
    expect(config.courseAuthoringEnabled, isFalse);
  });
}
