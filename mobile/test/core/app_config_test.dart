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
}
