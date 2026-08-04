import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimio_mobile/domain/failures.dart';
import 'package:kelimio_mobile/domain/learning/learning.dart';
import 'package:kelimio_mobile/infrastructure/storage/drift_attempt_recovery_store.dart';

import '../support/fixtures.dart';

void main() {
  test('schema v2 stores typed recovery metadata without raw text', () async {
    final connection = DatabaseConnection(NativeDatabase.memory());
    final store = DriftAttemptRecoveryStore(connection: connection);
    addTearDown(store.close);
    final snapshot = fixtureRecovery(
      RecoveryPhase.submitting,
      answerKind: AnswerKind.typed,
      recoveredSubmissionId: submissionId,
    );

    await store.write(snapshot);

    final restored = await store.read();
    expect(restored?.answerKind, AnswerKind.typed);
    expect(restored?.submissionId, submissionId);
    expect(restored?.selectedOptionId, isNull);
    final columns = await connection.runSelect(
      'PRAGMA table_info(attempt_recovery)',
      const [],
    );
    final names = columns.map((row) => row['name']).toSet();
    expect(names, contains('answer_kind'));
    expect(names.where((name) => '$name'.contains('typed')), isEmpty);
    expect(names.where((name) => '$name'.contains('raw')), isEmpty);
  });

  test('matching recovery stores identity only and no item mapping', () async {
    final connection = DatabaseConnection(NativeDatabase.memory());
    final store = DriftAttemptRecoveryStore(connection: connection);
    addTearDown(store.close);
    final snapshot = fixtureRecovery(
      RecoveryPhase.submitting,
      answerKind: AnswerKind.matching,
      recoveredSubmissionId: submissionId,
    );

    await store.write(snapshot);

    final restored = await store.read();
    expect(restored?.answerKind, AnswerKind.matching);
    expect(restored?.submissionId, submissionId);
    expect(restored?.selectedOptionId, isNull);

    final rows = await connection.runSelect(
      'SELECT * FROM attempt_recovery WHERE slot = 1',
      const [],
    );
    final rawRecord = rows.single.values.join('|');
    expect(rawRecord, isNot(contains(targetItemOneId)));
    expect(rawRecord, isNot(contains(targetItemTwoId)));
    expect(rawRecord, isNot(contains(supportItemOneId)));
    expect(rawRecord, isNot(contains(supportItemTwoId)));
    expect(snapshot.toString(), isNot(contains(targetItemOneId)));

    final columns = await connection.runSelect(
      'PRAGMA table_info(attempt_recovery)',
      const [],
    );
    final names = columns.map((row) => '${row['name']}').toList();
    expect(names.where((name) => name.contains('target')), isEmpty);
    expect(names.where((name) => name.contains('support')), isEmpty);
    expect(names.where((name) => name.contains('match')), isEmpty);
    expect(names.where((name) => name.contains('pair')), isEmpty);
  });

  test(
    'matching recovery with an item ID in option storage fails closed',
    () async {
      final connection = DatabaseConnection(NativeDatabase.memory());
      final store = DriftAttemptRecoveryStore(connection: connection);
      addTearDown(store.close);
      await store.write(
        fixtureRecovery(
          RecoveryPhase.submitting,
          answerKind: AnswerKind.matching,
          recoveredSubmissionId: submissionId,
        ),
      );
      await connection.runUpdate(
        'UPDATE attempt_recovery SET selected_option_id = ? WHERE slot = 1',
        [targetItemOneId],
      );

      await expectLater(store.read(), throwsA(isA<ProtocolFailure>()));
    },
  );

  test(
    'v1 option recovery migrates idempotently and remains readable',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kelimio-recovery-migration-',
      );
      final databaseFile = File('${directory.path}/recovery.sqlite');
      addTearDown(() async {
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });
      final firstConnection = DatabaseConnection(
        NativeDatabase(
          databaseFile,
          setup: (database) {
            database.execute(_v1CreateSql);
            database.execute(
              'INSERT INTO attempt_recovery ('
              'slot, test_id, start_command_id, phase, attempt_id, '
              'question_index, selected_option_id, submission_id, '
              'finish_command_id, updated_at_ms'
              ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
              [
                1,
                testId,
                '00000000-0000-4000-8000-000000000020',
                RecoveryPhase.submitting.name,
                attemptId,
                0,
                '00000000-0000-4000-8000-000000000010',
                submissionId,
                null,
                DateTime.utc(2026).millisecondsSinceEpoch,
              ],
            );
            database.userVersion = 1;
          },
        ),
      );
      final firstStore = DriftAttemptRecoveryStore(connection: firstConnection);

      final migrated = await firstStore.read();

      expect(migrated?.answerKind, isNull);
      expect(
        migrated?.selectedOptionId,
        '00000000-0000-4000-8000-000000000010',
      );
      expect(migrated?.submissionId, submissionId);
      final firstColumns = await firstConnection.runSelect(
        'PRAGMA table_info(attempt_recovery)',
        const [],
      );
      expect(
        firstColumns.where((row) => row['name'] == 'answer_kind'),
        hasLength(1),
      );
      await firstStore.close();

      final reopenedConnection = DatabaseConnection(
        NativeDatabase(databaseFile),
      );
      final reopenedStore = DriftAttemptRecoveryStore(
        connection: reopenedConnection,
      );
      addTearDown(reopenedStore.close);

      final reopened = await reopenedStore.read();
      final reopenedColumns = await reopenedConnection.runSelect(
        'PRAGMA table_info(attempt_recovery)',
        const [],
      );
      expect(reopened?.submissionId, submissionId);
      expect(
        reopenedColumns.where((row) => row['name'] == 'answer_kind'),
        hasLength(1),
      );
    },
  );
}

const _v1CreateSql =
    'CREATE TABLE IF NOT EXISTS attempt_recovery ('
    'slot INTEGER NOT NULL PRIMARY KEY CHECK (slot = 1), '
    'test_id TEXT NOT NULL, '
    'start_command_id TEXT NOT NULL, '
    'phase TEXT NOT NULL, '
    'attempt_id TEXT NULL, '
    'question_index INTEGER NOT NULL, '
    'selected_option_id TEXT NULL, '
    'submission_id TEXT NULL, '
    'finish_command_id TEXT NULL, '
    'updated_at_ms INTEGER NOT NULL'
    ')';
