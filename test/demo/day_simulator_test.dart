import 'package:drift/native.dart';
import 'package:dotbot/core/db/database.dart';
import 'package:dotbot/core/llm/demo_provider.dart';
import 'package:dotbot/core/notifications/notifier.dart';
import 'package:dotbot/features/demo/day_simulator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('simulated student day exercises every agent behaviour', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final notes = RecordingNotifier();
    final events = <SimEvent>[];
    await DaySimulator(
      db: db,
      llm: DemoProvider(),
      notifier: notes,
      day: DateTime(2026, 3, 3),
      pause: Duration.zero,
    ).run(events.add);

    String titles() => events.map((e) => e.title).join('\n');
    expect(titles(), contains('morning'));
    expect(events.where((e) => e.actor == 'silent'), isNotEmpty,
        reason: 'deliberate non-intervention');
    expect(titles(), contains('missedTasks (firm)'));
    expect(titles(), contains('lowMood (gentle)'));
    expect(titles(), contains('night'));
    expect(titles(), contains('Self-reflection'));

    // Tools really ran: tasks planned, memory saved, reasoning traced.
    expect((await db.select(db.tasks).get()).length, greaterThanOrEqualTo(5));
    expect((await db.select(db.facts).get()).single.content, contains('Rahul'));
    expect(events.any((e) => e.trace.any((s) => s.kind == 'tool')), true);

    // Reflection graded its own nudges and wrote a strategy.
    final ev = await db.select(db.mentorEvents).get();
    expect(ev.where((e) => e.spoke && e.effective != null), isNotEmpty);
    expect(notes.shown.length, greaterThanOrEqualTo(4));
    await db.close();
  });
}
