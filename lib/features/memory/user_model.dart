import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/db/database.dart';

/// The agent's long-term model of the user: profile, mastery, streaks, mood.
class UserModel {
  UserModel(this.db, {DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _now;

  // ---- key/value profile ----
  Future<String?> getKv(String key) async {
    final row = await (db.select(db.kv)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setKv(String key, String value) => db
      .into(db.kv)
      .insertOnConflictUpdate(KvCompanion.insert(key: key, value: value));

  Future<String> get name async => await getKv('name') ?? 'friend';

  Future<List<String>> get goals async {
    final raw = await getKv('goals');
    return raw == null ? [] : List<String>.from(jsonDecode(raw) as List);
  }

  Future<void> saveProfile({
    required String name,
    required List<String> goals,
    String morningTime = '07:00',
    String nightTime = '22:00',
  }) async {
    await setKv('name', name);
    await setKv('goals', jsonEncode(goals));
    await setKv('morningTime', morningTime);
    await setKv('nightTime', nightTime);
    await setKv('onboarded', '1');
  }

  Future<bool> get onboarded async => await getKv('onboarded') == '1';

  // ---- mastery ----
  Future<double> mastery(String topic) async {
    final row = await (db.select(db.topicMasteryRows)
          ..where((t) => t.topic.equals(topic)))
        .getSingleOrNull();
    return row?.mastery ?? 0.0;
  }

  /// Moving average; hints taken reduce credit for a correct answer.
  /// Returns the new mastery.
  Future<double> recordQuiz({
    required String topic,
    required bool correct,
    int hintLevel = 0,
  }) async {
    final now = _now();
    await db.into(db.quizResults).insert(QuizResultsCompanion.insert(
        topic: topic, correct: correct, hintLevel: Value(hintLevel), at: now));
    final row = await (db.select(db.topicMasteryRows)
          ..where((t) => t.topic.equals(topic)))
        .getSingleOrNull();
    final old = row?.mastery ?? 0.0;
    final credit = correct ? (1.0 - 0.2 * hintLevel).clamp(0.2, 1.0) : 0.0;
    final updated = (old * 0.8 + credit * 0.2).clamp(0.0, 1.0);
    await db.into(db.topicMasteryRows).insertOnConflictUpdate(
        TopicMasteryRowsCompanion.insert(
            topic: topic,
            mastery: Value(updated),
            attempts: Value((row?.attempts ?? 0) + 1),
            updatedAt: now));
    if (correct) await markStudied();
    return updated;
  }

  Future<List<String>> weakTopics({double below = 0.4, int limit = 5}) async {
    final rows = await (db.select(db.topicMasteryRows)
          ..where((t) => t.mastery.isSmallerThanValue(below))
          ..orderBy([(t) => OrderingTerm.asc(t.mastery)])
          ..limit(limit))
        .get();
    return rows.map((r) => r.topic).toList();
  }

  Future<Map<String, double>> allMastery() async {
    final rows = await db.select(db.topicMasteryRows).get();
    return {for (final r in rows) r.topic: r.mastery};
  }

  /// Fraction of the last [n] quiz answers that were correct; null if none.
  Future<double?> recentQuizScore({int n = 5}) async {
    final rows = await (db.select(db.quizResults)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(n))
        .get();
    if (rows.isEmpty) return null;
    return rows.where((r) => r.correct).length / rows.length;
  }

  // ---- streak ----
  static String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> markStudied() async {
    final today = _day(_now());
    final last = await getKv('lastStudyDay');
    if (last == today) return;
    final yesterday = _day(_now().subtract(const Duration(days: 1)));
    final streak = int.tryParse(await getKv('streak') ?? '0') ?? 0;
    await setKv('streak', (last == yesterday ? streak + 1 : 1).toString());
    await setKv('lastStudyDay', today);
  }

  /// Current streak; 0 if the last study day is older than yesterday.
  Future<int> streak() async {
    final last = await getKv('lastStudyDay');
    if (last == null) return 0;
    final today = _day(_now());
    final yesterday = _day(_now().subtract(const Duration(days: 1)));
    if (last != today && last != yesterday) return 0;
    return int.tryParse(await getKv('streak') ?? '0') ?? 0;
  }

  /// True if the user had a streak (>=2) that has lapsed.
  Future<bool> streakBroken() async {
    final stored = int.tryParse(await getKv('streak') ?? '0') ?? 0;
    return stored >= 2 && await streak() == 0;
  }

  // ---- mood ----
  Future<void> logMood(int mood, int energy) =>
      db.into(db.moodLogs).insert(MoodLogsCompanion.insert(
          mood: mood.clamp(1, 5), energy: energy.clamp(1, 5), at: _now()));

  Future<List<MoodLog>> moodHistory({int limit = 14}) =>
      (db.select(db.moodLogs)
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(limit))
          .get();

  /// Mean mood of the last [n] logs (null if none).
  Future<double?> recentMood({int n = 3}) async {
    final h = await moodHistory(limit: n);
    if (h.isEmpty) return null;
    return h.map((m) => m.mood).reduce((a, b) => a + b) / h.length;
  }

  /// Compact snapshot injected into LLM prompts.
  Future<Map<String, Object?>> snapshot() async => {
        'name': await name,
        'goals': await goals,
        'streak': await streak(),
        'mastery': await allMastery(),
        'weakTopics': await weakTopics(),
        'recentMood': await recentMood(),
      };
}
