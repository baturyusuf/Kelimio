import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/auth_controller.dart';
import '../../application/profile_controller.dart';
import '../../domain/profile/profile.dart';
import '../widgets/async_error_view.dart';
import '../widgets/localization.dart';

final class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

final class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  String? _initializedProfileId;
  String _appLocale = 'tr';
  String _targetLanguage = 'tr';
  String _supportLanguage = 'en';
  String _timeZone = 'Europe/Istanbul';

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.profileSetupTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.signOut,
            onPressed: () =>
                unawaited(ref.read(authControllerProvider.notifier).signOut()),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: profileState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => AsyncErrorView(
            error: error,
            onRetry: () => unawaited(
              ref.read(profileControllerProvider.notifier).retryLoad(),
            ),
          ),
          data: (profile) {
            if (profile == null) {
              return const Center(child: CircularProgressIndicator());
            }
            _initialize(profile);
            return _buildForm(profileState.isLoading);
          },
        ),
      ),
    );
  }

  void _initialize(UserProfile profile) {
    if (_initializedProfileId == profile.id) {
      return;
    }
    _initializedProfileId = profile.id;
    _displayNameController.text = profile.displayName;
    _appLocale = _appLocales.contains(profile.appLocale)
        ? profile.appLocale
        : 'tr';
    _targetLanguage = _learningLanguages.contains(profile.activeTargetLanguage)
        ? profile.activeTargetLanguage
        : 'tr';
    _supportLanguage =
        profile.preferredSupportLanguage ??
        (_targetLanguage == 'en' ? 'tr' : 'en');
    if (_supportLanguage == _targetLanguage ||
        !_learningLanguages.contains(_supportLanguage)) {
      _supportLanguage = _learningLanguages.firstWhere(
        (language) => language != _targetLanguage,
      );
    }
    _timeZone = profile.timeZone == 'Europe/Istanbul'
        ? profile.timeZone
        : 'Europe/Istanbul';
  }

  Widget _buildForm(bool saving) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.tune_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.profileSetupBody,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _displayNameController,
                  enabled: !saving,
                  maxLength: 80,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.l10n.displayName,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.l10n.requiredField
                      : null,
                ),
                const SizedBox(height: 12),
                _languageDropdown(
                  label: context.l10n.appLanguage,
                  value: _appLocale,
                  languages: _appLocales,
                  enabled: !saving,
                  onChanged: (value) => setState(() => _appLocale = value),
                ),
                const SizedBox(height: 12),
                _languageDropdown(
                  label: context.l10n.targetLanguage,
                  value: _targetLanguage,
                  languages: _learningLanguages,
                  enabled: !saving,
                  onChanged: (value) {
                    setState(() {
                      _targetLanguage = value;
                      if (_supportLanguage == value) {
                        _supportLanguage = _learningLanguages.firstWhere(
                          (language) => language != value,
                        );
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                _languageDropdown(
                  label: context.l10n.preferredSupportLanguage,
                  value: _supportLanguage,
                  languages: _learningLanguages
                      .where((language) => language != _targetLanguage)
                      .toList(growable: false),
                  enabled: !saving,
                  onChanged: (value) =>
                      setState(() => _supportLanguage = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('time-zone-$_timeZone'),
                  initialValue: _timeZone,
                  decoration: InputDecoration(labelText: context.l10n.timeZone),
                  items: [
                    DropdownMenuItem(
                      value: 'Europe/Istanbul',
                      child: Text(context.l10n.timeZoneIstanbul),
                    ),
                    DropdownMenuItem(
                      value: 'UTC',
                      child: Text(context.l10n.timeZoneUtc),
                    ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setState(() => _timeZone = value!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.profileSetupLegalNotice,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: saving ? null : _submit,
            icon: saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(context.l10n.completeProfileSetup),
          ),
        ],
      ),
    ),
  );

  Widget _languageDropdown({
    required String label,
    required String value,
    required List<String> languages,
    required bool enabled,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    key: ValueKey('$label-$value'),
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final language in languages)
        DropdownMenuItem(value: language, child: Text(_languageName(language))),
    ],
    onChanged: enabled ? (next) => onChanged(next!) : null,
  );

  String _languageName(String language) => switch (language) {
    'tr' => context.l10n.languageTurkish,
    'en' => context.l10n.languageEnglish,
    'ar' => context.l10n.languageArabic,
    'fr' => context.l10n.languageFrench,
    _ => language,
  };

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    unawaited(
      ref
          .read(profileControllerProvider.notifier)
          .completeSetup(
            ProfileSetupInput(
              displayName: _displayNameController.text,
              appLocale: _appLocale,
              activeTargetLanguage: _targetLanguage,
              preferredSupportLanguage: _supportLanguage,
              timeZone: _timeZone,
            ),
          ),
    );
  }

  static const _appLocales = <String>['tr', 'en', 'ar'];
  static const _learningLanguages = <String>['tr', 'en', 'ar', 'fr'];
}
