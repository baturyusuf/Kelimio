import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/application/providers.dart';
import 'package:kelimio_mobile/domain/offline/offline.dart';
import 'package:kelimio_mobile/l10n/generated/app_localizations.dart';
import 'package:kelimio_mobile/presentation/screens/offline_practice_screen.dart';

void main() {
  testWidgets('Arabic offline practice is RTL at 200% text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const package = OfflineCoursePackage(
      courseId: 'course-1',
      courseReleaseId: 'release-1',
      supportLanguage: 'ar',
      sha256: 'sha256',
      localPath: 'unused.json',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          offlinePackageRepositoryProvider.overrideWithValue(
            _OfflineRepository(),
          ),
        ],
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const OfflinePracticeScreen(package: package),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
    expect(find.text('تدريب دون اتصال ومن دون نقاط'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _OfflineRepository implements OfflinePackageRepository {
  @override
  Future<void> clearPrivateData() async {}

  @override
  Future<OfflineCoursePackage> download({
    required String courseId,
    required String supportLanguage,
  }) => throw UnimplementedError();

  @override
  Future<List<OfflinePracticeQuestion>> loadQuestions(
    OfflineCoursePackage package,
  ) async => [
    OfflinePracticeQuestion(
      type: 'WORD_MULTIPLE_CHOICE',
      prompt: 'اختر الإجابة الصحيحة',
      correctAnswer: 'صحيح',
      options: ['صحيح', 'خطأ'],
      matchingPairs: const {},
    ),
  ];

  @override
  Future<void> recordPractice({
    required OfflineCoursePackage package,
    required int answered,
    required int correct,
  }) async {}
}
