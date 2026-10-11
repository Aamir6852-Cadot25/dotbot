import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/llm/llm_provider.dart';

/// Stoic morning intention / night review. The USER writes; the agent only
/// asks one question back.
class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key, required this.kind});
  final String kind; // morning | night
  @override
  ConsumerState<JournalScreen> createState() => _State();
}

class _State extends ConsumerState<JournalScreen> {
  final _ctl = TextEditingController();
  String? _question;
  bool _busy = false;

  bool get _morning => widget.kind == 'morning';

  static const _prompts = {
    'morning': [
      'What is within my control today?',
      'What is the one thing that would make today a success?',
      'What obstacle might I meet, and how will I respond?',
    ],
    'night': [
      'What did I do well today?',
      'Where did I fall short, and what will I change?',
      'What did I learn?',
    ],
  };

  Future<void> _save() async {
    final text = _ctl.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    String q;
    try {
      final llm = await ref.read(llmProvider.future);
      if (llm == null) throw StateError('no key');
      q = (await llm.chat([
        const ChatMsg(Role.system,
            'You are a Stoic mentor. Reply with exactly ONE short, probing question and nothing else. Never give advice or answers.'),
        ChatMsg(Role.user,
            '${_morning ? 'Morning intention' : 'Night review'}:\n$text'),
      ]))
          .text
          .trim();
    } catch (_) {
      q = _morning
          ? 'What will you do first when the day gets hard?'
          : 'What is the one thing you would do differently tomorrow?';
    }
    final db = ref.read(dbProvider);
    await db.into(db.journalEntries).insert(JournalEntriesCompanion.insert(
        kind: widget.kind,
        body: text,
        agentQuestion: Value(q),
        createdAt: DateTime.now()));
    setState(() {
      _question = q;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prompts = _prompts[widget.kind]!;
    return Scaffold(
      appBar: AppBar(title: Text(_morning ? 'Morning intention' : 'Night review')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final p in prompts)
          Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $p', style: Theme.of(context).textTheme.bodyMedium)),
        const SizedBox(height: 12),
        TextField(
          controller: _ctl,
          minLines: 6,
          maxLines: 12,
          readOnly: _question != null,
          decoration: const InputDecoration(
              border: OutlineInputBorder(), hintText: 'Write in your own words...'),
        ),
        const SizedBox(height: 12),
        if (_question == null)
          FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Thinking...' : 'Save')),
        if (_question != null)
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_question!,
                    style: Theme.of(context).textTheme.titleMedium)),
          ),
      ]),
    );
  }
}
