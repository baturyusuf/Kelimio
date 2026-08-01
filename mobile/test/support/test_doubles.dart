import 'dart:async';

import 'package:kelimio_mobile/domain/auth/auth.dart';
import 'package:kelimio_mobile/domain/catalog/catalog.dart';
import 'package:kelimio_mobile/domain/development/development.dart';
import 'package:kelimio_mobile/domain/identifiers.dart';
import 'package:kelimio_mobile/domain/learning/learning.dart';
import 'package:kelimio_mobile/domain/profile/profile.dart';

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

final class RecordingCatalogRepository implements CatalogRepository {
  RecordingCatalogRepository({List<CourseProgress>? progressResults})
    : _progressResults = [...?progressResults];

  final List<CourseProgress> _progressResults;
  int listCalls = 0;
  int progressCalls = 0;

  @override
  Future<CatalogPage> listCourses({String? cursor, int limit = 20}) async {
    listCalls += 1;
    return CatalogPage(
      items: listCalls == 1
          ? []
          : [
              CourseSummary(
                id: '00000000-0000-4000-8000-000000000101',
                name: 'Starter',
                targetLanguage: 'tr',
                supportLanguages: const ['en'],
                accessType: CourseAccessType.free,
                visibility: CourseVisibility.public,
                enrolled: false,
              ),
            ],
    );
  }

  @override
  Future<Enrollment> enroll({
    required String courseId,
    required String supportLanguage,
    required String commandId,
  }) {
    throw UnimplementedError('Not used by this focused test');
  }

  @override
  Future<CourseDetail> getCourse(String courseId) {
    throw UnimplementedError('Not used by this focused test');
  }

  @override
  Future<CourseProgress> getProgress(String courseId) async {
    progressCalls += 1;
    if (_progressResults.isNotEmpty) {
      return _progressResults.removeAt(0);
    }
    return CourseProgress(
      courseId: courseId,
      answeredQuestions: progressCalls,
      correctAnswers: progressCalls,
      completedAttempts: progressCalls,
      passedAttempts: progressCalls,
      activeScore: progressCalls * 60,
      lifetimeScore: progressCalls * 60,
      projectionVersion: progressCalls,
      updating: false,
      updatedAt: DateTime.utc(2026),
    );
  }
}

final class RecordingDevelopmentRepository implements DevelopmentRepository {
  final List<String> commandIds = [];

  @override
  Future<LocalStarterCourseInstall> installStarterCourse({
    required String commandId,
  }) async {
    commandIds.add(commandId);
    return const LocalStarterCourseInstall(
      courseId: '00000000-0000-4000-8000-000000000101',
      created: true,
      sourceWorkbookSha256:
          '9fb87f680505e949304257e43e09ab0ce7f71324b4a06bcfae919260ab9f889e',
    );
  }
}

final class RecordingProfileRepository implements ProfileRepository {
  RecordingProfileRepository({this.failFirstCompletion = false});

  final bool failFirstCompletion;
  final List<String> commandIds = [];
  int getCalls = 0;
  int completionCalls = 0;

  static const requiredProfile = UserProfile(
    id: '00000000-0000-4000-8000-000000000901',
    displayName: 'Profile User',
    appLocale: 'en',
    activeTargetLanguage: 'tr',
    preferredSupportLanguage: null,
    timeZone: 'UTC',
    profileVersion: 0,
    setupStatus: ProfileSetupStatus.required,
  );

  @override
  Future<UserProfile> getMe() async {
    getCalls += 1;
    return requiredProfile;
  }

  @override
  Future<UserProfile> completeSetup({
    required ProfileSetupInput input,
    required String commandId,
  }) async {
    completionCalls += 1;
    commandIds.add(commandId);
    if (failFirstCompletion && completionCalls == 1) {
      throw StateError('simulated uncertain network result');
    }
    return UserProfile(
      id: requiredProfile.id,
      displayName: input.displayName.trim(),
      appLocale: input.appLocale,
      activeTargetLanguage: input.activeTargetLanguage,
      preferredSupportLanguage: input.preferredSupportLanguage,
      timeZone: input.timeZone,
      profileVersion: 1,
      setupStatus: ProfileSetupStatus.complete,
    );
  }
}
