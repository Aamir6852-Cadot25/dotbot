import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:dotbot/core/db/database.dart';
import 'package:dotbot/core/llm/llm_provider.dart';
import 'package:dotbot/core/notifications/notifier.dart';
import 'package:dotbot/features/agent/agent.dart';
import 'package:dotbot/features/agent/tools/tools.dart';
import 'package:dotbot/features/memory/user_model.dart';
import 'package:dotbot/features/mentor/mentor_policy.dart';
import 'package:dotbot/features/mentor/mentor_service.dart';
import 'package:flutter_test/flutter_test.dart';

class Echo implements LlmProvider {
  int calls = 0;
  String? lastSystem;
  @override
  String get id => 'echo';
  @override
  Future<LlmResponse> chat(List<ChatMsg> m, {List<ToolSpec> tools = const []}) async {
    calls++;
    lastSystem = m.first.content;
    return const LlmResponse(text: 'Stay on it.');
  }
}

class Never implements Random {
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0.99;
  @override
  int nextInt(int max) => 0;
}

void main() {
  late AppDatabase db;
  late UserModel user;
  late RecordingNotifier notes;
  late Echo llm;
  final now = DateTime(2026, 3, 3, 12);

  MentorService svc({bool withKey = true}) => MentorService(
        db: db,
        user: user,
        notifier: notes,
        rng: Never(),
        clock: () => now,
        agentFor: (ctx) async =>
            withKey ? Agent(llm, defaultTools(), ctx) : null,
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    user = UserModel(db, clock: () => now);
    notes = RecordingNotifier();
    llm = Echo();
    await user.saveProfile(name: 'Aamir', goals: ['DSA']);
  });
  tearDown(() => db.close());

  test('silent day costs zero LLM calls', () async {
    final r = await svc().tick();
    expect(r.decision.speak, false);
    expect(llm.calls, 0);
    expect(notes.shown, isEmpty);
  });

  test('low mood -> gentle LLM message + notification', () async {
    await user.logMood(1, 2);
    final r = await svc().tick();
    expect(r.decision.trigger, Cause.lowMood);
    expect(llm.calls, 1);
    expect(llm.lastSystem, contains('gentle'));
    expect(notes.shown.single.$2, 'Stay on it.');
  });

  test('silence budget / gap stop a second message right away', () async {
    await user.logMood(1, 2);
    await svc().tick();
    final r2 = await svc().tick();
    expect(r2.decision.speak, false);
    expect(notes.shown.length, 1);
  });

  test('no API key -> offline fallback text, still notifies', () async {
    await user.logMood(1, 2);
    final r = await svc(withKey: false).tick();
    expect(r.message, contains('Aamir'));
    expect(notes.shown.length, 1);
  });

  test('overdue tasks trigger firm nudge', () async {
    await db.into(db.tasks).insert(TasksCompanion.insert(
        title: 'a', createdAt: now, dueAt: Value(now.subtract(const Duration(hours: 3)))));
    await db.into(db.tasks).insert(TasksCompanion.insert(
        title: 'b', createdAt: now, dueAt: Value(now.subtract(const Duration(hours: 2)))));
    final r = await svc().tick();
    expect(r.decision.trigger, Cause.missedTasks);
    expect(llm.lastSystem, contains('firm'));
  });
}
