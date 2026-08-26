import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/application/providers.dart';
import 'package:kelimio_mobile/core/config/app_config.dart';
import 'package:kelimio_mobile/domain/teacher/teacher_access.dart';
import 'package:kelimio_mobile/l10n/generated/app_localizations.dart';
import 'package:kelimio_mobile/presentation/screens/teacher_gate_screen.dart';

void main() {
  testWidgets('production teacher terms require an explicit acknowledgement', (
    tester,
  ) async {
    final repository = _TeacherAccessRepository(
      const TeacherAccess(
        eligible: true,
        termsAccepted: false,
        productionFeaturesEnabled: true,
        requiredTermsVersion: 'internal-authoring-v1',
      ),
    );
    await _pump(tester, repository);

    final button = find.byKey(const Key('teacher-terms-accept'));
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.tap(find.byKey(const Key('teacher-terms-checkbox')));
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(repository.acceptedVersions, ['internal-authoring-v1']);
  });

  testWidgets('server-ineligible account never receives an authoring control', (
    tester,
  ) async {
    await _pump(
      tester,
      _TeacherAccessRepository(
        const TeacherAccess(
          eligible: false,
          termsAccepted: false,
          productionFeaturesEnabled: true,
          requiredTermsVersion: 'internal-authoring-v1',
        ),
      ),
    );

    expect(find.byKey(const Key('teacher-terms-checkbox')), findsNothing);
    expect(find.byKey(const Key('teacher-terms-accept')), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  TeacherAccessRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(_productionInternalConfig),
        teacherAccessRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TeacherGateScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _TeacherAccessRepository implements TeacherAccessRepository {
  _TeacherAccessRepository(this.access);

  final TeacherAccess access;
  final List<String> acceptedVersions = [];

  @override
  Future<TeacherAccess> getAccess() async => access;

  @override
  Future<TeacherAccess> acceptTerms(String termsVersion) async {
    acceptedVersions.add(termsVersion);
    return access;
  }
}

final _productionInternalConfig = AppConfig(
  apiBaseUri: Uri.parse('https://api.example.test'),
  oidcIssuer: Uri.parse('https://identity.example.test'),
  oidcClientId: 'mobile-client',
  redirectUri: 'com.kelimio.app:/oauthredirect',
  postLogoutRedirectUri: 'com.kelimio.app:/logout',
  isProduction: true,
  internalTestingEnabled: true,
);
