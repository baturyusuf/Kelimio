// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get findPreviousImports => 'Find previous imports';

  @override
  String get findingPreviousImports => 'Finding your previous imports';

  @override
  String get previousImportsHeading => 'Previous imports';

  @override
  String get noPreviousImports =>
      'No previous imports were found for this account.';

  @override
  String get resumeImport => 'Continue';

  @override
  String get loadMoreImports => 'Load more imports';

  @override
  String get importUploadIncomplete =>
      'Upload incomplete — select the file again';

  @override
  String get importProcessing => 'Scanning and preparing the preview';

  @override
  String get importReadyForReview => 'Ready for review';

  @override
  String get importValidationFailed => 'Review the workbook errors';

  @override
  String get importRejected => 'Import rejected safely';

  @override
  String get importExpired => 'Upload session expired';

  @override
  String get importApproved => 'Approved — draft creation pending';

  @override
  String get importReadyToPublish => 'Draft ready — publication pending';

  @override
  String get importAlreadyPublished => 'Published';

  @override
  String get workbookUploadIncomplete =>
      'The app no longer has the selected file after restart. Select the workbook again to start a safe new upload.';

  @override
  String get appName => 'Kelimio';

  @override
  String get configurationErrorTitle => 'Configuration required';

  @override
  String get configurationErrorBody =>
      'This build is missing required production settings.';

  @override
  String get costConservationMessage =>
      'Course creation and import are temporarily paused to protect the spending limit. You can continue learning.';

  @override
  String get costReadOnlyMessage =>
      'The service is temporarily view-only. Your action was not recorded.';

  @override
  String get costSuspendedMessage =>
      'The service is temporarily suspended to protect the spending limit. Please try again later.';

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

  @override
  String get typedAnswerLabel => 'Your answer';

  @override
  String get typedAnswerReentry =>
      'The previous answer was not stored on this device. Enter it again to continue the same submission.';

  @override
  String get correctAnswerLabel => 'Correct answer';

  @override
  String get matchingInstructions =>
      'Match each word in two steps: choose a learning-language word, then choose its meaning.';

  @override
  String get matchingTargetsHeading => 'Words to match';

  @override
  String get matchingSupportsHeading => 'Meanings';

  @override
  String get matchingPairsHeading => 'Your matches';

  @override
  String matchingProgress(Object matched, Object total) {
    return '$matched of $total pairs matched';
  }

  @override
  String matchingTargetItemLabel(Object item) {
    return 'Word: $item';
  }

  @override
  String matchingSupportItemLabel(Object item) {
    return 'Meaning: $item';
  }

  @override
  String get matchingTargetSelected => 'Selected word';

  @override
  String get matchingAlreadyPaired => 'Already matched';

  @override
  String get matchingChooseTargetFirst => 'Choose a word first';

  @override
  String matchingPairLabel(Object support, Object target) {
    return '$target matches $support';
  }

  @override
  String get matchingTentativePair => 'Tentative match';

  @override
  String get matchingCorrectPair => 'Correct match';

  @override
  String get matchingIncorrectPair => 'Incorrect match';

  @override
  String matchingRemovePair(Object target) {
    return 'Remove match for $target';
  }

  @override
  String get matchingCorrectMappingHeading => 'Correct matching';

  @override
  String get matchingFeedbackUnavailable =>
      'Your earlier matches are not stored on this device. The complete correct matching from the server is shown below.';

  @override
  String get teacher => 'Teacher';

  @override
  String get teacherAccessTitle => 'Course authoring access';

  @override
  String get teacherFeatureUnavailable =>
      'Secure course authoring is not enabled for this build.';

  @override
  String get teacherAccountNotEligible =>
      'This account is not authorized to create courses. Access is managed by the server.';

  @override
  String get teacherTermsBody =>
      'Your Excel file must contain only content you own or have the right to use. The file is security-scanned and previewed before the course is published.';

  @override
  String get teacherTermsAcceptance =>
      'I have read these terms and confirm that I have the rights to the content I upload.';

  @override
  String get teacherImportTitle => 'Create a course from Excel';

  @override
  String get teacherImportBody =>
      'This local test flow uploads one .xlsx file for malware scanning and review. Approval, draft creation, and publication stay separate.';

  @override
  String get selectWorkbook => 'Select Excel file';

  @override
  String get preparingWorkbook => 'Checking the workbook';

  @override
  String get uploadingWorkbook => 'Uploading the workbook';

  @override
  String get processingWorkbook => 'Scanning and preparing the preview';

  @override
  String get previewHeading => 'Review the import';

  @override
  String previewSummary(Object matching, Object questions, Object rows) {
    return '$rows source rows · $questions questions · $matching matching questions';
  }

  @override
  String previewRowLabel(Object row, Object test, Object type) {
    return 'Source row $row, test $test, question type $type';
  }

  @override
  String get loadMore => 'Load more';

  @override
  String get issuesHeading => 'Warnings and errors';

  @override
  String get previewApprovalConfirmation =>
      'I reviewed the preview and understand that approval does not publish the course.';

  @override
  String get approvePreview => 'Approve this preview';

  @override
  String get draftCreationNotice =>
      'The approved content can now be committed as an unpublished draft. This still does not make it visible to learners.';

  @override
  String get draftCreationConfirmation =>
      'Create exactly one immutable unpublished draft from this approved preview.';

  @override
  String get createDraft => 'Create course draft';

  @override
  String get releaseImpactHeading => 'Publication impact';

  @override
  String releaseImpactSummary(
    Object added,
    Object changed,
    Object learners,
    Object questions,
    Object removed,
  ) {
    return '$questions questions · $added added · $changed changed · $removed removed · $learners affected learners';
  }

  @override
  String get releaseImpactConfirmation =>
      'I reviewed this exact impact and want to activate the immutable release.';

  @override
  String get publishCourse => 'Publish course';

  @override
  String get coursePublished =>
      'The course release is active. Progress reprojection has been scheduled.';

  @override
  String get newImport => 'Start another import';

  @override
  String get workbookRejected =>
      'The workbook was rejected safely. Review the issues below.';

  @override
  String get workbookExpired =>
      'This upload session expired. Start a new import.';

  @override
  String fileDetails(Object name, Object size) {
    return '$name · $size bytes';
  }

  @override
  String questionType(Object type) {
    return 'Type $type';
  }

  @override
  String correctAnswerTeacher(Object answer) {
    return 'Reviewed answer: $answer';
  }

  @override
  String alternativeCorrectAnswerTeacher(Object answer) {
    return 'Reviewed alternative answer: $answer';
  }

  @override
  String wrongAnswersTeacher(Object answers) {
    return 'Reviewed distractors: $answers';
  }

  @override
  String matchingGroupTeacher(Object group) {
    return 'Matching group: $group';
  }

  @override
  String get editPublishedCourse => 'Edit published course';

  @override
  String get courseEditorTitle => 'Edit one course question';

  @override
  String get courseEditorScope =>
      'This local test editor changes the prompt of the first eligible typed-gap question. The answer stays on the server.';

  @override
  String courseEditorPath(
    Object level,
    Object test,
    Object topic,
    Object unit,
  ) {
    return '$level / $unit / $topic / $test';
  }

  @override
  String get courseEditorPromptLabel => 'Question prompt';

  @override
  String get courseEditorPromptHelp =>
      'Keep exactly one --- placeholder. Maximum 1,000 characters.';

  @override
  String get courseEditorRecovered =>
      'Your unsaved change was restored from this device\'s secure storage.';

  @override
  String get courseEditorRecoveryFailed =>
      'This change could not be protected in secure storage. Copy it before leaving this screen.';

  @override
  String get courseEditorPromptEmpty => 'Enter a question prompt.';

  @override
  String get courseEditorPromptTooLong =>
      'The prompt must be at most 1,000 characters.';

  @override
  String get courseEditorPromptPlaceholder =>
      'The prompt must contain exactly one --- placeholder.';

  @override
  String get courseEditorPromptUnchanged =>
      'Change the prompt before creating a draft.';

  @override
  String get discardEditorChanges => 'Discard changes';

  @override
  String get saveEditorDraft => 'Create immutable draft';

  @override
  String get courseEditorConflictHeading => 'The published question changed';

  @override
  String get courseEditorConflictBody =>
      'Compare the versions. Nothing will be overwritten until you choose how to continue.';

  @override
  String get courseEditorPreviousVersion => 'Version you started from';

  @override
  String get courseEditorYourVersion => 'Your unsaved version';

  @override
  String get courseEditorLatestVersion => 'Latest published version';

  @override
  String get courseEditorUseLatest => 'Use latest version';

  @override
  String get courseEditorReapplyMine => 'Reapply my version';

  @override
  String get courseEditorImpactConfirmation =>
      'I reviewed this exact one-question impact and want to publish the immutable release.';

  @override
  String get publishEditorRevision => 'Publish this revision';

  @override
  String get courseEditorPublished =>
      'The edited release is active. No answer key was sent to this device.';

  @override
  String get courseEditorOtherRecovery =>
      'Another course has an unsaved secure draft. Discard that draft before editing this course.';

  @override
  String get courseEditorDiscardOther => 'Discard other draft';

  @override
  String get courseEditorLeaveTitle => 'Discard unsaved change?';

  @override
  String get courseEditorLeaveBody =>
      'Your change is stored securely on this device. You can keep it for later or discard it now.';

  @override
  String get keepEditing => 'Keep for later';

  @override
  String get myCourses => 'My courses';

  @override
  String get newCourseFromExcel => 'New course from Excel';

  @override
  String get noTeacherCourses =>
      'You do not have a course yet. You can create your first course from an Excel file.';

  @override
  String courseRevision(Object language, Object revision) {
    return '$language · revision $revision';
  }

  @override
  String get unpublishedDraftAvailable => 'unpublished draft available';

  @override
  String get createInvitation => 'Create invitation';

  @override
  String get courseInvitationReady => 'Course invitation ready';

  @override
  String get courseInvitationShare =>
      'Share this single-use code securely with your learner:';

  @override
  String get copy => 'Copy';

  @override
  String invitationCreateFailed(Object error) {
    return 'Invitation could not be created: $error';
  }

  @override
  String draftReleaseTitle(Object revision) {
    return 'Draft revision $revision';
  }

  @override
  String get close => 'Close';

  @override
  String get abandonDraft => 'Abandon draft';

  @override
  String get draftAbandoned => 'The draft was abandoned safely.';

  @override
  String get courseRevisionPublished =>
      'The new course revision was published.';

  @override
  String draftPublishFailed(Object error) {
    return 'The draft could not be published: $error';
  }

  @override
  String get fullCourseEditorTitle => 'Course editor';

  @override
  String publishRevisionTitle(Object revision) {
    return 'Publish revision $revision?';
  }

  @override
  String get later => 'Later';

  @override
  String revisionPublished(Object revision) {
    return 'Revision $revision was published.';
  }

  @override
  String get fullEditorConflictHeading => 'The course changed elsewhere';

  @override
  String get fullEditorConflictBody =>
      'Nothing was saved. Compare the three versions below, then use the latest server version or explicitly reapply your edits on top of it.';

  @override
  String get fullEditorBaseVersion => 'Version you started editing';

  @override
  String get fullEditorMineVersion => 'Your edits';

  @override
  String get fullEditorLatestVersion => 'Latest server version';

  @override
  String get fullEditorUseLatest => 'Use latest server version';

  @override
  String get fullEditorReapplyMine => 'Reapply my edits to the latest version';

  @override
  String fullEditorVersionSummary(
    Object levels,
    Object name,
    Object questions,
    Object revision,
  ) {
    return '$name · $levels levels · $questions questions · revision $revision';
  }

  @override
  String editorChanges(Object count) {
    return '$count changes:';
  }

  @override
  String editorMoreChanges(Object count) {
    return '$count more changes';
  }

  @override
  String get courseName => 'Course name';

  @override
  String get description => 'Description';

  @override
  String get visibility => 'Visibility';

  @override
  String get publicVisibility => 'Public';

  @override
  String get privateVisibility => 'Private';

  @override
  String targetAndSupportLanguages(Object support, Object target) {
    return '$target · support: $support';
  }

  @override
  String get addLevel => 'Add level';

  @override
  String get level => 'Level';

  @override
  String get addUnit => 'Add unit';

  @override
  String get unit => 'Unit';

  @override
  String get addTopic => 'Add topic';

  @override
  String get topic => 'Topic';

  @override
  String get addTest => 'Add test';

  @override
  String get test => 'Test';

  @override
  String get addQuestion => 'Add question';

  @override
  String get questionTypeWordMultipleChoice => 'Word multiple choice';

  @override
  String get questionTypeMultipleChoiceCloze => 'Multiple-choice gap';

  @override
  String get questionTypeTypedCloze => 'Typed gap';

  @override
  String get questionTypeMatching => 'Matching';

  @override
  String questionTitle(Object type) {
    return 'Question · $type';
  }

  @override
  String get questionPrompt => 'Question text';

  @override
  String get alternativeCorrectAnswer => 'Alternative correct answer';

  @override
  String translationLanguage(Object language) {
    return 'Translation ($language)';
  }

  @override
  String get addMatchingPair => 'Add matching pair';

  @override
  String get moveOptionUp => 'Move option up';

  @override
  String get moveOptionDown => 'Move option down';

  @override
  String get correctOption => 'Correct option';

  @override
  String get option => 'Option';

  @override
  String optionTranslation(Object language) {
    return 'Option translation ($language)';
  }

  @override
  String get matchingTarget => 'Matching target';

  @override
  String matchingText(Object language) {
    return 'Matching text ($language)';
  }

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get delete => 'Delete';

  @override
  String newLevel(Object ordinal) {
    return 'New level $ordinal';
  }

  @override
  String newUnit(Object ordinal) {
    return 'New unit $ordinal';
  }

  @override
  String newTopic(Object ordinal) {
    return 'New topic $ordinal';
  }

  @override
  String newTest(Object ordinal) {
    return 'New test $ordinal';
  }

  @override
  String newTarget(Object ordinal) {
    return 'Target $ordinal';
  }

  @override
  String newMatch(Object language, Object ordinal) {
    return 'Match $ordinal $language';
  }

  @override
  String newWord(Object ordinal) {
    return 'New word $ordinal';
  }

  @override
  String newSentence(Object ordinal) {
    return 'New sentence --- $ordinal';
  }

  @override
  String newAnswer(Object ordinal) {
    return 'answer$ordinal';
  }

  @override
  String newWrongAnswer(Object option, Object ordinal) {
    return 'wrong$ordinal$option';
  }

  @override
  String newTranslation(Object ordinal) {
    return 'Translation $ordinal';
  }

  @override
  String newOption(Object option, Object ordinal) {
    return 'Option $ordinal.$option';
  }

  @override
  String get course => 'Course';

  @override
  String get identifier => 'identifier';

  @override
  String get title => 'title';

  @override
  String get order => 'order';

  @override
  String get passThreshold => 'pass threshold';

  @override
  String get type => 'type';

  @override
  String get text => 'text';

  @override
  String get correctValue => 'correct';

  @override
  String get question => 'Question';

  @override
  String get matching => 'Matching';

  @override
  String get useCourseInvitation => 'Use course invitation';

  @override
  String get courseInvitationTitle => 'Course invitation';

  @override
  String get invitationCode => 'Invitation code';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueAction => 'Continue';

  @override
  String get searchCourses => 'Search courses';

  @override
  String get accessFilter => 'Access filter';

  @override
  String get allCourses => 'All courses';

  @override
  String get acceptInvitationQuestion =>
      'Would you like to accept this private course invitation?';

  @override
  String get acceptInvitation => 'Accept invitation';

  @override
  String invitationAcceptFailed(Object error) {
    return 'The invitation could not be accepted: $error';
  }

  @override
  String get downloadOfflinePractice => 'Download scoreless offline practice';

  @override
  String offlinePackageDownloadFailed(Object error) {
    return 'The offline package could not be downloaded: $error';
  }

  @override
  String get offlinePracticeTitle => 'Scoreless offline practice';

  @override
  String offlinePracticeProgress(Object current, Object total) {
    return '$current/$total · This practice does not award score or energy.';
  }

  @override
  String get yourAnswer => 'Your answer';

  @override
  String offlineCorrectAnswer(Object answer) {
    return 'Correct answer: $answer';
  }

  @override
  String get practiceAgain => 'I need more practice';

  @override
  String get knewMatchingPairs => 'I knew the matches';

  @override
  String get next => 'Next';

  @override
  String get checkAnswer => 'Check answer';

  @override
  String get offlinePracticeComplete => 'Offline practice complete';

  @override
  String offlinePracticeResult(Object correct, Object total) {
    return '$correct/$total correct. This result was stored only on this device and was not sent to your online score.';
  }

  @override
  String get accountProfileTitle => 'Profile';

  @override
  String get accountLearningSummary => 'Learning summary';

  @override
  String accountScoreAndStreak(Object days, Object score) {
    return '$score points · $days-day streak';
  }

  @override
  String accountTestAndCourseSummary(
    Object attempts,
    Object completed,
    Object enrolled,
    Object passed,
  ) {
    return '$passed/$attempts passed tests · $completed/$enrolled active courses';
  }

  @override
  String accountCorrectAnswers(Object correct, Object total) {
    return '$correct/$total correct';
  }

  @override
  String get accountData => 'Account data';

  @override
  String get accountExportJson => 'Export my data as JSON';

  @override
  String get accountRevokeAllSessions => 'Sign out from all devices';

  @override
  String get accountRequestDeletion => 'Request account deletion';

  @override
  String get accountDeletionRecovery =>
      'Deletion requests include a 7-day recovery period to protect against mistakes.';

  @override
  String accountDeletionReadFailed(Object error) {
    return 'Deletion requests could not be loaded: $error';
  }

  @override
  String get accountPendingDeletion => 'Pending deletion request';

  @override
  String accountDeletionCancelableUntil(Object date) {
    return 'Can be cancelled until $date.';
  }

  @override
  String get accountCancelDeletion => 'Cancel';

  @override
  String get accountLeaderboard => 'Leaderboard';

  @override
  String get accountLeaderboardPrivacy =>
      'Only public profiles whose owners explicitly opted in are shown.';

  @override
  String get accountNoParticipants => 'No participants yet.';

  @override
  String accountCompletedTests(Object count, Object username) {
    return '@$username · $count completed tests';
  }

  @override
  String accountPoints(Object score) {
    return '$score points';
  }

  @override
  String get accountExportSaved => 'Data export saved.';

  @override
  String accountExportFailed(Object error) {
    return 'The export could not be saved: $error';
  }

  @override
  String get accountDeletionCancelled =>
      'The account deletion request was cancelled.';

  @override
  String accountDeletionCancelFailed(Object error) {
    return 'The request could not be cancelled: $error';
  }

  @override
  String get accountDeletionDialogTitle => 'Create a deletion request?';

  @override
  String get accountDeletionDialogBody =>
      'The request will be stored securely for processing after 7 days. This does not change score and learning-history retention rules.';

  @override
  String get accountCreateRequest => 'Create request';

  @override
  String accountDeletionScheduled(Object date) {
    return 'The deletion request was scheduled for $date.';
  }

  @override
  String accountDeletionRequestFailed(Object error) {
    return 'The request could not be created: $error';
  }

  @override
  String get accountRevokeDialogTitle => 'Close all sessions?';

  @override
  String get accountRevokeDialogBody =>
      'Refresh sessions on every device, including this one, will be revoked in AWS Cognito.';

  @override
  String get accountRevokeConfirm => 'Sign out everywhere';

  @override
  String accountRevokeFailed(Object error) {
    return 'Sessions could not be closed: $error';
  }

  @override
  String get accountNotifications => 'Notifications';

  @override
  String get accountLearningReminders => 'Learning reminders';

  @override
  String get accountCourseUpdates => 'Course updates';

  @override
  String get accountProductAnnouncements => 'Product announcements';

  @override
  String get accountPushNotification => 'Push notifications';

  @override
  String get accountEmailNotification => 'Email notifications';

  @override
  String get accountAvailable => 'Available';

  @override
  String get accountPushUnavailable =>
      'The Firebase provider is not configured yet';

  @override
  String get accountEmailUnavailable =>
      'A verified production sender is not configured yet';

  @override
  String get accountQuietHours => 'Quiet hours';

  @override
  String get accountDisabled => 'Off';

  @override
  String get accountDisableQuietHours => 'Turn off quiet hours';

  @override
  String get accountSetQuietHours => 'Set quiet hours';

  @override
  String get accountSaveNotifications => 'Save notifications';

  @override
  String get accountNotificationsSaved => 'Notification preferences saved.';

  @override
  String accountNotificationsSaveFailed(Object error) {
    return 'Preferences could not be saved: $error';
  }

  @override
  String get accountQuietHoursStart => 'Quiet hours start';

  @override
  String get accountQuietHoursEnd => 'Quiet hours end';

  @override
  String get accountMyAccount => 'My account';

  @override
  String get accountDisplayName => 'Display name';

  @override
  String get accountUsername => 'Username';

  @override
  String get accountBio => 'Short bio';

  @override
  String get accountPublicProfile => 'Public profile';

  @override
  String get accountPublicProfileDefault => 'It is off by default.';

  @override
  String get accountJoinLeaderboard => 'Join the leaderboard';

  @override
  String accountProfileStats(Object score, Object tests) {
    return '$score total points · $tests tests';
  }

  @override
  String get accountSave => 'Save';

  @override
  String get accountProfileSaved => 'Profile saved.';

  @override
  String get viewAsStudent => 'View as learner';

  @override
  String get studentPreviewTitle => 'Learner preview';

  @override
  String get studentPreviewNotice =>
      'Read-only preview of the active published revision. It does not start an attempt or award score or energy.';

  @override
  String studentPreviewActiveRevision(Object revision) {
    return 'Active revision $revision';
  }

  @override
  String get studentPreviewChooseOption =>
      'Choose one answer. Preview controls are not interactive.';

  @override
  String get studentPreviewTypeAnswer =>
      'Enter your answer. Preview controls are not interactive.';

  @override
  String get studentPreviewMatchItems =>
      'Match the words and meanings. The preview does not reveal the correct pairs.';

  @override
  String get studentPreviewNoQuestions =>
      'This test has no questions to preview.';
}
