// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get findPreviousImports => 'العثور على عمليات الاستيراد السابقة';

  @override
  String get findingPreviousImports =>
      'جارٍ العثور على عمليات الاستيراد السابقة';

  @override
  String get previousImportsHeading => 'عمليات الاستيراد السابقة';

  @override
  String get noPreviousImports =>
      'لم يُعثر على عمليات استيراد سابقة لهذا الحساب.';

  @override
  String get resumeImport => 'متابعة';

  @override
  String get loadMoreImports => 'تحميل المزيد من عمليات الاستيراد';

  @override
  String get importUploadIncomplete => 'لم يكتمل الرفع — اختر الملف مجددًا';

  @override
  String get importProcessing => 'جارٍ الفحص وإعداد المعاينة';

  @override
  String get importReadyForReview => 'جاهز للمراجعة';

  @override
  String get importValidationFailed => 'راجع أخطاء ملف Excel';

  @override
  String get importRejected => 'رُفض الاستيراد بأمان';

  @override
  String get importExpired => 'انتهت صلاحية جلسة الرفع';

  @override
  String get importApproved => 'تمت الموافقة — إنشاء المسودة معلّق';

  @override
  String get importReadyToPublish => 'المسودة جاهزة — النشر معلّق';

  @override
  String get importAlreadyPublished => 'منشور';

  @override
  String get workbookUploadIncomplete =>
      'لم يعد الملف المحدد موجودًا في التطبيق بعد إعادة التشغيل. اختر ملف Excel مجددًا لبدء رفع جديد وآمن.';

  @override
  String get appName => 'Kelimio';

  @override
  String get configurationErrorTitle => 'الإعداد مطلوب';

  @override
  String get configurationErrorBody =>
      'يفتقد هذا الإصدار إعدادات الإنتاج المطلوبة.';

  @override
  String get costConservationMessage =>
      'تم إيقاف إنشاء الدورات واستيرادها مؤقتًا لحماية حد الإنفاق. يمكنك متابعة التعلّم.';

  @override
  String get costReadOnlyMessage =>
      'الخدمة في وضع العرض فقط مؤقتًا. لم يتم حفظ الإجراء.';

  @override
  String get costSuspendedMessage =>
      'تم تعليق الخدمة مؤقتًا لحماية حد الإنفاق. يُرجى المحاولة لاحقًا.';

  @override
  String get signInTitle => 'تعلّم بتقدّم موثوق';

  @override
  String get signInBody => 'سجّل الدخول بأمان لتصفح الدورات ومتابعة التعلّم.';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get profileSetupTitle => 'إعداد ملف التعلّم';

  @override
  String get profileSetupBody =>
      'اختر لغة التطبيق واللغة التي تريد تعلّمها ولغة الشرح.';

  @override
  String get profileSetupLegalNotice =>
      'تحفظ هذه الخطوة تفضيلات التعلّم فقط، ولا تعني قبول الشروط القانونية أو الموافقة التسويقية.';

  @override
  String get displayName => 'الاسم الظاهر';

  @override
  String get appLanguage => 'لغة التطبيق';

  @override
  String get targetLanguage => 'اللغة المراد تعلّمها';

  @override
  String get preferredSupportLanguage => 'لغة الشرح المفضلة';

  @override
  String get timeZone => 'المنطقة الزمنية';

  @override
  String get timeZoneIstanbul => 'تركيا (Europe/Istanbul)';

  @override
  String get timeZoneUtc => 'UTC';

  @override
  String get completeProfileSetup => 'حفظ ومتابعة';

  @override
  String get requiredField => 'هذا الحقل مطلوب.';

  @override
  String get languageTurkish => 'التركية';

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageFrench => 'الفرنسية';

  @override
  String get catalog => 'الدورات';

  @override
  String get energy => 'الطاقة';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get refresh => 'تحديث';

  @override
  String get loading => 'جارٍ التحميل';

  @override
  String get genericError => 'حدث خطأ ما.';

  @override
  String get networkError => 'تحقق من الاتصال وحاول مرة أخرى.';

  @override
  String get emptyCatalog => 'لا توجد دورات متاحة الآن.';

  @override
  String get localStarterCourseBody =>
      'للاختبار المحلي، ثبّت دورة البداية المختلطة من النوعين A وB التي تمت مراجعتها. لا ينشئ هذا مستخدمين أو نتائج تعلّم.';

  @override
  String get installLocalStarterCourse => 'تثبيت دورة البداية المحلية';

  @override
  String get yourProgress => 'تقدمك';

  @override
  String progressAnswers(Object answered, Object correct) {
    return '$correct إجابات صحيحة من أصل $answered';
  }

  @override
  String progressAttempts(Object completed, Object passed) {
    return 'نجحت في $passed من أصل $completed محاولات مكتملة';
  }

  @override
  String progressScores(Object active, Object lifetime) {
    return 'النقاط النشطة: $active · نقاط مدى الحياة: $lifetime';
  }

  @override
  String get progressUpdating => 'يتم تحديث التقدم من أحداث الخادم الموثوقة.';

  @override
  String get courseDetails => 'تفاصيل الدورة';

  @override
  String get free => 'مجانية';

  @override
  String get paid => 'مدفوعة';

  @override
  String get enrolled => 'مسجّل';

  @override
  String get supportLanguage => 'لغة الدعم';

  @override
  String get enroll => 'الانضمام';

  @override
  String get paidEnrollmentUnavailable =>
      'التسجيل المدفوع غير متاح في التطبيق بعد.';

  @override
  String get tests => 'الاختبارات';

  @override
  String questionCount(num count) {
    return '$count سؤال';
  }

  @override
  String get startTest => 'بدء الاختبار';

  @override
  String questionProgress(Object current, Object total) {
    return 'السؤال $current من $total';
  }

  @override
  String get submitAnswer => 'إرسال الإجابة';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get correct => 'صحيح';

  @override
  String get incorrect => 'غير صحيح';

  @override
  String get finishing => 'جارٍ إعداد النتيجة';

  @override
  String get passed => 'لقد نجحت';

  @override
  String get failed => 'واصل التدريب';

  @override
  String resultSummary(
    Object correctCount,
    Object percentage,
    Object questionCount,
  ) {
    return '$correctCount من $questionCount صحيح ($percentage٪)';
  }

  @override
  String get backToCourse => 'العودة إلى الدورة';

  @override
  String get attemptInterrupted => 'توقف الاختبار';

  @override
  String get energyDepleted => 'نفدت طاقتك. تقدمك المؤكد من الخادم محفوظ.';

  @override
  String get contentChanged =>
      'تغيّر هذا الاختبار أثناء التعلّم. ارجع إلى الدورة وابدأ النسخة الحالية.';

  @override
  String get recoverAttempt => 'استعادة الاختبار';

  @override
  String get recoverableError =>
      'لم يتم تأكيد الطلب. ستستخدم إعادة المحاولة معرّف الإرسال الآمن نفسه.';

  @override
  String get fatalAttemptError => 'لا يمكن متابعة هذا الاختبار.';

  @override
  String get energyUnlimited => 'طاقة غير محدودة';

  @override
  String energyBalance(Object balance, Object maximum) {
    return '$balance من $maximum';
  }

  @override
  String nextRegeneration(Object time) {
    return 'الطاقة التالية: $time';
  }

  @override
  String energyCurrentAsOf(Object time) {
    return 'آخر تحديث $time';
  }

  @override
  String get authenticationCancelled => 'تم إلغاء تسجيل الدخول.';

  @override
  String get accessibilitySelectedAnswer => 'الإجابة المحددة';

  @override
  String get accessibilityCorrectAnswer => 'الإجابة الصحيحة';

  @override
  String get accessibilityIncorrectAnswer => 'الإجابة غير الصحيحة';

  @override
  String get accessibilityBlank => 'فراغ';

  @override
  String get typedAnswerLabel => 'إجابتك';

  @override
  String get typedAnswerReentry =>
      'لم تُحفظ الإجابة السابقة على هذا الجهاز. أدخلها مجددًا لمتابعة الإرسال نفسه.';

  @override
  String get correctAnswerLabel => 'الإجابة الصحيحة';

  @override
  String get matchingInstructions =>
      'طابق كل كلمة في خطوتين: اختر أولًا كلمة لغة التعلّم، ثم اختر معناها.';

  @override
  String get matchingTargetsHeading => 'الكلمات المطلوب مطابقتها';

  @override
  String get matchingSupportsHeading => 'المعاني';

  @override
  String get matchingPairsHeading => 'مطابقاتك';

  @override
  String matchingProgress(Object matched, Object total) {
    return 'تمت مطابقة $matched من $total';
  }

  @override
  String matchingTargetItemLabel(Object item) {
    return 'الكلمة: $item';
  }

  @override
  String matchingSupportItemLabel(Object item) {
    return 'المعنى: $item';
  }

  @override
  String get matchingTargetSelected => 'الكلمة محددة';

  @override
  String get matchingAlreadyPaired => 'تمت مطابقتها';

  @override
  String get matchingChooseTargetFirst => 'اختر كلمة أولًا';

  @override
  String matchingPairLabel(Object support, Object target) {
    return '$target تطابق $support';
  }

  @override
  String get matchingTentativePair => 'مطابقة مؤقتة';

  @override
  String get matchingCorrectPair => 'مطابقة صحيحة';

  @override
  String get matchingIncorrectPair => 'مطابقة غير صحيحة';

  @override
  String matchingRemovePair(Object target) {
    return 'إزالة مطابقة $target';
  }

  @override
  String get matchingCorrectMappingHeading => 'المطابقة الصحيحة';

  @override
  String get matchingFeedbackUnavailable =>
      'لم تُحفظ مطابقاتك السابقة على هذا الجهاز. تظهر أدناه المطابقة الصحيحة الكاملة التي أرسلها الخادم.';

  @override
  String get teacher => 'المعلّم';

  @override
  String get teacherAccessTitle => 'صلاحية إنشاء الدورات';

  @override
  String get teacherFeatureUnavailable =>
      'إنشاء الدورات الآمن غير مفعّل لهذا الإصدار حالياً.';

  @override
  String get teacherAccountNotEligible =>
      'هذا الحساب غير مخوّل بإنشاء الدورات. تُدار الصلاحية من الخادم.';

  @override
  String get teacherTermsBody =>
      'يجب أن يحتوي ملف Excel على محتوى تملكه أو يحق لك استخدامه فقط. يُفحص الملف أمنياً وتُعرض معاينته قبل نشر الدورة.';

  @override
  String get teacherTermsAcceptance =>
      'قرأت هذه الشروط وأؤكد أنني أملك حقوق المحتوى الذي أرفعه.';

  @override
  String get teacherImportTitle => 'إنشاء دورة من Excel';

  @override
  String get teacherImportBody =>
      'يرفع مسار الاختبار المحلي هذا ملف ‎.xlsx واحدًا لفحص البرمجيات الضارة ومراجعته. تبقى الموافقة وإنشاء المسودة والنشر خطوات منفصلة.';

  @override
  String get selectWorkbook => 'اختيار ملف Excel';

  @override
  String get preparingWorkbook => 'جارٍ فحص المصنف';

  @override
  String get uploadingWorkbook => 'جارٍ رفع المصنف';

  @override
  String get processingWorkbook => 'جارٍ الفحص وإعداد المعاينة';

  @override
  String get previewHeading => 'مراجعة الاستيراد';

  @override
  String previewSummary(Object matching, Object questions, Object rows) {
    return '$rows صفوف مصدر · $questions أسئلة · $matching أسئلة مطابقة';
  }

  @override
  String previewRowLabel(Object row, Object test, Object type) {
    return 'صف المصدر $row، الاختبار $test، نوع السؤال $type';
  }

  @override
  String get loadMore => 'تحميل المزيد';

  @override
  String get issuesHeading => 'التحذيرات والأخطاء';

  @override
  String get previewApprovalConfirmation =>
      'راجعت المعاينة وأفهم أن الموافقة لا تنشر الدورة.';

  @override
  String get approvePreview => 'الموافقة على هذه المعاينة';

  @override
  String get draftCreationNotice =>
      'يمكن الآن حفظ المحتوى الموافق عليه كمسودة غير منشورة. لن يصبح مرئيًا للمتعلمين.';

  @override
  String get draftCreationConfirmation =>
      'إنشاء مسودة واحدة ثابتة وغير منشورة من هذه المعاينة الموافق عليها.';

  @override
  String get createDraft => 'إنشاء مسودة الدورة';

  @override
  String get releaseImpactHeading => 'أثر النشر';

  @override
  String releaseImpactSummary(
    Object added,
    Object changed,
    Object learners,
    Object questions,
    Object removed,
  ) {
    return '$questions أسئلة · $added مضافة · $changed معدّلة · $removed محذوفة · $learners متعلمين متأثرين';
  }

  @override
  String get releaseImpactConfirmation =>
      'راجعت هذا الأثر الدقيق وأريد تفعيل الإصدار الثابت.';

  @override
  String get publishCourse => 'نشر الدورة';

  @override
  String get coursePublished =>
      'تم تفعيل إصدار الدورة، وجدولت إعادة حساب التقدم.';

  @override
  String get newImport => 'بدء استيراد جديد';

  @override
  String get workbookRejected => 'رُفض المصنف بأمان. راجع المشكلات أدناه.';

  @override
  String get workbookExpired =>
      'انتهت صلاحية جلسة الرفع. ابدأ استيرادًا جديدًا.';

  @override
  String fileDetails(Object name, Object size) {
    return '$name · $size بايت';
  }

  @override
  String questionType(Object type) {
    return 'النوع $type';
  }

  @override
  String correctAnswerTeacher(Object answer) {
    return 'الإجابة المراجعة: $answer';
  }

  @override
  String alternativeCorrectAnswerTeacher(Object answer) {
    return 'الإجابة البديلة المراجعة: $answer';
  }

  @override
  String wrongAnswersTeacher(Object answers) {
    return 'الخيارات المضللة المراجعة: $answers';
  }

  @override
  String matchingGroupTeacher(Object group) {
    return 'مجموعة المطابقة: $group';
  }

  @override
  String get editPublishedCourse => 'تحرير الدورة المنشورة';

  @override
  String get courseEditorTitle => 'تحرير سؤال واحد في الدورة';

  @override
  String get courseEditorScope =>
      'يغيّر محرر الاختبار المحلي هذا نص أول سؤال مؤهل ذي فراغ كتابي. تبقى الإجابة على الخادم.';

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
  String get courseEditorPromptLabel => 'نص السؤال';

  @override
  String get courseEditorPromptHelp =>
      'احتفظ بعلامة فراغ واحدة --- فقط. الحد الأقصى 1,000 حرف.';

  @override
  String get courseEditorRecovered =>
      'استُعيد تغييرك غير المحفوظ من التخزين الآمن لهذا الجهاز.';

  @override
  String get courseEditorRecoveryFailed =>
      'تعذر حماية هذا التغيير في التخزين الآمن. انسخ النص قبل مغادرة الشاشة.';

  @override
  String get courseEditorPromptEmpty => 'أدخل نص السؤال.';

  @override
  String get courseEditorPromptTooLong => 'يجب ألا يتجاوز نص السؤال 1,000 حرف.';

  @override
  String get courseEditorPromptPlaceholder =>
      'يجب أن يحتوي نص السؤال على علامة فراغ واحدة --- فقط.';

  @override
  String get courseEditorPromptUnchanged => 'غيّر نص السؤال قبل إنشاء المسودة.';

  @override
  String get discardEditorChanges => 'تجاهل التغييرات';

  @override
  String get saveEditorDraft => 'إنشاء مسودة ثابتة';

  @override
  String get courseEditorConflictHeading => 'تغيّر السؤال المنشور';

  @override
  String get courseEditorConflictBody =>
      'قارن بين الإصدارات. لن يُستبدل شيء حتى تختار كيفية المتابعة.';

  @override
  String get courseEditorPreviousVersion => 'الإصدار الذي بدأت منه';

  @override
  String get courseEditorYourVersion => 'إصدارك غير المحفوظ';

  @override
  String get courseEditorLatestVersion => 'أحدث إصدار منشور';

  @override
  String get courseEditorUseLatest => 'استخدام أحدث إصدار';

  @override
  String get courseEditorReapplyMine => 'إعادة تطبيق إصداري';

  @override
  String get courseEditorImpactConfirmation =>
      'راجعت أثر هذا السؤال الواحد وأريد نشر الإصدار الثابت.';

  @override
  String get publishEditorRevision => 'نشر هذا الإصدار';

  @override
  String get courseEditorPublished =>
      'الإصدار المعدّل نشط. لم تُرسل الإجابة الصحيحة إلى هذا الجهاز.';

  @override
  String get courseEditorOtherRecovery =>
      'هناك مسودة آمنة غير محفوظة لدورة أخرى. تجاهلها قبل تحرير هذه الدورة.';

  @override
  String get courseEditorDiscardOther => 'تجاهل المسودة الأخرى';

  @override
  String get courseEditorLeaveTitle => 'هل تريد تجاهل التغيير غير المحفوظ؟';

  @override
  String get courseEditorLeaveBody =>
      'تغييرك محفوظ بأمان على هذا الجهاز. يمكنك الاحتفاظ به لوقت لاحق أو تجاهله الآن.';

  @override
  String get keepEditing => 'الاحتفاظ به لوقت لاحق';

  @override
  String get myCourses => 'دوراتي';

  @override
  String get newCourseFromExcel => 'دورة جديدة من Excel';

  @override
  String get noTeacherCourses =>
      'ليست لديك دورة بعد. يمكنك إنشاء دورتك الأولى من ملف Excel.';

  @override
  String courseRevision(Object language, Object revision) {
    return '$language · الإصدار $revision';
  }

  @override
  String get unpublishedDraftAvailable => 'توجد مسودة غير منشورة';

  @override
  String get createInvitation => 'إنشاء دعوة';

  @override
  String get courseInvitationReady => 'دعوة الدورة جاهزة';

  @override
  String get courseInvitationShare =>
      'شارك هذا الرمز المخصص للاستخدام مرة واحدة بأمان مع المتعلم:';

  @override
  String get copy => 'نسخ';

  @override
  String invitationCreateFailed(Object error) {
    return 'تعذر إنشاء الدعوة: $error';
  }

  @override
  String draftReleaseTitle(Object revision) {
    return 'الإصدار المسودة $revision';
  }

  @override
  String get close => 'إغلاق';

  @override
  String get abandonDraft => 'التخلي عن المسودة';

  @override
  String get draftAbandoned => 'تم التخلي عن المسودة بأمان.';

  @override
  String get courseRevisionPublished => 'تم نشر الإصدار الجديد للدورة.';

  @override
  String draftPublishFailed(Object error) {
    return 'تعذر نشر المسودة: $error';
  }

  @override
  String get fullCourseEditorTitle => 'محرر الدورة';

  @override
  String publishRevisionTitle(Object revision) {
    return 'هل تريد نشر الإصدار $revision؟';
  }

  @override
  String get later => 'لاحقًا';

  @override
  String revisionPublished(Object revision) {
    return 'تم نشر الإصدار $revision.';
  }

  @override
  String get fullEditorConflictHeading => 'تغيرت الدورة في مكان آخر';

  @override
  String get fullEditorConflictBody =>
      'لم يُحفظ أي تغيير. قارن الإصدارات الثلاثة أدناه، ثم استخدم أحدث إصدار على الخادم أو أعد تطبيق تعديلاتك عليه بشكل صريح.';

  @override
  String get fullEditorBaseVersion => 'الإصدار الذي بدأت تحريره';

  @override
  String get fullEditorMineVersion => 'تعديلاتك';

  @override
  String get fullEditorLatestVersion => 'أحدث إصدار على الخادم';

  @override
  String get fullEditorUseLatest => 'استخدام أحدث إصدار على الخادم';

  @override
  String get fullEditorReapplyMine => 'إعادة تطبيق تعديلاتي على أحدث إصدار';

  @override
  String fullEditorVersionSummary(
    Object levels,
    Object name,
    Object questions,
    Object revision,
  ) {
    return '$name · $levels مستويات · $questions أسئلة · الإصدار $revision';
  }

  @override
  String editorChanges(Object count) {
    return '$count تغييرات:';
  }

  @override
  String editorMoreChanges(Object count) {
    return '$count تغييرات أخرى';
  }

  @override
  String get courseName => 'اسم الدورة';

  @override
  String get description => 'الوصف';

  @override
  String get visibility => 'مستوى الظهور';

  @override
  String get publicVisibility => 'عامة';

  @override
  String get privateVisibility => 'خاصة';

  @override
  String targetAndSupportLanguages(Object support, Object target) {
    return '$target · الدعم: $support';
  }

  @override
  String get addLevel => 'إضافة مستوى';

  @override
  String get level => 'المستوى';

  @override
  String get addUnit => 'إضافة وحدة';

  @override
  String get unit => 'الوحدة';

  @override
  String get addTopic => 'إضافة موضوع';

  @override
  String get topic => 'الموضوع';

  @override
  String get addTest => 'إضافة اختبار';

  @override
  String get test => 'الاختبار';

  @override
  String get addQuestion => 'إضافة سؤال';

  @override
  String get questionTypeWordMultipleChoice => 'اختيار متعدد للكلمة';

  @override
  String get questionTypeMultipleChoiceCloze => 'فراغ متعدد الخيارات';

  @override
  String get questionTypeTypedCloze => 'فراغ كتابي';

  @override
  String get questionTypeMatching => 'مطابقة';

  @override
  String questionTitle(Object type) {
    return 'سؤال · $type';
  }

  @override
  String get questionPrompt => 'نص السؤال';

  @override
  String get alternativeCorrectAnswer => 'إجابة صحيحة بديلة';

  @override
  String translationLanguage(Object language) {
    return 'الترجمة ($language)';
  }

  @override
  String get addMatchingPair => 'إضافة زوج مطابقة';

  @override
  String get moveOptionUp => 'نقل الخيار لأعلى';

  @override
  String get moveOptionDown => 'نقل الخيار لأسفل';

  @override
  String get correctOption => 'الخيار الصحيح';

  @override
  String get option => 'الخيار';

  @override
  String optionTranslation(Object language) {
    return 'ترجمة الخيار ($language)';
  }

  @override
  String get matchingTarget => 'هدف المطابقة';

  @override
  String matchingText(Object language) {
    return 'نص المطابقة ($language)';
  }

  @override
  String get moveUp => 'نقل لأعلى';

  @override
  String get moveDown => 'نقل لأسفل';

  @override
  String get delete => 'حذف';

  @override
  String newLevel(Object ordinal) {
    return 'مستوى جديد $ordinal';
  }

  @override
  String newUnit(Object ordinal) {
    return 'وحدة جديدة $ordinal';
  }

  @override
  String newTopic(Object ordinal) {
    return 'موضوع جديد $ordinal';
  }

  @override
  String newTest(Object ordinal) {
    return 'اختبار جديد $ordinal';
  }

  @override
  String newTarget(Object ordinal) {
    return 'هدف $ordinal';
  }

  @override
  String newMatch(Object language, Object ordinal) {
    return 'مطابقة $ordinal $language';
  }

  @override
  String newWord(Object ordinal) {
    return 'كلمة جديدة $ordinal';
  }

  @override
  String newSentence(Object ordinal) {
    return 'جملة جديدة --- $ordinal';
  }

  @override
  String newAnswer(Object ordinal) {
    return 'إجابة$ordinal';
  }

  @override
  String newWrongAnswer(Object option, Object ordinal) {
    return 'خاطئ$ordinal$option';
  }

  @override
  String newTranslation(Object ordinal) {
    return 'ترجمة $ordinal';
  }

  @override
  String newOption(Object option, Object ordinal) {
    return 'خيار $ordinal.$option';
  }

  @override
  String get course => 'الدورة';

  @override
  String get identifier => 'المعرّف';

  @override
  String get title => 'العنوان';

  @override
  String get order => 'الترتيب';

  @override
  String get passThreshold => 'حد النجاح';

  @override
  String get type => 'النوع';

  @override
  String get text => 'النص';

  @override
  String get correctValue => 'صحيح';

  @override
  String get question => 'السؤال';

  @override
  String get matching => 'المطابقة';

  @override
  String get useCourseInvitation => 'استخدام دعوة دورة';

  @override
  String get courseInvitationTitle => 'دعوة دورة';

  @override
  String get invitationCode => 'رمز الدعوة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get continueAction => 'متابعة';

  @override
  String get searchCourses => 'البحث في الدورات';

  @override
  String get accessFilter => 'تصفية الوصول';

  @override
  String get allCourses => 'كل الدورات';

  @override
  String get acceptInvitationQuestion => 'هل تريد قبول دعوة هذه الدورة الخاصة؟';

  @override
  String get acceptInvitation => 'قبول الدعوة';

  @override
  String invitationAcceptFailed(Object error) {
    return 'تعذّر قبول الدعوة: $error';
  }

  @override
  String get downloadOfflinePractice => 'تنزيل تدريب دون اتصال ومن دون نقاط';

  @override
  String offlinePackageDownloadFailed(Object error) {
    return 'تعذّر تنزيل حزمة العمل دون اتصال: $error';
  }

  @override
  String get offlinePracticeTitle => 'تدريب دون اتصال ومن دون نقاط';

  @override
  String offlinePracticeProgress(Object current, Object total) {
    return '$current/$total · هذا التدريب لا يمنح نقاطًا أو طاقة.';
  }

  @override
  String get yourAnswer => 'إجابتك';

  @override
  String offlineCorrectAnswer(Object answer) {
    return 'الإجابة الصحيحة: $answer';
  }

  @override
  String get practiceAgain => 'أحتاج إلى مزيد من التدريب';

  @override
  String get knewMatchingPairs => 'كنت أعرف المطابقات';

  @override
  String get next => 'التالي';

  @override
  String get checkAnswer => 'تحقق من الإجابة';

  @override
  String get offlinePracticeComplete => 'اكتمل التدريب دون اتصال';

  @override
  String offlinePracticeResult(Object correct, Object total) {
    return '$correct/$total صحيحة. حُفظت هذه النتيجة على هذا الجهاز فقط ولم تُرسل إلى نتيجتك عبر الإنترنت.';
  }

  @override
  String get accountProfileTitle => 'الملف الشخصي';

  @override
  String get accountLearningSummary => 'ملخص التعلم';

  @override
  String accountScoreAndStreak(Object days, Object score) {
    return '$score نقطة · سلسلة $days أيام';
  }

  @override
  String accountTestAndCourseSummary(
    Object attempts,
    Object completed,
    Object enrolled,
    Object passed,
  ) {
    return '$passed/$attempts اختبارات ناجحة · $completed/$enrolled دورات نشطة';
  }

  @override
  String accountCorrectAnswers(Object correct, Object total) {
    return '$correct/$total صحيحة';
  }

  @override
  String get accountData => 'بيانات الحساب';

  @override
  String get accountExportJson => 'تصدير بياناتي بصيغة JSON';

  @override
  String get accountRevokeAllSessions => 'تسجيل الخروج من جميع الأجهزة';

  @override
  String get accountRequestDeletion => 'طلب حذف حسابي';

  @override
  String get accountDeletionRecovery =>
      'يتضمن طلب الحذف فترة استرداد مدتها 7 أيام للحماية من الحذف بالخطأ.';

  @override
  String accountDeletionReadFailed(Object error) {
    return 'تعذّر تحميل طلبات الحذف: $error';
  }

  @override
  String get accountPendingDeletion => 'طلب حذف معلّق';

  @override
  String accountDeletionCancelableUntil(Object date) {
    return 'يمكن إلغاؤه حتى $date.';
  }

  @override
  String get accountCancelDeletion => 'إلغاء';

  @override
  String get accountLeaderboard => 'لوحة المتصدرين';

  @override
  String get accountLeaderboardPrivacy =>
      'لا تظهر إلا الملفات العامة التي اختار أصحابها المشاركة صراحةً.';

  @override
  String get accountNoParticipants => 'لا يوجد مشاركون بعد.';

  @override
  String accountCompletedTests(Object count, Object username) {
    return '@$username · $count اختبارات مكتملة';
  }

  @override
  String accountPoints(Object score) {
    return '$score نقطة';
  }

  @override
  String get accountExportSaved => 'تم حفظ تصدير البيانات.';

  @override
  String accountExportFailed(Object error) {
    return 'تعذّر حفظ التصدير: $error';
  }

  @override
  String get accountDeletionCancelled => 'تم إلغاء طلب حذف الحساب.';

  @override
  String accountDeletionCancelFailed(Object error) {
    return 'تعذّر إلغاء الطلب: $error';
  }

  @override
  String get accountDeletionDialogTitle => 'إنشاء طلب حذف؟';

  @override
  String get accountDeletionDialogBody =>
      'سيُحفظ الطلب بأمان لمعالجته بعد 7 أيام. لا يغيّر ذلك قواعد الاحتفاظ بالنقاط وسجل التعلم.';

  @override
  String get accountCreateRequest => 'إنشاء الطلب';

  @override
  String accountDeletionScheduled(Object date) {
    return 'تمت جدولة طلب الحذف في $date.';
  }

  @override
  String accountDeletionRequestFailed(Object error) {
    return 'تعذّر إنشاء الطلب: $error';
  }

  @override
  String get accountRevokeDialogTitle => 'إغلاق كل الجلسات؟';

  @override
  String get accountRevokeDialogBody =>
      'سيتم إلغاء جلسات التحديث في AWS Cognito على جميع الأجهزة، بما فيها هذا الجهاز.';

  @override
  String get accountRevokeConfirm => 'تسجيل الخروج من الجميع';

  @override
  String accountRevokeFailed(Object error) {
    return 'تعذّر إغلاق الجلسات: $error';
  }

  @override
  String get accountNotifications => 'الإشعارات';

  @override
  String get accountLearningReminders => 'تذكيرات التعلم';

  @override
  String get accountCourseUpdates => 'تحديثات الدورات';

  @override
  String get accountProductAnnouncements => 'إعلانات المنتج';

  @override
  String get accountPushNotification => 'الإشعارات الفورية';

  @override
  String get accountEmailNotification => 'إشعارات البريد الإلكتروني';

  @override
  String get accountAvailable => 'متاح';

  @override
  String get accountPushUnavailable => 'لم تتم تهيئة موفّر Firebase بعد';

  @override
  String get accountEmailUnavailable => 'لم تتم تهيئة مرسل إنتاج موثّق بعد';

  @override
  String get accountQuietHours => 'ساعات الهدوء';

  @override
  String get accountDisabled => 'متوقفة';

  @override
  String get accountDisableQuietHours => 'إيقاف ساعات الهدوء';

  @override
  String get accountSetQuietHours => 'ضبط ساعات الهدوء';

  @override
  String get accountSaveNotifications => 'حفظ الإشعارات';

  @override
  String get accountNotificationsSaved => 'تم حفظ تفضيلات الإشعارات.';

  @override
  String accountNotificationsSaveFailed(Object error) {
    return 'تعذّر حفظ التفضيلات: $error';
  }

  @override
  String get accountQuietHoursStart => 'بداية ساعات الهدوء';

  @override
  String get accountQuietHoursEnd => 'نهاية ساعات الهدوء';

  @override
  String get accountMyAccount => 'حسابي';

  @override
  String get accountDisplayName => 'الاسم المعروض';

  @override
  String get accountUsername => 'اسم المستخدم';

  @override
  String get accountBio => 'نبذة قصيرة';

  @override
  String get accountPublicProfile => 'ملف شخصي عام';

  @override
  String get accountPublicProfileDefault => 'يكون متوقفًا افتراضيًا.';

  @override
  String get accountJoinLeaderboard => 'الانضمام إلى لوحة المتصدرين';

  @override
  String accountProfileStats(Object score, Object tests) {
    return '$score مجموع النقاط · $tests اختبارات';
  }

  @override
  String get accountSave => 'حفظ';

  @override
  String get accountProfileSaved => 'تم حفظ الملف الشخصي.';

  @override
  String get viewAsStudent => 'العرض كمتعلم';

  @override
  String get studentPreviewTitle => 'معاينة المتعلم';

  @override
  String get studentPreviewNotice =>
      'معاينة للقراءة فقط للمراجعة المنشورة النشطة. لا تبدأ محاولة ولا تمنح نقاطًا أو طاقة.';

  @override
  String studentPreviewActiveRevision(Object revision) {
    return 'المراجعة النشطة $revision';
  }

  @override
  String get studentPreviewChooseOption =>
      'اختر إجابة واحدة. عناصر المعاينة غير تفاعلية.';

  @override
  String get studentPreviewTypeAnswer =>
      'أدخل إجابتك. عناصر المعاينة غير تفاعلية.';

  @override
  String get studentPreviewMatchItems =>
      'طابق الكلمات والمعاني. لا تكشف المعاينة الأزواج الصحيحة.';

  @override
  String get studentPreviewNoQuestions =>
      'لا توجد أسئلة لمعاينتها في هذا الاختبار.';
}
