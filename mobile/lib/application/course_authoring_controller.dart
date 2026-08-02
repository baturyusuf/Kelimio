import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/course_authoring/course_authoring.dart';
import '../domain/failures.dart';
import 'providers.dart';

final courseAuthoringPollDelayProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 1),
);

final courseAuthoringControllerProvider =
    NotifierProvider<CourseAuthoringController, CourseAuthoringState>(
      CourseAuthoringController.new,
    );

enum CourseAuthoringActivity {
  idle,
  preparing,
  uploading,
  processing,
  loadingPreview,
  approving,
  committing,
  loadingImpact,
  activating,
}

const _unset = Object();

final class CourseAuthoringState {
  const CourseAuthoringState({
    this.activity = CourseAuthoringActivity.idle,
    this.uploadProgress = 0,
    this.importSummary,
    this.previewRows = const [],
    this.previewNextCursor,
    this.issues = const [],
    this.issueNextCursor,
    this.previewAcknowledged = false,
    this.draftAcknowledged = false,
    this.impactAcknowledged = false,
    this.commit,
    this.impact,
    this.activation,
    this.error,
  });

  final CourseAuthoringActivity activity;
  final double uploadProgress;
  final CourseImportSummary? importSummary;
  final List<CourseImportPreviewRow> previewRows;
  final String? previewNextCursor;
  final List<CourseImportIssue> issues;
  final String? issueNextCursor;
  final bool previewAcknowledged;
  final bool draftAcknowledged;
  final bool impactAcknowledged;
  final CourseImportCommit? commit;
  final CourseReleaseImpact? impact;
  final CourseReleaseActivation? activation;
  final Object? error;

  bool get busy => activity != CourseAuthoringActivity.idle;

  CourseAuthoringState copyWith({
    CourseAuthoringActivity? activity,
    double? uploadProgress,
    Object? importSummary = _unset,
    List<CourseImportPreviewRow>? previewRows,
    Object? previewNextCursor = _unset,
    List<CourseImportIssue>? issues,
    Object? issueNextCursor = _unset,
    bool? previewAcknowledged,
    bool? draftAcknowledged,
    bool? impactAcknowledged,
    Object? commit = _unset,
    Object? impact = _unset,
    Object? activation = _unset,
    Object? error = _unset,
  }) => CourseAuthoringState(
    activity: activity ?? this.activity,
    uploadProgress: uploadProgress ?? this.uploadProgress,
    importSummary: importSummary == _unset
        ? this.importSummary
        : importSummary as CourseImportSummary?,
    previewRows: previewRows ?? this.previewRows,
    previewNextCursor: previewNextCursor == _unset
        ? this.previewNextCursor
        : previewNextCursor as String?,
    issues: issues ?? this.issues,
    issueNextCursor: issueNextCursor == _unset
        ? this.issueNextCursor
        : issueNextCursor as String?,
    previewAcknowledged: previewAcknowledged ?? this.previewAcknowledged,
    draftAcknowledged: draftAcknowledged ?? this.draftAcknowledged,
    impactAcknowledged: impactAcknowledged ?? this.impactAcknowledged,
    commit: commit == _unset ? this.commit : commit as CourseImportCommit?,
    impact: impact == _unset ? this.impact : impact as CourseReleaseImpact?,
    activation: activation == _unset
        ? this.activation
        : activation as CourseReleaseActivation?,
    error: error == _unset ? this.error : error,
  );
}

final class CourseAuthoringController extends Notifier<CourseAuthoringState> {
  SelectedWorkbook? _selectedWorkbook;
  String? _createCommandId;
  String? _completeCommandId;
  String? _approvalCommandId;
  String? _commitCommandId;
  String? _activationCommandId;

  @override
  CourseAuthoringState build() => const CourseAuthoringState();

  Future<void> selectAndUpload() async {
    _requireLocalTools();
    if (state.busy) return;
    SelectedWorkbook? selected;
    try {
      selected = await ref.read(workbookPickerProvider).pickWorkbook();
    } on Object catch (error) {
      _fail(error);
      return;
    }
    if (selected == null) return;
    _selectedWorkbook = selected;
    _createCommandId = ref.read(identifierFactoryProvider).create();
    _completeCommandId = ref.read(identifierFactoryProvider).create();
    _approvalCommandId = null;
    _commitCommandId = null;
    _activationCommandId = null;
    state = const CourseAuthoringState(
      activity: CourseAuthoringActivity.preparing,
    );
    await _uploadSelected();
  }

