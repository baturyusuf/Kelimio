import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_controller.dart';
import '../../application/providers.dart';
import '../../application/social_controller.dart';
import '../../domain/account/account.dart';
import '../../domain/social/social.dart';
import '../widgets/async_error_view.dart';
import '../widgets/localization.dart';

final class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(ownPublicProfileProvider);
    final leaderboard = ref.watch(leaderboardProvider);
    final learning = ref.watch(learningSummaryProvider);
    final notifications = ref.watch(notificationPreferencesProvider);
    final deletionRequests = ref.watch(accountDeletionRequestsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.accountProfileTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.signOut,
            onPressed: () =>
                unawaited(ref.read(authControllerProvider.notifier).signOut()),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          profile.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => AsyncErrorView(
              error: error,
              onRetry: () => ref.invalidate(ownPublicProfileProvider),
            ),
            data: (value) => _ProfileEditor(profile: value),
          ),
          const SizedBox(height: 16),
          learning.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => AsyncErrorView(
              error: error,
              onRetry: () => ref.invalidate(learningSummaryProvider),
            ),
            data: (value) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.accountLearningSummary,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.accountScoreAndStreak(
                        value.currentStreakDays,
                        value.lifetimeScore,
                      ),
                    ),
                    Text(
                      context.l10n.accountTestAndCourseSummary(
                        value.completedAttempts,
                        value.completedCourses,
                        value.enrolledCourses,
                        value.passedAttempts,
                      ),
                    ),
                    const Divider(),
                    for (final item in value.history.take(10))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          item.passed
                              ? Icons.check_circle_outline
                              : Icons.replay_outlined,
                        ),
                        title: Text('${item.courseName} · ${item.testTitle}'),
                        subtitle: Text(
                          context.l10n.accountCorrectAnswers(
                            item.correctCount,
                            item.totalQuestions,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          notifications.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => AsyncErrorView(
              error: error,
              onRetry: () => ref.invalidate(notificationPreferencesProvider),
            ),
            data: (value) => _NotificationEditor(preferences: value),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.accountData,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(_export(context, ref)),
                    icon: const Icon(Icons.download_outlined),
                    label: Text(context.l10n.accountExportJson),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(_revokeSessions(context, ref)),
                    icon: const Icon(Icons.phonelink_erase_outlined),
                    label: Text(context.l10n.accountRevokeAllSessions),
                  ),
                  TextButton.icon(
                    onPressed:
                        deletionRequests.value?.any(
                              (request) => request.status == 'PENDING',
                            ) ==
                            true
                        ? null
                        : () => unawaited(_delete(context, ref)),
                    icon: const Icon(Icons.delete_forever_outlined),
                    label: Text(context.l10n.accountRequestDeletion),
                  ),
                  Text(context.l10n.accountDeletionRecovery),
                  deletionRequests.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stackTrace) =>
                        Text(context.l10n.accountDeletionReadFailed('$error')),
                    data: (requests) {
                      final pending = requests
                          .where((request) => request.status == 'PENDING')
                          .firstOrNull;
                      if (pending == null) return const SizedBox.shrink();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(context.l10n.accountPendingDeletion),
                        subtitle: Text(
                          context.l10n.accountDeletionCancelableUntil(
                            pending.scheduledFor.toLocal(),
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () => unawaited(
                            _cancelDeletion(context, ref, pending.id),
                          ),
                          child: Text(context.l10n.accountCancelDeletion),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.accountLeaderboard,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(context.l10n.accountLeaderboardPrivacy),
          const SizedBox(height: 8),
          leaderboard.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => AsyncErrorView(
              error: error,
              onRetry: () => ref.invalidate(leaderboardProvider),
            ),
            data: (entries) => entries.isEmpty
                ? ListTile(title: Text(context.l10n.accountNoParticipants))
                : Column(
                    children: entries
                        .map(
                          (entry) => ListTile(
                            leading: CircleAvatar(child: Text('${entry.rank}')),
                            title: Text(entry.displayName),
                            subtitle: Text(
                              context.l10n.accountCompletedTests(
                                entry.completedAttempts,
                                entry.username,
                              ),
                            ),
                            trailing: Text(
                              context.l10n.accountPoints(entry.lifetimeScore),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final data = await ref.read(accountRepositoryProvider).export();
      final location = await getSaveLocation(
        suggestedName: 'kelimio-hesap-verileri.json',
      );
      if (location == null) {
        return;
      }
      await XFile.fromData(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
        mimeType: 'application/json',
        name: 'kelimio-hesap-verileri.json',
      ).saveTo(location.path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.accountExportSaved)),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.accountExportFailed('$error'))),
        );
      }
    }
  }

  Future<void> _cancelDeletion(
    BuildContext context,
    WidgetRef ref,
    String requestId,
  ) async {
    try {
      await ref
          .read(accountRepositoryProvider)
          .cancelDeletion(
            requestId: requestId,
            commandId: ref.read(identifierFactoryProvider).create(),
          );
      ref.invalidate(accountDeletionRequestsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.accountDeletionCancelled)),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.accountDeletionCancelFailed('$error')),
          ),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.accountDeletionDialogTitle),
        content: Text(context.l10n.accountDeletionDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.accountCreateRequest),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      final result = await ref
          .read(accountRepositoryProvider)
          .requestDeletion(ref.read(identifierFactoryProvider).create());
      ref.invalidate(accountDeletionRequestsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.accountDeletionScheduled(
                result.scheduledFor.toLocal(),
              ),
            ),
          ),
        );
      }
      await ref.read(authControllerProvider.notifier).signOut();
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.accountDeletionRequestFailed('$error')),
          ),
        );
      }
    }
  }

  Future<void> _revokeSessions(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.accountRevokeDialogTitle),
        content: Text(context.l10n.accountRevokeDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.accountRevokeConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(accountRepositoryProvider).revokeAllSessions();
      await ref.read(authControllerProvider.notifier).signOut();
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.accountRevokeFailed('$error'))),
        );
      }
    }
  }
}

