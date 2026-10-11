import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:dotbot/core/db/database.dart';
import 'package:dotbot/features/memory/user_model.dart';
import 'package:dotbot/features/reflection/reflection_service.dart';
import 'package:flutter_test/flutter_test.dart';

DayStats stats({int sent = 0, int eff = 0, int quiz = 0, int correct = 0,
        double hints = 0, double? mood, int planned = 0, int done = 0,
        Map<String, List<int>> tone = const {}}) =>
    DayStats(
        tasksPlanned: planned,
        tasksDone: done,
        quizAttempts: quiz,
        quizCorrect: correct,
        avgHintLevel: hints,
        nudgesSent: sent,
        nudgesEffective: eff,
        deliberateSilences: 0,
        avgMood: mood,
        effectByTone: tone);

void main() {
  test('ignored nudges shrink the budget (speak less)', () {
    final a = ReflectionService.adapt(stats(sent: 3, eff: 0), 3);
    expect(a.budget, 2);
    expect(a.strategy, contains('speak less'));
  });

  test('effective nudges allow one more', () {
    expect(ReflectionService.adapt(stats(sent: 3, eff: 3), 3).budget, 4);
  });

  test('strong unaided quiz performance -> hold back help', () {
    final a = ReflectionService.adapt(stats(quiz: 4, correct: 4, hints: 0), 3);
    expect(a.strategy, contains('hold back'));
  });

  test('low mood -> gentle + people', () {
    expect(ReflectionService.adapt(stats(mood: 1.5), 3).strategy, contains('people'));
  });

  test('picks the tone that worked', () {
    final a = ReflectionService.adapt(
        stats(tone: {'firm': [2, 2], 'warm': [0, 2]}), 3);
    expect(a.strategy, contains('firm tone'));
  });

  test('reflect grades nudges by whether the user acted within 2h', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final now = DateTime(2026, 3, 3, 23);
    final user = UserModel(db, clock: () => now);
    final t0 = DateTime(2026, 3, 3, 14);
    await db.into(db.mentorEvents).insert(MentorEventsCompanion.insert(
        trigger: 'missedTasks', spoke: true, tone: const Value('firm'), at: t0));
    await db.into(db.mentorEvents).insert(MentorEventsCompanion.insert(
        trigger: 'lowQuiz', spoke: true, tone: const Value('warm'), at: DateTime(2026, 3, 3, 18)));
    await db.into(db.tasks).insert(TasksCompanion.insert(
        title: 'x', createdAt: t0, doneAt: Value(t0.add(const Duration(minutes: 40)))));
    final r = await ReflectionService(db, user, clock: () => now).reflect();
    final ev = await db.select(db.mentorEvents).get();
    expect(ev.map((e) => e.effective), [true, false]);
    expect(r.strategy, contains('firm tone'));
    expect(await user.getKv('strategy'), r.strategy);
    await db.close();
  });
}
