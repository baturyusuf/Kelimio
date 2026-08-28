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
        title: const Text('Profil'),
        actions: [
          IconButton(
            tooltip: 'Çıkış yap',
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
                      'Öğrenme özeti',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${value.lifetimeScore} puan · ${value.currentStreakDays} günlük seri',
                    ),
                    Text(
                      '${value.passedAttempts}/${value.completedAttempts} başarılı test · ${value.completedCourses}/${value.enrolledCourses} aktif kurs',
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
                          '${item.correctCount}/${item.totalQuestions} doğru',
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
                    'Hesap verileri',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(_export(context, ref)),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Verilerimi JSON olarak dışa aktar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(_revokeSessions(context, ref)),
                    icon: const Icon(Icons.phonelink_erase_outlined),
                    label: const Text('Tüm cihazlardan çıkış yap'),
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
                    label: const Text('Hesabımı silme talebi oluştur'),
                  ),
                  const Text(
                    'Silme talebi, yanlışlıkla silmeye karşı 7 günlük kurtarma süresiyle kaydedilir.',
                  ),
                  deletionRequests.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stackTrace) =>
                        Text('Silme talepleri okunamadı: $error'),
                    data: (requests) {
                      final pending = requests
                          .where((request) => request.status == 'PENDING')
                          .firstOrNull;
                      if (pending == null) return const SizedBox.shrink();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Bekleyen silme talebi'),
                        subtitle: Text(
                          '${pending.scheduledFor.toLocal()} tarihine kadar iptal edilebilir.',
                        ),
                        trailing: TextButton(
                          onPressed: () => unawaited(
                            _cancelDeletion(context, ref, pending.id),
                          ),
                          child: const Text('İptal et'),
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
            'Liderlik tablosu',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Yalnızca açıkça katılmayı seçen herkese açık profiller gösterilir.',
          ),
          const SizedBox(height: 8),
          leaderboard.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) => AsyncErrorView(
              error: error,
              onRetry: () => ref.invalidate(leaderboardProvider),
            ),
            data: (entries) => entries.isEmpty
                ? const ListTile(title: Text('Henüz katılımcı yok.'))
                : Column(
                    children: entries
                        .map(
                          (entry) => ListTile(
                            leading: CircleAvatar(child: Text('${entry.rank}')),
                            title: Text(entry.displayName),
                            subtitle: Text(
                              '@${entry.username} · ${entry.completedAttempts} tamamlanan test',
                            ),
                            trailing: Text('${entry.lifetimeScore} puan'),
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
          const SnackBar(content: Text('Veri dışa aktarımı kaydedildi.')),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dışa aktarma kaydedilemedi: $error')),
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
          const SnackBar(content: Text('Hesap silme talebi iptal edildi.')),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Talep iptal edilemedi: $error')),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Silme talebi oluşturulsun mu?'),
        content: const Text(
          'Talep 7 gün sonra işlenmek üzere güvenli biçimde kaydedilir. Bu işlem puan ve öğrenme geçmişi saklama kurallarını değiştirmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Talep oluştur'),
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
              'Silme talebi ${result.scheduledFor.toLocal()} için kaydedildi.',
            ),
          ),
        );
      }
      await ref.read(authControllerProvider.notifier).signOut();
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Talep oluşturulamadı: $error')));
      }
    }
  }

  Future<void> _revokeSessions(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tüm oturumlar kapatılsın mı?'),
        content: const Text(
          'Bu cihaz dahil tüm cihazlardaki yenileme oturumları AWS Cognito üzerinde iptal edilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tümünden çıkış yap'),
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
          SnackBar(content: Text('Oturumlar kapatılamadı: $error')),
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
          Text('Bildirimler', style: Theme.of(context).textTheme.titleLarge),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: value.learningReminders,
            title: const Text('Öğrenme hatırlatmaları'),
            onChanged: (enabled) => _replace(learning: enabled),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: value.courseUpdates,
            title: const Text('Kurs güncellemeleri'),
            onChanged: (enabled) => _replace(course: enabled),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: value.productAnnouncements,
            title: const Text('Ürün duyuruları'),
            onChanged: (enabled) => _replace(product: enabled),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: value.pushEnabled,
            title: const Text('Anlık bildirim'),
            subtitle: Text(
              value.pushAvailable
                  ? 'Kullanılabilir'
                  : 'Firebase sağlayıcısı henüz yapılandırılmadı',
            ),
            onChanged: value.pushAvailable
                ? (enabled) => _replace(push: enabled)
                : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: value.emailEnabled,
            title: const Text('E-posta bildirimi'),
            subtitle: Text(
              value.emailAvailable
                  ? 'Kullanılabilir'
                  : 'Doğrulanmış üretim göndericisi henüz yapılandırılmadı',
            ),
            onChanged: value.emailAvailable
                ? (enabled) => _replace(email: enabled)
                : null,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bedtime_outlined),
            title: const Text('Sessiz saatler'),
            subtitle: Text(
              value.quietHoursStart == null
                  ? 'Kapalı'
                  : '${value.quietHoursStart!.substring(0, 5)}–${value.quietHoursEnd!.substring(0, 5)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value.quietHoursStart != null)
                  IconButton(
                    tooltip: 'Sessiz saatleri kapat',
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
                  tooltip: 'Sessiz saatleri ayarla',
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
              child: const Text('Bildirimleri kaydet'),
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
          const SnackBar(content: Text('Bildirim tercihleri kaydedildi.')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tercihler kaydedilemedi: $error')),
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
      helpText: 'Sessiz saat başlangıcı',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime:
          _parseTime(value.quietHoursEnd) ??
          const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Sessiz saat bitişi',
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
          Text('Hesabım', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextFormField(
            controller: _displayName,
            decoration: const InputDecoration(labelText: 'Görünen ad'),
          ),
          TextFormField(
            controller: _username,
            decoration: const InputDecoration(
              labelText: 'Kullanıcı adı',
              prefixText: '@',
            ),
          ),
          TextFormField(
            controller: _bio,
            maxLength: 280,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Kısa tanıtım'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _publicEnabled,
            title: const Text('Herkese açık profil'),
            subtitle: const Text('Varsayılan olarak kapalıdır.'),
            onChanged: (value) => setState(() {
              _publicEnabled = value;
              if (!value) _leaderboardOptIn = false;
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _leaderboardOptIn,
            title: const Text('Liderlik tablosuna katıl'),
            onChanged: _publicEnabled
                ? (value) => setState(() => _leaderboardOptIn = value)
                : null,
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.profile.lifetimeScore} toplam puan · ${widget.profile.completedAttempts} test',
                ),
              ),
              FilledButton(
                onPressed: () => unawaited(_save()),
                child: const Text('Kaydet'),
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
      ).showSnackBar(const SnackBar(content: Text('Profil kaydedildi.')));
    }
  }
}
