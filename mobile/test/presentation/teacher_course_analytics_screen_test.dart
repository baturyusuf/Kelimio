import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/application/providers.dart';
import 'package:kelimio_mobile/domain/teacher/teacher_course.dart';
import 'package:kelimio_mobile/l10n/generated/app_localizations.dart';
import 'package:kelimio_mobile/presentation/screens/teacher_course_analytics_screen.dart';

void main() {
  testWidgets('small cohorts expose activity but suppress performance', (
    tester,
  ) async {
    await _pump(
      tester,
      analytics: _analytics(
        metrics: const TeacherCourseAnalyticsMetrics(
          learnersWithRecordedActivity: 2,
          performance: null,
        ),
      ),
    );

    expect(find.text('2 learners have recorded activity'), findsOneWidget);
    expect(find.text('Performance is protected'), findsOneWidget);
    expect(find.textContaining('correct answers'), findsNothing);
  });

  testWidgets('updating analytics never show partial metrics', (tester) async {
    await _pump(tester, analytics: _analytics(updating: true, metrics: null));

    expect(find.byKey(const Key('teacher-analytics-updating')), findsOneWidget);
    expect(find.text('Analytics are updating'), findsOneWidget);
    expect(find.textContaining('learners have recorded'), findsNothing);
    expect(find.text('Refresh'), findsOneWidget);
  });

  testWidgets('Arabic aggregate analytics support RTL at 200 percent text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pump(
      tester,
      locale: const Locale('ar'),
      textScaler: const TextScaler.linear(2),
      analytics: _analytics(
        metrics: const TeacherCourseAnalyticsMetrics(
          learnersWithRecordedActivity: 3,
          performance: TeacherCoursePerformance(
            answeredQuestions: 12,
            correctAnswers: 9,
            completedAttempts: 4,
            passedAttempts: 3,
          ),
        ),
      ),
    );

    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
    expect(find.text('تحليلات الدورة'), findsOneWidget);
    expect(find.text('9 إجابات صحيحة من أصل 12'), findsOneWidget);
    expect(find.text('نسبة الإجابات الصحيحة: 75%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required TeacherCourseAnalytics analytics,
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        teacherCourseRepositoryProvider.overrideWithValue(
          _TeacherRepository(analytics),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TeacherCourseAnalyticsScreen(courseId: analytics.courseId),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TeacherCourseAnalytics _analytics({
  bool updating = false,
  required TeacherCourseAnalyticsMetrics? metrics,
}) => TeacherCourseAnalytics(
  courseId: '00000000-0000-4000-8000-000000000001',
  courseReleaseId: '00000000-0000-4000-8000-000000000002',
  updating: updating,
  metrics: metrics,
  updatedAt: updating ? null : DateTime.utc(2026, 8, 29, 12),
);

final class _TeacherRepository implements TeacherCourseRepository {
  const _TeacherRepository(this.analytics);

  final TeacherCourseAnalytics analytics;

  @override
  Future<TeacherCourseAnalytics> getAnalytics(String courseId) async =>
      analytics;

  @override
  Future<String> createInvitation(String courseId) =>
      throw UnimplementedError();

  @override
  Future<FullCourseEditorDocument> getEditor(String courseId) =>
      throw UnimplementedError();

  @override
  Future<TeacherCoursePage> listCourses({String? cursor, int limit = 20}) =>
      throw UnimplementedError();

  @override
  Future<FullCourseDraft> saveDraft({
    required FullCourseEditorDocument document,
    required String commandId,
  }) => throw UnimplementedError();
}
