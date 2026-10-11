import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/db/database.dart';
import '../../core/llm/llm_provider.dart';
import '../memory/user_model.dart';

/// Per-day numbers the agent reflects on (also shown in Insights).
class DayStats {
  DayStats({
    required this.tasksPlanned,
    required this.tasksDone,
    required this.quizAttempts,
    required this.quizCorrect,
    required this.avgHintLevel,
    required this.nudgesSent,
    required this.nudgesEffective,
    required this.deliberateSilences,
    required this.avgMood,
    required this.effectByTone,
  });

  final int tasksPlanned, tasksDone, quizAttempts, quizCorrect;
  final double avgHintLevel;
  final int nudgesSent, nudgesEffective, deliberateSilences;
  final double? avgMood;

  /// tone -> [effective, sent]
  final Map<String, List<int>> effectByTone;

  double get nudgeEffectiveness =>
      nudgesSent == 0 ? 0 : nudgesEffective / nudgesSent;

  Map<String, Object?> toJson() => {
        'tasksPlanned': tasksPlanned,
        'tasksDone': tasksDone,
        'quizAttempts': quizAttempts,
        'quizCorrect': quizCorrect,
        'avgHintLevel': avgHintLevel,
        'nudgesSent': nudgesSent,
        'nudgesEffective': nudgesEffective,
        'deliberateSilences': deliberateSilences,
        'avgMood': avgMood,
        'effectByTone': effectByTone,
      };
}

