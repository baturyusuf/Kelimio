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
