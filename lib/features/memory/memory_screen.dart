import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';

final factsProvider = StreamProvider<List<Fact>>((ref) {
  final db = ref.watch(dbProvider);
  return db.select(db.facts).watch();
});

final masteryProvider = StreamProvider<List<TopicMasteryRow>>((ref) {
  final db = ref.watch(dbProvider);
  return db.select(db.topicMasteryRows).watch();
});

/// Everything Dotbot knows about you, on-device, and deletable.
class MemoryScreen extends ConsumerWidget {
  const MemoryScreen({super.key});

  static const _icons = {
    'goal': Icons.flag_outlined,
    'preference': Icons.favorite_border,
    'person': Icons.people_outline,
    'fact': Icons.info_outline,
    'strategy': Icons.auto_fix_high_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facts = ref.watch(factsProvider).value ?? const <Fact>[];
    final mastery = ref.watch(masteryProvider).value ?? const <TopicMasteryRow>[];
    final user = ref.read(userProvider);
    final th = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Memory'), actions: [
        IconButton(
          tooltip: 'Forget everything',
          icon: const Icon(Icons.delete_sweep_outlined),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Forget all memories?'),
                content: const Text('This deletes every saved fact. Tasks and journal stay.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Forget')),
                ],
              ),
            );
            if (ok == true) {
              final db = ref.read(dbProvider);
              await db.delete(db.facts).go();
            }
          },
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tell Dotbot something',
        onPressed: () => _add(context, ref),
        child: const Icon(Icons.add),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          color: th.colorScheme.secondaryContainer,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
                'Stored only on this device. Only what is needed for a reply is sent to the AI model. '
                'Delete anything you do not want remembered.'),
          ),
        ),
        const SizedBox(height: 16),
        Text('Facts (${facts.length})', style: th.textTheme.titleMedium),
        if (facts.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Nothing yet. Tell Dotbot about people, goals or preferences.')),
        for (final f in facts.reversed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_icons[f.category] ?? Icons.info_outline),
            title: Text(f.content),
            subtitle: Text('${f.category} · saved by ${f.source}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Forget',
              onPressed: () => user.forget(f.id),
            ),
          ),
        const SizedBox(height: 16),
        Text('Skill mastery', style: th.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (mastery.isEmpty) const Text('No quiz data yet.'),
        for (final m in mastery)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              SizedBox(width: 120, child: Text(m.topic)),
              Expanded(child: LinearProgressIndicator(value: m.mastery, minHeight: 8)),
              const SizedBox(width: 8),
              Text('${(m.mastery * 100).round()}%'),
            ]),
          ),
        const SizedBox(height: 80),
      ]),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final ctl = TextEditingController();
    var cat = 'fact';
    final res = await showDialog<(String, String)>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Remember'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButton<String>(
              value: cat,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'fact', child: Text('Fact')),
                DropdownMenuItem(value: 'person', child: Text('Person')),
                DropdownMenuItem(value: 'goal', child: Text('Goal')),
                DropdownMenuItem(value: 'preference', child: Text('Preference')),
              ],
              onChanged: (v) => set(() => cat = v!),
            ),
            TextField(controller: ctl, autofocus: true),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(c, (cat, ctl.text)),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (res == null || res.$2.trim().isEmpty) return;
    await ref.read(userProvider).remember(res.$1, res.$2.trim(), source: 'user');
  }
}
