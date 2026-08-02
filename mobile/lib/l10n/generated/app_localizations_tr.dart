// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get findPreviousImports => 'Önceki aktarımları bul';

  @override
  String get findingPreviousImports => 'Önceki aktarımlarınız bulunuyor';

  @override
  String get previousImportsHeading => 'Önceki aktarımlar';

  @override
  String get noPreviousImports =>
      'Bu hesap için önceki bir aktarım bulunamadı.';

  @override
  String get resumeImport => 'Devam et';

  @override
  String get loadMoreImports => 'Daha fazla aktarım yükle';

  @override
  String get importUploadIncomplete =>
      'Yükleme tamamlanmadı — dosyayı yeniden seçin';

  @override
  String get importProcessing => 'Taranıyor ve önizleme hazırlanıyor';

  @override
  String get importReadyForReview => 'İncelemeye hazır';

  @override
  String get importValidationFailed => 'Excel hatalarını inceleyin';

  @override
  String get importRejected => 'Aktarım güvenli biçimde reddedildi';

  @override
  String get importExpired => 'Yükleme süresi doldu';

  @override
  String get importApproved => 'Onaylandı — taslak oluşturulmayı bekliyor';

  @override
  String get importReadyToPublish => 'Taslak hazır — yayımlanmayı bekliyor';

  @override
  String get importAlreadyPublished => 'Yayımlandı';

  @override
  String get workbookUploadIncomplete =>
      'Yeniden başlatmanın ardından seçilen dosya artık uygulamada değil. Güvenli yeni bir yükleme başlatmak için Excel dosyasını yeniden seçin.';

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
  String get profileSetupTitle => 'Öğrenme profilini ayarla';

  @override
  String get profileSetupBody =>
      'Uygulamanın dilini, öğrenmek istediğin dili ve açıklamalarda kullanılacak dili seç.';

  @override
  String get profileSetupLegalNotice =>
      'Bu adım yalnızca öğrenme tercihlerini kaydeder. Hukuki koşulları kabul veya pazarlama izni anlamına gelmez.';

  @override
  String get displayName => 'Görünen ad';

  @override
  String get appLanguage => 'Uygulama dili';

  @override
  String get targetLanguage => 'Öğrenilecek dil';

  @override
  String get preferredSupportLanguage => 'Tercih edilen açıklama dili';

  @override
  String get timeZone => 'Saat dilimi';

  @override
  String get timeZoneIstanbul => 'Türkiye (Europe/Istanbul)';

  @override
  String get timeZoneUtc => 'UTC';

  @override
  String get completeProfileSetup => 'Kaydet ve devam et';

  @override
  String get requiredField => 'Bu alan zorunludur.';

  @override
  String get languageTurkish => 'Türkçe';

  @override
  String get languageEnglish => 'İngilizce';

  @override
  String get languageArabic => 'Arapça';

  @override
  String get languageFrench => 'Fransızca';

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
  String get localStarterCourseBody =>
      'Yerel test için incelenmiş karma Type-A ve Type-B başlangıç kursunu kur. Bu işlem kullanıcı veya öğrenme sonucu oluşturmaz.';

  @override
  String get installLocalStarterCourse => 'Yerel başlangıç kursunu kur';

  @override
  String get yourProgress => 'İlerlemen';

  @override
  String progressAnswers(Object answered, Object correct) {
    return '$answered cevabın $correct tanesi doğru';
  }

  @override
  String progressAttempts(Object completed, Object passed) {
    return 'Tamamlanan $completed denemenin $passed tanesi başarılı';
  }

  @override
  String progressScores(Object active, Object lifetime) {
    return 'Aktif skor: $active · Yaşam boyu skor: $lifetime';
  }

  @override
  String get progressUpdating =>
      'İlerleme, doğrulanmış sunucu olaylarından güncelleniyor.';

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

  @override
  String get accessibilityBlank => 'boşluk';

  @override
  String get typedAnswerLabel => 'Cevabın';

  @override
  String get typedAnswerReentry =>
      'Önceki cevap cihazda saklanmadı. Aynı gönderimi sürdürmek için cevabı yeniden yaz.';

  @override
  String get correctAnswerLabel => 'Doğru cevap';

  @override
  String get matchingInstructions =>
      'Her kelimeyi iki adımda eşleştir: önce öğrenilen dildeki kelimeyi, sonra anlamını seç.';

  @override
  String get matchingTargetsHeading => 'Eşleştirilecek kelimeler';

  @override
  String get matchingSupportsHeading => 'Anlamlar';

  @override
  String get matchingPairsHeading => 'Eşleştirmelerin';

  @override
  String matchingProgress(Object matched, Object total) {
    return '$matched / $total eşleştirme tamamlandı';
  }

  @override
  String matchingTargetItemLabel(Object item) {
    return 'Kelime: $item';
  }

  @override
  String matchingSupportItemLabel(Object item) {
    return 'Anlam: $item';
  }

  @override
  String get matchingTargetSelected => 'Seçili kelime';

  @override
  String get matchingAlreadyPaired => 'Daha önce eşleştirildi';

  @override
  String get matchingChooseTargetFirst => 'Önce bir kelime seç';

  @override
  String matchingPairLabel(Object support, Object target) {
    return '$target, $support ile eşleşiyor';
  }

  @override
  String get matchingTentativePair => 'Geçici eşleştirme';

  @override
  String get matchingCorrectPair => 'Doğru eşleştirme';

  @override
  String get matchingIncorrectPair => 'Yanlış eşleştirme';

  @override
  String matchingRemovePair(Object target) {
    return '$target eşleştirmesini kaldır';
  }

  @override
  String get matchingCorrectMappingHeading => 'Doğru eşleştirme';

  @override
  String get matchingFeedbackUnavailable =>
      'Önceki eşleştirmelerin bu cihazda saklanmadı. Sunucunun bildirdiği doğru eşleştirmenin tamamı aşağıda gösteriliyor.';

  @override
  String get teacher => 'Öğretmen';

  @override
  String get teacherImportTitle => 'Excel’den kurs oluştur';

  @override
  String get teacherImportBody =>
      'Bu yerel test akışı bir .xlsx dosyasını zararlı yazılım taraması ve inceleme için yükler. Onay, taslak oluşturma ve yayımlama ayrı adımlardır.';

  @override
  String get selectWorkbook => 'Excel dosyası seç';

  @override
  String get preparingWorkbook => 'Çalışma kitabı denetleniyor';

  @override
  String get uploadingWorkbook => 'Çalışma kitabı yükleniyor';

  @override
  String get processingWorkbook => 'Dosya taranıyor ve önizleme hazırlanıyor';

  @override
  String get previewHeading => 'İçe aktarmayı incele';

  @override
  String previewSummary(Object matching, Object questions, Object rows) {
    return '$rows kaynak satırı · $questions soru · $matching eşleştirme sorusu';
  }

  @override
  String previewRowLabel(Object row, Object test, Object type) {
    return 'Kaynak satırı $row, test $test, soru tipi $type';
  }

  @override
  String get loadMore => 'Daha fazla yükle';

  @override
  String get issuesHeading => 'Uyarılar ve hatalar';

  @override
  String get previewApprovalConfirmation =>
      'Önizlemeyi inceledim ve bu onayın kursu yayımlamadığını biliyorum.';

  @override
  String get approvePreview => 'Bu önizlemeyi onayla';

  @override
  String get draftCreationNotice =>
      'Onaylanan içerik artık yayımlanmamış bir taslak olarak kaydedilebilir. Bu işlem içeriği öğrencilere açmaz.';

  @override
  String get draftCreationConfirmation =>
      'Bu onaylı önizlemeden tam olarak bir değişmez, yayımlanmamış taslak oluştur.';

  @override
  String get createDraft => 'Kurs taslağını oluştur';

  @override
  String get releaseImpactHeading => 'Yayımlama etkisi';

  @override
  String releaseImpactSummary(
    Object added,
    Object changed,
    Object learners,
    Object questions,
    Object removed,
  ) {
    return '$questions soru · $added eklendi · $changed değişti · $removed kaldırıldı · $learners etkilenen öğrenci';
  }

  @override
  String get releaseImpactConfirmation =>
      'Bu kesin etkiyi inceledim ve değişmez yayını etkinleştirmek istiyorum.';

  @override
  String get publishCourse => 'Kursu yayımla';

  @override
  String get coursePublished =>
      'Kurs yayını etkin. İlerleme yeniden hesaplama işi sıraya alındı.';

  @override
  String get newImport => 'Yeni içe aktarma başlat';

  @override
  String get workbookRejected =>
      'Çalışma kitabı güvenli biçimde reddedildi. Aşağıdaki sorunları incele.';

  @override
  String get workbookExpired =>
      'Bu yükleme oturumunun süresi doldu. Yeni bir içe aktarma başlat.';

  @override
  String fileDetails(Object name, Object size) {
    return '$name · $size bayt';
  }

  @override
  String questionType(Object type) {
    return 'Tip $type';
  }

  @override
  String correctAnswerTeacher(Object answer) {
    return 'İncelenen cevap: $answer';
  }

  @override
  String alternativeCorrectAnswerTeacher(Object answer) {
    return 'İncelenen alternatif cevap: $answer';
  }

  @override
  String wrongAnswersTeacher(Object answers) {
    return 'İncelenen çeldiriciler: $answers';
  }

  @override
  String matchingGroupTeacher(Object group) {
    return 'Eşleştirme grubu: $group';
  }

  @override
  String get editPublishedCourse => 'Yayımlanmış kursu düzenle';

  @override
  String get courseEditorTitle => 'Bir kurs sorusunu düzenle';

  @override
  String get courseEditorScope =>
      'Bu yerel test editörü, uygun ilk yazılı boşluk sorusunun metnini değiştirir. Doğru cevap yalnızca sunucuda kalır.';

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
  String get courseEditorPromptLabel => 'Soru metni';

  @override
  String get courseEditorPromptHelp =>
      'Tam olarak bir --- boşluğu bırakın. En fazla 1.000 karakter.';

  @override
  String get courseEditorRecovered =>
      'Kaydedilmemiş değişikliğiniz bu cihazın güvenli alanından geri yüklendi.';

  @override
  String get courseEditorRecoveryFailed =>
      'Bu değişiklik güvenli alanda korunamadı. Ekrandan ayrılmadan önce metni kopyalayın.';

  @override
  String get courseEditorPromptEmpty => 'Bir soru metni girin.';

  @override
  String get courseEditorPromptTooLong =>
      'Soru metni en fazla 1.000 karakter olabilir.';

  @override
  String get courseEditorPromptPlaceholder =>
      'Soru metninde tam olarak bir --- boşluğu bulunmalı.';

  @override
  String get courseEditorPromptUnchanged =>
      'Taslak oluşturmadan önce soru metnini değiştirin.';

  @override
  String get discardEditorChanges => 'Değişiklikleri sil';

  @override
  String get saveEditorDraft => 'Değişmez taslak oluştur';

  @override
  String get courseEditorConflictHeading => 'Yayımlanan soru değişmiş';

  @override
  String get courseEditorConflictBody =>
      'Sürümleri karşılaştırın. Nasıl devam edeceğinizi seçene kadar hiçbir şeyin üzerine yazılmaz.';

  @override
  String get courseEditorPreviousVersion => 'Başladığınız sürüm';

  @override
  String get courseEditorYourVersion => 'Kaydedilmemiş sürümünüz';

  @override
  String get courseEditorLatestVersion => 'En son yayımlanan sürüm';

  @override
  String get courseEditorUseLatest => 'En son sürümü kullan';

  @override
  String get courseEditorReapplyMine => 'Benim sürümümü yeniden uygula';

  @override
  String get courseEditorImpactConfirmation =>
      'Bu tek soruluk etkiyi inceledim ve değişmez yayını etkinleştirmek istiyorum.';

  @override
  String get publishEditorRevision => 'Bu sürümü yayımla';

  @override
  String get courseEditorPublished =>
      'Düzenlenen yayın etkin. Doğru cevap bu cihaza gönderilmedi.';

  @override
  String get courseEditorOtherRecovery =>
      'Başka bir kursun güvenli, kaydedilmemiş taslağı var. Bu kursu düzenlemeden önce o taslağı silin.';

  @override
  String get courseEditorDiscardOther => 'Diğer taslağı sil';

  @override
  String get courseEditorLeaveTitle => 'Kaydedilmemiş değişiklik silinsin mi?';

  @override
  String get courseEditorLeaveBody =>
      'Değişikliğiniz bu cihazda güvenle saklanıyor. Daha sonrası için tutabilir veya şimdi silebilirsiniz.';

  @override
  String get keepEditing => 'Daha sonrası için tut';
}