final class _NotificationEditor extends ConsumerStatefulWidget {
  const _NotificationEditor({required this.preferences});
  final NotificationPreferences preferences;
  @override
  ConsumerState<_NotificationEditor> createState() =>
      _NotificationEditorState();
}

final class _NotificationEditorState
    extends ConsumerState<_NotificationEditor> {
  late NotificationPreferences value = widget.preferences;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.accountNotifications,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: value.learningReminders,
            title: Text(context.l10n.accountLearningReminders),
            onChanged: (enabled) => _replace(learning: enabled),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: value.courseUpdates,
            title: Text(context.l10n.accountCourseUpdates),
            onChanged: (enabled) => _replace(course: enabled),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: value.productAnnouncements,
            title: Text(context.l10n.accountProductAnnouncements),
            onChanged: (enabled) => _replace(product: enabled),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: value.pushEnabled,
            title: Text(context.l10n.accountPushNotification),
            subtitle: Text(
              value.pushAvailable
                  ? context.l10n.accountAvailable
                  : context.l10n.accountPushUnavailable,
            ),
            onChanged: value.pushAvailable
                ? (enabled) => _replace(push: enabled)
                : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: value.emailEnabled,
            title: Text(context.l10n.accountEmailNotification),
            subtitle: Text(
              value.emailAvailable
                  ? context.l10n.accountAvailable
                  : context.l10n.accountEmailUnavailable,
            ),
            onChanged: value.emailAvailable
                ? (enabled) => _replace(email: enabled)
                : null,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bedtime_outlined),
            title: Text(context.l10n.accountQuietHours),
            subtitle: Text(
              value.quietHoursStart == null
                  ? context.l10n.accountDisabled
                  : '${value.quietHoursStart!.substring(0, 5)}–${value.quietHoursEnd!.substring(0, 5)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value.quietHoursStart != null)
                  IconButton(
                    tooltip: context.l10n.accountDisableQuietHours,
                    onPressed: () => setState(
                      () => value = NotificationPreferences(
                        learningReminders: value.learningReminders,
                        courseUpdates: value.courseUpdates,
                        productAnnouncements: value.productAnnouncements,
                        pushEnabled: value.pushEnabled,
                        emailEnabled: value.emailEnabled,
                        pushAvailable: value.pushAvailable,
                        emailAvailable: value.emailAvailable,
                        version: value.version,
                      ),
                    ),
                    icon: const Icon(Icons.clear),
                  ),
                IconButton(
                  tooltip: context.l10n.accountSetQuietHours,
                  onPressed: () => unawaited(_pickQuietHours()),
                  icon: const Icon(Icons.schedule),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => unawaited(_save()),
              child: Text(context.l10n.accountSaveNotifications),
            ),
          ),
        ],
      ),
    ),
  );

  void _replace({
    bool? learning,
    bool? course,
    bool? product,
    bool? push,
    bool? email,
  }) => setState(
    () => value = NotificationPreferences(
      learningReminders: learning ?? value.learningReminders,
      courseUpdates: course ?? value.courseUpdates,
      productAnnouncements: product ?? value.productAnnouncements,
      pushEnabled: push ?? value.pushEnabled,
      emailEnabled: email ?? value.emailEnabled,
      pushAvailable: value.pushAvailable,
      emailAvailable: value.emailAvailable,
      version: value.version,
      quietHoursStart: value.quietHoursStart,
      quietHoursEnd: value.quietHoursEnd,
    ),
  );
  Future<void> _save() async {
    try {
      value = await ref
          .read(accountRepositoryProvider)
          .updateNotifications(value);
      ref.invalidate(notificationPreferencesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.accountNotificationsSaved)),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.accountNotificationsSaveFailed('$error'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickQuietHours() async {
    final start = await showTimePicker(
      context: context,
      initialTime:
          _parseTime(value.quietHoursStart) ??
          const TimeOfDay(hour: 22, minute: 0),
      helpText: context.l10n.accountQuietHoursStart,
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime:
          _parseTime(value.quietHoursEnd) ??
          const TimeOfDay(hour: 8, minute: 0),
      helpText: context.l10n.accountQuietHoursEnd,
    );
    if (end == null || !mounted) return;
    setState(
      () => value = NotificationPreferences(
        learningReminders: value.learningReminders,
        courseUpdates: value.courseUpdates,
        productAnnouncements: value.productAnnouncements,
        pushEnabled: value.pushEnabled,
        emailEnabled: value.emailEnabled,
        pushAvailable: value.pushAvailable,
        emailAvailable: value.emailAvailable,
        quietHoursStart: _time(start),
        quietHoursEnd: _time(end),
        version: value.version,
      ),
    );
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _time(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';
}

final class _ProfileEditor extends ConsumerStatefulWidget {
  const _ProfileEditor({required this.profile});
  final OwnPublicProfile profile;
  @override
  ConsumerState<_ProfileEditor> createState() => _ProfileEditorState();
}

final class _ProfileEditorState extends ConsumerState<_ProfileEditor> {
  late final TextEditingController _username;
  late final TextEditingController _displayName;
  late final TextEditingController _bio;
  late bool _publicEnabled;
  late bool _leaderboardOptIn;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.profile.username);
    _displayName = TextEditingController(text: widget.profile.displayName);
    _bio = TextEditingController(text: widget.profile.bio);
    _publicEnabled = widget.profile.publicProfileEnabled;
    _leaderboardOptIn = widget.profile.leaderboardOptIn;
  }

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.accountMyAccount,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _displayName,
            decoration: InputDecoration(
              labelText: context.l10n.accountDisplayName,
            ),
          ),
          TextFormField(
            controller: _username,
            decoration: InputDecoration(
              labelText: context.l10n.accountUsername,
              prefixText: '@',
            ),
          ),
          TextFormField(
            controller: _bio,
            maxLength: 280,
            maxLines: 3,
            decoration: InputDecoration(labelText: context.l10n.accountBio),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _publicEnabled,
            title: Text(context.l10n.accountPublicProfile),
            subtitle: Text(context.l10n.accountPublicProfileDefault),
            onChanged: (value) => setState(() {
              _publicEnabled = value;
              if (!value) _leaderboardOptIn = false;
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _leaderboardOptIn,
            title: Text(context.l10n.accountJoinLeaderboard),
            onChanged: _publicEnabled
                ? (value) => setState(() => _leaderboardOptIn = value)
                : null,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.accountProfileStats(
                    widget.profile.lifetimeScore,
                    widget.profile.completedAttempts,
                  ),
                ),
              ),
              FilledButton(
                onPressed: () => unawaited(_save()),
                child: Text(context.l10n.accountSave),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Future<void> _save() async {
    final ok = await ref
        .read(ownPublicProfileProvider.notifier)
        .save(
          username: _username.text.trim().isEmpty
              ? null
              : _username.text.trim(),
          displayName: _displayName.text.trim(),
          bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
          publicProfileEnabled: _publicEnabled,
          leaderboardOptIn: _leaderboardOptIn,
        );
    if (mounted && ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.accountProfileSaved)));
    }
  }
}
