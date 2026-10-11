import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../reflection/reflection_service.dart';

final eventsProvider = StreamProvider<List<MentorEvent>>((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.mentorEvents)
        ..orderBy([(e) => OrderingTerm.desc(e.id)])
        ..limit(30))
      .watch();
});

final reflectionsProvider = StreamProvider<List<Reflection>>((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.reflections)
        ..orderBy([(e) => OrderingTerm.desc(e.id)])
        ..limit(7))
      .watch();
});

/// Last 7 days of tasks done, for the bar chart.
final weekProvider = StreamProvider<List<int>>((ref) {
  final db = ref.watch(dbProvider);
  return db.select(db.tasks).watch().map((tasks) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 6));
    final out = List.filled(7, 0);
    for (final t in tasks) {
      final d = t.doneAt;
      if (d == null || d.isBefore(start)) continue;
      final i = DateTime(d.year, d.month, d.day).difference(start).inDays;
      if (i >= 0 && i < 7) out[i]++;
    }
    return out;
  });
});

/// Results the agent produced: proof it helps, and its own decisions.
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});
  @override
  ConsumerState<InsightsScreen> createState() => _State();
}

class _State extends ConsumerState<InsightsScreen> {
  bool _busy = false;

  Future<void> _reflect() async {
    setState(() => _busy = true);
    try {
      final llm = await ref.read(llmProvider.future);
      await ReflectionService(ref.read(dbProvider), ref.read(userProvider), llm: llm)
          .reflect();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final events = ref.watch(eventsProvider).value ?? const <MentorEvent>[];
    final refl = ref.watch(reflectionsProvider).value ?? const <Reflection>[];
    final week = ref.watch(weekProvider).value ?? List.filled(7, 0);
    final spoke = events.where((e) => e.spoke).toList();
    final graded = spoke.where((e) => e.effective != null).toList();
    final eff = graded.where((e) => e.effective!).length;
    final silent = events.where((e) => !e.spoke).length;
    final latest = refl.isEmpty
        ? null
        : Map<String, dynamic>.from(jsonDecode(refl.first.stats) as Map);

    return ListView(padding: const EdgeInsets.all(16), children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        _Kpi('Nudges sent', '${spoke.length}'),
        _Kpi('Chose silence', '$silent'),
        _Kpi('Nudges acted on',
            graded.isEmpty ? '–' : '${(eff * 100 / graded.length).round()}%'),
        if (latest != null)
          _Kpi('Tasks (last day)', '${latest['tasksDone']}/${latest['tasksPlanned']}'),
        if (latest != null)
          _Kpi('Quiz correct', '${latest['quizCorrect']}/${latest['quizAttempts']}'),
      ]),
      const SizedBox(height: 24),
      Text('Tasks completed, last 7 days', style: th.textTheme.titleMedium),
      const SizedBox(height: 8),
      _Bars(week),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: Text('Self-reflection', style: th.textTheme.titleMedium)),
        FilledButton.tonalIcon(
          onPressed: _busy ? null : _reflect,
          icon: const Icon(Icons.auto_fix_high_outlined),
          label: Text(_busy ? 'Reflecting…' : 'Reflect now'),
        ),
      ]),
      if (refl.isEmpty)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Dotbot reflects on its own behaviour every night at 23:00.')),
      for (final r in refl)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.day, style: th.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(r.summary),
              const SizedBox(height: 8),
              Text('Strategy for tomorrow: ${r.strategy}',
                  style: th.textTheme.bodySmall
                      ?.copyWith(color: th.colorScheme.primary)),
            ]),
          ),
        ),
      const SizedBox(height: 24),
      Text('Mentor decisions', style: th.textTheme.titleMedium),
      if (events.isEmpty)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No triggers yet. Dotbot stays silent when nothing needs saying.')),
      for (final e in events)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(e.spoke ? Icons.campaign_outlined : Icons.volume_off_outlined,
              color: e.spoke ? th.colorScheme.primary : th.colorScheme.outline),
          title: Text('${e.trigger} · ${e.spoke ? 'spoke (${e.tone})' : 'stayed silent'}'),
          subtitle: Text(
              '${_hhmm(e.at)} · ${e.reason}${e.effective == null ? '' : (e.effective! ? ' · user acted ✓' : ' · ignored')}'),
        ),
    ]);
  }

  static String _hhmm(DateTime d) =>
      '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: th.textTheme.headlineSmall),
            Text(label, style: th.textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars(this.values);
  final List<int> values;
  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final max = values.fold<int>(1, (a, b) => b > a ? b : a);
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now();
    return SizedBox(
      height: 120,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('${values[i]}', style: th.textTheme.labelSmall),
              const SizedBox(height: 2),
              Container(
                height: 80 * values[i] / max + 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: th.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(days[today.subtract(Duration(days: 6 - i)).weekday - 1],
                  style: th.textTheme.labelSmall),
            ]),
          ),
      ]),
    );
  }
}
