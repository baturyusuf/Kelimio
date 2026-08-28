import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/offline/offline.dart';

final class OfflinePracticeScreen extends ConsumerStatefulWidget {
  const OfflinePracticeScreen({required this.package, super.key});
  final OfflineCoursePackage package;
  @override
  ConsumerState<OfflinePracticeScreen> createState() =>
      _OfflinePracticeScreenState();
}

final class _OfflinePracticeScreenState
    extends ConsumerState<OfflinePracticeScreen> {
  late final Future<List<OfflinePracticeQuestion>> _questions;
  var _index = 0;
  var _correct = 0;
  var _revealed = false;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _questions = ref
        .read(offlinePackageRepositoryProvider)
        .loadQuestions(widget.package);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Çevrimdışı puansız çalışma')),
    body: FutureBuilder<List<OfflinePracticeQuestion>>(
      future: _questions,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final questions = snapshot.requireData;
        if (_index >= questions.length) return _finished(questions.length);
        final question = questions[_index];
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '${_index + 1}/${questions.length} · Bu çalışma puan ve enerji kazandırmaz.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Text(
              question.prompt,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            if (question.options.isNotEmpty)
              for (final option in question.options)
                ListTile(
                  title: Text(option),
                  trailing: _selected == option
                      ? const Icon(Icons.radio_button_checked)
                      : const Icon(Icons.radio_button_unchecked),
                  onTap: _revealed
                      ? null
                      : () => setState(() => _selected = option),
                ),
            if (question.matchingPairs.isNotEmpty)
              for (final entry in question.matchingPairs.entries)
                ListTile(
                  title: Text(entry.key),
                  trailing: _revealed ? Text(entry.value) : const Text('?'),
                ),
            if (question.options.isEmpty && question.matchingPairs.isEmpty)
              TextField(
                enabled: !_revealed,
                onChanged: (value) => _selected = value,
                decoration: const InputDecoration(labelText: 'Cevabın'),
              ),
            const SizedBox(height: 16),
            if (_revealed)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Doğru cevap: ${question.correctAnswer}'),
                ),
              ),
            if (_revealed && question.matchingPairs.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _next(questions.length),
                      child: const Text('Tekrar çalışmalıyım'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          _next(questions.length, matchingCorrect: true),
                      child: const Text('Eşleştirmeleri biliyordum'),
                    ),
                  ),
                ],
              )
            else
              FilledButton(
                onPressed: _revealed
                    ? () => _next(questions.length)
                    : () => _reveal(question),
                child: Text(_revealed ? 'Sonraki' : 'Cevabı kontrol et'),
              ),
          ],
        );
      },
    ),
  );

  void _reveal(OfflinePracticeQuestion question) {
    final answer = _selected?.trim().toLowerCase();
    final correct = question.options.isNotEmpty
        ? answer == question.correctAnswer.trim().toLowerCase()
        : question.matchingPairs.isEmpty &&
              answer == question.correctAnswer.trim().toLowerCase();
    setState(() {
      _revealed = true;
      if (correct) {
        _correct++;
      }
    });
  }

  void _next(int total, {bool matchingCorrect = false}) {
    setState(() {
      if (matchingCorrect) _correct++;
      _index++;
      _revealed = false;
      _selected = null;
    });
    if (_index >= total) {
      unawaited(
        ref
            .read(offlinePackageRepositoryProvider)
            .recordPractice(
              package: widget.package,
              answered: total,
              correct: _correct,
            ),
      );
    }
  }

  Widget _finished(int total) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.offline_bolt_outlined, size: 64),
          const SizedBox(height: 16),
          Text(
            'Çevrimdışı çalışma tamamlandı',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '$_correct/$total doğru. Bu sonuç yalnızca cihazda tutuldu ve çevrimiçi puana gönderilmedi.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
