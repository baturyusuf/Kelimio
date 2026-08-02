import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/course_authoring_controller.dart';
import '../../domain/course_authoring/course_authoring.dart';
import '../../domain/failures.dart';
import '../widgets/localization.dart';

final class TeacherImportScreen extends ConsumerWidget {
  const TeacherImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(courseAuthoringControllerProvider);
    final controller = ref.read(courseAuthoringControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.teacher)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.l10n.teacherImportTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(context.l10n.teacherImportBody),
          const SizedBox(height: 16),
          if (state.error != null) ...[
            _ErrorCard(
              error: state.error!,
              onRetry: () => unawaited(controller.retry()),
            ),
            const SizedBox(height: 12),
          ],
          if (state.activity != CourseAuthoringActivity.idle) ...[
            _ActivityCard(state: state),
            const SizedBox(height: 12),
          ],
          if (state.importSummary == null && state.activation == null) ...[
            FilledButton.icon(
              key: const Key('teacher-select-workbook'),
              onPressed: state.busy
                  ? null
                  : () => unawaited(controller.selectAndUpload()),
              icon: const Icon(Icons.upload_file),
              label: Text(context.l10n.selectWorkbook),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('teacher-discover-imports'),
              onPressed: state.busy
                  ? null
                  : () => unawaited(controller.discoverImports()),
              icon: const Icon(Icons.history),
              label: Text(context.l10n.findPreviousImports),
            ),
            if (state.discoveryLoaded) ...[
              const SizedBox(height: 16),
              Text(
                context.l10n.previousImportsHeading,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (state.discoveredImports.isEmpty)
                _MessageCard(
                  icon: Icons.inbox_outlined,
                  message: context.l10n.noPreviousImports,
                )
              else
                ...state.discoveredImports.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DiscoveredImportCard(
                      summary: item,
                      busy: state.busy,
                      onResume: () => unawaited(controller.resumeImport(item)),
                    ),
                  ),
                ),
              if (state.discoveryNextCursor != null)
                OutlinedButton.icon(
                  key: const Key('teacher-imports-load-more'),
                  onPressed: state.busy
                      ? null
                      : () => unawaited(controller.loadMoreDiscoveredImports()),
                  icon: const Icon(Icons.expand_more),
                  label: Text(context.l10n.loadMoreImports),
                ),
            ],
          ],
          if (state.importSummary case final summary?) ...[
            _ImportHeader(summary: summary),
            const SizedBox(height: 12),
            if (_rejected(summary.status)) ...[
              _MessageCard(
                icon: Icons.gpp_bad_outlined,
                message: context.l10n.workbookRejected,
              ),
              const SizedBox(height: 12),
            ] else if (summary.status == CourseImportStatus.expired) ...[
              _MessageCard(
                icon: Icons.timer_off_outlined,
                message: context.l10n.workbookExpired,
              ),
              const SizedBox(height: 12),
            ] else if (summary.status == CourseImportStatus.uploading) ...[
              _MessageCard(
                icon: Icons.upload_file_outlined,
                message: context.l10n.workbookUploadIncomplete,
              ),
              const SizedBox(height: 12),
            ],
            if (_rejected(summary.status) ||
                summary.status == CourseImportStatus.expired ||
                summary.status == CourseImportStatus.uploading) ...[
              OutlinedButton.icon(
                key: const Key('teacher-rejected-new-import'),
                onPressed: state.busy ? null : controller.reset,
                icon: const Icon(Icons.add),
                label: Text(context.l10n.newImport),
              ),
              const SizedBox(height: 12),
            ],
            if (summary.preview case final preview?) ...[
              _PreviewSummaryCard(preview: preview),
              const SizedBox(height: 12),
            ],
            if (state.issues.isNotEmpty) ...[
              _IssuesCard(
                issues: state.issues,
                hasMore: state.issueNextCursor != null,
                busy: state.busy,
                onLoadMore: () => unawaited(controller.loadMoreIssues()),
              ),
              const SizedBox(height: 12),
            ],
            if (state.previewRows.isNotEmpty) ...[
              Text(
                context.l10n.previewHeading,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...state.previewRows.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PreviewRowCard(row: row),
                ),
              ),
              if (state.previewNextCursor != null)
                OutlinedButton.icon(
                  key: const Key('teacher-preview-load-more'),
                  onPressed: state.busy
                      ? null
                      : () => unawaited(controller.loadMorePreview()),
                  icon: const Icon(Icons.expand_more),
                  label: Text(context.l10n.loadMore),
                ),
              const SizedBox(height: 12),
            ],
            if (summary.status == CourseImportStatus.previewReady &&
                summary.preview?.valid == true)
              _PreviewApprovalCard(
                checked: state.previewAcknowledged,
                busy: state.busy,
                onChanged: controller.acknowledgePreview,
                onApprove: () => unawaited(controller.approve()),
              ),
            if (summary.status == CourseImportStatus.approved &&
                state.commit == null)
              _DraftCreationCard(
                checked: state.draftAcknowledged,
                busy: state.busy,
                onChanged: controller.acknowledgeDraftCreation,
                onCommit: () => unawaited(controller.commitDraft()),
              ),
          ],
          if (state.impact case final impact?) ...[
            const SizedBox(height: 12),
            _ReleaseImpactCard(
              impact: impact,
              checked: state.impactAcknowledged,
              busy: state.busy,
              onChanged: controller.acknowledgeImpact,
              onActivate: () => unawaited(controller.activateRelease()),
              onRefresh: () => unawaited(controller.reloadImpact()),
            ),
          ],
          if (state.activation != null ||
              state.importSummary?.activation != null) ...[
            const SizedBox(height: 12),
            _MessageCard(
              key: const Key('teacher-publication-success'),
              icon: Icons.check_circle_outline,
              message: context.l10n.coursePublished,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('teacher-new-import'),
              onPressed: state.busy ? null : controller.reset,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.newImport),
            ),
          ],
        ],
      ),
    );
  }

  static bool _rejected(CourseImportStatus status) =>
      status == CourseImportStatus.validationFailed ||
      status == CourseImportStatus.malwareRejected ||
      status == CourseImportStatus.processingFailed;
}

