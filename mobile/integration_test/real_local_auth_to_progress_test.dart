import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kelimio_mobile/app.dart';
import 'package:kelimio_mobile/application/attempt_controller.dart';
import 'package:kelimio_mobile/application/catalog_controller.dart';
import 'package:kelimio_mobile/application/profile_controller.dart';
import 'package:kelimio_mobile/application/providers.dart';
import 'package:kelimio_mobile/core/config/app_config.dart';
import 'package:kelimio_mobile/domain/failures.dart';
import 'package:kelimio_mobile/domain/learning/attempt_machine.dart';
import 'package:kelimio_mobile/domain/learning/learning.dart';
import 'package:kelimio_mobile/domain/profile/profile.dart';
import 'package:kelimio_mobile/infrastructure/repositories/dio_repositories.dart';
import 'package:kelimio_mobile/infrastructure/storage/drift_attempt_recovery_store.dart';
import 'package:kelimio_mobile/l10n/generated/app_localizations.dart';
import 'package:kelimio_mobile/presentation/screens/attempt_screen.dart';
import 'package:kelimio_mobile/presentation/screens/catalog_screen.dart';
import 'package:kelimio_mobile/presentation/screens/course_detail_screen.dart';
import 'package:kelimio_mobile/presentation/screens/profile_setup_screen.dart';
import 'package:kelimio_mobile/presentation/screens/sign_in_screen.dart';

import 'support/local_keycloak_pkce_session.dart';

