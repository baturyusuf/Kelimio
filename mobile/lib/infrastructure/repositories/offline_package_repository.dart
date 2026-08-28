import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:kelimio_api_client/kelimio_api_client.dart' as api;
import 'package:path_provider/path_provider.dart';

import '../../domain/failures.dart';
import '../../domain/offline/offline.dart';
import '../network/failure_mapper.dart';

final class GeneratedOfflinePackageRepository
    implements OfflinePackageRepository {
  GeneratedOfflinePackageRepository(this._api, this._failures)
    : _download = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(minutes: 2),
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );
  final api.LearningApi _api;
  final DioFailureMapper _failures;
  final Dio _download;

  void close() => _download.close(force: true);

  @override
  Future<void> clearPrivateData() async {
    final root = await getApplicationSupportDirectory();
    for (final name in const ['offline_packages', 'offline_practice']) {
      final directory = Directory('${root.path}${Platform.pathSeparator}$name');
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  }

  @override
  Future<OfflineCoursePackage> download({
    required String courseId,
    required String supportLanguage,
  }) async {
    try {
      final metadata = (await _api.getOfflineCoursePackage(
        courseId: courseId,
        supportLanguage: supportLanguage,
      )).data;
      if (metadata == null) {
        throw const ProtocolFailure('Offline package metadata was empty');
      }
      final response = await _download.get<List<int>>(metadata.downloadUrl);
      final bytes = response.data;
      if (bytes == null ||
          sha256.convert(bytes).toString() != metadata.sha256) {
        throw const ProtocolFailure(
          'Offline package checksum verification failed',
        );
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, Object?> ||
          decoded['mode'] != 'OFFLINE_SCORELESS' ||
          decoded['formatVersion'] != 1 ||
          decoded['courseReleaseId'] != metadata.courseReleaseId) {
        throw const ProtocolFailure('Offline package identity was invalid');
      }
      final root = await getApplicationSupportDirectory();
      final directory = Directory(
        '${root.path}${Platform.pathSeparator}offline_packages',
      );
      await directory.create(recursive: true);
      final file = File(
        '${directory.path}${Platform.pathSeparator}${metadata.courseReleaseId}-$supportLanguage-${metadata.sha256}.json',
      );
      if (await file.exists()) {
        final installedSha256 = sha256
            .convert(await file.readAsBytes())
            .toString();
        if (installedSha256 != metadata.sha256) {
          await file.delete();
        }
      }
      if (!await file.exists()) {
        final temporaryFile = File(
          '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
        );
        try {
          await temporaryFile.writeAsBytes(bytes, flush: true);
          await temporaryFile.rename(file.path);
        } finally {
          if (await temporaryFile.exists()) {
            await temporaryFile.delete();
          }
        }
      }
      return OfflineCoursePackage(
        courseId: courseId,
        courseReleaseId: metadata.courseReleaseId,
        supportLanguage: supportLanguage,
        sha256: metadata.sha256,
        localPath: file.path,
      );
    } on DioException catch (error) {
      throw _failures.map(error);
    } on AppFailure {
      rethrow;
    } on Object catch (error) {
      throw UnknownFailure(cause: error);
    }
  }

  @override
  Future<void> recordPractice({
    required OfflineCoursePackage package,
    required int answered,
    required int correct,
  }) async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}offline_practice',
    );
    await directory.create(recursive: true);
    final event = <String, Object?>{
      'courseReleaseId': package.courseReleaseId,
      'supportLanguage': package.supportLanguage,
      'answered': answered,
      'correct': correct,
      'mode': 'OFFLINE_SCORELESS',
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
    };
    await File(
      '${directory.path}${Platform.pathSeparator}events.jsonl',
    ).writeAsString(
      '${jsonEncode(event)}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  @override
  Future<List<OfflinePracticeQuestion>> loadQuestions(
    OfflineCoursePackage package,
  ) async {
    final root =
        jsonDecode(await File(package.localPath).readAsString())
            as Map<String, Object?>;
    final course = root['course']! as Map<String, Object?>;
    final result = <OfflinePracticeQuestion>[];
    for (final level in course['levels']! as List<Object?>) {
      for (final unit
          in (level! as Map<String, Object?>)['units']! as List<Object?>) {
        for (final topic
            in (unit! as Map<String, Object?>)['topics']! as List<Object?>) {
          for (final test
              in (topic! as Map<String, Object?>)['tests']! as List<Object?>) {
            for (final raw
                in (test! as Map<String, Object?>)['questions']!
                    as List<Object?>) {
              final question = raw! as Map<String, Object?>;
              final options =
                  (question['options'] as List<Object?>? ?? const [])
                      .cast<Map<String, Object?>>();
              final pairs =
                  (question['matchingPairs'] as List<Object?>? ?? const [])
                      .cast<Map<String, Object?>>();
              final type = question['type']! as String;
              result.add(
                OfflinePracticeQuestion(
                  type: type,
                  prompt:
                      (question['prompt'] as String?) ??
                      (question['correctAnswer'] as String?) ??
                      'Kelimeyi çalış',
                  correctAnswer: type == 'MATCHING'
                      ? 'Eşleştirmeleri kontrol et'
                      : (question['correctAnswer'] as String?) ??
                            options
                                .where((item) => item['correct'] == true)
                                .map((item) => item['text']! as String)
                                .join(', '),
                  options: options
                      .map((item) => item['text']! as String)
                      .toList(growable: false),
                  matchingPairs: {
                    for (final pair in pairs)
                      pair['targetText']! as String:
                          ((pair['translations']!
                                      as Map<String, Object?>)[package
                                      .supportLanguage] ??
                                  '')
                              .toString(),
                  },
                ),
              );
            }
          }
        }
      }
    }
    return result;
  }
}