  Future<void> retry() async {
    _requireLocalTools();
    if (state.busy) return;
    if (_selectedWorkbook != null &&
        _createCommandId != null &&
        _completeCommandId != null &&
        state.importSummary == null) {
      state = state.copyWith(
        activity: CourseAuthoringActivity.preparing,
        error: null,
      );
      await _uploadSelected();
      return;
    }
    final summary = state.importSummary;
    if (summary != null && summary.processing) {
      state = state.copyWith(
        activity: CourseAuthoringActivity.processing,
        error: null,
      );
      await _pollUntilReviewable(summary);
      return;
    }
    if (state.commit != null && state.impact == null) {
      await reloadImpact();
      return;
    }
    if (summary != null) {
      state = state.copyWith(
        activity: CourseAuthoringActivity.loadingPreview,
        error: null,
      );
      try {
        await _loadReviewData(summary);
      } on Object catch (error) {
        _fail(error);
      }
      return;
    }
    state = state.copyWith(error: null);
    await selectAndUpload();
  }

  Future<void> loadMorePreview() async {
    final summary = state.importSummary;
    final cursor = state.previewNextCursor;
    if (summary == null || cursor == null || state.busy) return;
    state = state.copyWith(
      activity: CourseAuthoringActivity.loadingPreview,
      error: null,
    );
    try {
      final page = await ref
          .read(courseAuthoringRepositoryProvider)
          .getPreview(importId: summary.id, cursor: cursor);
      state = state.copyWith(
        activity: CourseAuthoringActivity.idle,
        previewRows: List.unmodifiable([...state.previewRows, ...page.items]),
        previewNextCursor: page.nextCursor,
      );
    } on Object catch (error) {
      _fail(error);
    }
  }

  Future<void> loadMoreIssues() async {
    final summary = state.importSummary;
    final cursor = state.issueNextCursor;
    if (summary == null || cursor == null || state.busy) return;
    state = state.copyWith(
      activity: CourseAuthoringActivity.loadingPreview,
      error: null,
    );
    try {
      final page = await ref
          .read(courseAuthoringRepositoryProvider)
          .getIssues(importId: summary.id, cursor: cursor);
      state = state.copyWith(
        activity: CourseAuthoringActivity.idle,
        issues: List.unmodifiable([...state.issues, ...page.items]),
        issueNextCursor: page.nextCursor,
      );
    } on Object catch (error) {
      _fail(error);
    }
  }

  void acknowledgePreview(bool value) {
    if (!state.busy) {
      state = state.copyWith(previewAcknowledged: value, error: null);
    }
  }

  Future<void> approve() async {
    _requireLocalTools();
    final summary = state.importSummary;
    final binding = summary?.approvalBindingSha256;
    if (state.busy ||
        summary?.status != CourseImportStatus.previewReady ||
        summary?.preview?.valid != true ||
        binding == null ||
        !state.previewAcknowledged) {
      return;
    }
    _approvalCommandId ??= ref.read(identifierFactoryProvider).create();
    state = state.copyWith(
      activity: CourseAuthoringActivity.approving,
      error: null,
    );
    try {
      final approved = await ref
          .read(courseAuthoringRepositoryProvider)
          .approve(
            importId: summary!.id,
            approvalBindingSha256: binding,
            commandId: _approvalCommandId!,
          );
      _approvalCommandId = null;
      state = state.copyWith(
        activity: CourseAuthoringActivity.idle,
        importSummary: approved,
        draftAcknowledged: false,
      );
    } on Object catch (error) {
      _fail(error);
    }
  }

  void acknowledgeDraftCreation(bool value) {
    if (!state.busy) {
      state = state.copyWith(draftAcknowledged: value, error: null);
    }
  }

  Future<void> commitDraft() async {
    _requireLocalTools();
    final summary = state.importSummary;
    final binding = summary?.approvalBindingSha256;
    if (state.busy ||
        summary?.status != CourseImportStatus.approved ||
        binding == null ||
        !state.draftAcknowledged) {
      return;
    }
    _commitCommandId ??= ref.read(identifierFactoryProvider).create();
    state = state.copyWith(
      activity: CourseAuthoringActivity.committing,
      error: null,
    );
    try {
      final committed = await ref
          .read(courseAuthoringRepositoryProvider)
          .commit(
            importId: summary!.id,
            approvalBindingSha256: binding,
            commandId: _commitCommandId!,
          );
      _commitCommandId = null;
      state = state.copyWith(
        activity: CourseAuthoringActivity.loadingImpact,
        commit: committed,
      );
      final impact = await ref
          .read(courseAuthoringRepositoryProvider)
          .getReleaseImpact(
            courseId: committed.courseId,
            releaseId: committed.draftReleaseId,
          );
      state = state.copyWith(
        activity: CourseAuthoringActivity.idle,
        commit: committed,
        impact: impact,
        impactAcknowledged: false,
      );
    } on Object catch (error) {
      _fail(error);
    }
  }

  Future<void> reloadImpact() async {
    final committed = state.commit;
    if (committed == null || state.busy) return;
    state = state.copyWith(
      activity: CourseAuthoringActivity.loadingImpact,
      error: null,
    );
    try {
      final impact = await ref
          .read(courseAuthoringRepositoryProvider)
          .getReleaseImpact(
            courseId: committed.courseId,
            releaseId: committed.draftReleaseId,
          );
      _activationCommandId = null;
      state = state.copyWith(
        activity: CourseAuthoringActivity.idle,
        impact: impact,
        impactAcknowledged: false,
      );
    } on Object catch (error) {
      _fail(error);
    }
  }

