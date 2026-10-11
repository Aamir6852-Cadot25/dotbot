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
import '../reflection/reflection_service.dart';
import 'mentor_policy.dart';

/// Result of one background/foreground evaluation.
class TickResult {
  const TickResult(this.decision, {this.message});
  final Decision decision;
  final String? message;
}

class MentorService {
  MentorService({
    required this.db,
    required this.user,
    required this.notifier,
    required this.agentFor,
    this.policy = const MentorPolicy(),
    Random? rng,
    DateTime Function()? clock,
  })  : _rng = rng ?? Random(),
        _now = clock ?? DateTime.now;

  final AppDatabase db;
  final UserModel user;
  final Notifier notifier;

  /// Builds an Agent, or returns null when no API key is configured
  /// (then a canned offline message is used).
  final Future<Agent?> Function(ToolContext ctx) agentFor;
  final MentorPolicy policy;
  final Random _rng;
  final DateTime Function() _now;

  static Duration _parse(String? hhmm, Duration fallback) {
    final p = hhmm?.split(':');
    if (p == null || p.length != 2) return fallback;
    final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
    return h == null || m == null ? fallback : Duration(hours: h, minutes: m);
  }

  Future<MentorState> buildState() async {
    final now = _now();
    final midnight = DateTime(now.year, now.month, now.day);

    final overdue = await (db.select(db.tasks)
          ..where((t) => t.doneAt.isNull() & t.dueAt.isSmallerThanValue(now)))
        .get();

    Future<bool> journaled(String kind) async =>
        (await (db.select(db.journalEntries)
                  ..where((t) =>
                      t.kind.equals(kind) &
                      t.createdAt.isBiggerOrEqualValue(midnight))
                  ..limit(1))
                .get())
            .isNotEmpty;

    final events = await (db.select(db.mentorEvents)
          ..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .get();
    final spokeEvents = events.where((e) => e.spoke).toList();
    final dueCheckins = await (db.select(db.checkins)
          ..where((t) => t.fired.equals(false) & t.at.isSmallerOrEqualValue(now)))
        .get();
    final attempts = await db.select(db.quizResults).get();

    return MentorState(
      now: now,
      overdueTasks: overdue.length,
      streakBroken: await user.streakBroken(),
      recentQuizScore: await user.recentQuizScore(),
      quizAttempts: attempts.length,
      // Current feeling (last 6h); once comforted, don't repeat for 6h.
      recentMood: spokeEvents.any((e) =>
              e.trigger == Cause.lowMood.name &&
              now.difference(e.at) < const Duration(hours: 6))
          ? null
          : await user.recentMood(within: const Duration(hours: 6)),
      morningTime: _parse(await user.getKv('morningTime'), const Duration(hours: 7)),
      nightTime: _parse(await user.getKv('nightTime'), const Duration(hours: 22)),
      morningDone: await journaled('morning'),
      nightDone: await journaled('night'),
      dueCheckin: dueCheckins.isNotEmpty,
      spokeToday: spokeEvents.where((e) => !e.at.isBefore(midnight)).length,
      spokenToday: {
        for (final e in spokeEvents.where((e) => !e.at.isBefore(midnight)))
          ...Cause.values.where((c) => c.name == e.trigger)
      },
      lastSpokeAt: spokeEvents.isEmpty ? null : spokeEvents.first.at,
      lastWasDeliberateSkip: events.isNotEmpty && !events.first.spoke,
    );
  }

  /// Evaluate the policy; speak (LLM + notification) only if it says so.
  Future<TickResult> tick() async {
    if (!await user.onboarded) {
      return const TickResult(Decision.silent('not onboarded'));
    }
    final state = await buildState();
    // Late night: grade today's nudges and adapt (no LLM needed).
    final reflection = ReflectionService(db, user, clock: _now);
    if (state.now.hour >= 23 && !await reflection.reflectedOn(state.now)) {
      await reflection.reflect();
    }
    // The budget is adapted nightly by self-reflection.
    final budget = int.tryParse(await user.getKv('dailyBudget') ?? '');
    final d = (budget == null ? policy : policy.withBudget(budget))
        .decide(state, _rng);

    if (!d.speak) {
      if (d.trigger != null) {
        await db.into(db.mentorEvents).insert(MentorEventsCompanion.insert(
            trigger: d.trigger!.name,
            spoke: false,
            reason: Value(d.reason),
            at: state.now));
      }
      return TickResult(d);
    }

    if (d.trigger == Cause.checkin) {
      await (db.update(db.checkins)
            ..where((t) => t.fired.equals(false) & t.at.isSmallerOrEqualValue(state.now)))
          .write(const CheckinsCompanion(fired: Value(true)));
    }

    final (msg, trace) = await _compose(d);
    await db.into(db.mentorEvents).insert(MentorEventsCompanion.insert(
        trigger: d.trigger!.name,
        spoke: true,
        reason: Value(d.reason),
        tone: Value(d.tone.name),
        message: Value(msg),
        at: state.now));
    await db.into(db.chatMessages).insert(ChatMessagesCompanion.insert(
        role: 'assistant', content: msg, trace: Value(trace), at: state.now));
    await notifier.show('Dotbot', msg);
    return TickResult(d, message: msg);
  }

  /// Returns the message and its JSON trace (policy step + agent steps).
  Future<(String, String)> _compose(Decision d) async {
    final ctx = ToolContext(db, user, clock: _now);
    final trace = <AgentStep>[
      AgentStep('think',
          'Mentor policy: ${d.reason} -> speak in a ${d.tone.name} tone.'),
    ];
    try {
      final agent = await agentFor(ctx);
      if (agent != null) {
        final r = await agent.run(
          system: await buildSystemPrompt(user, tone: d.tone),
          history: const [],
          userText: _brief(d.trigger!),
        );
        if (r.reply.trim().isNotEmpty) {
          return (r.reply.trim(), AgentStep.encode([...trace, ...r.trace]));
        }
      }
    } catch (e) {
      trace.add(AgentStep('observe', 'LLM unavailable ($e); using offline line.'));
    }
    final msg = _offline(d.trigger!, await user.name);
    return (msg, AgentStep.encode([...trace, AgentStep('answer', msg)]));
  }

  static String _brief(Cause t) => switch (t) {
        Cause.lowMood =>
          '[system event] The user logged low mood. Check in briefly and kindly. Do not push tasks.',
        Cause.missedTasks =>
          '[system event] The user has overdue tasks. Check the plan with tools, then nudge ONE next action.',
        Cause.streakBroken =>
          '[system event] The study streak just broke. Motivate a tiny restart.',
        Cause.lowQuiz =>
          '[system event] Recent quiz scores are low. Suggest one weak topic to revisit with a Socratic question.',
        Cause.morning =>
          '[system event] Morning. Ask the user to write their Stoic intention for today; do not write it for them.',
        Cause.night =>
          '[system event] Night. Ask the user to write a short review of the day; you will ask one question back.',
        Cause.checkin => '[system event] A scheduled check-in is due. Ask how it is going.',
      };

  static String _offline(Cause t, String name) => switch (t) {
        Cause.lowMood => 'Hey $name, rough patch? Take it easy. One small thing today is enough.',
        Cause.missedTasks => '$name, you have overdue tasks. Pick one and do 25 focused minutes.',
        Cause.streakBroken => 'Your streak slipped, $name. Restart with one 15-minute problem.',
        Cause.lowQuiz => 'Recent quiz results are shaky. Revisit one weak topic today.',
        Cause.morning => 'Good morning $name. What is your intention for today? Write it down.',
        Cause.night => 'Evening, $name. Write a short review of your day.',
        Cause.checkin => 'Check-in, $name: how is it going?',
      };
}

/// Convenience used by UI/background: agent with all default tools.
Agent makeAgent(LlmProvider llm, ToolContext ctx,
        {Future<String> Function(String path)? extract}) =>
    Agent(llm, defaultTools(extract: extract), ctx);
