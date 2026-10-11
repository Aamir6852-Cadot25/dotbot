import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'challenges.dart';

/// Offline practice: works with no network and no API key.
class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});
  @override
  ConsumerState<ChallengesScreen> createState() => _State();
}

class _State extends ConsumerState<ChallengesScreen> {
  Challenge? _c;
  bool _revealed = false;
  String? _msg;

  Future<void> _next() async {
    final weak = await ref.read(userProvider).weakTopics();
    setState(() {
      _c = pickChallenge(weakTopics: weak);
      _revealed = false;
      _msg = null;
    });
  }

  Future<void> _grade(bool ok) async {
    final m = await ref.read(userProvider).recordQuiz(
        topic: _c!.topic, correct: ok, hintLevel: _revealed ? 1 : 0);
    setState(() => _msg =
        '${_c!.topic}: mastery ${(m * 100).round()}%${ok ? '' : ' — it will come back'}');
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Offline challenges', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      const Text('No network needed. Try first, hints cost mastery credit.'),
      const SizedBox(height: 16),
      if (c == null)
        FilledButton(onPressed: _next, child: const Text('Give me one'))
      else ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Chip(label: Text(c.topic)),
              const SizedBox(height: 8),
              Text(c.prompt, style: Theme.of(context).textTheme.titleMedium),
              if (_revealed) ...[
                const Divider(height: 24),
                Text('Hint: ${c.answerHint}'),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 12),
        if (_msg == null)
          Wrap(spacing: 8, children: [
            if (!_revealed)
              OutlinedButton(
                  onPressed: () => setState(() => _revealed = true),
                  child: const Text('Hint')),
            FilledButton(onPressed: () => _grade(true), child: const Text('Solved it')),
            TextButton(onPressed: () => _grade(false), child: const Text('Could not')),
          ])
        else ...[
          Text(_msg!),
          const SizedBox(height: 8),
          FilledButton(onPressed: _next, child: const Text('Next')),
        ],
      ],
    ]);
  }
}
