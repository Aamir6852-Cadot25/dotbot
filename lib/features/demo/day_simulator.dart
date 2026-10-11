import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/db/database.dart';
import '../../core/llm/llm_provider.dart';
import '../../core/notifications/notifier.dart';
import '../agent/agent.dart';
import '../agent/prompts.dart';
import '../agent/tools/tool.dart';
import '../agent/tools/tools.dart';
import '../memory/user_model.dart';
import '../mentor/mentor_service.dart';
import '../reflection/reflection_service.dart';
import '../tutor/hint_ladder.dart';
import '../tutor/tutor_service.dart';

/// One beat of the simulated day, shown on the demo timeline.
class SimEvent {
  const SimEvent(this.time, this.actor, this.title, this.detail, {this.trace = const []});
  final DateTime time;

  /// user | agent | silent | system
  final String actor;
  final String title;
  final String detail;
  final List<AgentStep> trace;
}

/// Scripted dice: first non-urgent nudge is skipped on purpose, then speak.
class _ScriptedRandom implements Random {
  final _values = [0.1];
  @override
  double nextDouble() => _values.isEmpty ? 0.99 : _values.removeAt(0);
  @override
  bool nextBool() => false;
  @override
  int nextInt(int max) => 0;
}

/// Replays "a student's day" in ~1 minute with a fake clock, driving the REAL
/// policy, agent, tools, tutor and reflection. Used for live demos.
class DaySimulator {
  DaySimulator({
    required this.db,
    required this.llm,
    required this.notifier,
    DateTime? day,
    this.pause = const Duration(milliseconds: 900),
  }) : day = day ?? DateTime.now();

  final AppDatabase db;
  final LlmProvider llm;
  final Notifier notifier;
  final DateTime day;
  final Duration pause;

  late DateTime _now;
  DateTime _at(int h, [int m = 0]) => DateTime(day.year, day.month, day.day, h, m);

