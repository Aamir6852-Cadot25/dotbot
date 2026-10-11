import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import 'journal_screen.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider).value ?? const <Task>[];
    final open = tasks.where((t) => t.doneAt == null).toList();
    final done = tasks.where((t) => t.doneAt != null).toList();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addTask(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Task'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _MoodRow(),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: FilledButton.tonalIcon(
              onPressed: () => _journal(context, 'morning'),
              icon: const Icon(Icons.wb_sunny_outlined),
              label: const Text('Morning intention'),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: FilledButton.tonalIcon(
              onPressed: () => _journal(context, 'night'),
              icon: const Icon(Icons.nights_stay_outlined),
              label: const Text('Night review'),
            )),
          ]),
          const SizedBox(height: 24),
          Text('Plan', style: Theme.of(context).textTheme.titleMedium),
          if (open.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Nothing planned. Add a task or ask Dotbot to plan your day.')),
          for (final t in open) _TaskTile(t),
          if (done.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Done', style: Theme.of(context).textTheme.titleMedium),
            for (final t in done.reversed.take(5)) _TaskTile(t),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _journal(BuildContext context, String kind) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => JournalScreen(kind: kind)));

  Future<void> _addTask(BuildContext context, WidgetRef ref) async {
    final ctl = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('New task'),
        content: TextField(controller: ctl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('Add')),
        ],
      ),
    );
    if (title == null || title.trim().isEmpty) return;
    final db = ref.read(dbProvider);
    final now = DateTime.now();
    await db.into(db.tasks).insert(TasksCompanion.insert(
        title: title.trim(),
        createdAt: now,
        dueAt: Value(DateTime(now.year, now.month, now.day, 23, 59))));
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile(this.t);
  final Task t;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(dbProvider);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: t.doneAt != null,
      title: Text(t.title,
          style: t.doneAt == null
              ? null
              : const TextStyle(decoration: TextDecoration.lineThrough)),
      controlAffinity: ListTileControlAffinity.leading,
      secondary: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () =>
            (db.delete(db.tasks)..where((x) => x.id.equals(t.id))).go(),
      ),
      onChanged: (v) async {
        await (db.update(db.tasks)..where((x) => x.id.equals(t.id)))
            .write(TasksCompanion(doneAt: Value(v == true ? DateTime.now() : null)));
        if (v == true) await ref.read(userProvider).markStudied();
      },
    );
  }
}

/// One-tap mood, then one-tap energy.
class _MoodRow extends ConsumerStatefulWidget {
  const _MoodRow();
  @override
  ConsumerState<_MoodRow> createState() => _MoodState();
}

class _MoodState extends ConsumerState<_MoodRow> {
  int? _mood;
  bool _saved = false;
  static const _faces = ['😞', '😕', '😐', '🙂', '😄'];

  Future<void> _log(int energy) async {
    await ref.read(userProvider).logMood(_mood!, energy);
    setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final label = _saved
        ? 'Logged. Thanks.'
        : (_mood == null ? 'How are you?' : 'Energy level?');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          if (!_saved)
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (var i = 1; i <= 5; i++)
                _mood == null
                    ? IconButton(
                        onPressed: () => setState(() => _mood = i),
                        icon: Text(_faces[i - 1], style: const TextStyle(fontSize: 28)))
                    : IconButton.outlined(
                        onPressed: () => _log(i),
                        icon: Text('$i'),
                        tooltip: 'Energy $i'),
            ]),
        ]),
      ),
    );
  }
}
