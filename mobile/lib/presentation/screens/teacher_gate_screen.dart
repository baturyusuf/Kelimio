import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../application/teacher_access_controller.dart';
import '../../domain/teacher/teacher_access.dart';
import '../widgets/async_error_view.dart';
import '../widgets/localization.dart';
import 'teacher_import_screen.dart';

final class TeacherGateScreen extends ConsumerWidget {
  const TeacherGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(appConfigProvider).localDevelopmentToolsEnabled) {
      return const TeacherImportScreen();
    }
    final access = ref.watch(teacherAccessControllerProvider);
    return access.when(
      data: (value) => value.authorized
          ? const TeacherImportScreen()
          : _TeacherAccessView(access: value),
      loading: () => Scaffold(
        appBar: AppBar(title: Text(context.l10n.teacher)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.teacher)),
        body: AsyncErrorView(
          error: error,
          onRetry: () => unawaited(
            ref.read(teacherAccessControllerProvider.notifier).refresh(),
          ),
        ),
      ),
    );
  }
}

final class _TeacherAccessView extends ConsumerStatefulWidget {
  const _TeacherAccessView({required this.access});

  final TeacherAccess access;

  @override
  ConsumerState<_TeacherAccessView> createState() => _TeacherAccessViewState();
}

final class _TeacherAccessViewState extends ConsumerState<_TeacherAccessView> {
  var _accepted = false;

  @override
  Widget build(BuildContext context) {
    final access = widget.access;
    final message = !access.productionFeaturesEnabled
        ? context.l10n.teacherFeatureUnavailable
        : !access.eligible
        ? context.l10n.teacherAccountNotEligible
        : context.l10n.teacherTermsBody;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.teacher)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            access.eligible ? Icons.verified_user_outlined : Icons.lock_outline,
            size: 56,
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.teacherAccessTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(message),
          if (access.productionFeaturesEnabled &&
              access.eligible &&
              !access.termsAccepted) ...[
            const SizedBox(height: 16),
            CheckboxListTile(
              key: const Key('teacher-terms-checkbox'),
              contentPadding: EdgeInsets.zero,
              value: _accepted,
              onChanged: (value) => setState(() => _accepted = value ?? false),
              title: Text(context.l10n.teacherTermsAcceptance),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('teacher-terms-accept'),
              onPressed: _accepted
                  ? () => unawaited(
                      ref
                          .read(teacherAccessControllerProvider.notifier)
                          .acceptRequiredTerms(),
                    )
                  : null,
              child: Text(context.l10n.continueLabel),
            ),
          ],
        ],
      ),
    );
  }
}