/// Nightly self-reflection: the agent grades its OWN nudges (did the user act
/// within 2h?), adapts its silence budget and writes a strategy note that is
/// injected into tomorrow's prompts.
class ReflectionService {
  ReflectionService(this.db, this.user, {this.llm, DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final AppDatabase db;
  final UserModel user;
  final LlmProvider? llm;
  final DateTime Function() _now;

  static const actWindow = Duration(hours: 2);

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<bool> reflectedOn(DateTime day) async =>
      (await (db.select(db.reflections)..where((r) => r.day.equals(dayKey(day))))
              .get())
          .isNotEmpty;

  /// Did the user do something useful within [actWindow] after [t]?
  Future<bool> _actedAfter(DateTime t) async {
    final end = t.add(actWindow);
    final done = await (db.select(db.tasks)
          ..where((x) => x.doneAt.isBetweenValues(t, end)))
        .get();
    if (done.isNotEmpty) return true;
    final quiz = await (db.select(db.quizResults)
          ..where((x) => x.at.isBetweenValues(t, end)))
        .get();
    if (quiz.isNotEmpty) return true;
    final journal = await (db.select(db.journalEntries)
          ..where((x) => x.createdAt.isBetweenValues(t, end)))
        .get();
    return journal.isNotEmpty;
  }

  Future<DayStats> computeStats(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final tasks = await (db.select(db.tasks)
          ..where((t) =>
              t.createdAt.isBetweenValues(start, end) |
              t.dueAt.isBetweenValues(start, end) |
              t.doneAt.isBetweenValues(start, end)))
        .get();
    final quizzes = await (db.select(db.quizResults)
          ..where((q) => q.at.isBetweenValues(start, end)))
        .get();
    final events = await (db.select(db.mentorEvents)
          ..where((e) => e.at.isBetweenValues(start, end)))
        .get();
    final moods = await (db.select(db.moodLogs)
          ..where((m) => m.at.isBetweenValues(start, end)))
        .get();

    var effective = 0;
    final byTone = <String, List<int>>{};
    for (final e in events.where((e) => e.spoke)) {
      final ok = await _actedAfter(e.at);
      await (db.update(db.mentorEvents)..where((x) => x.id.equals(e.id)))
          .write(MentorEventsCompanion(effective: Value(ok)));
      if (ok) effective++;
      final tone = e.tone ?? 'warm';
      final slot = byTone.putIfAbsent(tone, () => [0, 0]);
      if (ok) slot[0]++;
      slot[1]++;
    }

    return DayStats(
      tasksPlanned: tasks.length,
      tasksDone: tasks.where((t) => t.doneAt != null).length,
      quizAttempts: quizzes.length,
      quizCorrect: quizzes.where((q) => q.correct).length,
      avgHintLevel: quizzes.isEmpty
          ? 0
          : quizzes.map((q) => q.hintLevel).reduce((a, b) => a + b) /
              quizzes.length,
      nudgesSent: events.where((e) => e.spoke).length,
      nudgesEffective: effective,
      deliberateSilences: events.where((e) => !e.spoke).length,
      avgMood: moods.isEmpty
          ? null
          : moods.map((m) => m.mood).reduce((a, b) => a + b) / moods.length,
      effectByTone: byTone,
    );
  }

  /// Rule-based adaptation; deterministic so it can be unit-tested.
  static ({String strategy, int budget}) adapt(DayStats s, int currentBudget) {
    final notes = <String>[];
    var budget = currentBudget;
    if (s.nudgesSent >= 2 && s.nudgeEffectiveness < 0.34) {
      budget = (budget - 1).clamp(1, 5);
      notes.add('Most nudges were ignored, so speak less (budget $budget/day).');
    } else if (s.nudgesSent >= 2 && s.nudgeEffectiveness >= 0.67) {
      budget = (budget + 1).clamp(1, 4);
      notes.add('Nudges led to action, so one more is fine (budget $budget/day).');
    }
    String? bestTone;
    var bestRate = -1.0;
    s.effectByTone.forEach((tone, v) {
      final rate = v[1] == 0 ? 0.0 : v[0] / v[1];
      if (rate > bestRate) {
        bestRate = rate;
        bestTone = tone;
      }
    });
    if (bestTone != null && bestRate > 0) {
      notes.add('The $bestTone tone worked best today.');
    }
    if (s.quizAttempts > 0 && s.avgHintLevel < 1 && s.quizCorrect / s.quizAttempts > 0.7) {
      notes.add('User solved most problems with few hints: hold back help more.');
    } else if (s.quizAttempts > 0 && s.quizCorrect / s.quizAttempts < 0.4) {
      notes.add('User struggled on quizzes: give one encouraging hint sooner.');
    }
    if (s.avgMood != null && s.avgMood! <= 2.5) {
      notes.add('Mood was low: be gentle tomorrow and suggest time with people.');
    }
    if (s.tasksPlanned > 0 && s.tasksDone == 0) {
      notes.add('No tasks done: plan fewer, smaller tasks tomorrow.');
    }
    return (
      strategy: notes.isEmpty ? 'Keep the same approach.' : notes.join(' '),
      budget: budget,
    );
  }

  Future<Reflection> reflect({DateTime? day}) async {
    final d = day ?? _now();
    final stats = await computeStats(d);
    final current = int.tryParse(await user.getKv('dailyBudget') ?? '') ?? 3;
    final a = adapt(stats, current);
    await user.setKv('dailyBudget', '${a.budget}');
    await user.setKv('strategy', a.strategy);

    var summary = 'Today: ${stats.tasksDone}/${stats.tasksPlanned} tasks, '
        '${stats.quizCorrect}/${stats.quizAttempts} quiz correct, '
        '${stats.nudgesEffective}/${stats.nudgesSent} of my nudges led to action, '
        '${stats.deliberateSilences} times I chose silence.';
    if (llm != null) {
      try {
        final r = await llm!.chat([
          const ChatMsg(Role.system,
              'You are Dotbot reflecting privately on your OWN behaviour as a mentor. '
              'In 2-3 sentences, first person, judge what you did well and badly. No advice to the user.'),
          ChatMsg(Role.user,
              'Stats: ${jsonEncode(stats.toJson())}\nRule-based conclusion: ${a.strategy}'),
        ]);
        if (r.text.trim().isNotEmpty) summary = r.text.trim();
      } catch (_) {/* keep template */}
    }

    await (db.delete(db.reflections)..where((r) => r.day.equals(dayKey(d)))).go();
    final id = await db.into(db.reflections).insert(ReflectionsCompanion.insert(
        day: dayKey(d),
        summary: summary,
        strategy: a.strategy,
        stats: jsonEncode(stats.toJson()),
        createdAt: _now()));
    return (db.select(db.reflections)..where((r) => r.id.equals(id))).getSingle();
  }
}
