import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/application/providers.dart';
import 'package:kelimio_mobile/core/config/app_config.dart';
import 'package:kelimio_mobile/domain/catalog/catalog.dart';
import 'package:kelimio_mobile/l10n/generated/app_localizations.dart';
import 'package:kelimio_mobile/presentation/screens/catalog_screen.dart';

import '../support/test_doubles.dart';

void main() {
  testWidgets(
    'local starter install remains reachable with an existing v1 course',
    (tester) async {
      const existingCourseId = '00000000-0000-4000-8000-000000000201';
      final catalog = RecordingCatalogRepository(
        initialItems: [
          CourseSummary(
            id: existingCourseId,
            name: 'Existing Type-A starter',
            targetLanguage: 'tr',
            supportLanguages: ['en'],
            accessType: CourseAccessType.free,
            visibility: CourseVisibility.public,
            enrolled: false,
          ),
        ],
      );
      final development = RecordingDevelopmentRepository();

      await tester.pumpWidget(
        ProviderScope(
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
              SequenceIdentifierFactory([
                '00000000-0000-4000-8000-000000000299',
              ]),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CatalogScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('catalog-course-$existingCourseId')),
        findsOneWidget,
      );
      final install = find.byKey(const Key('catalog-install-starter'));
      expect(install, findsOneWidget);
      await tester.tap(install);
      await tester.pumpAndSettle();

      expect(development.commandIds, ['00000000-0000-4000-8000-000000000299']);
      expect(catalog.listCalls, 2);
    },
  );
}
