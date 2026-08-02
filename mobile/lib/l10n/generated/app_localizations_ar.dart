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
}
