import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/course_authoring/course_authoring.dart';
import '../domain/failures.dart';
import 'providers.dart';

final courseEditorControllerProvider =
    NotifierProvider<CourseEditorController, CourseEditorState>(
      CourseEditorController.new,
    );

enum CourseEditorActivity { idle, loading, saving, loadingImpact, activating }

enum CourseEditorPromptError { empty, tooLong, placeholder, unchanged }

const _unset = Object();

final class CourseEditorConflict {
  const CourseEditorConflict({
    required this.originalPrompt,
    required this.editedPrompt,
    required this.latestDocument,
    required this.recoveredAfterRestart,
  });

  final String originalPrompt;
  final String editedPrompt;
  final LocalCourseEditorDocument latestDocument;
  final bool recoveredAfterRestart;
}

final class CourseEditorState {
  const CourseEditorState({
    this.activity = CourseEditorActivity.idle,
    this.document,
    this.editedPrompt = '',
    this.recoveryRestored = false,
    this.conflict,
    this.draft,
    this.impact,
    this.impactAcknowledged = false,
    this.activation,
    this.error,
    this.recoveryError,
  });

  final CourseEditorActivity activity;
  final LocalCourseEditorDocument? document;
  final String editedPrompt;
  final bool recoveryRestored;
  final CourseEditorConflict? conflict;
  final LocalCourseEditorDraftResult? draft;
  final CourseReleaseImpact? impact;
  final bool impactAcknowledged;
  final CourseReleaseActivation? activation;
  final Object? error;
  final Object? recoveryError;

  bool get busy => activity != CourseEditorActivity.idle;
  bool get dirty =>
      document != null &&
      editedPrompt != document!.prompt &&
      draft == null &&
      activation == null;

  CourseEditorPromptError? get promptError {
    if (editedPrompt.trim().isEmpty) return CourseEditorPromptError.empty;
    if (editedPrompt.length > 1000) return CourseEditorPromptError.tooLong;
    if (RegExp('---').allMatches(editedPrompt).length != 1) {
      return CourseEditorPromptError.placeholder;
    }
    if (editedPrompt == document?.prompt) {
      return CourseEditorPromptError.unchanged;
    }
    return null;
  }

  bool get canSave =>
      !busy && conflict == null && draft == null && promptError == null;

  CourseEditorState copyWith({
    CourseEditorActivity? activity,
    Object? document = _unset,
    String? editedPrompt,
    bool? recoveryRestored,
    Object? conflict = _unset,
    Object? draft = _unset,
    Object? impact = _unset,
    bool? impactAcknowledged,
    Object? activation = _unset,
    Object? error = _unset,
    Object? recoveryError = _unset,
  }) => CourseEditorState(
    activity: activity ?? this.activity,
    document: document == _unset
        ? this.document
        : document as LocalCourseEditorDocument?,
    editedPrompt: editedPrompt ?? this.editedPrompt,
    recoveryRestored: recoveryRestored ?? this.recoveryRestored,
    conflict: conflict == _unset
        ? this.conflict
        : conflict as CourseEditorConflict?,
    draft: draft == _unset
        ? this.draft
        : draft as LocalCourseEditorDraftResult?,
    impact: impact == _unset ? this.impact : impact as CourseReleaseImpact?,
    impactAcknowledged: impactAcknowledged ?? this.impactAcknowledged,
    activation: activation == _unset
        ? this.activation
        : activation as CourseReleaseActivation?,
    error: error == _unset ? this.error : error,
    recoveryError: recoveryError == _unset ? this.recoveryError : recoveryError,
  );
}

final class CourseEditorController extends Notifier<CourseEditorState> {
  Future<void> _storageTail = Future.value();
  String? _draftCommandId;
  String? _activationCommandId;

  @override
  CourseEditorState build() => const CourseEditorState();

