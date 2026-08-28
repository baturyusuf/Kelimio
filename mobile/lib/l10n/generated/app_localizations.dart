import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @findPreviousImports.
  ///
  /// In en, this message translates to:
  /// **'Find previous imports'**
  String get findPreviousImports;

  /// No description provided for @findingPreviousImports.
  ///
  /// In en, this message translates to:
  /// **'Finding your previous imports'**
  String get findingPreviousImports;

  /// No description provided for @previousImportsHeading.
  ///
  /// In en, this message translates to:
  /// **'Previous imports'**
  String get previousImportsHeading;

  /// No description provided for @noPreviousImports.
  ///
  /// In en, this message translates to:
  /// **'No previous imports were found for this account.'**
  String get noPreviousImports;

  /// No description provided for @resumeImport.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get resumeImport;

  /// No description provided for @loadMoreImports.
  ///
  /// In en, this message translates to:
  /// **'Load more imports'**
  String get loadMoreImports;

  /// No description provided for @importUploadIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Upload incomplete — select the file again'**
  String get importUploadIncomplete;

  /// No description provided for @importProcessing.
  ///
  /// In en, this message translates to:
  /// **'Scanning and preparing the preview'**
  String get importProcessing;

  /// No description provided for @importReadyForReview.
  ///
  /// In en, this message translates to:
  /// **'Ready for review'**
  String get importReadyForReview;

  /// No description provided for @importValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'Review the workbook errors'**
  String get importValidationFailed;

  /// No description provided for @importRejected.
  ///
  /// In en, this message translates to:
  /// **'Import rejected safely'**
  String get importRejected;

  /// No description provided for @importExpired.
  ///
  /// In en, this message translates to:
  /// **'Upload session expired'**
  String get importExpired;

  /// No description provided for @importApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved — draft creation pending'**
  String get importApproved;

  /// No description provided for @importReadyToPublish.
  ///
  /// In en, this message translates to:
  /// **'Draft ready — publication pending'**
  String get importReadyToPublish;

  /// No description provided for @importAlreadyPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get importAlreadyPublished;

  /// No description provided for @workbookUploadIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The app no longer has the selected file after restart. Select the workbook again to start a safe new upload.'**
  String get workbookUploadIncomplete;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Kelimio'**
  String get appName;

  /// No description provided for @configurationErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Configuration required'**
  String get configurationErrorTitle;

  /// No description provided for @configurationErrorBody.
  ///
  /// In en, this message translates to:
  /// **'This build is missing required production settings.'**
  String get configurationErrorBody;

  /// No description provided for @costConservationMessage.
  ///
  /// In en, this message translates to:
  /// **'Course creation and import are temporarily paused to protect the spending limit. You can continue learning.'**
  String get costConservationMessage;

  /// No description provided for @costReadOnlyMessage.
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily view-only. Your action was not recorded.'**
  String get costReadOnlyMessage;

  /// No description provided for @costSuspendedMessage.
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily suspended to protect the spending limit. Please try again later.'**
  String get costSuspendedMessage;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Learn with verified progress'**
  String get signInTitle;

  /// No description provided for @signInBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in securely to browse courses and continue learning.'**
  String get signInBody;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @profileSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your learning profile'**
  String get profileSetupTitle;

  /// No description provided for @profileSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Choose the language used by the app, the language you want to learn, and the language used for explanations.'**
  String get profileSetupBody;

  /// No description provided for @profileSetupLegalNotice.
  ///
  /// In en, this message translates to:
  /// **'This step saves learning preferences only. It is not acceptance of legal terms or marketing consent.'**
  String get profileSetupLegalNotice;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get appLanguage;

  /// No description provided for @targetLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language to learn'**
  String get targetLanguage;

  /// No description provided for @preferredSupportLanguage.
  ///
  /// In en, this message translates to:
  /// **'Preferred explanation language'**
  String get preferredSupportLanguage;

  /// No description provided for @timeZone.
  ///
  /// In en, this message translates to:
  /// **'Time zone'**
  String get timeZone;

  /// No description provided for @timeZoneIstanbul.
  ///
  /// In en, this message translates to:
  /// **'Türkiye (Europe/Istanbul)'**
  String get timeZoneIstanbul;

  /// No description provided for @timeZoneUtc.
  ///
  /// In en, this message translates to:
  /// **'UTC'**
  String get timeZoneUtc;

  /// No description provided for @completeProfileSetup.
  ///
  /// In en, this message translates to:
  /// **'Save and continue'**
  String get completeProfileSetup;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get requiredField;

  /// No description provided for @languageTurkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get languageTurkish;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @catalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get catalog;

  /// No description provided for @energy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get energy;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get genericError;

  /// No description provided for @networkError.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get networkError;

  /// No description provided for @emptyCatalog.
  ///
  /// In en, this message translates to:
  /// **'No courses are available right now.'**
  String get emptyCatalog;

  /// No description provided for @localStarterCourseBody.
  ///
  /// In en, this message translates to:
  /// **'For local testing, install the reviewed mixed Type-A and Type-B starter course. This does not create users or learning results.'**
  String get localStarterCourseBody;

  /// No description provided for @installLocalStarterCourse.
  ///
  /// In en, this message translates to:
  /// **'Install local starter course'**
  String get installLocalStarterCourse;

  /// No description provided for @yourProgress.
  ///
  /// In en, this message translates to:
  /// **'Your progress'**
  String get yourProgress;

  /// No description provided for @progressAnswers.
  ///
  /// In en, this message translates to:
  /// **'{correct} of {answered} answers correct'**
  String progressAnswers(Object answered, Object correct);

  /// No description provided for @progressAttempts.
  ///
  /// In en, this message translates to:
  /// **'{passed} of {completed} completed attempts passed'**
  String progressAttempts(Object completed, Object passed);

  /// No description provided for @progressScores.
  ///
  /// In en, this message translates to:
  /// **'Active score: {active} · Lifetime score: {lifetime}'**
  String progressScores(Object active, Object lifetime);

  /// No description provided for @progressUpdating.
  ///
  /// In en, this message translates to:
  /// **'Progress is updating from verified server events.'**
  String get progressUpdating;

  /// No description provided for @courseDetails.
  ///
  /// In en, this message translates to:
  /// **'Course details'**
  String get courseDetails;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @enrolled.
  ///
  /// In en, this message translates to:
  /// **'Enrolled'**
  String get enrolled;

  /// No description provided for @supportLanguage.
  ///
  /// In en, this message translates to:
  /// **'Support language'**
  String get supportLanguage;

  /// No description provided for @enroll.
  ///
  /// In en, this message translates to:
  /// **'Enroll'**
  String get enroll;

  /// No description provided for @paidEnrollmentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Paid enrollment is not available in this app yet.'**
  String get paidEnrollmentUnavailable;

  /// No description provided for @tests.
  ///
  /// In en, this message translates to:
  /// **'Tests'**
  String get tests;

  /// No description provided for @questionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 question} other{{count} questions}}'**
  String questionCount(num count);

  /// No description provided for @startTest.
  ///
  /// In en, this message translates to:
  /// **'Start test'**
  String get startTest;

  /// No description provided for @questionProgress.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String questionProgress(Object current, Object total);

  /// No description provided for @submitAnswer.
  ///
  /// In en, this message translates to:
  /// **'Submit answer'**
  String get submitAnswer;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get correct;

  /// No description provided for @incorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get incorrect;

  /// No description provided for @finishing.
  ///
  /// In en, this message translates to:
  /// **'Finishing your attempt'**
  String get finishing;

  /// No description provided for @passed.
  ///
  /// In en, this message translates to:
  /// **'You passed'**
  String get passed;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Keep practicing'**
  String get failed;

  /// No description provided for @resultSummary.
  ///
  /// In en, this message translates to:
  /// **'{correctCount} of {questionCount} correct ({percentage}%)'**
  String resultSummary(
    Object correctCount,
    Object percentage,
    Object questionCount,
  );

  /// No description provided for @backToCourse.
  ///
  /// In en, this message translates to:
  /// **'Back to course'**
  String get backToCourse;

  /// No description provided for @attemptInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Attempt interrupted'**
  String get attemptInterrupted;

  /// No description provided for @energyDepleted.
  ///
  /// In en, this message translates to:
  /// **'You have no energy left. Your server-confirmed progress is safe.'**
  String get energyDepleted;

  /// No description provided for @contentChanged.
  ///
  /// In en, this message translates to:
  /// **'This test changed while you were learning. Return to the course and start the current version.'**
  String get contentChanged;

  /// No description provided for @recoverAttempt.
  ///
  /// In en, this message translates to:
  /// **'Recover attempt'**
  String get recoverAttempt;

  /// No description provided for @recoverableError.
  ///
  /// In en, this message translates to:
  /// **'The request was not confirmed. Retrying uses the same safe submission identifier.'**
  String get recoverableError;

  /// No description provided for @fatalAttemptError.
  ///
  /// In en, this message translates to:
  /// **'This attempt cannot continue.'**
  String get fatalAttemptError;

  /// No description provided for @energyUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited energy'**
  String get energyUnlimited;

  /// No description provided for @energyBalance.
  ///
  /// In en, this message translates to:
  /// **'{balance} of {maximum}'**
  String energyBalance(Object balance, Object maximum);

  /// No description provided for @nextRegeneration.
  ///
  /// In en, this message translates to:
  /// **'Next energy: {time}'**
  String nextRegeneration(Object time);

  /// No description provided for @energyCurrentAsOf.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String energyCurrentAsOf(Object time);

  /// No description provided for @authenticationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was cancelled.'**
  String get authenticationCancelled;

  /// No description provided for @accessibilitySelectedAnswer.
  ///
  /// In en, this message translates to:
  /// **'Selected answer'**
  String get accessibilitySelectedAnswer;

  /// No description provided for @accessibilityCorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get accessibilityCorrectAnswer;

  /// No description provided for @accessibilityIncorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Incorrect answer'**
  String get accessibilityIncorrectAnswer;

  /// No description provided for @accessibilityBlank.
  ///
  /// In en, this message translates to:
  /// **'blank'**
  String get accessibilityBlank;

  /// No description provided for @typedAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get typedAnswerLabel;

  /// No description provided for @typedAnswerReentry.
  ///
  /// In en, this message translates to:
  /// **'The previous answer was not stored on this device. Enter it again to continue the same submission.'**
  String get typedAnswerReentry;

  /// No description provided for @correctAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get correctAnswerLabel;

  /// No description provided for @matchingInstructions.
  ///
  /// In en, this message translates to:
  /// **'Match each word in two steps: choose a learning-language word, then choose its meaning.'**
  String get matchingInstructions;

  /// No description provided for @matchingTargetsHeading.
  ///
  /// In en, this message translates to:
  /// **'Words to match'**
  String get matchingTargetsHeading;

  /// No description provided for @matchingSupportsHeading.
  ///
  /// In en, this message translates to:
  /// **'Meanings'**
  String get matchingSupportsHeading;

  /// No description provided for @matchingPairsHeading.
  ///
  /// In en, this message translates to:
  /// **'Your matches'**
  String get matchingPairsHeading;

  /// No description provided for @matchingProgress.
  ///
  /// In en, this message translates to:
  /// **'{matched} of {total} pairs matched'**
  String matchingProgress(Object matched, Object total);

  /// No description provided for @matchingTargetItemLabel.
  ///
  /// In en, this message translates to:
  /// **'Word: {item}'**
  String matchingTargetItemLabel(Object item);

  /// No description provided for @matchingSupportItemLabel.
  ///
  /// In en, this message translates to:
  /// **'Meaning: {item}'**
  String matchingSupportItemLabel(Object item);

  /// No description provided for @matchingTargetSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected word'**
  String get matchingTargetSelected;

  /// No description provided for @matchingAlreadyPaired.
  ///
  /// In en, this message translates to:
  /// **'Already matched'**
  String get matchingAlreadyPaired;

  /// No description provided for @matchingChooseTargetFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a word first'**
  String get matchingChooseTargetFirst;

  /// No description provided for @matchingPairLabel.
  ///
  /// In en, this message translates to:
  /// **'{target} matches {support}'**
  String matchingPairLabel(Object support, Object target);

  /// No description provided for @matchingTentativePair.
  ///
  /// In en, this message translates to:
  /// **'Tentative match'**
  String get matchingTentativePair;

  /// No description provided for @matchingCorrectPair.
  ///
  /// In en, this message translates to:
  /// **'Correct match'**
  String get matchingCorrectPair;

  /// No description provided for @matchingIncorrectPair.
  ///
  /// In en, this message translates to:
  /// **'Incorrect match'**
  String get matchingIncorrectPair;

  /// No description provided for @matchingRemovePair.
  ///
  /// In en, this message translates to:
  /// **'Remove match for {target}'**
  String matchingRemovePair(Object target);

  /// No description provided for @matchingCorrectMappingHeading.
  ///
  /// In en, this message translates to:
  /// **'Correct matching'**
  String get matchingCorrectMappingHeading;

  /// No description provided for @matchingFeedbackUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Your earlier matches are not stored on this device. The complete correct matching from the server is shown below.'**
  String get matchingFeedbackUnavailable;

  /// No description provided for @teacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get teacher;

  /// No description provided for @teacherAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Course authoring access'**
  String get teacherAccessTitle;

  /// No description provided for @teacherFeatureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Secure course authoring is not enabled for this build.'**
  String get teacherFeatureUnavailable;

  /// No description provided for @teacherAccountNotEligible.
  ///
  /// In en, this message translates to:
  /// **'This account is not authorized to create courses. Access is managed by the server.'**
  String get teacherAccountNotEligible;

  /// No description provided for @teacherTermsBody.
  ///
  /// In en, this message translates to:
  /// **'Your Excel file must contain only content you own or have the right to use. The file is security-scanned and previewed before the course is published.'**
  String get teacherTermsBody;

  /// No description provided for @teacherTermsAcceptance.
  ///
  /// In en, this message translates to:
  /// **'I have read these terms and confirm that I have the rights to the content I upload.'**
  String get teacherTermsAcceptance;

  /// No description provided for @teacherImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a course from Excel'**
  String get teacherImportTitle;

  /// No description provided for @teacherImportBody.
  ///
  /// In en, this message translates to:
  /// **'This local test flow uploads one .xlsx file for malware scanning and review. Approval, draft creation, and publication stay separate.'**
  String get teacherImportBody;

  /// No description provided for @selectWorkbook.
  ///
  /// In en, this message translates to:
  /// **'Select Excel file'**
  String get selectWorkbook;

  /// No description provided for @preparingWorkbook.
  ///
  /// In en, this message translates to:
  /// **'Checking the workbook'**
  String get preparingWorkbook;

  /// No description provided for @uploadingWorkbook.
  ///
  /// In en, this message translates to:
  /// **'Uploading the workbook'**
  String get uploadingWorkbook;

  /// No description provided for @processingWorkbook.
  ///
  /// In en, this message translates to:
  /// **'Scanning and preparing the preview'**
  String get processingWorkbook;

  /// No description provided for @previewHeading.
  ///
  /// In en, this message translates to:
  /// **'Review the import'**
  String get previewHeading;

  /// No description provided for @previewSummary.
  ///
  /// In en, this message translates to:
  /// **'{rows} source rows · {questions} questions · {matching} matching questions'**
  String previewSummary(Object matching, Object questions, Object rows);

  /// No description provided for @previewRowLabel.
  ///
  /// In en, this message translates to:
  /// **'Source row {row}, test {test}, question type {type}'**
  String previewRowLabel(Object row, Object test, Object type);

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @issuesHeading.
  ///
  /// In en, this message translates to:
  /// **'Warnings and errors'**
  String get issuesHeading;

  /// No description provided for @previewApprovalConfirmation.
  ///
  /// In en, this message translates to:
  /// **'I reviewed the preview and understand that approval does not publish the course.'**
  String get previewApprovalConfirmation;

  /// No description provided for @approvePreview.
  ///
  /// In en, this message translates to:
  /// **'Approve this preview'**
  String get approvePreview;

  /// No description provided for @draftCreationNotice.
  ///
  /// In en, this message translates to:
  /// **'The approved content can now be committed as an unpublished draft. This still does not make it visible to learners.'**
  String get draftCreationNotice;

  /// No description provided for @draftCreationConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Create exactly one immutable unpublished draft from this approved preview.'**
  String get draftCreationConfirmation;

  /// No description provided for @createDraft.
  ///
  /// In en, this message translates to:
  /// **'Create course draft'**
  String get createDraft;

  /// No description provided for @releaseImpactHeading.
  ///
  /// In en, this message translates to:
  /// **'Publication impact'**
  String get releaseImpactHeading;

  /// No description provided for @releaseImpactSummary.
  ///
  /// In en, this message translates to:
  /// **'{questions} questions · {added} added · {changed} changed · {removed} removed · {learners} affected learners'**
  String releaseImpactSummary(
    Object added,
    Object changed,
    Object learners,
    Object questions,
    Object removed,
  );

  /// No description provided for @releaseImpactConfirmation.
  ///
  /// In en, this message translates to:
  /// **'I reviewed this exact impact and want to activate the immutable release.'**
  String get releaseImpactConfirmation;

  /// No description provided for @publishCourse.
  ///
  /// In en, this message translates to:
  /// **'Publish course'**
  String get publishCourse;

  /// No description provided for @coursePublished.
  ///
  /// In en, this message translates to:
  /// **'The course release is active. Progress reprojection has been scheduled.'**
  String get coursePublished;

  /// No description provided for @newImport.
  ///
  /// In en, this message translates to:
  /// **'Start another import'**
  String get newImport;

  /// No description provided for @workbookRejected.
  ///
  /// In en, this message translates to:
  /// **'The workbook was rejected safely. Review the issues below.'**
  String get workbookRejected;

  /// No description provided for @workbookExpired.
  ///
  /// In en, this message translates to:
  /// **'This upload session expired. Start a new import.'**
  String get workbookExpired;

  /// No description provided for @fileDetails.
  ///
  /// In en, this message translates to:
  /// **'{name} · {size} bytes'**
  String fileDetails(Object name, Object size);

  /// No description provided for @questionType.
  ///
  /// In en, this message translates to:
  /// **'Type {type}'**
  String questionType(Object type);

  /// No description provided for @correctAnswerTeacher.
  ///
  /// In en, this message translates to:
  /// **'Reviewed answer: {answer}'**
  String correctAnswerTeacher(Object answer);

  /// No description provided for @alternativeCorrectAnswerTeacher.
  ///
  /// In en, this message translates to:
  /// **'Reviewed alternative answer: {answer}'**
  String alternativeCorrectAnswerTeacher(Object answer);

  /// No description provided for @wrongAnswersTeacher.
  ///
  /// In en, this message translates to:
  /// **'Reviewed distractors: {answers}'**
  String wrongAnswersTeacher(Object answers);

  /// No description provided for @matchingGroupTeacher.
  ///
  /// In en, this message translates to:
  /// **'Matching group: {group}'**
  String matchingGroupTeacher(Object group);

  /// No description provided for @editPublishedCourse.
  ///
  /// In en, this message translates to:
  /// **'Edit published course'**
  String get editPublishedCourse;

  /// No description provided for @courseEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit one course question'**
  String get courseEditorTitle;

  /// No description provided for @courseEditorScope.
  ///
  /// In en, this message translates to:
  /// **'This local test editor changes the prompt of the first eligible typed-gap question. The answer stays on the server.'**
  String get courseEditorScope;

  /// No description provided for @courseEditorPath.
  ///
  /// In en, this message translates to:
  /// **'{level} / {unit} / {topic} / {test}'**
  String courseEditorPath(Object level, Object test, Object topic, Object unit);

  /// No description provided for @courseEditorPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Question prompt'**
  String get courseEditorPromptLabel;

  /// No description provided for @courseEditorPromptHelp.
  ///
  /// In en, this message translates to:
  /// **'Keep exactly one --- placeholder. Maximum 1,000 characters.'**
  String get courseEditorPromptHelp;

  /// No description provided for @courseEditorRecovered.
  ///
  /// In en, this message translates to:
  /// **'Your unsaved change was restored from this device\'\'s secure storage.'**
  String get courseEditorRecovered;

  /// No description provided for @courseEditorRecoveryFailed.
  ///
  /// In en, this message translates to:
  /// **'This change could not be protected in secure storage. Copy it before leaving this screen.'**
  String get courseEditorRecoveryFailed;

  /// No description provided for @courseEditorPromptEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a question prompt.'**
  String get courseEditorPromptEmpty;

  /// No description provided for @courseEditorPromptTooLong.
  ///
  /// In en, this message translates to:
  /// **'The prompt must be at most 1,000 characters.'**
  String get courseEditorPromptTooLong;

  /// No description provided for @courseEditorPromptPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'The prompt must contain exactly one --- placeholder.'**
  String get courseEditorPromptPlaceholder;

  /// No description provided for @courseEditorPromptUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Change the prompt before creating a draft.'**
  String get courseEditorPromptUnchanged;

  /// No description provided for @discardEditorChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardEditorChanges;

  /// No description provided for @saveEditorDraft.
  ///
  /// In en, this message translates to:
  /// **'Create immutable draft'**
  String get saveEditorDraft;

  /// No description provided for @courseEditorConflictHeading.
  ///
  /// In en, this message translates to:
  /// **'The published question changed'**
  String get courseEditorConflictHeading;

  /// No description provided for @courseEditorConflictBody.
  ///
  /// In en, this message translates to:
  /// **'Compare the versions. Nothing will be overwritten until you choose how to continue.'**
  String get courseEditorConflictBody;

  /// No description provided for @courseEditorPreviousVersion.
  ///
  /// In en, this message translates to:
  /// **'Version you started from'**
  String get courseEditorPreviousVersion;

  /// No description provided for @courseEditorYourVersion.
  ///
  /// In en, this message translates to:
  /// **'Your unsaved version'**
  String get courseEditorYourVersion;

  /// No description provided for @courseEditorLatestVersion.
  ///
  /// In en, this message translates to:
  /// **'Latest published version'**
  String get courseEditorLatestVersion;

  /// No description provided for @courseEditorUseLatest.
  ///
  /// In en, this message translates to:
  /// **'Use latest version'**
  String get courseEditorUseLatest;

  /// No description provided for @courseEditorReapplyMine.
  ///
  /// In en, this message translates to:
  /// **'Reapply my version'**
  String get courseEditorReapplyMine;

  /// No description provided for @courseEditorImpactConfirmation.
  ///
  /// In en, this message translates to:
  /// **'I reviewed this exact one-question impact and want to publish the immutable release.'**
  String get courseEditorImpactConfirmation;

  /// No description provided for @publishEditorRevision.
  ///
  /// In en, this message translates to:
  /// **'Publish this revision'**
  String get publishEditorRevision;

  /// No description provided for @courseEditorPublished.
  ///
  /// In en, this message translates to:
  /// **'The edited release is active. No answer key was sent to this device.'**
  String get courseEditorPublished;

  /// No description provided for @courseEditorOtherRecovery.
  ///
  /// In en, this message translates to:
  /// **'Another course has an unsaved secure draft. Discard that draft before editing this course.'**
  String get courseEditorOtherRecovery;

  /// No description provided for @courseEditorDiscardOther.
  ///
  /// In en, this message translates to:
  /// **'Discard other draft'**
  String get courseEditorDiscardOther;

  /// No description provided for @courseEditorLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved change?'**
  String get courseEditorLeaveTitle;

  /// No description provided for @courseEditorLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'Your change is stored securely on this device. You can keep it for later or discard it now.'**
  String get courseEditorLeaveBody;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep for later'**
  String get keepEditing;

  /// No description provided for @myCourses.
  ///
  /// In en, this message translates to:
  /// **'My courses'**
  String get myCourses;

  /// No description provided for @newCourseFromExcel.
  ///
  /// In en, this message translates to:
  /// **'New course from Excel'**
  String get newCourseFromExcel;

  /// No description provided for @noTeacherCourses.
  ///
  /// In en, this message translates to:
  /// **'You do not have a course yet. You can create your first course from an Excel file.'**
  String get noTeacherCourses;

  /// No description provided for @courseRevision.
  ///
  /// In en, this message translates to:
  /// **'{language} · revision {revision}'**
  String courseRevision(Object language, Object revision);

  /// No description provided for @unpublishedDraftAvailable.
  ///
  /// In en, this message translates to:
  /// **'unpublished draft available'**
  String get unpublishedDraftAvailable;

  /// No description provided for @createInvitation.
  ///
  /// In en, this message translates to:
  /// **'Create invitation'**
  String get createInvitation;

  /// No description provided for @courseInvitationReady.
  ///
  /// In en, this message translates to:
  /// **'Course invitation ready'**
  String get courseInvitationReady;

  /// No description provided for @courseInvitationShare.
  ///
  /// In en, this message translates to:
  /// **'Share this single-use code securely with your learner:'**
  String get courseInvitationShare;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @invitationCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Invitation could not be created: {error}'**
  String invitationCreateFailed(Object error);

  /// No description provided for @draftReleaseTitle.
  ///
  /// In en, this message translates to:
  /// **'Draft revision {revision}'**
  String draftReleaseTitle(Object revision);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @abandonDraft.
  ///
  /// In en, this message translates to:
  /// **'Abandon draft'**
  String get abandonDraft;

  /// No description provided for @draftAbandoned.
  ///
  /// In en, this message translates to:
  /// **'The draft was abandoned safely.'**
  String get draftAbandoned;

  /// No description provided for @courseRevisionPublished.
  ///
  /// In en, this message translates to:
  /// **'The new course revision was published.'**
  String get courseRevisionPublished;

  /// No description provided for @draftPublishFailed.
  ///
  /// In en, this message translates to:
  /// **'The draft could not be published: {error}'**
  String draftPublishFailed(Object error);

  /// No description provided for @fullCourseEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Course editor'**
  String get fullCourseEditorTitle;

  /// No description provided for @publishRevisionTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish revision {revision}?'**
  String publishRevisionTitle(Object revision);

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @revisionPublished.
  ///
  /// In en, this message translates to:
  /// **'Revision {revision} was published.'**
  String revisionPublished(Object revision);

  /// No description provided for @fullEditorConflictHeading.
  ///
  /// In en, this message translates to:
  /// **'The course changed elsewhere'**
  String get fullEditorConflictHeading;

  /// No description provided for @fullEditorConflictBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing was saved. Compare the three versions below, then use the latest server version or explicitly reapply your edits on top of it.'**
  String get fullEditorConflictBody;

  /// No description provided for @fullEditorBaseVersion.
  ///
  /// In en, this message translates to:
  /// **'Version you started editing'**
  String get fullEditorBaseVersion;

  /// No description provided for @fullEditorMineVersion.
  ///
  /// In en, this message translates to:
  /// **'Your edits'**
  String get fullEditorMineVersion;

  /// No description provided for @fullEditorLatestVersion.
  ///
  /// In en, this message translates to:
  /// **'Latest server version'**
  String get fullEditorLatestVersion;

  /// No description provided for @fullEditorUseLatest.
  ///
  /// In en, this message translates to:
  /// **'Use latest server version'**
  String get fullEditorUseLatest;

  /// No description provided for @fullEditorReapplyMine.
  ///
  /// In en, this message translates to:
  /// **'Reapply my edits to the latest version'**
  String get fullEditorReapplyMine;

  /// No description provided for @fullEditorVersionSummary.
  ///
  /// In en, this message translates to:
  /// **'{name} · {levels} levels · {questions} questions · revision {revision}'**
  String fullEditorVersionSummary(
    Object levels,
    Object name,
    Object questions,
    Object revision,
  );

  /// No description provided for @editorChanges.
  ///
  /// In en, this message translates to:
  /// **'{count} changes:'**
  String editorChanges(Object count);

  /// No description provided for @editorMoreChanges.
  ///
  /// In en, this message translates to:
  /// **'{count} more changes'**
  String editorMoreChanges(Object count);

  /// No description provided for @courseName.
  ///
  /// In en, this message translates to:
  /// **'Course name'**
  String get courseName;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @visibility.
  ///
  /// In en, this message translates to:
  /// **'Visibility'**
  String get visibility;

  /// No description provided for @publicVisibility.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get publicVisibility;

  /// No description provided for @privateVisibility.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get privateVisibility;

  /// No description provided for @targetAndSupportLanguages.
  ///
  /// In en, this message translates to:
  /// **'{target} · support: {support}'**
  String targetAndSupportLanguages(Object support, Object target);

  /// No description provided for @addLevel.
  ///
  /// In en, this message translates to:
  /// **'Add level'**
  String get addLevel;

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// No description provided for @addUnit.
  ///
  /// In en, this message translates to:
  /// **'Add unit'**
  String get addUnit;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @addTopic.
  ///
  /// In en, this message translates to:
  /// **'Add topic'**
  String get addTopic;

  /// No description provided for @topic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get topic;

  /// No description provided for @addTest.
  ///
  /// In en, this message translates to:
  /// **'Add test'**
  String get addTest;

  /// No description provided for @test.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get test;

  /// No description provided for @addQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add question'**
  String get addQuestion;

  /// No description provided for @questionTypeWordMultipleChoice.
  ///
  /// In en, this message translates to:
  /// **'Word multiple choice'**
  String get questionTypeWordMultipleChoice;

  /// No description provided for @questionTypeMultipleChoiceCloze.
  ///
  /// In en, this message translates to:
  /// **'Multiple-choice gap'**
  String get questionTypeMultipleChoiceCloze;

  /// No description provided for @questionTypeTypedCloze.
  ///
  /// In en, this message translates to:
  /// **'Typed gap'**
  String get questionTypeTypedCloze;

  /// No description provided for @questionTypeMatching.
  ///
  /// In en, this message translates to:
  /// **'Matching'**
  String get questionTypeMatching;

  /// No description provided for @questionTitle.
  ///
  /// In en, this message translates to:
  /// **'Question · {type}'**
  String questionTitle(Object type);

  /// No description provided for @questionPrompt.
  ///
  /// In en, this message translates to:
  /// **'Question text'**
  String get questionPrompt;

  /// No description provided for @alternativeCorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Alternative correct answer'**
  String get alternativeCorrectAnswer;

  /// No description provided for @translationLanguage.
  ///
  /// In en, this message translates to:
  /// **'Translation ({language})'**
  String translationLanguage(Object language);

  /// No description provided for @addMatchingPair.
  ///
  /// In en, this message translates to:
  /// **'Add matching pair'**
  String get addMatchingPair;

  /// No description provided for @moveOptionUp.
  ///
  /// In en, this message translates to:
  /// **'Move option up'**
  String get moveOptionUp;

  /// No description provided for @moveOptionDown.
  ///
  /// In en, this message translates to:
  /// **'Move option down'**
  String get moveOptionDown;

  /// No description provided for @correctOption.
  ///
  /// In en, this message translates to:
  /// **'Correct option'**
  String get correctOption;

  /// No description provided for @option.
  ///
  /// In en, this message translates to:
  /// **'Option'**
  String get option;

  /// No description provided for @optionTranslation.
  ///
  /// In en, this message translates to:
  /// **'Option translation ({language})'**
  String optionTranslation(Object language);

  /// No description provided for @matchingTarget.
  ///
  /// In en, this message translates to:
  /// **'Matching target'**
  String get matchingTarget;

  /// No description provided for @matchingText.
  ///
  /// In en, this message translates to:
  /// **'Matching text ({language})'**
  String matchingText(Object language);

  /// No description provided for @moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get moveDown;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @newLevel.
  ///
  /// In en, this message translates to:
  /// **'New level {ordinal}'**
  String newLevel(Object ordinal);

  /// No description provided for @newUnit.
  ///
  /// In en, this message translates to:
  /// **'New unit {ordinal}'**
  String newUnit(Object ordinal);

  /// No description provided for @newTopic.
  ///
  /// In en, this message translates to:
  /// **'New topic {ordinal}'**
  String newTopic(Object ordinal);

  /// No description provided for @newTest.
  ///
  /// In en, this message translates to:
  /// **'New test {ordinal}'**
  String newTest(Object ordinal);

  /// No description provided for @newTarget.
  ///
  /// In en, this message translates to:
  /// **'Target {ordinal}'**
  String newTarget(Object ordinal);

  /// No description provided for @newMatch.
  ///
  /// In en, this message translates to:
  /// **'Match {ordinal} {language}'**
  String newMatch(Object language, Object ordinal);

  /// No description provided for @newWord.
  ///
  /// In en, this message translates to:
  /// **'New word {ordinal}'**
  String newWord(Object ordinal);

  /// No description provided for @newSentence.
  ///
  /// In en, this message translates to:
  /// **'New sentence --- {ordinal}'**
  String newSentence(Object ordinal);

  /// No description provided for @newAnswer.
  ///
  /// In en, this message translates to:
  /// **'answer{ordinal}'**
  String newAnswer(Object ordinal);

  /// No description provided for @newWrongAnswer.
  ///
  /// In en, this message translates to:
  /// **'wrong{ordinal}{option}'**
  String newWrongAnswer(Object option, Object ordinal);

  /// No description provided for @newTranslation.
  ///
  /// In en, this message translates to:
  /// **'Translation {ordinal}'**
  String newTranslation(Object ordinal);

  /// No description provided for @newOption.
  ///
  /// In en, this message translates to:
  /// **'Option {ordinal}.{option}'**
  String newOption(Object option, Object ordinal);

  /// No description provided for @course.
  ///
  /// In en, this message translates to:
  /// **'Course'**
  String get course;

  /// No description provided for @identifier.
  ///
  /// In en, this message translates to:
  /// **'identifier'**
  String get identifier;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'title'**
  String get title;

  /// No description provided for @order.
  ///
  /// In en, this message translates to:
  /// **'order'**
  String get order;

  /// No description provided for @passThreshold.
  ///
  /// In en, this message translates to:
  /// **'pass threshold'**
  String get passThreshold;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'type'**
  String get type;

  /// No description provided for @text.
  ///
  /// In en, this message translates to:
  /// **'text'**
  String get text;

  /// No description provided for @correctValue.
  ///
  /// In en, this message translates to:
  /// **'correct'**
  String get correctValue;

  /// No description provided for @question.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get question;

  /// No description provided for @matching.
  ///
  /// In en, this message translates to:
  /// **'Matching'**
  String get matching;

  /// No description provided for @useCourseInvitation.
  ///
  /// In en, this message translates to:
  /// **'Use course invitation'**
  String get useCourseInvitation;

  /// No description provided for @courseInvitationTitle.
  ///
  /// In en, this message translates to:
  /// **'Course invitation'**
  String get courseInvitationTitle;

  /// No description provided for @invitationCode.
  ///
  /// In en, this message translates to:
  /// **'Invitation code'**
  String get invitationCode;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @searchCourses.
  ///
  /// In en, this message translates to:
  /// **'Search courses'**
  String get searchCourses;

  /// No description provided for @accessFilter.
  ///
  /// In en, this message translates to:
  /// **'Access filter'**
  String get accessFilter;

  /// No description provided for @allCourses.
  ///
  /// In en, this message translates to:
  /// **'All courses'**
  String get allCourses;

  /// No description provided for @acceptInvitationQuestion.
  ///
  /// In en, this message translates to:
  /// **'Would you like to accept this private course invitation?'**
  String get acceptInvitationQuestion;

  /// No description provided for @acceptInvitation.
  ///
  /// In en, this message translates to:
  /// **'Accept invitation'**
  String get acceptInvitation;

  /// No description provided for @invitationAcceptFailed.
  ///
  /// In en, this message translates to:
  /// **'The invitation could not be accepted: {error}'**
  String invitationAcceptFailed(Object error);

  /// No description provided for @downloadOfflinePractice.
  ///
  /// In en, this message translates to:
  /// **'Download scoreless offline practice'**
  String get downloadOfflinePractice;

  /// No description provided for @offlinePackageDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'The offline package could not be downloaded: {error}'**
  String offlinePackageDownloadFailed(Object error);

  /// No description provided for @offlinePracticeTitle.
  ///
  /// In en, this message translates to:
  /// **'Scoreless offline practice'**
  String get offlinePracticeTitle;

  /// No description provided for @offlinePracticeProgress.
  ///
  /// In en, this message translates to:
  /// **'{current}/{total} · This practice does not award score or energy.'**
  String offlinePracticeProgress(Object current, Object total);

  /// No description provided for @yourAnswer.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get yourAnswer;

  /// No description provided for @offlineCorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer: {answer}'**
  String offlineCorrectAnswer(Object answer);

  /// No description provided for @practiceAgain.
  ///
  /// In en, this message translates to:
  /// **'I need more practice'**
  String get practiceAgain;

  /// No description provided for @knewMatchingPairs.
  ///
  /// In en, this message translates to:
  /// **'I knew the matches'**
  String get knewMatchingPairs;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @checkAnswer.
  ///
  /// In en, this message translates to:
  /// **'Check answer'**
  String get checkAnswer;

  /// No description provided for @offlinePracticeComplete.
  ///
  /// In en, this message translates to:
  /// **'Offline practice complete'**
  String get offlinePracticeComplete;

  /// No description provided for @offlinePracticeResult.
  ///
  /// In en, this message translates to:
  /// **'{correct}/{total} correct. This result was stored only on this device and was not sent to your online score.'**
  String offlinePracticeResult(Object correct, Object total);

  /// No description provided for @accountProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get accountProfileTitle;

  /// No description provided for @accountLearningSummary.
  ///
  /// In en, this message translates to:
  /// **'Learning summary'**
  String get accountLearningSummary;

  /// No description provided for @accountScoreAndStreak.
  ///
  /// In en, this message translates to:
  /// **'{score} points · {days}-day streak'**
  String accountScoreAndStreak(Object days, Object score);

  /// No description provided for @accountTestAndCourseSummary.
  ///
  /// In en, this message translates to:
  /// **'{passed}/{attempts} passed tests · {completed}/{enrolled} active courses'**
  String accountTestAndCourseSummary(
    Object attempts,
    Object completed,
    Object enrolled,
    Object passed,
  );

  /// No description provided for @accountCorrectAnswers.
  ///
  /// In en, this message translates to:
  /// **'{correct}/{total} correct'**
  String accountCorrectAnswers(Object correct, Object total);

  /// No description provided for @accountData.
  ///
  /// In en, this message translates to:
  /// **'Account data'**
  String get accountData;

  /// No description provided for @accountExportJson.
  ///
  /// In en, this message translates to:
  /// **'Export my data as JSON'**
  String get accountExportJson;

  /// No description provided for @accountRevokeAllSessions.
  ///
  /// In en, this message translates to:
  /// **'Sign out from all devices'**
  String get accountRevokeAllSessions;

  /// No description provided for @accountRequestDeletion.
  ///
  /// In en, this message translates to:
  /// **'Request account deletion'**
  String get accountRequestDeletion;

  /// No description provided for @accountDeletionRecovery.
  ///
  /// In en, this message translates to:
  /// **'Deletion requests include a 7-day recovery period to protect against mistakes.'**
  String get accountDeletionRecovery;

  /// No description provided for @accountDeletionReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Deletion requests could not be loaded: {error}'**
  String accountDeletionReadFailed(Object error);

  /// No description provided for @accountPendingDeletion.
  ///
  /// In en, this message translates to:
  /// **'Pending deletion request'**
  String get accountPendingDeletion;

  /// No description provided for @accountDeletionCancelableUntil.
  ///
  /// In en, this message translates to:
  /// **'Can be cancelled until {date}.'**
  String accountDeletionCancelableUntil(Object date);

  /// No description provided for @accountCancelDeletion.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get accountCancelDeletion;

  /// No description provided for @accountLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get accountLeaderboard;

  /// No description provided for @accountLeaderboardPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Only public profiles whose owners explicitly opted in are shown.'**
  String get accountLeaderboardPrivacy;

  /// No description provided for @accountNoParticipants.
  ///
  /// In en, this message translates to:
  /// **'No participants yet.'**
  String get accountNoParticipants;

  /// No description provided for @accountCompletedTests.
  ///
  /// In en, this message translates to:
  /// **'@{username} · {count} completed tests'**
  String accountCompletedTests(Object count, Object username);

  /// No description provided for @accountPoints.
  ///
  /// In en, this message translates to:
  /// **'{score} points'**
  String accountPoints(Object score);

  /// No description provided for @accountExportSaved.
  ///
  /// In en, this message translates to:
  /// **'Data export saved.'**
  String get accountExportSaved;

  /// No description provided for @accountExportFailed.
  ///
  /// In en, this message translates to:
  /// **'The export could not be saved: {error}'**
  String accountExportFailed(Object error);

  /// No description provided for @accountDeletionCancelled.
  ///
  /// In en, this message translates to:
  /// **'The account deletion request was cancelled.'**
  String get accountDeletionCancelled;

  /// No description provided for @accountDeletionCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'The request could not be cancelled: {error}'**
  String accountDeletionCancelFailed(Object error);

  /// No description provided for @accountDeletionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a deletion request?'**
  String get accountDeletionDialogTitle;

  /// No description provided for @accountDeletionDialogBody.
  ///
  /// In en, this message translates to:
  /// **'The request will be stored securely for processing after 7 days. This does not change score and learning-history retention rules.'**
  String get accountDeletionDialogBody;

  /// No description provided for @accountCreateRequest.
  ///
  /// In en, this message translates to:
  /// **'Create request'**
  String get accountCreateRequest;

  /// No description provided for @accountDeletionScheduled.
  ///
  /// In en, this message translates to:
  /// **'The deletion request was scheduled for {date}.'**
  String accountDeletionScheduled(Object date);

  /// No description provided for @accountDeletionRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'The request could not be created: {error}'**
  String accountDeletionRequestFailed(Object error);

  /// No description provided for @accountRevokeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Close all sessions?'**
  String get accountRevokeDialogTitle;

  /// No description provided for @accountRevokeDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Refresh sessions on every device, including this one, will be revoked in AWS Cognito.'**
  String get accountRevokeDialogBody;

  /// No description provided for @accountRevokeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out everywhere'**
  String get accountRevokeConfirm;

  /// No description provided for @accountRevokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Sessions could not be closed: {error}'**
  String accountRevokeFailed(Object error);

  /// No description provided for @accountNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get accountNotifications;

  /// No description provided for @accountLearningReminders.
  ///
  /// In en, this message translates to:
  /// **'Learning reminders'**
  String get accountLearningReminders;

  /// No description provided for @accountCourseUpdates.
  ///
  /// In en, this message translates to:
  /// **'Course updates'**
  String get accountCourseUpdates;

  /// No description provided for @accountProductAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'Product announcements'**
  String get accountProductAnnouncements;

  /// No description provided for @accountPushNotification.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get accountPushNotification;

  /// No description provided for @accountEmailNotification.
  ///
  /// In en, this message translates to:
  /// **'Email notifications'**
  String get accountEmailNotification;

  /// No description provided for @accountAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get accountAvailable;

  /// No description provided for @accountPushUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The Firebase provider is not configured yet'**
  String get accountPushUnavailable;

  /// No description provided for @accountEmailUnavailable.
  ///
  /// In en, this message translates to:
  /// **'A verified production sender is not configured yet'**
  String get accountEmailUnavailable;

  /// No description provided for @accountQuietHours.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours'**
  String get accountQuietHours;

  /// No description provided for @accountDisabled.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get accountDisabled;

  /// No description provided for @accountDisableQuietHours.
  ///
  /// In en, this message translates to:
  /// **'Turn off quiet hours'**
  String get accountDisableQuietHours;

  /// No description provided for @accountSetQuietHours.
  ///
  /// In en, this message translates to:
  /// **'Set quiet hours'**
  String get accountSetQuietHours;

  /// No description provided for @accountSaveNotifications.
  ///
  /// In en, this message translates to:
  /// **'Save notifications'**
  String get accountSaveNotifications;

  /// No description provided for @accountNotificationsSaved.
  ///
  /// In en, this message translates to:
  /// **'Notification preferences saved.'**
  String get accountNotificationsSaved;

  /// No description provided for @accountNotificationsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Preferences could not be saved: {error}'**
  String accountNotificationsSaveFailed(Object error);

  /// No description provided for @accountQuietHoursStart.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours start'**
  String get accountQuietHoursStart;

  /// No description provided for @accountQuietHoursEnd.
  ///
  /// In en, this message translates to:
  /// **'Quiet hours end'**
  String get accountQuietHoursEnd;

  /// No description provided for @accountMyAccount.
  ///
  /// In en, this message translates to:
  /// **'My account'**
  String get accountMyAccount;

  /// No description provided for @accountDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get accountDisplayName;

  /// No description provided for @accountUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get accountUsername;

  /// No description provided for @accountBio.
  ///
  /// In en, this message translates to:
  /// **'Short bio'**
  String get accountBio;

  /// No description provided for @accountPublicProfile.
  ///
  /// In en, this message translates to:
  /// **'Public profile'**
  String get accountPublicProfile;

  /// No description provided for @accountPublicProfileDefault.
  ///
  /// In en, this message translates to:
  /// **'It is off by default.'**
  String get accountPublicProfileDefault;

  /// No description provided for @accountJoinLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Join the leaderboard'**
  String get accountJoinLeaderboard;

  /// No description provided for @accountProfileStats.
  ///
  /// In en, this message translates to:
  /// **'{score} total points · {tests} tests'**
  String accountProfileStats(Object score, Object tests);

  /// No description provided for @accountSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get accountSave;

  /// No description provided for @accountProfileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved.'**
  String get accountProfileSaved;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
