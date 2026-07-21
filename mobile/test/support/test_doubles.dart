import 'dart:async';

import 'package:kelimio_mobile/domain/auth/auth.dart';
import 'package:kelimio_mobile/domain/identifiers.dart';
import 'package:kelimio_mobile/domain/learning/learning.dart';

import 'fixtures.dart';

final class RecordingLearningRepository implements LearningRepository {
  RecordingLearningRepository({required this.answerBehaviors});

  final List<Future<AnswerFeedback> Function(String submissionId)>
  answerBehaviors;
  final List<String> submittedIds = [];
  int startCalls = 0;

  @override
  Future<AttemptSession> startAttempt({
    required String testId,
    required String commandId,
  }) async {
    startCalls += 1;
    return fixtureSession();
  }

  @override
  Future<AnswerFeedback> submitAnswer({
    required String attemptId,
    required String questionRevisionId,
    required String selectedOptionId,
    required String submissionId,
  }) {
    submittedIds.add(submissionId);
    return answerBehaviors.removeAt(0)(submissionId);
  }

  @override
  Future<AttemptResult> finishAttempt({
    required String attemptId,
    required String commandId,
  }) {
    throw UnimplementedError('Not used by these focused tests');
  }
}

final class MemoryRecoveryStore implements AttemptRecoveryStore {
  AttemptRecoverySnapshot? value;
  int clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls += 1;
    value = null;
  }

  @override
  Future<AttemptRecoverySnapshot?> read() async => value;

  @override
  Future<void> write(AttemptRecoverySnapshot snapshot) async {
    value = snapshot;
  }
}

final class RecordingAuthRepository implements AuthRepository {
  RecordingAuthRepository({this.restoredSession, AuthSession? signedInSession})
    : signedInSession =
          signedInSession ?? AuthSession(expiresAt: DateTime.utc(2030));

  final AuthSession? restoredSession;
  final AuthSession signedInSession;
  int signInCalls = 0;
  int signOutCalls = 0;

  @override
  Future<AuthSession?> restore() async => restoredSession;

  @override
  Future<AuthSession> signIn() async {
    signInCalls += 1;
    return signedInSession;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }
}

final class SequenceIdentifierFactory implements IdentifierFactory {
  SequenceIdentifierFactory(this._values);

  final List<String> _values;
  int _index = 0;

  @override
  String create() => _values[_index++];
}
