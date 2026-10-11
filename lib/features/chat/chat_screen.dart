import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/llm/llm_provider.dart';
import '../agent/agent.dart';
import '../agent/prompts.dart';
import 'trace_view.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _State();
}

class _State extends ConsumerState<ChatScreen> {
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  final _live = <AgentStep>[];

  Future<void> _send() async {
    final text = _ctl.text.trim();
    if (text.isEmpty || _busy) return;
    _ctl.clear();
    setState(() {
      _busy = true;
      _live.clear();
    });
    final db = ref.read(dbProvider);
    final user = ref.read(userProvider);
    await db.into(db.chatMessages).insert(ChatMessagesCompanion.insert(
        role: 'user', content: text, at: DateTime.now()));
    _toBottom();
    String reply;
    String? trace;
    try {
      final agent = await ref.read(agentProvider.future);
      if (agent == null) {
        reply = 'Add an API key in You > Settings (or pick Offline demo) and I can answer.';
      } else {
        final past = await (db.select(db.chatMessages)
              ..orderBy([(t) => OrderingTerm.desc(t.id)])
              ..limit(13))
            .get();
        // Drop the message we just inserted; run() appends it.
        final history = past.reversed
            .take(past.length - 1)
            .map((m) => ChatMsg(m.role == 'user' ? Role.user : Role.assistant, m.content))
            .toList();
        final r = await agent.run(
          system: await buildSystemPrompt(user),
          history: history,
          userText: text,
          onStep: (s) {
            if (mounted) setState(() => _live.add(s));
            _toBottom();
          },
        );
        reply = r.reply;
        trace = AgentStep.encode(r.trace);
      }
    } catch (e) {
      reply = 'Could not reach the model: $e';
    }
    await db.into(db.chatMessages).insert(ChatMessagesCompanion.insert(
        role: 'assistant', content: reply, trace: Value(trace), at: DateTime.now()));
    if (mounted) setState(() => _busy = false);
    _toBottom();
  }

  void _toBottom() => Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });

  Future<void> _attach() async {
    final r = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf', 'txt', 'md']);
    final path = r.isEmpty ? null : r.first.path;
    if (path == null) return;
    _ctl.text = 'Summarize this document: $path';
    await _send();
  }

  @override
  Widget build(BuildContext context) {
    final msgs = ref.watch(chatProvider).value ?? const <ChatMessage>[];
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Expanded(
        child: msgs.isEmpty && !_busy
            ? const Center(
                child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'Dotbot is quiet by default.\nTry "plan my day", "quiz me" or "I feel lonely".',
                    textAlign: TextAlign.center),
              ))
            : ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                children: [
                  for (final m in msgs) _Bubble(m),
                  if (_busy)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: TraceView(_live, live: true),
                      ),
                    ),
                ],
              ),
      ),
      if (_busy) LinearProgressIndicator(color: cs.tertiary),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            IconButton(
                onPressed: _attach,
                icon: const Icon(Icons.attach_file),
                tooltip: 'Summarize a PDF'),
            Expanded(
              child: TextField(
                controller: _ctl,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                    hintText: 'Message Dotbot', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
          ]),
        ),
      ),
    ]);
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.m);
  final ChatMessage m;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mine = m.role == 'user';
    final steps = AgentStep.decode(m.trace);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: mine ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SelectableText(m.content),
          if (steps.length > 1)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                title: Text('How I got here (${steps.length} steps)',
                    style: Theme.of(context).textTheme.labelMedium),
                children: [TraceView(steps)],
              ),
            ),
        ]),
      ),
    );
  }
}