final class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.state});

  final CourseAuthoringState state;

  @override
  Widget build(BuildContext context) {
    final label = switch (state.activity) {
      CourseAuthoringActivity.discovering =>
        context.l10n.findingPreviousImports,
      CourseAuthoringActivity.preparing => context.l10n.preparingWorkbook,
      CourseAuthoringActivity.uploading => context.l10n.uploadingWorkbook,
      CourseAuthoringActivity.processing => context.l10n.processingWorkbook,
      CourseAuthoringActivity.loadingPreview ||
      CourseAuthoringActivity.loadingImpact => context.l10n.loading,
      CourseAuthoringActivity.approving ||
      CourseAuthoringActivity.committing ||
      CourseAuthoringActivity.activating => context.l10n.loading,
      CourseAuthoringActivity.idle => '',
    };
    return Semantics(
      liveRegion: true,
      label: label,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label),
              const SizedBox(height: 10),
              if (state.activity == CourseAuthoringActivity.uploading)
                LinearProgressIndicator(value: state.uploadProgress)
              else
                const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

final class _DiscoveredImportCard extends StatelessWidget {
  const _DiscoveredImportCard({
    required this.summary,
    required this.busy,
    required this.onResume,
  });

  final CourseImportSummary summary;
  final bool busy;
  final VoidCallback onResume;

  bool get resumable =>
      summary.status != CourseImportStatus.uploading &&
      summary.status != CourseImportStatus.expired &&
      summary.activation == null;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('teacher-discovered-import-${summary.id}'),
    child: ListTile(
      leading: Icon(summary.activation == null ? Icons.history : Icons.check),
      title: Text(summary.preview?.courseName ?? summary.fileName),
      subtitle: Text(_statusLabel(context, summary)),
      trailing: TextButton(
        key: Key('teacher-resume-import-${summary.id}'),
        onPressed: busy || !resumable ? null : onResume,
        child: Text(context.l10n.resumeImport),
      ),
    ),
  );

  static String _statusLabel(
    BuildContext context,
    CourseImportSummary summary,
  ) {
    if (summary.activation != null) return context.l10n.importAlreadyPublished;
    return switch (summary.status) {
      CourseImportStatus.uploading => context.l10n.importUploadIncomplete,
      CourseImportStatus.queued ||
      CourseImportStatus.processing => context.l10n.importProcessing,
      CourseImportStatus.previewReady => context.l10n.importReadyForReview,
      CourseImportStatus.validationFailed =>
        context.l10n.importValidationFailed,
      CourseImportStatus.malwareRejected ||
      CourseImportStatus.processingFailed => context.l10n.importRejected,
      CourseImportStatus.expired => context.l10n.importExpired,
      CourseImportStatus.approved => context.l10n.importApproved,
      CourseImportStatus.committed => context.l10n.importReadyToPublish,
    };
  }
}

