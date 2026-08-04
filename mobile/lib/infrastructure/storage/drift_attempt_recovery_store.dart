import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../domain/failures.dart';
import '../../domain/learning/learning.dart';

final class DriftAttemptRecoveryStore implements AttemptRecoveryStore {
  DriftAttemptRecoveryStore({DatabaseConnection? connection})
    : _connection = connection ?? driftDatabase(name: 'kelimio_recovery');

  final DatabaseConnection _connection;
  final _schema = _RecoverySchema();
  bool _opened = false;

  Future<void> open() async {
    if (_opened) {
      return;
    }
    await _connection.ensureOpen(_schema);
    _opened = true;
  }

  @override
  Future<AttemptRecoverySnapshot?> read() async {
    await open();
    final rows = await _connection.runSelect(
      'SELECT test_id, start_command_id, phase, attempt_id, question_index, '
      'answer_kind, selected_option_id, submission_id, finish_command_id, '
      'updated_at_ms '
      'FROM attempt_recovery WHERE slot = 1',
      const [],
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.single;
    try {
      final snapshot = AttemptRecoverySnapshot(
        testId: row['test_id']! as String,
        startCommandId: row['start_command_id']! as String,
        phase: RecoveryPhase.values.byName(row['phase']! as String),
        attemptId: row['attempt_id'] as String?,
        questionIndex: row['question_index']! as int,
        answerKind: row['answer_kind'] == null
            ? null
            : AnswerKind.values.byName(row['answer_kind']! as String),
        selectedOptionId: row['selected_option_id'] as String?,
        submissionId: row['submission_id'] as String?,
        finishCommandId: row['finish_command_id'] as String?,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row['updated_at_ms']! as int,
          isUtc: true,
        ),
      );
      _validateRecoverySnapshot(snapshot);
      return snapshot;
    } on Object catch (error) {
      throw ProtocolFailure('Invalid attempt recovery record', cause: error);
    }
  }

  @override
  Future<void> write(AttemptRecoverySnapshot snapshot) async {
    _validateRecoverySnapshot(snapshot);
    await open();
    await _connection.runInsert(
      'INSERT INTO attempt_recovery ('
      'slot, test_id, start_command_id, phase, attempt_id, question_index, '
      'answer_kind, selected_option_id, submission_id, finish_command_id, '
      'updated_at_ms'
      ') VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(slot) DO UPDATE SET '
      'test_id = excluded.test_id, '
      'start_command_id = excluded.start_command_id, '
      'phase = excluded.phase, '
      'attempt_id = excluded.attempt_id, '
      'question_index = excluded.question_index, '
      'answer_kind = excluded.answer_kind, '
      'selected_option_id = excluded.selected_option_id, '
      'submission_id = excluded.submission_id, '
      'finish_command_id = excluded.finish_command_id, '
      'updated_at_ms = excluded.updated_at_ms',
      [
        snapshot.testId,
        snapshot.startCommandId,
        snapshot.phase.name,
        snapshot.attemptId,
        snapshot.questionIndex,
        snapshot.answerKind?.name,
        snapshot.selectedOptionId,
        snapshot.submissionId,
        snapshot.finishCommandId,
        snapshot.updatedAt.toUtc().millisecondsSinceEpoch,
      ],
    );
  }

  @override
  Future<void> clear() async {
    await open();
    await _connection.runDelete(
      'DELETE FROM attempt_recovery WHERE slot = 1',
      const [],
    );
  }

  Future<void> close() => _connection.close();
}

void _validateRecoverySnapshot(AttemptRecoverySnapshot snapshot) {
  final kind = snapshot.answerKind;
  if ((kind == AnswerKind.typed || kind == AnswerKind.matching) &&
      snapshot.selectedOptionId != null) {
    throw const ProtocolFailure(
      'Private-answer recovery record contained forbidden option data',
    );
  }
  if (kind == AnswerKind.matching) {
    final phase = snapshot.phase;
    if ((phase == RecoveryPhase.submitting ||
            phase == RecoveryPhase.feedback) &&
        snapshot.submissionId == null) {
      throw const ProtocolFailure(
        'Matching recovery record omitted its submission identity',
      );
    }
    if (phase != RecoveryPhase.presenting &&
        phase != RecoveryPhase.submitting &&
        phase != RecoveryPhase.feedback) {
      throw const ProtocolFailure('Invalid matching recovery phase');
    }
  }
}

final class _RecoverySchema implements QueryExecutorUser {
  @override
  int get schemaVersion => 2;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {
    // Background Drift connections proxy migrations back to this isolate.
    // Opening that migration executor first is required before issuing SQL.
    await executor.ensureOpen(this);
    await executor.runCustom(
      'CREATE TABLE IF NOT EXISTS attempt_recovery ('
      'slot INTEGER NOT NULL PRIMARY KEY CHECK (slot = 1), '
      'test_id TEXT NOT NULL, '
      'start_command_id TEXT NOT NULL, '
      'phase TEXT NOT NULL, '
      'attempt_id TEXT NULL, '
      'question_index INTEGER NOT NULL, '
      'answer_kind TEXT NULL, '
      'selected_option_id TEXT NULL, '
      'submission_id TEXT NULL, '
      'finish_command_id TEXT NULL, '
      'updated_at_ms INTEGER NOT NULL'
      ')',
    );
    final columns = await executor.runSelect(
      'PRAGMA table_info(attempt_recovery)',
      const [],
    );
    final hasAnswerKind = columns.any(
      (column) => column['name'] == 'answer_kind',
    );
    if (!hasAnswerKind) {
      await executor.runCustom(
        'ALTER TABLE attempt_recovery ADD COLUMN answer_kind TEXT NULL',
      );
    }
  }
}
