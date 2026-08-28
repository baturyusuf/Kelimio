import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/catalog_controller.dart';
import '../../application/profile_controller.dart';
import '../../application/providers.dart';

final class CourseInvitationScreen extends ConsumerStatefulWidget {
  const CourseInvitationScreen({required this.token, super.key});
  final String token;
  @override
  ConsumerState<CourseInvitationScreen> createState() =>
      _CourseInvitationScreenState();
}

final class _CourseInvitationScreenState
    extends ConsumerState<CourseInvitationScreen> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileControllerProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Kurs daveti')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mark_email_read_outlined, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Bu özel kurs davetini kabul etmek ister misiniz?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy || profile?.preferredSupportLanguage == null
                    ? null
                    : () => unawaited(
                        _accept(profile!.preferredSupportLanguage!),
                      ),
                child: _busy
                    ? const CircularProgressIndicator()
                    : const Text('Daveti kabul et'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _accept(String language) async {
    setState(() => _busy = true);
    try {
      final courseId = await ref
          .read(catalogRepositoryProvider)
          .acceptInvitation(token: widget.token, supportLanguage: language);
      ref.invalidate(catalogControllerProvider);
      ref.invalidate(courseDetailProvider(courseId));
      if (mounted) {
        context.go('/catalog/course/$courseId');
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Davet kabul edilemedi: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}
