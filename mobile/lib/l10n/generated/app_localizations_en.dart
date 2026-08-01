// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Kelimio';

  @override
  String get configurationErrorTitle => 'Configuration required';

  @override
  String get configurationErrorBody =>
      'This build is missing required production settings.';

  @override
  String get signInTitle => 'Learn with verified progress';

  @override
  String get signInBody =>
      'Sign in securely to browse courses and continue learning.';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get profileSetupTitle => 'Set up your learning profile';

  @override
  String get profileSetupBody =>
      'Choose the language used by the app, the language you want to learn, and the language used for explanations.';

  @override
  String get profileSetupLegalNotice =>
      'This step saves learning preferences only. It is not acceptance of legal terms or marketing consent.';

  @override
  String get displayName => 'Display name';

  @override
  String get appLanguage => 'App language';

  @override
  String get targetLanguage => 'Language to learn';

  @override
  String get preferredSupportLanguage => 'Preferred explanation language';

  @override
  String get timeZone => 'Time zone';

  @override
  String get timeZoneIstanbul => 'Türkiye (Europe/Istanbul)';

  @override
  String get timeZoneUtc => 'UTC';

  @override
  String get completeProfileSetup => 'Save and continue';

  @override
  String get requiredField => 'This field is required.';

  @override
  String get languageTurkish => 'Turkish';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get languageFrench => 'French';

  @override
  String get catalog => 'Catalog';

  @override
  String get energy => 'Energy';

  @override
  String get retry => 'Try again';

  @override
  String get refresh => 'Refresh';

  @override
  String get loading => 'Loading';

  @override
  String get genericError => 'Something went wrong.';

  @override
  String get networkError => 'Check your connection and try again.';

  @override
  String get emptyCatalog => 'No courses are available right now.';

  @override
  String get localStarterCourseBody =>
      'For local testing, install the reviewed mixed Type-A and Type-B starter course. This does not create users or learning results.';

  @override
  String get installLocalStarterCourse => 'Install local starter course';

  @override
  String get yourProgress => 'Your progress';

  @override
  String progressAnswers(Object answered, Object correct) {
    return '$correct of $answered answers correct';
  }

  @override
  String progressAttempts(Object completed, Object passed) {
    return '$passed of $completed completed attempts passed';
  }

  @override
  String progressScores(Object active, Object lifetime) {
    return 'Active score: $active · Lifetime score: $lifetime';
  }

  @override
  String get progressUpdating =>
      'Progress is updating from verified server events.';

  @override
  String get courseDetails => 'Course details';

  @override
  String get free => 'Free';

  @override
  String get paid => 'Paid';

  @override
  String get enrolled => 'Enrolled';

  @override
  String get supportLanguage => 'Support language';

  @override
  String get enroll => 'Enroll';

  @override
  String get paidEnrollmentUnavailable =>
      'Paid enrollment is not available in this app yet.';

  @override
  String get tests => 'Tests';

  @override
  String questionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '1 question',
    );
    return '$_temp0';
  }

  @override
  String get startTest => 'Start test';

  @override
  String questionProgress(Object current, Object total) {
    return 'Question $current of $total';
  }

  @override
  String get submitAnswer => 'Submit answer';

  @override
  String get continueLabel => 'Continue';

  @override
  String get correct => 'Correct';

  @override
  String get incorrect => 'Incorrect';

  @override
  String get finishing => 'Finishing your attempt';

  @override
  String get passed => 'You passed';

  @override
  String get failed => 'Keep practicing';

  @override
  String resultSummary(
    Object correctCount,
    Object percentage,
    Object questionCount,
  ) {
    return '$correctCount of $questionCount correct ($percentage%)';
  }

  @override
  String get backToCourse => 'Back to course';

  @override
  String get attemptInterrupted => 'Attempt interrupted';

  @override
  String get energyDepleted =>
      'You have no energy left. Your server-confirmed progress is safe.';

  @override
  String get contentChanged =>
      'This test changed while you were learning. Return to the course and start the current version.';

  @override
  String get recoverAttempt => 'Recover attempt';

  @override
  String get recoverableError =>
      'The request was not confirmed. Retrying uses the same safe submission identifier.';

  @override
  String get fatalAttemptError => 'This attempt cannot continue.';

  @override
  String get energyUnlimited => 'Unlimited energy';

  @override
  String energyBalance(Object balance, Object maximum) {
    return '$balance of $maximum';
  }

  @override
  String nextRegeneration(Object time) {
    return 'Next energy: $time';
  }

  @override
  String energyCurrentAsOf(Object time) {
    return 'Updated $time';
  }

  @override
  String get authenticationCancelled => 'Sign-in was cancelled.';

  @override
  String get accessibilitySelectedAnswer => 'Selected answer';

  @override
  String get accessibilityCorrectAnswer => 'Correct answer';

  @override
  String get accessibilityIncorrectAnswer => 'Incorrect answer';

  @override
  String get accessibilityBlank => 'blank';
}