final class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = switch (error) {
      NetworkFailure() || TimeoutFailure() => context.l10n.networkError,
      _ => context.l10n.genericError,
    };
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ImportHeader extends StatelessWidget {
  const _ImportHeader({required this.summary});

  final CourseImportSummary summary;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.description_outlined),
      title: Text(summary.preview?.courseName ?? context.l10n.previewHeading),
      subtitle: Text(
        context.l10n.fileDetails(summary.fileName, summary.fileSizeBytes),
      ),
    ),
  );
}

final class _PreviewSummaryCard extends StatelessWidget {
  const _PreviewSummaryCard({required this.preview});

  final CourseImportPreviewSummary preview;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.previewHeading,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.previewSummary(
              preview.sourceRowCount,
              preview.questionCount ?? 0,
              preview.matchingQuestionCount ?? 0,
            ),
          ),
          if (preview.supportLanguages.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(preview.supportLanguages.join(' · ')),
          ],
        ],
      ),
    ),
  );
}

final class _IssuesCard extends StatelessWidget {
  const _IssuesCard({
    required this.issues,
    required this.hasMore,
    required this.busy,
    required this.onLoadMore,
  });

  final List<CourseImportIssue> issues;
  final bool hasMore;
  final bool busy;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.issuesHeading,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...issues.map(
            (issue) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                issue.severity == 'ERROR'
                    ? Icons.error_outline
                    : Icons.warning_amber_outlined,
              ),
              title: Text(issue.code),
              subtitle: Text(issue.message),
            ),
          ),
          if (hasMore)
            TextButton(
              onPressed: busy ? null : onLoadMore,
              child: Text(context.l10n.loadMore),
            ),
        ],
      ),
    ),
  );
}

final class _PreviewRowCard extends StatelessWidget {
  const _PreviewRowCard({required this.row});

  final CourseImportPreviewRow row;

  @override
  Widget build(BuildContext context) {
    final type = row.questionType ?? row.recordType;
    return Semantics(
      label: context.l10n.previewRowLabel(row.ordinal, row.testNumber, type),
      child: Card(
        child: ExpansionTile(
          title: Text(
            row.targetText,
            textDirection: _firstStrongDirection(
              row.targetText,
              Directionality.of(context),
            ),
          ),
          subtitle: Text(
            '${row.level} · ${row.unit} · ${row.topic} · ${context.l10n.questionType(type)}',
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...row.translations.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  textDirection: _firstStrongDirection(
                    entry.value,
                    Directionality.of(context),
                  ),
                ),
              ),
            ),
            if (row.sentence case final sentence?) ...[
              const SizedBox(height: 8),
              Text(sentence),
            ],
            if (row.correctAnswer case final answer?) ...[
              const SizedBox(height: 8),
              Text(context.l10n.correctAnswerTeacher(answer)),
            ],
            if (row.alternativeCorrectAnswer case final answer?) ...[
              const SizedBox(height: 8),
              Text(context.l10n.alternativeCorrectAnswerTeacher(answer)),
            ],
            if (row.wrongAnswers.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.wrongAnswersTeacher(row.wrongAnswers.join(' · ')),
              ),
            ],
            if (row.matchingGroup case final group?) ...[
              const SizedBox(height: 8),
              Text(context.l10n.matchingGroupTeacher(group)),
            ],
            if (row.note case final note?) ...[
              const SizedBox(height: 8),
              Text(note),
            ],
          ],
        ),
      ),
    );
  }
}

