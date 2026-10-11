import 'package:drift/drift.dart' show OrderingTerm;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/llm/llm_provider.dart';
import '../agent/prompts.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _State();
}

class _State extends ConsumerState<ChatScreen> {
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;

  Future<void> _send() async {
    final text = _ctl.text.trim();
    if (text.isEmpty || _busy) return;
    _ctl.clear();
    setState(() => _busy = true);
    final db = ref.read(dbProvider);
    final user = ref.read(userProvider);
    await db.into(db.chatMessages).insert(ChatMessagesCompanion.insert(
        role: 'user', content: text, at: DateTime.now()));
    String reply;
    try {
      final agent = await ref.read(agentProvider.future);
      if (agent == null) {
        reply = 'Add an API key in Settings and I can answer.';
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
        reply = (await agent.run(
                system: await buildSystemPrompt(user),
                history: history,
                userText: text))
            .reply;
      }
    } catch (e) {
      reply = 'Could not reach the model: $e';
    }
    await db.into(db.chatMessages).insert(ChatMessagesCompanion.insert(
        role: 'assistant', content: reply, at: DateTime.now()));
    if (mounted) setState(() => _busy = false);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (_scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  }

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
        child: msgs.isEmpty
            ? const Center(child: Text('Dotbot is quiet. Say something.'))
            : ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final m = msgs[i];
                  final mine = m.role == 'user';
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 520),
                      decoration: BoxDecoration(
                        color: mine ? cs.primaryContainer : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SelectableText(m.content),
                    ),
                  );
                },
              ),
      ),
      if (_busy) const LinearProgressIndicator(),
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
            IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
          ]),
        ),
      ),
    ]);
  }
}