const _realStackEnabled = bool.fromEnvironment('KELIMIO_REAL_STACK_E2E');
const _apiBaseUrl = String.fromEnvironment('KELIMIO_API_BASE_URL');
const _issuerUrl = String.fromEnvironment('KELIMIO_OIDC_ISSUER');
const _clientId = String.fromEnvironment('KELIMIO_OIDC_CLIENT_ID');
const _mailpitBaseUrl = String.fromEnvironment(
  'KELIMIO_REAL_E2E_MAILPIT_BASE_URL',
);
const _redirectUri = 'com.kelimio.app.e2e:/oauthredirect';
const _postLogoutRedirectUri = 'com.kelimio.app.e2e:/logout';
const _starterOptionAnswers = <String, String>{
  'Merhaba': 'Hello',
  'Hoşça kal': 'Goodbye',
  'Teşekkür ederim': 'Thank you',
  'Lütfen': 'Please',
  'Evet': 'Yes',
  'Ben her sabah çay ---.': 'içerim',
};
const _typedStarterPrompt = 'Sabah kahvaltıda çay ---.';
const _typedStarterInput = '  İÇİYORUM  ';
const _typedStarterCanonicalAlternative = 'içiyorum';
const _typedStarterPrimaryAnswer = 'içerim';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real verified registration reaches authoritative projected progress',
    (tester) async {
      final guarded = _guardedRealStackConfiguration();
      final session = await _runIo(
        tester,
        () => LocalKeycloakPkceSession.registerAndAuthorize(
          issuer: guarded.appConfig.oidcIssuer,
          mailpitBaseUri: guarded.mailpitBaseUri,
          clientId: guarded.appConfig.oidcClientId,
          redirectUri: _redirectUri,
          isolatedLocalMode: _realStackEnabled,
        ),
      );
      addTearDown(session.signOut);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(guarded.appConfig),
            authRepositoryProvider.overrideWithValue(session),
            accessTokenProviderProvider.overrideWithValue(session),
          ],
          child: const KelimioApp(),
        ),
      );

      await _pumpUntil(
        tester,
        () => find.byType(SignInScreen).evaluate().length == 1,
        label: 'fresh isolated sign-in screen',
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(KelimioApp)),
      );
      final attemptTimeline = <String>[];
      final attemptSubscription = container.listen<AttemptState>(
        attemptControllerProvider,
        (_, next) {
          attemptTimeline.add(_describeAttemptState(next));
          if (attemptTimeline.length > 24) {
            attemptTimeline.removeAt(0);
          }
        },
        fireImmediately: true,
      );
      addTearDown(attemptSubscription.close);
      final initialRecovery = await _runIo(
        tester,
        () => container.read(recoveryStoreProvider.future),
      );
      expect(initialRecovery, isA<DriftAttemptRecoveryStore>());
      expect(await _runIo(tester, initialRecovery.read), isNull);
      await _tapVisible(
        tester,
        find.byKey(const Key('sign-in-submit')),
        label: 'isolated session sign in',
      );
      await _pumpUntil(
        tester,
        () => find.byType(ProfileSetupScreen).evaluate().length == 1,
        label: 'provisional profile screen',
      );
      expect(
        container.read(catalogRepositoryProvider),
        isA<GeneratedCatalogRepository>(),
      );
      expect(
        container.read(learningRepositoryProvider),
        isA<GeneratedLearningRepository>(),
      );

      final provisional = container
          .read(profileControllerProvider)
          .requireValue!;
      expect(provisional.setupStatus, ProfileSetupStatus.required);
      expect(provisional.profileVersion, 0);
      await _expectIoFailure<ConflictFailure>(
        tester,
        () => container.read(catalogRepositoryProvider).listCourses(),
      );

      await tester.enterText(
        find.byKey(const Key('profile-display-name')),
        'Kelimio E2E',
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('profile-setup-submit')),
        label: 'profile setup submit',
      );
      await _pumpUntil(
        tester,
        () => find.byType(CatalogScreen).evaluate().length == 1,
        label: 'completed profile catalog',
      );
      final completed = container.read(profileControllerProvider).requireValue!;
      expect(completed.setupStatus, ProfileSetupStatus.complete);
      expect(completed.profileVersion, 1);
      expect(completed.activeTargetLanguage, 'tr');
      expect(completed.preferredSupportLanguage, 'en');
      expect(completed.timeZone, 'Europe/Istanbul');

      await _pumpUntil(
        tester,
        () => find
            .byKey(const Key('catalog-install-starter'))
            .evaluate()
            .isNotEmpty,
        label: 'empty-catalog local tool',
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('catalog-install-starter')),
        label: 'starter course install',
      );
      await _pumpUntil(tester, () {
        final catalog = container.read(catalogControllerProvider);
        return catalog.hasValue && catalog.requireValue.items.length == 1;
      }, label: 'immutable starter course');
      final course = container
          .read(catalogControllerProvider)
          .requireValue
          .items
          .single;
      await _tapVisible(
        tester,
        find.byKey(Key('catalog-course-${course.id}')),
        label: 'starter course card',
      );
      await _pumpUntil(
        tester,
        () => find.byType(CourseDetailScreen).evaluate().length == 1,
        label: 'course details',
      );
      final detail = await _runIo(
        tester,
        () => container.read(courseDetailProvider(course.id).future),
      );
      expect(detail.tests, hasLength(1));
      expect(detail.tests.single.questionCount, 7);
      final testId = detail.tests.single.id;

      await _pumpUntil(
        tester,
        () => find.byKey(const Key('course-enroll')).evaluate().isNotEmpty,
        label: 'course enrollment control',
      );
      final enroll = find.byKey(const Key('course-enroll'));
      await _tapVisible(tester, enroll, label: 'course enrollment');
      await _pumpUntil(tester, () {
        final value = container.read(courseDetailProvider(course.id));
        return value.hasValue && value.requireValue.summary.enrolled;
      }, label: 'active enrollment');
      final startTest = find.byKey(Key('course-test-$testId'));
      await _tapVisible(tester, startTest, label: 'test start');

      var renderedMultipleChoiceClozeQuestions = 0;
      var renderedTypedClozeQuestions = 0;
      var replayedMultipleChoiceClozeSubmission = false;
      var replayedTypedClozeSubmission = false;
      for (var index = 0; index < 7; index += 1) {
        await _pumpUntil(tester, () {
          final state = container.read(attemptControllerProvider);
          return state is AttemptPresenting && state.questionIndex == index;
        }, label: 'question ${index + 1}');
        final presenting =
            container.read(attemptControllerProvider) as AttemptPresenting;
        switch (presenting.question.type) {
          case QuestionType.wordMultipleChoice:
            expect(
              find.byKey(const Key('attempt-word-prompt')),
              findsOneWidget,
            );
            break;
          case QuestionType.multipleChoiceCloze:
            renderedMultipleChoiceClozeQuestions += 1;
            final prompt = tester.widget<Text>(
              find.byKey(const Key('attempt-cloze-prompt')),
            );
            expect(prompt.textSpan!.toPlainText(), isNot(contains('---')));
            break;
          case QuestionType.typedCloze:
            renderedTypedClozeQuestions += 1;
            expect(presenting.question.prompt, _typedStarterPrompt);
            expect(presenting.question.options, isEmpty);
            final prompt = tester.widget<Text>(
              find.byKey(const Key('attempt-cloze-prompt')),
            );
            expect(prompt.textSpan!.toPlainText(), isNot(contains('---')));
            expect(
              find.byKey(const Key('attempt-typed-answer')),
              findsOneWidget,
            );
            break;
        }
        String? selectedOptionId;
        if (presenting.question.answerKind == AnswerKind.option) {
          final expectedAnswer =
              _starterOptionAnswers[presenting.question.prompt];
          expect(expectedAnswer, isNotNull);
          final selected = presenting.question.options.singleWhere(
            (option) => option.text == expectedAnswer,
          );
          selectedOptionId = selected.id;
          await _tapVisible(
            tester,
            find.byKey(Key('answer-${selected.id}')),
            label: 'answer ${index + 1}',
          );
          await _pumpUntil(
            tester,
            () {
              final state = container.read(attemptControllerProvider);
              return state is AttemptPresenting &&
                  state.questionIndex == index &&
                  state.selectedOptionId == selected.id;
            },
            label: 'selected answer ${index + 1}',
            timeout: const Duration(seconds: 5),
            diagnostic: () => _describeAttemptState(
              container.read(attemptControllerProvider),
              timeline: attemptTimeline,
            ),
          );
          await _tapVisible(
            tester,
            find.byKey(const Key('attempt-primary-button')),
            label: 'answer submit ${index + 1}',
          );
        } else {
          await tester.enterText(
            find.byKey(const Key('attempt-typed-answer')),
            _typedStarterInput,
          );
          await _pumpUntil(
            tester,
            () =>
                tester
                    .widget<TextField>(
                      find.byKey(const Key('attempt-typed-answer')),
                    )
                    .onSubmitted !=
                null,
            label: 'typed answer submission readiness ${index + 1}',
            timeout: const Duration(seconds: 5),
            diagnostic: () => _describeAttemptState(
              container.read(attemptControllerProvider),
              timeline: attemptTimeline,
            ),
          );
          await tester.testTextInput.receiveAction(TextInputAction.done);
        }
        await _pumpUntil(
          tester,
          () {
            final state = container.read(attemptControllerProvider);
            return (state is AttemptSubmitting &&
                    state.questionIndex == index) ||
                (state is AttemptFeedback && state.questionIndex == index);
          },
          label: 'answer submission ${index + 1}',
          timeout: const Duration(seconds: 5),
          diagnostic: () => _describeAttemptState(
            container.read(attemptControllerProvider),
            timeline: attemptTimeline,
          ),
        );
        await _pumpUntil(
          tester,
          () {
            final state = container.read(attemptControllerProvider);
            return state is AttemptFeedback && state.questionIndex == index;
          },
          label: 'server feedback ${index + 1}',
          diagnostic: () => _describeAttemptState(
            container.read(attemptControllerProvider),
            timeline: attemptTimeline,
          ),
        );

        final feedback =
            container.read(attemptControllerProvider) as AttemptFeedback;
        expect(feedback.feedback.correct, isTrue);
        if (feedback.question.answerKind == AnswerKind.option) {
          expect(feedback.feedback.correctOptionId, selectedOptionId);
          expect(feedback.feedback.correctAnswerText, isNull);
        } else {
          expect(feedback.feedback.correctOptionId, isNull);
          expect(
            feedback.feedback.correctAnswerText,
            _typedStarterPrimaryAnswer,
          );
          expect(
            find.byKey(const Key('attempt-correct-answer-text')),
            findsOneWidget,
          );
          expect(find.text(_typedStarterPrimaryAnswer), findsOneWidget);
        }
        expect(feedback.feedback.activeScoreDelta, 60);
        expect(feedback.feedback.lifetimeScoreDelta, 60);
        expect(feedback.feedback.activeQuestionScore, 60);
        expect(feedback.feedback.lifetimeScore, (index + 1) * 60);
        expect(feedback.feedback.energy.balance, 5);

        if (feedback.question.type == QuestionType.multipleChoiceCloze &&
            !replayedMultipleChoiceClozeSubmission) {
          final replay = await _runIo(
            tester,
            () => container
                .read(learningRepositoryProvider)
                .submitAnswer(
                  attemptId: feedback.context.session.id,
                  questionRevisionId: feedback.question.revisionId,
                  answer: OptionAnswerInput(feedback.selectedOptionId!),
                  submissionId: feedback.feedback.submissionId,
                ),
          );
          expect(replay.submissionId, feedback.feedback.submissionId);
          expect(replay.correct, feedback.feedback.correct);
          expect(replay.lifetimeScore, feedback.feedback.lifetimeScore);
          expect(replay.energy.balance, feedback.feedback.energy.balance);
          replayedMultipleChoiceClozeSubmission = true;
        }

        if (feedback.question.type == QuestionType.typedCloze &&
            !replayedTypedClozeSubmission) {
          final recorded = await _runIo(
            tester,
            () => container
                .read(learningRepositoryProvider)
                .getRecordedAnswer(
                  attemptId: feedback.context.session.id,
                  submissionId: feedback.feedback.submissionId,
                ),
          );
          expect(recorded, isNotNull);
          expect(recorded!.submissionId, feedback.feedback.submissionId);
          expect(recorded.correct, feedback.feedback.correct);
          expect(recorded.correctOptionId, isNull);
          expect(recorded.correctAnswerText, _typedStarterPrimaryAnswer);

          final replay = await _runIo(
            tester,
            () => container
                .read(learningRepositoryProvider)
                .submitAnswer(
                  attemptId: feedback.context.session.id,
                  questionRevisionId: feedback.question.revisionId,
                  answer: TypedAnswerInput(_typedStarterCanonicalAlternative),
                  submissionId: feedback.feedback.submissionId,
                ),
          );
          expect(replay.submissionId, feedback.feedback.submissionId);
          expect(replay.correct, feedback.feedback.correct);
          expect(replay.correctOptionId, isNull);
          expect(replay.correctAnswerText, _typedStarterPrimaryAnswer);
          expect(replay.lifetimeScore, feedback.feedback.lifetimeScore);
          expect(replay.energy.balance, feedback.feedback.energy.balance);
          replayedTypedClozeSubmission = true;
        }

        await _tapVisible(
          tester,
          find.byKey(const Key('attempt-primary-button')),
          label: 'answer continue ${index + 1}',
        );
      }
      expect(renderedMultipleChoiceClozeQuestions, 1);
      expect(renderedTypedClozeQuestions, 1);
      expect(replayedMultipleChoiceClozeSubmission, isTrue);
      expect(replayedTypedClozeSubmission, isTrue);

      await _pumpUntil(
        tester,
        () => find.byType(AttemptResultView).evaluate().length == 1,
        label: 'authoritative attempt result',
      );
      final passed = container.read(attemptControllerProvider) as AttemptPassed;
      expect(passed.result.status, ServerAttemptStatus.completedPass);
      expect(passed.result.correctCount, 7);
      expect(passed.result.questionCount, 7);
      expect(passed.result.correctRatio, 1);

      await _tapVisible(
        tester,
        find.byKey(const Key('attempt-result-done')),
        label: 'attempt result completion',
      );
      await _pumpUntil(
        tester,
        () => find.byType(CourseDetailScreen).evaluate().length == 1,
        label: 'course progress screen',
      );
      await _pumpUntil(
        tester,
        () {
          final value = container.read(courseProgressProvider(course.id));
          if (!value.hasValue) {
            return false;
          }
          final progress = value.requireValue;
          return !progress.updating &&
              progress.answeredQuestions == 7 &&
              progress.correctAnswers == 7 &&
              progress.completedAttempts == 1 &&
              progress.passedAttempts == 1 &&
              progress.activeScore == 420 &&
              progress.lifetimeScore == 420 &&
              progress.projectionVersion == 8;
        },
        timeout: const Duration(seconds: 20),
        label: 'completed outbox projection',
      );
      final progress = container
          .read(courseProgressProvider(course.id))
          .requireValue;
      final localizations = AppLocalizations.of(
        tester.element(find.byType(CourseDetailScreen)),
      );
      await _ensureVisible(
        tester,
        find.byKey(const Key('course-progress-card')),
        label: 'projected progress card',
      );
      expect(
        find.text(
          localizations.progressAnswers(
            progress.correctAnswers,
            progress.answeredQuestions,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          localizations.progressAttempts(
            progress.passedAttempts,
            progress.completedAttempts,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          localizations.progressScores(
            progress.activeScore,
            progress.lifetimeScore,
          ),
        ),
        findsOneWidget,
      );

      final progressSubscription = container.listen(
        courseProgressProvider(course.id),
        (previous, next) {},
      );
      addTearDown(progressSubscription.close);
      await tester.binding.handlePopRoute();
      await _pumpUntil(
        tester,
        () => find.byType(CatalogScreen).evaluate().length == 1,
        label: 'catalog before sign out',
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('catalog-sign-out')),
        label: 'catalog sign out',
      );
      await _pumpUntil(
        tester,
        () => find.byType(SignInScreen).evaluate().length == 1,
        label: 'signed-out screen',
      );
      expect(await _runIo(tester, () => session.accessToken()), isNull);
      await _pumpUntil(tester, () {
        final profile = container.read(profileControllerProvider);
        return profile.hasValue && profile.value == null;
      }, label: 'cleared profile state');
      final recovery = await _runIo(
        tester,
        () => container.read(recoveryStoreProvider.future),
      );
      expect(await _runIo(tester, recovery.read), isNull);
      await _pumpUntil(
        tester,
        () => container.read(courseProgressProvider(course.id)).hasError,
        label: 'cleared progress cache',
      );
      expect(
        container.read(courseProgressProvider(course.id)).error,
        isA<AuthenticationRequiredFailure>(),
      );
      await _expectIoFailure<AuthenticationRequiredFailure>(
        tester,
        () => container.read(profileRepositoryProvider).getMe(),
      );
    },
    skip: !_realStackEnabled,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

