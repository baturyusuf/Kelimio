//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'package:dio/dio.dart';
import 'package:kelimio_api_client/src/auth/api_key_auth.dart';
import 'package:kelimio_api_client/src/auth/basic_auth.dart';
import 'package:kelimio_api_client/src/auth/bearer_auth.dart';
import 'package:kelimio_api_client/src/auth/oauth.dart';
import 'package:kelimio_api_client/src/api/account_api.dart';
import 'package:kelimio_api_client/src/api/catalog_api.dart';
import 'package:kelimio_api_client/src/api/course_import_api.dart';
import 'package:kelimio_api_client/src/api/course_release_api.dart';
import 'package:kelimio_api_client/src/api/development_api.dart';
import 'package:kelimio_api_client/src/api/energy_api.dart';
import 'package:kelimio_api_client/src/api/enrollment_api.dart';
import 'package:kelimio_api_client/src/api/learning_api.dart';
import 'package:kelimio_api_client/src/api/profile_api.dart';
import 'package:kelimio_api_client/src/api/social_api.dart';
import 'package:kelimio_api_client/src/api/teacher_api.dart';

class KelimioApiClient {
  static const String basePath = r'http://localhost';

  final Dio dio;
  KelimioApiClient({
    Dio? dio,
    String? basePathOverride,
    List<Interceptor>? interceptors,
  }) : this.dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: basePathOverride ?? basePath,
               connectTimeout: const Duration(milliseconds: 5000),
               receiveTimeout: const Duration(milliseconds: 3000),
             ),
           ) {
    if (interceptors == null) {
      this.dio.interceptors.addAll([
        OAuthInterceptor(),
        BasicAuthInterceptor(),
        BearerAuthInterceptor(),
        ApiKeyAuthInterceptor(),
      ]);
    } else {
      this.dio.interceptors.addAll(interceptors);
    }
  }

  void setOAuthToken(String name, String token) {
    if (this.dio.interceptors.any((i) => i is OAuthInterceptor)) {
      (this.dio.interceptors.firstWhere((i) => i is OAuthInterceptor)
                  as OAuthInterceptor)
              .tokens[name] =
          token;
    }
  }

  void setBearerAuth(String name, String token) {
    if (this.dio.interceptors.any((i) => i is BearerAuthInterceptor)) {
      (this.dio.interceptors.firstWhere((i) => i is BearerAuthInterceptor)
                  as BearerAuthInterceptor)
              .tokens[name] =
          token;
    }
  }

  void setBasicAuth(String name, String username, String password) {
    if (this.dio.interceptors.any((i) => i is BasicAuthInterceptor)) {
      (this.dio.interceptors.firstWhere((i) => i is BasicAuthInterceptor)
              as BasicAuthInterceptor)
          .authInfo[name] = BasicAuthInfo(
        username,
        password,
      );
    }
  }

  void setApiKey(String name, String apiKey) {
    if (this.dio.interceptors.any((i) => i is ApiKeyAuthInterceptor)) {
      (this.dio.interceptors.firstWhere(
                    (element) => element is ApiKeyAuthInterceptor,
                  )
                  as ApiKeyAuthInterceptor)
              .apiKeys[name] =
          apiKey;
    }
  }

  /// Get AccountApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  AccountApi getAccountApi() {
    return AccountApi(dio);
  }

  /// Get CatalogApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  CatalogApi getCatalogApi() {
    return CatalogApi(dio);
  }

  /// Get CourseImportApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  CourseImportApi getCourseImportApi() {
    return CourseImportApi(dio);
  }

  /// Get CourseReleaseApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  CourseReleaseApi getCourseReleaseApi() {
    return CourseReleaseApi(dio);
  }

  /// Get DevelopmentApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  DevelopmentApi getDevelopmentApi() {
    return DevelopmentApi(dio);
  }

  /// Get EnergyApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  EnergyApi getEnergyApi() {
    return EnergyApi(dio);
  }

  /// Get EnrollmentApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  EnrollmentApi getEnrollmentApi() {
    return EnrollmentApi(dio);
  }

  /// Get LearningApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  LearningApi getLearningApi() {
    return LearningApi(dio);
  }

  /// Get ProfileApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  ProfileApi getProfileApi() {
    return ProfileApi(dio);
  }

  /// Get SocialApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  SocialApi getSocialApi() {
    return SocialApi(dio);
  }

  /// Get TeacherApi instance, base route and serializer can be overridden by a given but be careful,
  /// by doing that all interceptors will not be executed
  TeacherApi getTeacherApi() {
    return TeacherApi(dio);
  }
}