  void acknowledgeImpact(bool value) {
    if (!state.busy) {
      state = state.copyWith(impactAcknowledged: value, error: null);
    }
  }

  Future<void> activateRelease() async {
    _requireLocalTools();
    final impact = state.impact;
    if (state.busy || impact == null || !state.impactAcknowledged) return;
    _activationCommandId ??= ref.read(identifierFactoryProvider).create();
    state = state.copyWith(
      activity: CourseAuthoringActivity.activating,
      error: null,
    );
    try {
      final activation = await ref
          .read(courseAuthoringRepositoryProvider)
          .activateRelease(impact: impact, commandId: _activationCommandId!);
      _activationCommandId = null;
      _selectedWorkbook = null;
      state = state.copyWith(
        activity: CourseAuthoringActivity.idle,
        activation: activation,
      );
    } on ConflictFailure catch (error) {
      _activationCommandId = null;
      state = state.copyWith(
        activity: CourseAuthoringActivity.idle,
        impactAcknowledged: false,
        error: error,
      );
    } on Object catch (error) {
      _fail(error);
    }
  }

  void reset() {
    if (state.busy) return;
    _selectedWorkbook = null;
    _createCommandId = null;
    _completeCommandId = null;
    _approvalCommandId = null;
    _commitCommandId = null;
    _activationCommandId = null;
    state = const CourseAuthoringState();
  }

  Future<void> _uploadSelected() async {
    final workbook = _selectedWorkbook!;
    try {
      final uploaded = await ref
          .read(courseAuthoringRepositoryProvider)
          .uploadWorkbook(
            workbook: workbook,
            createCommandId: _createCommandId!,
            completeCommandId: _completeCommandId!,
            onProgress: (sent, total) {
              state = state.copyWith(
                activity: CourseAuthoringActivity.uploading,
                uploadProgress: total == 0 ? 0 : sent / total,
              );
            },
          );
      state = state.copyWith(
        activity: uploaded.processing
            ? CourseAuthoringActivity.processing
            : CourseAuthoringActivity.idle,
        uploadProgress: 1,
        importSummary: uploaded,
      );
      if (uploaded.processing) {
        await _pollUntilReviewable(uploaded);
      } else {
        await _loadReviewData(uploaded);
      }
    } on Object catch (error) {
      _fail(error);
    }
  }

  Future<void> _pollUntilReviewable(CourseImportSummary initial) async {
    var current = initial;
    try {
      for (var attempt = 0; attempt < 360 && current.processing; attempt++) {
        await Future<void>.delayed(ref.read(courseAuthoringPollDelayProvider));
        current = await ref
            .read(courseAuthoringRepositoryProvider)
            .getImport(current.id);
        state = state.copyWith(importSummary: current);
      }
      if (current.processing) {
        throw const TimeoutFailure();
      }
      state = state.copyWith(
        activity: CourseAuthoringActivity.loadingPreview,
        importSummary: current,
      );
      await _loadReviewData(current);
    } on Object catch (error) {
      _fail(error);
    }
  }

  Future<void> _loadReviewData(CourseImportSummary summary) async {
    final repository = ref.read(courseAuthoringRepositoryProvider);
    if (summary.status == CourseImportStatus.previewReady ||
        summary.status == CourseImportStatus.approved ||
        summary.status == CourseImportStatus.committed) {
      final results = await Future.wait<Object>([
        repository.getPreview(importId: summary.id),
        repository.getIssues(importId: summary.id),
      ]);
      final preview = results[0] as CourseImportPreviewPage;
      final issues = results[1] as CourseImportIssuePage;
      state = state.copyWith(
        activity: CourseAuthoringActivity.idle,
        importSummary: summary,
        previewRows: preview.items,
        previewNextCursor: preview.nextCursor,
        issues: issues.items,
        issueNextCursor: issues.nextCursor,
      );
      return;
    }
    if (summary.status == CourseImportStatus.validationFailed ||
        summary.status == CourseImportStatus.processingFailed ||
        summary.status == CourseImportStatus.malwareRejected) {
      final issues = await repository.getIssues(importId: summary.id);
      state = state.copyWith(
        activity: CourseAuthoringActivity.idle,
        importSummary: summary,
        issues: issues.items,
        issueNextCursor: issues.nextCursor,
      );
      return;
    }
    state = state.copyWith(
      activity: CourseAuthoringActivity.idle,
      importSummary: summary,
    );
  }

  void _fail(Object error) {
    state = state.copyWith(
      activity: CourseAuthoringActivity.idle,
      error: error,
    );
  }

  void _requireLocalTools() {
    if (!ref.read(appConfigProvider).localDevelopmentToolsEnabled) {
      throw StateError('Course authoring is disabled outside local tools');
    }
  }
}