  Future<void> open(String courseId) async {
    _requireLocalTools();
    if (state.busy) return;
    _draftCommandId = null;
    _activationCommandId = null;
    state = const CourseEditorState(activity: CourseEditorActivity.loading);
    try {
      final repository = ref.read(courseAuthoringRepositoryProvider);
      final document = await repository.getEditor(courseId);
      final recovery = await ref.read(courseEditorRecoveryStoreProvider).read();
      if (recovery == null) {
        state = CourseEditorState(
          document: document,
          editedPrompt: document.prompt,
        );
        return;
      }
      if (recovery.courseId != document.courseId) {
        state = CourseEditorState(
          document: document,
          editedPrompt: document.prompt,
          error: const ConflictFailure(
            code: 'course-editor-recovery-belongs-to-another-course',
          ),
        );
        return;
      }
      final current =
          recovery.baseReleaseId == document.activeReleaseId &&
          recovery.questionRevisionId == document.questionRevisionId &&
          recovery.entityTag == document.entityTag &&
          recovery.originalPrompt == document.prompt;
      if (current) {
        state = CourseEditorState(
          document: document,
          editedPrompt: recovery.editedPrompt,
          recoveryRestored: true,
        );
      } else {
        state = CourseEditorState(
          document: document,
          editedPrompt: recovery.editedPrompt,
          conflict: CourseEditorConflict(
            originalPrompt: recovery.originalPrompt,
            editedPrompt: recovery.editedPrompt,
            latestDocument: document,
            recoveredAfterRestart: true,
          ),
        );
      }
    } on Object catch (error) {
      state = CourseEditorState(error: error);
    }
  }

  void updatePrompt(String value) {
    final document = state.document;
    if (document == null || state.draft != null || state.activation != null) {
      return;
    }
    state = state.copyWith(
      editedPrompt: value,
      recoveryRestored: false,
      error: null,
      recoveryError: null,
    );
    if (value == document.prompt || value.isEmpty || value.length > 1000) {
      _queueStorage(() => ref.read(courseEditorRecoveryStoreProvider).clear());
      return;
    }
    final recovery = LocalCourseEditorRecoveryDraft(
      courseId: document.courseId,
      baseReleaseId: document.activeReleaseId,
      questionRevisionId: document.questionRevisionId,
      entityTag: document.entityTag,
      originalPrompt: document.prompt,
      editedPrompt: value,
      updatedAt: DateTime.now().toUtc(),
    );
    _queueStorage(
      () => ref.read(courseEditorRecoveryStoreProvider).write(recovery),
    );
  }

  Future<void> save() async {
    if (!state.canSave) return;
    final document = state.document!;
    final editedPrompt = state.editedPrompt;
    _draftCommandId ??= ref.read(identifierFactoryProvider).create();
    state = state.copyWith(activity: CourseEditorActivity.saving, error: null);
    try {
      await _storageTail;
      final repository = ref.read(courseAuthoringRepositoryProvider);
      final draft = await repository.createEditorDraft(
        document: document,
        editedPrompt: editedPrompt,
        commandId: _draftCommandId!,
      );
      await ref.read(courseEditorRecoveryStoreProvider).clear();
      state = state.copyWith(
        activity: CourseEditorActivity.loadingImpact,
        draft: draft,
        conflict: null,
        recoveryRestored: false,
        recoveryError: null,
      );
      final impact = await repository.getReleaseImpact(
        courseId: draft.courseId,
        releaseId: draft.draftReleaseId,
      );
      state = state.copyWith(
        activity: CourseEditorActivity.idle,
        impact: impact,
      );
    } on ConflictFailure catch (error) {
      await _reloadConflict(document, editedPrompt, error);
    } on Object catch (error) {
      state = state.copyWith(activity: CourseEditorActivity.idle, error: error);
    }
  }

  void acknowledgeImpact(bool? value) {
    if (state.impact != null && !state.busy) {
      state = state.copyWith(impactAcknowledged: value ?? false);
    }
  }

