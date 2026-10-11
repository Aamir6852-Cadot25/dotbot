import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'hint_ladder.dart';
import 'tutor_service.dart';

/// Socratic tutor: question -> (hint -> partial -> answer), capped by mastery.
class TutorScreen extends ConsumerStatefulWidget {
  const TutorScreen({super.key});
  @override
  ConsumerState<TutorScreen> createState() => _State();
}

class _State extends ConsumerState<TutorScreen> {
  final _topic = TextEditingController(text: 'arrays');
  final _answer = TextEditingController();
  String? _question;
  final _hints = <String>[];
  HintLevel? _level; // highest rung shown so far
  String? _result;
  bool _busy = false;

  Future<T?> _guard<T>(Future<T> Function(TutorService t) f) async {
    final t = await ref.read(tutorProvider.future);
    if (t == null) {
      setState(() => _result = 'Add an API key in Settings, or use Challenges (offline).');
      return null;
    }
    setState(() => _busy = true);
    try {
      return await f(t);
    } catch (e) {
      setState(() => _result = 'Model error: $e');
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    final topic = _topic.text.trim();
    if (topic.isEmpty) return;
    final q = await _guard((t) => t.newQuestion(topic));
    if (q == null) return;
    setState(() {
      _question = q;
      _hints.clear();
      _level = null;
      _result = null;
      _answer.clear();
    });
  }

  Future<void> _hint() async {
    final topic = _topic.text.trim();
    final m = await ref.read(userProvider).mastery(topic);
    final next = _level == null ? HintLadder.start(m) : HintLadder.next(_level!, m);
    if (next == null) {
      setState(() => _result =
          'No more hints. You are strong enough here — keep struggling, or submit what you have.');
      return;
    }
    final h = await _guard((t) => t.hint(topic, _question!, next));
    if (h == null) return;
    setState(() {
      _hints.add(h);
      _level = next;
      _result = null;
    });
  }

  Future<void> _submit() async {
    final topic = _topic.text.trim();
    final e = await _guard((t) => t.evaluate(_question!, _answer.text));
    if (e == null) return;
    final m = await ref.read(userProvider).recordQuiz(
        topic: topic, correct: e.correct, hintLevel: _level?.index ?? 0);
    setState(() => _result =
        '${e.correct ? 'Correct' : 'Not quite'}. ${e.feedback}\nMastery of $topic: ${(m * 100).round()}%');
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Socratic tutor', style: th.textTheme.titleLarge),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: TextField(
                controller: _topic,
                decoration: const InputDecoration(labelText: 'Topic'))),
        const SizedBox(width: 12),
        FilledButton(onPressed: _busy ? null : _start, child: const Text('Ask me')),
      ]),
      if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
      if (_question != null) ...[
        const SizedBox(height: 16),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_question!, style: th.textTheme.titleMedium))),
        for (var i = 0; i < _hints.length; i++)
          ListTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: Text(_hints[i]),
          ),
        TextField(
          controller: _answer,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
              border: OutlineInputBorder(), hintText: 'Your answer'),
        ),
        const SizedBox(height: 8),
        Row(children: [
          OutlinedButton(onPressed: _busy ? null : _hint, child: const Text('Hint')),
          const SizedBox(width: 8),
          FilledButton(onPressed: _busy ? null : _submit, child: const Text('Submit')),
        ]),
      ],
      if (_result != null) ...[
        const SizedBox(height: 16),
        Text(_result!),
      ],
    ]);
  }
}
