import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/application/course_authoring_controller.dart';
import 'package:kelimio_mobile/application/providers.dart';
import 'package:kelimio_mobile/core/config/app_config.dart';
import 'package:kelimio_mobile/l10n/generated/app_localizations.dart';
import 'package:kelimio_mobile/presentation/screens/teacher_import_screen.dart';

import '../support/course_authoring_fixtures.dart';
import '../support/test_doubles.dart';

void main() {
  testWidgets('review, draft, and publication remain separate explicit gates', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = RecordingCourseAuthoringRepository();
    await _pumpScreen(tester, repository: repository);

    await tester.tap(find.byKey(const Key('teacher-select-workbook')));
    await tester.pumpAndSettle();

    expect(find.text('Kelimio test course'), findsOneWidget);
    expect(find.text('Pencere'), findsOneWidget);
    expect(_button(tester, 'teacher-approve-preview').onPressed, isNull);

    await _tapVisible(tester, 'teacher-preview-confirmation');
    expect(_button(tester, 'teacher-approve-preview').onPressed, isNotNull);
    await _tapVisible(tester, 'teacher-approve-preview');
    await tester.pumpAndSettle();

    expect(repository.approvalCommands, hasLength(1));
    expect(_button(tester, 'teacher-create-draft').onPressed, isNull);
    await _tapVisible(tester, 'teacher-draft-confirmation');
    expect(_button(tester, 'teacher-create-draft').onPressed, isNotNull);
    await _tapVisible(tester, 'teacher-create-draft');
    await tester.pumpAndSettle();

    expect(repository.commitCommands, hasLength(1));
    expect(_button(tester, 'teacher-publish-course').onPressed, isNull);
    await _tapVisible(tester, 'teacher-impact-confirmation');
    expect(_button(tester, 'teacher-publish-course').onPressed, isNotNull);
    await _tapVisible(tester, 'teacher-publish-course');
    await tester.pumpAndSettle();

    expect(repository.activationCommands, hasLength(1));
    expect(
      find.byKey(const Key('teacher-publication-success')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic teacher UI is RTL and survives 200% text scaling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpScreen(
      tester,
      repository: RecordingCourseAuthoringRepository(),
      locale: const Locale('ar'),
      textScale: 2,
    );

    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
    expect(find.byKey(const Key('teacher-select-workbook')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required RecordingCourseAuthoringRepository repository,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(_config),
        workbookPickerProvider.overrideWithValue(const StubWorkbookPicker()),
        courseAuthoringRepositoryProvider.overrideWithValue(repository),
        identifierFactoryProvider.overrideWithValue(
          SequenceIdentifierFactory([
            '00000000-0000-4000-8000-000000000001',
            '00000000-0000-4000-8000-000000000002',
            '00000000-0000-4000-8000-000000000003',
            '00000000-0000-4000-8000-000000000004',
            '00000000-0000-4000-8000-000000000005',
          ]),
        ),
        courseAuthoringPollDelayProvider.overrideWithValue(Duration.zero),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const TeacherImportScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

FilledButton _button(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(find.byKey(Key(key)));

final _config = AppConfig(
  apiBaseUri: Uri.parse('http://localhost:8080'),
  oidcIssuer: Uri.parse('http://localhost:8081/realms/kelimio'),
  oidcClientId: 'kelimio-mobile',
  redirectUri: 'com.kelimio.app:/oauthredirect',
  postLogoutRedirectUri: 'com.kelimio.app:/logout',
  isProduction: false,
  localDevelopmentToolsEnabled: true,
);
