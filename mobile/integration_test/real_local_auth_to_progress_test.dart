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
import 'package:kelimio_mobile/domain/catalog/catalog.dart';
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
const _matchingStarterAnswers = <String, String>{
  'Pencere': 'Window',
  'Kapı': 'Door',
  'Masa': 'Table',
  'Sandalye': 'Chair',
};

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
      expect(detail.tests.single.questionCount, 8);
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
      var renderedMatchingQuestions = 0;
      var replayedMultipleChoiceClozeSubmission = false;
      var replayedTypedClozeSubmission = false;
      var replayedMatchingSubmission = false;
      for (var index = 0; index < 8; index += 1) {
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
          case QuestionType.matching:
            renderedMatchingQuestions += 1;
            expect(presenting.context.session.supportLanguage, 'en');
            expect(presenting.question.prompt, isNull);
            expect(presenting.question.options, isEmpty);
            expect(presenting.question.targetItems, hasLength(4));
            expect(presenting.question.supportItems, hasLength(4));
            expect(
              presenting.question.targetItems.map((item) => item.text),
              unorderedEquals(_matchingStarterAnswers.keys),
            );
            expect(
              presenting.question.supportItems.map((item) => item.text),
              unorderedEquals(_matchingStarterAnswers.values),
            );
            expect(
              presenting.question.targetItems
                  .map((item) => item.id)
                  .toSet()
                  .intersection(
                    presenting.question.supportItems
                        .map((item) => item.id)
                        .toSet(),
                  ),
              isEmpty,
            );
            for (final item in presenting.question.targetItems) {
              expect(
                find.byKey(Key('matching-target-${item.id}')),
                findsOneWidget,
              );
            }
            for (final item in presenting.question.supportItems) {
              expect(
                find.byKey(Key('matching-support-${item.id}')),
                findsOneWidget,
              );
            }
            break;
        }
        String? selectedOptionId;
        MatchingAnswerInput? submittedMatchingAnswer;
        switch (presenting.question.answerKind) {
          case AnswerKind.option:
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
          case AnswerKind.typed:
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
          case AnswerKind.matching:
            submittedMatchingAnswer = _matchingAnswerFor(presenting.question);
            await _enterMatchingAnswer(
              tester,
              presenting.question,
              submittedMatchingAnswer,
            );
            await _pumpUntil(
              tester,
              () {
                final state = container.read(attemptControllerProvider);
                return state is AttemptPresenting &&
                    state.questionIndex == index &&
                    state.matchingDraft.isCompleteFor(state.question);
              },
              label: 'complete matching selection ${index + 1}',
              timeout: const Duration(seconds: 5),
              diagnostic: () => _describeAttemptState(
                container.read(attemptControllerProvider),
                timeline: attemptTimeline,
              ),
            );
            await _tapVisible(
              tester,
              find.byKey(const Key('attempt-primary-button')),
              label: 'matching answer submit ${index + 1}',
            );
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
        switch (feedback.question.answerKind) {
          case AnswerKind.option:
            expect(feedback.feedback.correctOptionId, selectedOptionId);
            expect(feedback.feedback.correctAnswerText, isNull);
            expect(feedback.feedback.correctMatches, isNull);
          case AnswerKind.typed:
            expect(feedback.feedback.correctOptionId, isNull);
            expect(
              feedback.feedback.correctAnswerText,
              _typedStarterPrimaryAnswer,
            );
            expect(feedback.feedback.correctMatches, isNull);
            expect(
              find.byKey(const Key('attempt-correct-answer-text')),
              findsOneWidget,
            );
            expect(find.text(_typedStarterPrimaryAnswer), findsOneWidget);
          case AnswerKind.matching:
            final submitted = submittedMatchingAnswer;
            final correctMatches = feedback.feedback.correctMatches;
            expect(submitted, isNotNull);
            expect(feedback.selectedOptionId, isNull);
            expect(feedback.feedback.correctOptionId, isNull);
            expect(feedback.feedback.correctAnswerText, isNull);
            expect(correctMatches, isNotNull);
            expect(
              MatchingAnswerInput(
                correctMatches!,
              ).hasExactCoverageOf(feedback.question),
              isTrue,
            );
            expect(submitted!.hasSameMappingAs(correctMatches), isTrue);
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

        if (feedback.question.type == QuestionType.matching &&
            !replayedMatchingSubmission) {
          final submitted = submittedMatchingAnswer!;
          final repository = container.read(learningRepositoryProvider);
          final replay = await _runIo(
            tester,
            () => repository.submitAnswer(
              attemptId: feedback.context.session.id,
              questionRevisionId: feedback.question.revisionId,
              answer: MatchingAnswerInput(submitted.pairs.reversed),
              submissionId: feedback.feedback.submissionId,
            ),
          );
          _expectSameMatchingFeedback(replay, feedback.feedback);

          final recorded = await _runIo(
            tester,
            () => repository.getRecordedAnswer(
              attemptId: feedback.context.session.id,
              submissionId: feedback.feedback.submissionId,
            ),
          );
          expect(recorded, isNotNull);
          _expectSameMatchingFeedback(recorded!, feedback.feedback);

          final progressBeforeConflict = await _waitForSettledProgress(
            tester,
            container.read(catalogRepositoryProvider),
            course.id,
          );
          final energyBeforeConflict = await _runIo(
            tester,
            () => container.read(energyRepositoryProvider).getEnergy(),
          );
          await _expectIoFailure<ConflictFailure>(
            tester,
            () => repository.submitAnswer(
              attemptId: feedback.context.session.id,
              questionRevisionId: feedback.question.revisionId,
              answer: _changedMatchingAnswerFor(feedback.question, submitted),
              submissionId: feedback.feedback.submissionId,
            ),
          );

          final recordedAfterConflict = await _runIo(
            tester,
            () => repository.getRecordedAnswer(
              attemptId: feedback.context.session.id,
              submissionId: feedback.feedback.submissionId,
            ),
          );
          expect(recordedAfterConflict, isNotNull);
          _expectSameMatchingFeedback(
            recordedAfterConflict!,
            feedback.feedback,
          );
          final progressAfterConflict = await _waitForSettledProgress(
            tester,
            container.read(catalogRepositoryProvider),
            course.id,
          );
          final energyAfterConflict = await _runIo(
            tester,
            () => container.read(energyRepositoryProvider).getEnergy(),
          );
          expect(
            _progressFactSnapshot(progressAfterConflict),
            _progressFactSnapshot(progressBeforeConflict),
          );
          expect(energyAfterConflict.balance, energyBeforeConflict.balance);
          expect(energyAfterConflict.maximum, energyBeforeConflict.maximum);
          expect(energyAfterConflict.unlimited, energyBeforeConflict.unlimited);
          expect(
            energyAfterConflict.nextRegenerationAt,
            energyBeforeConflict.nextRegenerationAt,
          );
          replayedMatchingSubmission = true;
        }

        await _tapVisible(
          tester,
          find.byKey(const Key('attempt-primary-button')),
          label: 'answer continue ${index + 1}',
        );
      }
      expect(renderedMultipleChoiceClozeQuestions, 1);
      expect(renderedTypedClozeQuestions, 1);
      expect(renderedMatchingQuestions, 1);
      expect(replayedMultipleChoiceClozeSubmission, isTrue);
      expect(replayedTypedClozeSubmission, isTrue);
      expect(replayedMatchingSubmission, isTrue);

      await _pumpUntil(
        tester,
        () => find.byType(AttemptResultView).evaluate().length == 1,
        label: 'authoritative attempt result',
      );
      final passed = container.read(attemptControllerProvider) as AttemptPassed;
      expect(passed.result.status, ServerAttemptStatus.completedPass);
      expect(passed.result.correctCount, 8);
      expect(passed.result.questionCount, 8);
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
              progress.answeredQuestions == 8 &&
              progress.correctAnswers == 8 &&
              progress.completedAttempts == 1 &&
              progress.passedAttempts == 1 &&
              progress.activeScore == 480 &&
              progress.lifetimeScore == 480 &&
              progress.projectionVersion == 9;
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

MatchingAnswerInput _matchingAnswerFor(Question question) {
  if (question.type != QuestionType.matching ||
      question.targetItems.length != _matchingStarterAnswers.length ||
      question.supportItems.length != _matchingStarterAnswers.length) {
    throw StateError('The isolated starter matching question was malformed.');
  }
  final targetTexts = question.targetItems.map((item) => item.text).toSet();
  final supportByText = <String, MatchingItem>{
    for (final item in question.supportItems) item.text: item,
  };
  if (targetTexts.length != _matchingStarterAnswers.length ||
      !targetTexts.containsAll(_matchingStarterAnswers.keys) ||
      supportByText.length != _matchingStarterAnswers.length ||
      !supportByText.keys.toSet().containsAll(_matchingStarterAnswers.values)) {
    throw StateError(
      'The isolated starter matching vocabulary was not the expected fixture.',
    );
  }

  final answer = MatchingAnswerInput(
    question.targetItems.map((target) {
      final expectedSupportText = _matchingStarterAnswers[target.text];
      final support = supportByText[expectedSupportText];
      if (expectedSupportText == null || support == null) {
        throw StateError(
          'The isolated starter matching vocabulary was incomplete.',
        );
      }
      return MatchingPair(targetItemId: target.id, supportItemId: support.id);
    }),
  );
  if (!answer.hasExactCoverageOf(question)) {
    throw StateError('The isolated starter matching answer lacked coverage.');
  }
  return answer;
}

MatchingAnswerInput _changedMatchingAnswerFor(
  Question question,
  MatchingAnswerInput submitted,
) {
  final firstTarget = question.targetItems.singleWhere(
    (item) => item.text == 'Pencere',
  );
  final secondTarget = question.targetItems.singleWhere(
    (item) => item.text == 'Kapı',
  );
  final submittedByTarget = <String, MatchingPair>{
    for (final pair in submitted.pairs) pair.targetItemId: pair,
  };
  final firstPair = submittedByTarget[firstTarget.id];
  final secondPair = submittedByTarget[secondTarget.id];
  if (firstPair == null || secondPair == null) {
    throw StateError('The isolated matching conflict fixture was incomplete.');
  }
  final changed = MatchingAnswerInput(
    submitted.pairs.map(
      (pair) => switch (pair.targetItemId) {
        final id when id == firstTarget.id => MatchingPair(
          targetItemId: pair.targetItemId,
          supportItemId: secondPair.supportItemId,
        ),
        final id when id == secondTarget.id => MatchingPair(
          targetItemId: pair.targetItemId,
          supportItemId: firstPair.supportItemId,
        ),
        _ => pair,
      },
    ),
  );
  if (!changed.hasExactCoverageOf(question) ||
      changed.hasSameMappingAs(submitted.pairs)) {
    throw StateError('The isolated matching conflict fixture was invalid.');
  }
  return changed;
}

Future<void> _enterMatchingAnswer(
  WidgetTester tester,
  Question question,
  MatchingAnswerInput answer,
) async {
  final removableTarget = question.targetItems.singleWhere(
    (item) => item.text == 'Pencere',
  );
  final removablePair = answer.pairs.singleWhere(
    (pair) => pair.targetItemId == removableTarget.id,
  );
  await _tapVisible(
    tester,
    find.byKey(Key('matching-target-${removablePair.targetItemId}')),
    label: 'matching target selection check',
  );
  await _tapVisible(
    tester,
    find.byKey(Key('matching-support-${removablePair.supportItemId}')),
    label: 'matching support selection check',
  );
  final remove = find.byKey(
    Key('matching-remove-${removablePair.targetItemId}'),
  );
  await _pumpUntil(
    tester,
    () => remove.evaluate().length == 1,
    label: 'matching selection removal control',
  );
  await _tapVisible(tester, remove, label: 'matching selection removal');

  for (final pair in answer.pairs) {
    await _tapVisible(
      tester,
      find.byKey(Key('matching-target-${pair.targetItemId}')),
      label: 'matching target selection',
    );
    await _tapVisible(
      tester,
      find.byKey(Key('matching-support-${pair.supportItemId}')),
      label: 'matching support selection',
    );
  }
}

void _expectSameMatchingFeedback(
  AnswerFeedback actual,
  AnswerFeedback expected,
) {
  expect(actual.submissionId, expected.submissionId);
  expect(actual.correct, expected.correct);
  expect(actual.correctOptionId, isNull);
  expect(actual.correctAnswerText, isNull);
  expect(actual.correctMatches, isNotNull);
  expect(expected.correctMatches, isNotNull);
  expect(
    MatchingAnswerInput(
      actual.correctMatches!,
    ).hasSameMappingAs(expected.correctMatches!),
    isTrue,
  );
  expect(actual.activeScoreDelta, expected.activeScoreDelta);
  expect(actual.lifetimeScoreDelta, expected.lifetimeScoreDelta);
  expect(actual.activeQuestionScore, expected.activeQuestionScore);
  expect(actual.lifetimeScore, expected.lifetimeScore);
  expect(actual.energy.balance, expected.energy.balance);
  expect(actual.energy.maximum, expected.energy.maximum);
  expect(actual.energy.unlimited, expected.energy.unlimited);
  expect(actual.energy.nextRegenerationAt, expected.energy.nextRegenerationAt);
  expect(actual.attemptStatus, expected.attemptStatus);
}

Future<CourseProgress> _waitForSettledProgress(
  WidgetTester tester,
  CatalogRepository repository,
  String courseId,
) => _runIo(tester, () async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  do {
    final progress = await repository.getProgress(courseId);
    if (!progress.updating) {
      return progress;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  } while (DateTime.now().isBefore(deadline));
  throw StateError('The isolated progress projection did not settle.');
});

Object _progressFactSnapshot(CourseProgress progress) => (
  progress.answeredQuestions,
  progress.correctAnswers,
  progress.completedAttempts,
  progress.passedAttempts,
  progress.activeScore,
  progress.lifetimeScore,
  progress.projectionVersion,
);

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
