import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart' as api;
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../domain/auth/auth.dart';
import '../domain/catalog/catalog.dart';
import '../domain/course_authoring/course_authoring.dart';
import '../domain/development/development.dart';
import '../domain/energy/energy.dart';
import '../domain/failures.dart';
import '../domain/identifiers.dart';
import '../domain/learning/learning.dart';
import '../domain/profile/profile.dart';
import '../infrastructure/auth/app_auth_gateway.dart';
import '../infrastructure/files/native_workbook_picker.dart';
import '../infrastructure/network/failure_mapper.dart';
import '../infrastructure/network/interceptors.dart';
import '../infrastructure/repositories/course_authoring_repository.dart';
import '../infrastructure/repositories/dio_repositories.dart';
import '../infrastructure/storage/drift_attempt_recovery_store.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  throw StateError('AppConfig must be overridden at startup');
});

final identifierFactoryProvider = Provider<IdentifierFactory>((ref) {
  return const UuidIdentifierFactory();
});

final authGatewayProvider = Provider<AppAuthGateway>((ref) {
  return AppAuthGateway(config: ref.watch(appConfigProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ref.watch(authGatewayProvider);
});

final accessTokenProviderProvider = Provider<AccessTokenProvider>((ref) {
  return ref.watch(authGatewayProvider);
});

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUri.toString(),
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      headers: const {
        'Accept': 'application/json, application/problem+json',
        'Content-Type': 'application/json',
      },
    ),
  );
  dio.interceptors.addAll([
    CorrelationInterceptor(ref.watch(identifierFactoryProvider)),
    IdempotencyInterceptor(),
    ClientCapabilityInterceptor(),
    AuthInterceptor(dio, ref.watch(accessTokenProviderProvider)),
    AnswerKeyLeakGuardInterceptor(),
    RedactedLogInterceptor(enabled: !config.isProduction),
  ]);
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

final apiClientProvider = Provider<api.KelimioApiClient>((ref) {
  return api.KelimioApiClient(
    dio: ref.watch(dioProvider),
    interceptors: const [],
  );
});

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return GeneratedCatalogRepository(
    client.getCatalogApi(),
    client.getEnrollmentApi(),
    client.getLearningApi(),
    const DioFailureMapper(),
  );
});

final learningRepositoryProvider = Provider<LearningRepository>((ref) {
  return GeneratedLearningRepository(
    ref.watch(apiClientProvider).getLearningApi(),
    const DioFailureMapper(),
  );
});

final developmentRepositoryProvider = Provider<DevelopmentRepository>((ref) {
  return GeneratedDevelopmentRepository(
    ref.watch(apiClientProvider).getDevelopmentApi(),
    const DioFailureMapper(),
  );
});

final workbookPickerProvider = Provider<WorkbookPicker>((ref) {
  return const NativeWorkbookPicker();
});

final courseAuthoringUploadClientProvider = Provider<Dio>((ref) {
  final dio = GeneratedCourseAuthoringRepository.createPresignedUploadClient();
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

final courseAuthoringRepositoryProvider = Provider<CourseAuthoringRepository>((
  ref,
) {
  final client = ref.watch(apiClientProvider);
  return GeneratedCourseAuthoringRepository(
    client.getCourseImportApi(),
    client.getCourseReleaseApi(),
    const DioFailureMapper(),
    uploadClient: ref.watch(courseAuthoringUploadClientProvider),
  );
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return GeneratedProfileRepository(
    ref.watch(apiClientProvider).getProfileApi(),
    const DioFailureMapper(),
  );
});

final energyRepositoryProvider = Provider<EnergyRepository>((ref) {
  return GeneratedEnergyRepository(
    ref.watch(apiClientProvider).getEnergyApi(),
    const DioFailureMapper(),
  );
});

final recoveryStoreProvider = FutureProvider<AttemptRecoveryStore>((ref) async {
  final store = DriftAttemptRecoveryStore();
  await store.open();
  ref.onDispose(() => unawaited(store.close()));
  return store;
});

final courseDetailProvider = FutureProvider.family<CourseDetail, String>((
  ref,
  id,
) {
  return ref.watch(catalogRepositoryProvider).getCourse(id);
});

final courseProgressRefreshDelaysProvider = Provider<List<Duration>>(
  (ref) => const [
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 4),
  ],
);

final courseProgressProvider = StreamProvider.autoDispose
    .family<CourseProgress, String>((ref, id) async* {
      var progress = await ref.watch(catalogRepositoryProvider).getProgress(id);
      yield progress;

      final refreshDelays = ref.watch(courseProgressRefreshDelaysProvider);
      for (final delay in refreshDelays) {
        if (!progress.updating) {
          return;
        }
        await Future<void>.delayed(delay);
        progress = await ref.read(catalogRepositoryProvider).getProgress(id);
        yield progress;
      }
      if (progress.updating) {
        throw const TimeoutFailure();
      }
    }, retry: (retryCount, error) => null);

final class UuidIdentifierFactory implements IdentifierFactory {
  const UuidIdentifierFactory();

  static const _uuid = Uuid();

  @override
  String create() => _uuid.v4();
}
