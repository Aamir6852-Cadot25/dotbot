import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../demo/demo_screen.dart';
import '../memory/memory_screen.dart';
import 'settings_screen.dart';

/// Hub: memory, persona/language, settings, demo.
class YouScreen extends ConsumerStatefulWidget {
  const YouScreen({super.key});
  @override
  ConsumerState<YouScreen> createState() => _State();
}

class _State extends ConsumerState<YouScreen> {
  String _persona = 'friend';
  String _lang = 'english';

  @override
  void initState() {
    super.initState();
    final u = ref.read(userProvider);
    Future.wait([u.getKv('persona'), u.getKv('language')]).then((v) {
      if (mounted) {
        setState(() {
          _persona = v[0] ?? 'friend';
          _lang = v[1] ?? 'english';
        });
      }
    });
  }

  void _open(Widget w) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => w));

  Future<void> _resetAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reset all app data?'),
        content: const Text(
            'Deletes tasks, chat, journal, mood, memory, quiz results and reflections on this device. '
            'Your profile and API key are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok != true) return;
    final db = ref.read(dbProvider);
    await db.transaction(() async {
      for (final drift.TableInfo<drift.Table, dynamic> t in [
        db.tasks, db.chatMessages, db.journalEntries, db.moodLogs, db.facts,
        db.quizResults, db.topicMasteryRows, db.mentorEvents, db.reflections, db.checkins,
      ]) {
        await db.delete(t).go();
      }
    });
    final u = ref.read(userProvider);
    for (final k in ['streak', 'lastStudyDay', 'strategy', 'dailyBudget']) {
      await (db.delete(db.kv)..where((x) => x.key.equals(k))).go();
    }
    await u.setKv('onboarded', '1');
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('All data cleared.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.read(userProvider);
    final th = Theme.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(
        child: ListTile(
          leading: const Icon(Icons.play_circle_outline),
          title: const Text("Simulate a student's day"),
          subtitle: const Text('Live demo of every agent behaviour in ~1 minute'),
          onTap: () => _open(const DemoScreen()),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.memory_outlined),
        title: const Text('Memory'),
        subtitle: const Text('See and delete what Dotbot knows'),
        onTap: () => _open(const MemoryScreen()),
      ),
      ListTile(
        leading: const Icon(Icons.key_outlined),
        title: const Text('AI provider & key'),
        onTap: () => _open(Scaffold(
            appBar: AppBar(title: const Text('Settings')), body: const SettingsScreen())),
      ),
      const Divider(height: 32),
      Text('Personality', style: th.textTheme.titleMedium),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'friend', label: Text('Friend')),
          ButtonSegment(value: 'stoic', label: Text('Stoic')),
          ButtonSegment(value: 'coach', label: Text('Coach')),
        ],
        selected: {_persona},
        onSelectionChanged: (s) {
          setState(() => _persona = s.first);
          u.setKv('persona', s.first);
        },
      ),
      const SizedBox(height: 16),
      Text('Language', style: th.textTheme.titleMedium),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'english', label: Text('English')),
          ButtonSegment(value: 'hinglish', label: Text('Hinglish')),
        ],
        selected: {_lang},
        onSelectionChanged: (s) {
          setState(() => _lang = s.first);
          u.setKv('language', s.first);
        },
      ),
      const Divider(height: 32),
      ListTile(
        leading: Icon(Icons.restart_alt, color: th.colorScheme.error),
        title: const Text('Reset all data'),
        onTap: _resetAll,
      ),
    ]);
  }
}