  Future<void> activate() async {
    final impact = state.impact;
    if (state.busy || impact == null || !state.impactAcknowledged) return;
    _activationCommandId ??= ref.read(identifierFactoryProvider).create();
    state = state.copyWith(
      activity: CourseEditorActivity.activating,
      error: null,
    );
    try {
      final activation = await ref
          .read(courseAuthoringRepositoryProvider)
          .activateRelease(impact: impact, commandId: _activationCommandId!);
      await ref.read(courseEditorRecoveryStoreProvider).clear();
      state = state.copyWith(
        activity: CourseEditorActivity.idle,
        activation: activation,
      );
    } on Object catch (error) {
      state = state.copyWith(activity: CourseEditorActivity.idle, error: error);
    }
  }

  Future<void> reapplyMine() async {
    final conflict = state.conflict;
    if (conflict == null || state.busy) return;
    _draftCommandId = null;
    state = CourseEditorState(
      document: conflict.latestDocument,
      editedPrompt: conflict.editedPrompt,
    );
    updatePrompt(conflict.editedPrompt);
  }

  Future<void> useLatest() async {
    final conflict = state.conflict;
    if (conflict == null || state.busy) return;
    await ref.read(courseEditorRecoveryStoreProvider).clear();
    _draftCommandId = null;
    state = CourseEditorState(
      document: conflict.latestDocument,
      editedPrompt: conflict.latestDocument.prompt,
    );
  }

  Future<void> discardRecoveryForAnotherCourse() async {
    if (state.document == null || state.busy) return;
    await ref.read(courseEditorRecoveryStoreProvider).clear();
    state = CourseEditorState(
      document: state.document,
      editedPrompt: state.document!.prompt,
    );
  }

  Future<void> discard() async {
    if (state.busy) return;
    await ref.read(courseEditorRecoveryStoreProvider).clear();
    _draftCommandId = null;
    _activationCommandId = null;
    state = const CourseEditorState();
  }

  void closeKeepingRecovery() {
    if (state.busy) return;
    _draftCommandId = null;
    _activationCommandId = null;
    state = const CourseEditorState();
  }

  Future<void> retry() async {
    final document = state.document;
    if (state.busy) return;
    if (state.draft != null && state.impact == null) {
      state = state.copyWith(
        activity: CourseEditorActivity.loadingImpact,
        error: null,
      );
      try {
        final draft = state.draft!;
        final impact = await ref
            .read(courseAuthoringRepositoryProvider)
            .getReleaseImpact(
              courseId: draft.courseId,
              releaseId: draft.draftReleaseId,
            );
        state = state.copyWith(
          activity: CourseEditorActivity.idle,
          impact: impact,
        );
      } on Object catch (error) {
        state = state.copyWith(
          activity: CourseEditorActivity.idle,
          error: error,
        );
      }
    } else if (document != null) {
      await save();
    }
  }

  Future<void> _reloadConflict(
    LocalCourseEditorDocument previous,
    String editedPrompt,
    ConflictFailure failure,
  ) async {
    try {
      final latest = await ref
          .read(courseAuthoringRepositoryProvider)
          .getEditor(previous.courseId);
      state = CourseEditorState(
        document: latest,
        editedPrompt: editedPrompt,
        conflict: CourseEditorConflict(
          originalPrompt: previous.prompt,
          editedPrompt: editedPrompt,
          latestDocument: latest,
          recoveredAfterRestart: false,
        ),
        error: failure,
      );
    } on Object catch (error) {
      state = state.copyWith(activity: CourseEditorActivity.idle, error: error);
    }
  }

  void _queueStorage(Future<void> Function() action) {
    _storageTail = _storageTail
        .catchError((Object _) {})
        .then((_) => action())
        .catchError((Object error) {
          if (ref.mounted) {
            state = state.copyWith(recoveryError: error);
          }
        });
  }

  void _requireLocalTools() {
    if (!ref.read(appConfigProvider).localDevelopmentToolsEnabled) {
      throw StateError('Course editing is disabled outside local tools');
    }
  }
}