_GuardedRealStackConfiguration _guardedRealStackConfiguration() {
  final api = Uri.tryParse(_apiBaseUrl);
  final issuer = Uri.tryParse(_issuerUrl);
  final mailpit = Uri.tryParse(_mailpitBaseUrl);
  final endpoints = [api, issuer, mailpit];
  final ports = endpoints.whereType<Uri>().map((uri) => uri.port).toSet();
  final guarded =
      _realStackEnabled &&
      appFlavor == 'e2e' &&
      _clientId == 'kelimio-mobile' &&
      endpoints.every(
        (uri) =>
            uri != null &&
            uri.scheme == 'http' &&
            uri.host == 'localhost' &&
            uri.userInfo.isEmpty &&
            !uri.hasQuery &&
            !uri.hasFragment &&
            uri.port >= 20000,
      ) &&
      ports.length == 3 &&
      api!.path.isEmpty &&
      issuer!.path == '/realms/kelimio' &&
      mailpit!.path.isEmpty;
  if (!guarded) {
    throw StateError(
      'The real-stack test accepts only distinct runner-assigned localhost endpoints.',
    );
  }
  final guardedApi = api;
  final guardedIssuer = issuer;
  final guardedMailpit = mailpit;
  return _GuardedRealStackConfiguration(
    appConfig: AppConfig(
      apiBaseUri: guardedApi,
      oidcIssuer: guardedIssuer,
      oidcClientId: _clientId,
      redirectUri: _redirectUri,
      postLogoutRedirectUri: _postLogoutRedirectUri,
      isProduction: false,
      localDevelopmentToolsEnabled: true,
    ),
    mailpitBaseUri: guardedMailpit,
  );
}