  Future<void> run(void Function(SimEvent e) emit) async {
    _now = _at(7);
    DateTime clock() => _now;
    final user = UserModel(db, clock: clock);
    final ctx = ToolContext(db, user, clock: clock);
    final agent = Agent(llm, defaultTools(), ctx);
    final mentor = MentorService(
      db: db,
      user: user,
      notifier: notifier,
      agentFor: (_) async => agent,
      rng: _ScriptedRandom(),
      clock: clock,
    );
    final tutor = TutorService(llm, user);

    Future<void> step(int h, int m, SimEvent Function() make) async {
      _now = _at(h, m);
      emit(make());
      await Future<void>.delayed(pause);
    }

    Future<void> tick(int h, int m) async {
      _now = _at(h, m);
      final r = await mentor.tick();
      final last = await (db.select(db.chatMessages)
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(1))
          .getSingleOrNull();
      emit(r.decision.speak
          ? SimEvent(_now, 'agent', 'Dotbot speaks · ${r.decision.trigger!.name} (${r.decision.tone.name})',
              r.message ?? '', trace: AgentStep.decode(last?.trace))
          : r.decision.deliberate
              ? SimEvent(_now, 'silent', 'Dotbot chooses silence on purpose',
                  '${r.decision.trigger!.name} detected, but it lets the student self-correct. '
                  'It never skips twice in a row.')
              : SimEvent(_now, 'silent', 'Dotbot stays silent', r.decision.reason));
      await Future<void>.delayed(pause);
    }

    Future<void> say(int h, int m, String text) async {
      _now = _at(h, m);
      emit(SimEvent(_now, 'user', 'Student', text));
      final r = await agent.run(
          system: await buildSystemPrompt(user), history: const [], userText: text);
      await db.into(db.chatMessages).insert(ChatMessagesCompanion.insert(
          role: 'user', content: text, at: _now));
      await db.into(db.chatMessages).insert(ChatMessagesCompanion.insert(
          role: 'assistant', content: r.reply, trace: Value(AgentStep.encode(r.trace)), at: _now));
      emit(SimEvent(_now, 'agent', 'Dotbot replies', r.reply, trace: r.trace));
      await Future<void>.delayed(pause);
    }

    Future<String> journal(String kind, String body) async {
      String q;
      try {
        q = (await llm.chat([
          const ChatMsg(Role.system,
              'You are a Stoic mentor. Reply with exactly ONE short, probing question and nothing else.'),
          ChatMsg(Role.user, body),
        ]))
            .text
            .trim();
      } catch (_) {
        q = 'What is one thing you would change?';
      }
      await db.into(db.journalEntries).insert(JournalEntriesCompanion.insert(
          kind: kind, body: body, agentQuestion: Value(q), createdAt: _now));
      return q;
    }

    Future<int> task(String title, DateTime due) => db.into(db.tasks).insert(
        TasksCompanion.insert(title: title, createdAt: _at(7), dueAt: Value(due)));

    Future<void> complete(int id) => (db.update(db.tasks)..where((t) => t.id.equals(id)))
        .write(TasksCompanion(doneAt: Value(_now)));

    // ---------------- the day ----------------
    if (!await user.onboarded) {
      await user.saveProfile(name: 'Aamir', goals: ['Java', 'DSA', 'placements']);
    }
    await step(7, 0, () => SimEvent(_now, 'system', 'Day starts',
        'Leftover from yesterday: 2 unfinished tasks. Dotbot is silent by default.'));
    final r1 = await task('Revise recursion (from yesterday)', _at(9, 30));
    await task('Finish OOP notes (from yesterday)', _at(10));

    await tick(7, 5); // morning ritual

    _now = _at(7, 10);
    const intention = 'Today I will finish arrays practice before lunch and not open Instagram until 6.';
    final q1 = await journal('morning', intention);
    await step(7, 10, () => SimEvent(_now, 'user', 'Writes morning intention (own words)', intention));
    await step(7, 11, () => SimEvent(_now, 'agent', 'Asks ONE question back', q1));

    _now = _at(7, 15);
    await user.logMood(4, 4);
    await step(7, 15, () => SimEvent(_now, 'user', 'One-tap mood', 'Mood 4/5 · Energy 4/5'));

    await say(9, 0, 'Plan my day');
    // Make sure there is a morning task to (not) do, whatever the model planned.
    final open = await (db.select(db.tasks)..where((t) => t.doneAt.isNull())).get();
    final arrays = open.firstWhere((t) => t.title.toLowerCase().contains('array'),
        orElse: () => open.first);
    if (arrays.dueAt == null || arrays.dueAt!.isAfter(_at(12))) {
      await (db.update(db.tasks)..where((t) => t.id.equals(arrays.id)))
          .write(TasksCompanion(dueAt: Value(_at(11))));
    }

    // Tutor with a fading hint ladder.
    _now = _at(10, 30);
    final m0 = await user.mastery('arrays');
    final q = await tutor.newQuestion('arrays');
    await step(10, 30, () => SimEvent(_now, 'agent', 'Tutor asks (mastery ${(m0 * 100).round()}%)', q));
    final lvl = HintLadder.start(m0);
    final h = await tutor.hint('arrays', q, lvl);
    await step(10, 35, () => SimEvent(_now, 'agent',
        'Hint ladder: "${lvl.name}" (cap: ${HintLadder.cap(m0).name})', h));
    const ans = 'Keep max and second max, update both in one pass, O(n).';
    final ev = await tutor.evaluate(q, ans);
    final m1 = await tutor.finish('arrays', ev.correct, lvl);
    await step(10, 45, () => SimEvent(_now, 'user', 'Answers: ${ev.correct ? 'correct' : 'incorrect'}',
        '$ans\nMastery arrays: ${(m0 * 100).round()}% → ${(m1 * 100).round()}% (hint used, so less credit)'));

    await tick(12, 30); // 3 overdue -> deliberate silence

    _now = _at(13, 15);
    await complete(arrays.id);
    await user.markStudied();
    await step(13, 15, () => SimEvent(_now, 'user', 'Finishes arrays task on their own',
        'No reminder needed. This is the independence Dotbot is designed for.'));

    await tick(14, 30); // overdue still -> firm nudge now

    _now = _at(15, 10);
    await complete(r1);
    await step(15, 10, () => SimEvent(_now, 'user', 'Acts on the nudge', 'Completes "Revise recursion".'));

    _now = _at(19);
    await user.logMood(1, 2);
    await step(19, 0, () => SimEvent(_now, 'user', 'One-tap mood', 'Mood 1/5 · Energy 2/5'));
    await tick(19, 5); // low mood -> gentle

    await say(19, 20, 'I feel lonely today');
    await say(19, 30, 'Remember my best friend Rahul loves cricket');

    await tick(22, 5); // night ritual
    _now = _at(22, 10);
    const review = 'Did arrays and recursion. Skipped OOP notes. Felt low in the evening but called Rahul.';
    final q2 = await journal('night', review);
    await step(22, 10, () => SimEvent(_now, 'user', 'Writes night review', review));
    await step(22, 11, () => SimEvent(_now, 'agent', 'Asks ONE question back', q2));

    _now = _at(23, 30);
    final refl = await ReflectionService(db, user, llm: llm, clock: clock).reflect(day: _now);
    await step(23, 30, () => SimEvent(_now, 'agent', 'Self-reflection on its OWN behaviour',
        '${refl.summary}\n\nStrategy for tomorrow: ${refl.strategy}'));
  }
}