final class _PreviewApprovalCard extends StatelessWidget {
  const _PreviewApprovalCard({
    required this.checked,
    required this.busy,
    required this.onChanged,
    required this.onApprove,
  });

  final bool checked;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) => _ConfirmationCard(
    checkboxKey: const Key('teacher-preview-confirmation'),
    buttonKey: const Key('teacher-approve-preview'),
    checked: checked,
    busy: busy,
    confirmation: context.l10n.previewApprovalConfirmation,
    action: context.l10n.approvePreview,
    onChanged: onChanged,
    onPressed: onApprove,
  );
}

final class _DraftCreationCard extends StatelessWidget {
  const _DraftCreationCard({
    required this.checked,
    required this.busy,
    required this.onChanged,
    required this.onCommit,
  });

  final bool checked;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _MessageCard(
        icon: Icons.edit_note_outlined,
        message: context.l10n.draftCreationNotice,
      ),
      _ConfirmationCard(
        checkboxKey: const Key('teacher-draft-confirmation'),
        buttonKey: const Key('teacher-create-draft'),
        checked: checked,
        busy: busy,
        confirmation: context.l10n.draftCreationConfirmation,
        action: context.l10n.createDraft,
        onChanged: onChanged,
        onPressed: onCommit,
      ),
    ],
  );
}

final class _ReleaseImpactCard extends StatelessWidget {
  const _ReleaseImpactCard({
    required this.impact,
    required this.checked,
    required this.busy,
    required this.onChanged,
    required this.onActivate,
    required this.onRefresh,
  });

  final CourseReleaseImpact impact;
  final bool checked;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final VoidCallback onActivate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.releaseImpactHeading,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: context.l10n.refresh,
                onPressed: busy ? null : onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.releaseImpactSummary(
              impact.targetQuestionCount,
              impact.addedQuestionCount,
              impact.changedQuestionCount,
              impact.removedQuestionCount,
              impact.affectedEnrollmentCount,
            ),
          ),
          CheckboxListTile(
            key: const Key('teacher-impact-confirmation'),
            contentPadding: EdgeInsets.zero,
            value: checked,
            onChanged: busy ? null : (value) => onChanged(value ?? false),
            title: Text(context.l10n.releaseImpactConfirmation),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          FilledButton.icon(
            key: const Key('teacher-publish-course'),
            onPressed: busy || !checked ? null : onActivate,
            icon: const Icon(Icons.publish),
            label: Text(context.l10n.publishCourse),
          ),
        ],
      ),
    ),
  );
}

final class _ConfirmationCard extends StatelessWidget {
  const _ConfirmationCard({
    required this.checkboxKey,
    required this.buttonKey,
    required this.checked,
    required this.busy,
    required this.confirmation,
    required this.action,
    required this.onChanged,
    required this.onPressed,
  });

  final Key checkboxKey;
  final Key buttonKey;
  final bool checked;
  final bool busy;
  final String confirmation;
  final String action;
  final ValueChanged<bool> onChanged;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CheckboxListTile(
            key: checkboxKey,
            contentPadding: EdgeInsets.zero,
            value: checked,
            onChanged: busy ? null : (value) => onChanged(value ?? false),
            title: Text(confirmation),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          FilledButton(
            key: buttonKey,
            onPressed: busy || !checked ? null : onPressed,
            child: Text(action),
          ),
        ],
      ),
    ),
  );
}

final class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.message, super.key});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

TextDirection _firstStrongDirection(String text, TextDirection fallback) =>
    RegExp(r'[\u0590-\u08FF]').hasMatch(text)
    ? TextDirection.rtl
    : RegExp(r'[A-Za-z\u00C0-\u024F]').hasMatch(text)
    ? TextDirection.ltr
    : fallback;
