import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/domain/course_authoring/course_authoring.dart';
import 'package:kelimio_mobile/domain/failures.dart';
import 'package:kelimio_mobile/infrastructure/storage/secure_course_editor_recovery_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('round trips the single bounded editor recovery record', () async {
    final storage = _MemorySecureStorage();
    final store = SecureCourseEditorRecoveryStore(storage: storage);
    final draft = _draft();

    await store.write(draft);
    final restored = await store.read();

    expect(restored?.editedPrompt, 'Ben her sabah ---.');
    expect(storage.values, hasLength(1));
    await store.clear();
    expect(await store.read(), isNull);
  });

  test('malformed secure recovery is cleared and fails closed', () async {
    final storage = _MemorySecureStorage()
      ..values[SecureCourseEditorRecoveryStore.storageKey] = '{"prompt":1}';
    final store = SecureCourseEditorRecoveryStore(storage: storage);

    await expectLater(store.read(), throwsA(isA<ProtocolFailure>()));
    expect(storage.values, isEmpty);
  });
}

LocalCourseEditorRecoveryDraft _draft() => LocalCourseEditorRecoveryDraft(
  courseId: '00000000-0000-4000-8000-000000000200',
  baseReleaseId: '00000000-0000-4000-8000-000000000300',
  questionRevisionId: '00000000-0000-4000-8000-000000000430',
  entityTag:
      '"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"',
  originalPrompt: 'Ben her gun ---.',
  editedPrompt: 'Ben her sabah ---.',
  updatedAt: DateTime.now().toUtc(),
);

final class _MemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}
