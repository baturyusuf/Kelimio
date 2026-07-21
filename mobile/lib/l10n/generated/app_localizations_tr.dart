// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'Kelimio';

  @override
  String get configurationErrorTitle => 'Yapılandırma gerekli';

  @override
  String get configurationErrorBody =>
      'Bu derlemede zorunlu üretim ayarları eksik.';

  @override
  String get signInTitle => 'Doğrulanmış ilerlemeyle öğren';

  @override
  String get signInBody =>
      'Kursları görmek ve öğrenmeye devam etmek için güvenli biçimde giriş yap.';

  @override
  String get signIn => 'Giriş yap';

  @override
  String get signOut => 'Çıkış yap';

  @override
  String get catalog => 'Katalog';

  @override
  String get energy => 'Enerji';

  @override
  String get retry => 'Tekrar dene';

  @override
  String get refresh => 'Yenile';

  @override
  String get loading => 'Yükleniyor';

  @override
  String get genericError => 'Bir sorun oluştu.';

  @override
  String get networkError => 'Bağlantını kontrol edip tekrar dene.';

  @override
  String get emptyCatalog => 'Şu anda kullanılabilir kurs yok.';

  @override
  String get courseDetails => 'Kurs ayrıntıları';

  @override
  String get free => 'Ücretsiz';

  @override
  String get paid => 'Ücretli';

  @override
  String get enrolled => 'Kayıtlı';

  @override
  String get supportLanguage => 'Destek dili';

  @override
  String get enroll => 'Kursa katıl';

  @override
  String get paidEnrollmentUnavailable =>
      'Ücretli kayıt henüz bu uygulamada kullanılamıyor.';

  @override
  String get tests => 'Testler';

  @override
  String questionCount(num count) {
    return '$count soru';
  }

  @override
  String get startTest => 'Teste başla';

  @override
  String questionProgress(Object current, Object total) {
    return 'Soru $current / $total';
  }

  @override
  String get submitAnswer => 'Cevabı gönder';

  @override
  String get continueLabel => 'Devam et';

  @override
  String get correct => 'Doğru';

  @override
  String get incorrect => 'Yanlış';

  @override
  String get finishing => 'Sonucun hazırlanıyor';

  @override
  String get passed => 'Başardın';

  @override
  String get failed => 'Çalışmaya devam';

  @override
  String resultSummary(
    Object correctCount,
    Object percentage,
    Object questionCount,
  ) {
    return '$questionCount soruda $correctCount doğru (%$percentage)';
  }

  @override
  String get backToCourse => 'Kursa dön';

  @override
  String get attemptInterrupted => 'Test kesintiye uğradı';

  @override
  String get energyDepleted =>
      'Enerjin kalmadı. Sunucunun onayladığı ilerlemen güvende.';

  @override
  String get contentChanged =>
      'Sen öğrenirken bu test değişti. Kursa dönüp güncel sürümü başlat.';

  @override
  String get recoverAttempt => 'Testi kurtar';

  @override
  String get recoverableError =>
      'İstek onaylanmadı. Tekrar denendiğinde aynı güvenli gönderim kimliği kullanılır.';

  @override
  String get fatalAttemptError => 'Bu test devam edemiyor.';

  @override
  String get energyUnlimited => 'Sınırsız enerji';

  @override
  String energyBalance(Object balance, Object maximum) {
    return '$maximum üzerinden $balance';
  }

  @override
  String nextRegeneration(Object time) {
    return 'Sonraki enerji: $time';
  }

  @override
  String energyCurrentAsOf(Object time) {
    return 'Güncelleme: $time';
  }

  @override
  String get authenticationCancelled => 'Giriş iptal edildi.';

  @override
  String get accessibilitySelectedAnswer => 'Seçili cevap';

  @override
  String get accessibilityCorrectAnswer => 'Doğru cevap';

  @override
  String get accessibilityIncorrectAnswer => 'Yanlış cevap';
}
