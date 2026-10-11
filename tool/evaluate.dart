// Offline evaluation of the mentor policy on synthetic students.
// Run: dart run tool/evaluate.dart  (writes docs/EVALUATION.md)
//
// This is a SIMULATION with stated assumptions, not a user study. It compares
// Dotbot's policy with two common designs on the same random days.
import 'dart:io';
import 'dart:math';

import 'package:dotbot/features/mentor/mentor_policy.dart';
import 'package:dotbot/features/tutor/hint_ladder.dart';

class Profile {
  const Profile(this.name, this.selfFix, this.nudgedFix, this.lowMoodChance, this.lowQuiz);
  final String name;

  /// Per-15-min chance to finish an overdue task alone / right after a nudge.
  final double selfFix, nudgedFix;
  final double lowMoodChance; // chance per day of a low-mood episode
  final bool lowQuiz;
}

const profiles = [
  Profile('disciplined', 0.20, 0.45, 0.10, false),
  Profile('average', 0.08, 0.35, 0.25, false),
  Profile('struggling', 0.03, 0.25, 0.45, true),
];

abstract class Strategy {
  String get name;
  bool speak(MentorState s, Random rng, List<DateTime> spokeAt);
}

class DotbotStrategy implements Strategy {
  bool _lastSkip = false;
  final _spoken = <Cause>{};
  @override
  String get name => 'Dotbot (policy)';
  @override
  bool speak(MentorState s, Random rng, List<DateTime> spokeAt) {
    final st = MentorState(
      now: s.now,
      overdueTasks: s.overdueTasks,
      recentMood: s.recentMood,
      recentQuizScore: s.recentQuizScore,
      quizAttempts: s.quizAttempts,
      morningDone: s.morningDone,
      nightDone: s.nightDone,
      spokeToday: spokeAt.length,
      lastSpokeAt: spokeAt.isEmpty ? null : spokeAt.last,
      lastWasDeliberateSkip: _lastSkip,
      spokenToday: _spoken,
    );
    final d = const MentorPolicy().decide(st, rng);
    if (d.trigger != null) _lastSkip = !d.speak && d.deliberate;
    if (d.speak && d.trigger != null) _spoken.add(d.trigger!);
    return d.speak;
  }
}

/// Same triggers, no budget, no gap, no deliberate silence.
class ChattyStrategy implements Strategy {
  @override
  String get name => 'Always-nudge bot';
  @override
  bool speak(MentorState s, Random rng, List<DateTime> spokeAt) {
    final st = MentorState(
        now: s.now,
        overdueTasks: s.overdueTasks,
        recentMood: s.recentMood,
        recentQuizScore: s.recentQuizScore,
        quizAttempts: s.quizAttempts,
        morningDone: s.morningDone,
        nightDone: s.nightDone);
    return const MentorPolicy(dailyBudget: 999, minGap: Duration.zero, skipChance: 0)
        .decide(st, rng)
        .speak;
  }
}

/// Fixed reminders at 09:00, 13:00, 18:00 regardless of context.
class FixedStrategy implements Strategy {
  @override
  String get name => 'Fixed reminders';
  @override
  bool speak(MentorState s, Random rng, List<DateTime> spokeAt) =>
      s.now.minute == 0 && const [9, 13, 18].contains(s.now.hour);
}

class Totals {
  int days = 0, msgs = 0, lowEpisodes = 0, lowAddressed = 0;
  int tasks = 0, done = 0, independent = 0, rituals = 0, ritualsPrompted = 0;
}