final class _GuardedRealStackConfiguration {
  const _GuardedRealStackConfiguration({
    required this.appConfig,
    required this.mailpitBaseUri,
  });

  final AppConfig appConfig;
  final Uri mailpitBaseUri;
}

Future<T> _runIo<T>(WidgetTester tester, Future<T> Function() body) async {
  final result = await tester.runAsync(() async => _AsyncResult(await body()));
  if (result == null) {
    throw StateError('The real asynchronous test stage returned no result.');
  }
  return result.value;
}

final class _AsyncResult<T> {
  const _AsyncResult(this.value);

  final T value;
}

Future<void> _expectIoFailure<T extends Object>(
  WidgetTester tester,
  Future<Object?> Function() body,
) async {
  final result = await tester.runAsync(() async {
    try {
      await body();
      return const _CapturedFailure(null);
    } on Object catch (error) {
      return _CapturedFailure(error);
    }
  });
  if (result == null) {
    throw StateError('The expected-failure stage returned no result.');
  }
  expect(result.error, isA<T>());
}

final class _CapturedFailure {
  const _CapturedFailure(this.error);

  final Object? error;
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String label,
  Duration timeout = const Duration(seconds: 15),
  String Function()? diagnostic,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      final suffix = diagnostic == null ? '' : ' Last state: ${diagnostic()}.';
      fail('Timed out waiting for $label.$suffix');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

String _describeAttemptState(AttemptState state, {List<String>? timeline}) {
  final current = switch (state) {
    final AttemptPresenting value =>
      'AttemptPresenting(index=${value.questionIndex}, '
          'selected=${value.selectedOptionId != null}, '
          'resume=${value.resumeSubmissionId != null})',
    final AttemptSubmitting value =>
      'AttemptSubmitting(index=${value.questionIndex}, kind=${value.pending.kind.name})',
    final AttemptReconciling value =>
      'AttemptReconciling(index=${value.questionIndex}, kind=${value.answerKind.name})',
    final AttemptFeedback value =>
      'AttemptFeedback(index=${value.questionIndex}, kind=${value.answerKind.name})',
    final AttemptRecovery value =>
      'AttemptRecovery(context=${value.recovery.runtimeType}, '
          'failure=${value.failure.runtimeType})',
    final AttemptFatal value =>
      'AttemptFatal(failure=${value.failure.runtimeType})',
    final AttemptContentChanged value =>
      'AttemptContentChanged(failure=${value.failure.runtimeType})',
    final AttemptInterrupted value =>
      'AttemptInterrupted(failure=${value.failure?.runtimeType})',
    _ => state.runtimeType.toString(),
  };
  if (timeline == null || timeline.isEmpty) {
    return current;
  }
  return '$current; recent=${timeline.join(' -> ')}';
}

Future<void> _ensureVisible(
  WidgetTester tester,
  Finder finder, {
  required String label,
}) async {
  if (finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder);
  } else {
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isNotEmpty) {
      try {
        await tester.scrollUntilVisible(
          finder,
          -200,
          scrollable: scrollables.last,
          maxScrolls: 20,
        );
      } on StateError {
        await tester.scrollUntilVisible(
          finder,
          200,
          scrollable: scrollables.last,
          maxScrolls: 20,
        );
      }
    }
  }
  if (finder.evaluate().isEmpty) {
    fail('Unable to find $label.');
  }
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 100));
  expect(finder.hitTestable(), findsOneWidget, reason: label);
}

Future<void> _tapVisible(
  WidgetTester tester,
  Finder finder, {
  required String label,
}) async {
  await _ensureVisible(tester, finder, label: label);
  await tester.tap(finder.hitTestable());
  await tester.pump();
}
