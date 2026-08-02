import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/course_authoring/course_authoring.dart';
import '../../domain/failures.dart';

final class SecureCourseEditorRecoveryStore
    implements CourseEditorRecoveryStore {
  SecureCourseEditorRecoveryStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const storageKey = 'kelimio.course_editor.recovery.v1';
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static final _entityTag = RegExp(r'^"[0-9a-f]{64}"$');

  final FlutterSecureStorage _storage;

  @override
  Future<LocalCourseEditorRecoveryDraft?> read() async {
    final encoded = await _storage.read(key: storageKey);
    if (encoded == null) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, Object?> || decoded.length != 7) {
        throw const FormatException('unexpected recovery shape');
      }
      const keys = {
        'courseId',
        'baseReleaseId',
        'questionRevisionId',
        'entityTag',
        'originalPrompt',
        'editedPrompt',
        'updatedAt',
      };
      if (!decoded.keys.toSet().containsAll(keys)) {
        throw const FormatException('missing recovery field');
      }
      final draft = LocalCourseEditorRecoveryDraft(
        courseId: _string(decoded, 'courseId'),
        baseReleaseId: _string(decoded, 'baseReleaseId'),
        questionRevisionId: _string(decoded, 'questionRevisionId'),
        entityTag: _string(decoded, 'entityTag'),
        originalPrompt: _string(decoded, 'originalPrompt'),
        editedPrompt: _string(decoded, 'editedPrompt'),
        updatedAt: DateTime.parse(_string(decoded, 'updatedAt')).toUtc(),
      );
      _validate(draft);
      return draft;
    } on Object catch (error) {
      try {
        await clear();
      } on Object {
        // The malformed value remains inaccessible and is never returned.
      }
      throw ProtocolFailure(
        'Course editor recovery data was invalid and was discarded',
        cause: error,
      );
    }
  }

  @override
  Future<void> write(LocalCourseEditorRecoveryDraft draft) async {
    _validate(draft);
    await _storage.write(
      key: storageKey,
      value: jsonEncode({
        'courseId': draft.courseId,
        'baseReleaseId': draft.baseReleaseId,
        'questionRevisionId': draft.questionRevisionId,
        'entityTag': draft.entityTag,
        'originalPrompt': draft.originalPrompt,
        'editedPrompt': draft.editedPrompt,
        'updatedAt': draft.updatedAt.toUtc().toIso8601String(),
      }),
    );
  }

  @override
  Future<void> clear() => _storage.delete(key: storageKey);

  static String _string(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String) throw FormatException('$key must be a string');
    return value;
  }

  static void _validate(LocalCourseEditorRecoveryDraft draft) {
    if (!_uuid.hasMatch(draft.courseId) ||
        !_uuid.hasMatch(draft.baseReleaseId) ||
        !_uuid.hasMatch(draft.questionRevisionId) ||
        !_entityTag.hasMatch(draft.entityTag) ||
        !_validOriginalPrompt(draft.originalPrompt) ||
        !_validEditedPrompt(draft.editedPrompt) ||
        draft.originalPrompt == draft.editedPrompt ||
        draft.updatedAt.isAfter(
          DateTime.now().toUtc().add(const Duration(minutes: 5)),
        )) {
      throw const ProtocolFailure('Course editor recovery data was invalid');
    }
  }

  static bool _validOriginalPrompt(String value) =>
      value.isNotEmpty &&
      value.length <= 1000 &&
      RegExp('---').allMatches(value).length == 1;

  static bool _validEditedPrompt(String value) =>
      value.isNotEmpty && value.length <= 1000;
}