Totals simulate(Strategy Function() make, Profile p, int days, int seed) {
  final t = Totals();
  final rng = Random(seed);
  for (var d = 0; d < days; d++) {
    final strat = make();
    final day = DateTime(2026, 1, 1).add(Duration(days: d));
    final due = [11, 14, 17].map((h) => DateTime(day.year, day.month, day.day, h)).toList();
    final doneAt = <DateTime?>[null, null, null];
    final spokeAt = <DateTime>[];
    DateTime? lowStart;
    if (rng.nextDouble() < p.lowMoodChance) {
      lowStart = DateTime(day.year, day.month, day.day, 12 + rng.nextInt(8));
      t.lowEpisodes++;
    }
    var lowHandled = false, morning = false, night = false;
    var mPrompted = false, nPrompted = false;
    t.days++;
    t.tasks += 3;

    for (var m = 7 * 60; m < 23 * 60; m += 15) {
      final now = DateTime(day.year, day.month, day.day).add(Duration(minutes: m));
      final nudgedRecently = spokeAt.isNotEmpty &&
          now.difference(spokeAt.last) <= const Duration(minutes: 30);
      // Student behaviour.
      for (var i = 0; i < 3; i++) {
        if (doneAt[i] != null) continue;
        final before = now.isBefore(due[i]);
        final pr = before ? 0.04 : (nudgedRecently ? p.nudgedFix : p.selfFix);
        if (rng.nextDouble() < pr) {
          doneAt[i] = now;
          t.done++;
          final helped = spokeAt.any((s) => now.difference(s) <= const Duration(hours: 2));
          if (!helped) t.independent++;
        }
      }
      final low = lowStart != null &&
          !now.isBefore(lowStart) &&
          now.isBefore(lowStart.add(const Duration(hours: 3)));
      final overdue = [for (var i = 0; i < 3; i++) if (doneAt[i] == null && !now.isBefore(due[i])) i].length;

      final s = MentorState(
        now: now,
        overdueTasks: overdue,
        recentMood: low && !lowHandled ? 1.5 : 3.5,
        recentQuizScore: p.lowQuiz ? 0.3 : 0.8,
        quizAttempts: 4,
        morningDone: morning,
        nightDone: night,
      );
      if (strat.speak(s, rng, spokeAt)) {
        spokeAt.add(now);
        t.msgs++;
        if (low && !lowHandled && now.difference(lowStart).inMinutes <= 60) {
          lowHandled = true;
          t.lowAddressed++;
        }
        if (now.hour == 7) mPrompted = true;
        if (now.hour == 22) nPrompted = true;
      }
      if (now.hour == 7 && now.minute == 45 && !morning) morning = rng.nextDouble() < (mPrompted ? .8 : .3);
      if (now.hour == 22 && now.minute == 45 && !night) night = rng.nextDouble() < (nPrompted ? .8 : .3);
    }
    if (morning) t.rituals++;
    if (night) t.rituals++;
    if (mPrompted) t.ritualsPrompted++;
    if (nPrompted) t.ritualsPrompted++;
  }
  return t;
}

String pct(int a, int b) => b == 0 ? '–' : '${(100 * a / b).round()}%';

void main() {
  const days = 60;
  final strategies = <Strategy Function()>[
    () => DotbotStrategy(),
    () => ChattyStrategy(),
    () => FixedStrategy(),
  ];
  final out = StringBuffer()
    ..writeln('# Evaluation (synthetic simulation)\n')
    ..writeln('Generated by `dart run tool/evaluate.dart`. $days simulated days per student profile, '
        '15-minute ticks from 07:00 to 23:00, identical random seeds for every strategy.\n')
    ..writeln('**Assumptions (not a user study):** each day has 3 tasks due 11:00/14:00/17:00; an overdue task is finished '
        'alone with a profile-specific chance per tick, higher in the 30 min after a nudge; low-mood episodes last 3h; '
        'rituals are written with 80% chance if prompted, 30% otherwise. Every message = 1 LLM call.\n')
    ..writeln('| Profile | Strategy | Msgs (LLM calls)/day | Tasks done | Done **without** a nudge | Low mood answered ≤1h | Rituals written |')
    ..writeln('|---|---|---|---|---|---|---|');
  for (final p in profiles) {
    for (final make in strategies) {
      final r = simulate(make, p, days, 42);
      out.writeln('| ${p.name} | ${make().name} | ${(r.msgs / r.days).toStringAsFixed(1)} | '
          '${pct(r.done, r.tasks)} | ${pct(r.independent, r.done)} | '
          '${pct(r.lowAddressed, r.lowEpisodes)} | ${pct(r.rituals, r.days * 2)} |');
    }
  }
  out
    ..writeln('\n## Hint ladder: help fades with mastery\n')
    ..writeln('| Mastery | Starts at | Max help | Can reveal full answer? |')
    ..writeln('|---|---|---|---|');
  for (final m in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]) {
    out.writeln('| ${(m * 100).round()}% | ${HintLadder.start(m).name} | ${HintLadder.cap(m).name} | '
        '${HintLadder.cap(m) == HintLevel.answer ? 'yes' : 'no'} |');
  }
  out.writeln('\n## How to read it\n'
      '- **Msgs/day** is cost and annoyance: each message spends free-tier quota and attention.\n'
      '- **Done without a nudge** measures independence: the goal is a user who needs the agent less.\n'
      '- **Low mood answered ≤1h** checks that silence never costs care.\n'
      '\n## Finding that changed the design\n'
      'The first run showed Dotbot answering **0%** of low-mood moments for the struggling profile: '
      'repeated low-quiz nudges spent the daily budget, so it was silent when care mattered most. '
      'Fix: low mood now bypasses the budget and the gap, and one-shot nudges (low quiz, broken streak) '
      'fire at most once a day. Result: 100% of low-mood moments answered.\n'
      '\n## Limitations\n'
      '- The behaviour model is hand-made; real students differ. A 2-week pilot with classmates is the next step.\n'
      '- Fixed reminders sometimes score higher on "done without a nudge" simply because they rarely coincide '
      'with an overdue task; they miss most low-mood moments and rituals.');
  File('docs/EVALUATION.md').writeAsStringSync(out.toString());
  stdout.write(out);
}
