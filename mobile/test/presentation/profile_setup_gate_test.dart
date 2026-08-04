import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/app.dart';
import 'package:kelimio_mobile/application/providers.dart';
import 'package:kelimio_mobile/core/config/app_config.dart';
import 'package:kelimio_mobile/domain/auth/auth.dart';

import '../support/test_doubles.dart';

void main() {
  testWidgets('authenticated provisional user is gated on profile setup', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ar')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_config),
          authRepositoryProvider.overrideWithValue(
            RecordingAuthRepository(
              restoredSession: AuthSession(expiresAt: DateTime.utc(2030)),
            ),
          ),
          profileRepositoryProvider.overrideWithValue(
            RecordingProfileRepository(),
          ),
        ],
        child: const KelimioApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إعداد ملف التعلّم'), findsOneWidget);
    expect(find.text('الدورات'), findsNothing);
    final field = tester.element(find.byType(TextFormField));
    expect(Directionality.of(field), TextDirection.rtl);
  });
}

final _config = AppConfig(
  apiBaseUri: Uri.parse('http://127.0.0.1:8080'),
  oidcIssuer: Uri.parse('http://127.0.0.1:8081/realms/kelimio'),
  oidcClientId: 'kelimio-mobile',
  redirectUri: 'com.kelimio.app:/oauthredirect',
  postLogoutRedirectUri: 'com.kelimio.app:/logout',
  isProduction: false,
);
