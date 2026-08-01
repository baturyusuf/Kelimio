// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

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
  String get signInBody => 'سجّل الدخول بأمان لتصفح الدورات ومتابعة التعلم.';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signOut => 'تسجيل الخروج';

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
      'للاختبار المحلي، ثبّت دورة البداية من النوع A التي تمت مراجعتها. لا ينشئ هذا مستخدمين أو نتائج تعلم.';

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
  String get progressUpdating => 'يتم تحديث التقدم من أحداث الخادم الموثقة.';

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
      'تغيّر هذا الاختبار أثناء التعلم. ارجع إلى الدورة وابدأ النسخة الحالية.';

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
}
