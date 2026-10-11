import 'package:drift/native.dart';
import 'package:dotbot/core/db/database.dart';
import 'package:dotbot/features/memory/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  var now = DateTime(2026, 1, 10, 9);
  late UserModel m;

  setUp(() {
    now = DateTime(2026, 1, 10, 9);
    db = AppDatabase(NativeDatabase.memory());
    m = UserModel(db, clock: () => now);
  });
  tearDown(() => db.close());

  test('profile round trip', () async {
    expect(await m.onboarded, false);
    await m.saveProfile(name: 'Aamir', goals: ['Java', 'DSA']);
    expect(await m.name, 'Aamir');
    expect(await m.goals, ['Java', 'DSA']);
    expect(await m.onboarded, true);
  });

  test('mastery rises with unaided answers more than with hints', () async {
    final a = await m.recordQuiz(topic: 'arrays', correct: true);
    final b = await m.recordQuiz(topic: 'trees', correct: true, hintLevel: 3);
    expect(a, greaterThan(b));
    expect(await m.recordQuiz(topic: 'dp', correct: false), 0.0);
    expect(await m.weakTopics(), contains('dp'));
  });

  test('streak increments daily and breaks after a gap', () async {
    await m.markStudied();
    now = now.add(const Duration(days: 1));
    await m.markStudied();
    expect(await m.streak(), 2);
    now = now.add(const Duration(days: 3));
    expect(await m.streak(), 0);
    expect(await m.streakBroken(), true);
  });

  test('mood average', () async {
    await m.logMood(2, 3);
    await m.logMood(4, 3);
    expect(await m.recentMood(), 3.0);
  });
}
