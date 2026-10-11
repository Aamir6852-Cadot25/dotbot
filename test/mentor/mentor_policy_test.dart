import 'dart:math';

import 'package:dotbot/features/mentor/mentor_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Random whose nextDouble is fixed.
class FixedRandom implements Random {
  FixedRandom(this.v);
  final double v;
  @override
  double nextDouble() => v;
  @override
  bool nextBool() => v > .5;
  @override
  int nextInt(int max) => 0;
}

final noon = DateTime(2026, 3, 3, 12);
const policy = MentorPolicy();
final never = FixedRandom(0.99); // never skips
final always = FixedRandom(0.0); // always skips when allowed

void main() {
  test('nothing happening -> silent', () {
    final d = policy.decide(MentorState(now: noon), never);
    expect(d.speak, false);
  });

  test('low mood -> gentle, even when skip roll would have silenced', () {
    final d = policy.decide(MentorState(now: noon, recentMood: 1.5), always);
    expect(d.speak, true);
    expect(d.trigger, Cause.lowMood);
    expect(d.tone, Tone.gentle);
  });

  test('missed tasks -> firm', () {
    final d = policy.decide(MentorState(now: noon, overdueTasks: 3), never);
    expect(d.trigger, Cause.missedTasks);
    expect(d.tone, Tone.firm);
  });

  test('deliberate non-intervention on a nudge, but not twice in a row', () {
    final s = MentorState(now: noon, overdueTasks: 2);
    final first = policy.decide(s, always);
    expect(first.speak, false);
    expect(first.deliberate, true);
    final second = policy.decide(
        MentorState(now: noon, overdueTasks: 2, lastWasDeliberateSkip: true),
        always);
    expect(second.speak, true);
  });

  test('silence budget caps proactive messages per day', () {
    final d = policy.decide(
        MentorState(now: noon, recentMood: 1, spokeToday: 3), never);
    expect(d.speak, false);
    expect(d.reason, contains('budget'));
  });

  test('minimum gap between messages', () {
    final d = policy.decide(
        MentorState(
            now: noon,
            recentMood: 1,
            lastSpokeAt: noon.subtract(const Duration(minutes: 30))),
        never);
    expect(d.speak, false);
  });

  test('morning ritual fires inside window only, once', () {
    final inWin = DateTime(2026, 3, 3, 7, 10);
    expect(policy.decide(MentorState(now: inWin), never).trigger, Cause.morning);
    expect(
        policy.decide(MentorState(now: inWin, morningDone: true), never).speak,
        false);
    expect(policy.decide(MentorState(now: DateTime(2026, 3, 3, 9)), never).speak,
        false);
  });

  test('night ritual', () {
    final d = policy.decide(MentorState(now: DateTime(2026, 3, 3, 22, 5)), never);
    expect(d.trigger, Cause.night);
  });

  test('low quiz needs enough attempts', () {
    expect(
        policy
            .decide(MentorState(now: noon, recentQuizScore: 0.1, quizAttempts: 2), never)
            .speak,
        false);
    expect(
        policy
            .decide(MentorState(now: noon, recentQuizScore: 0.1, quizAttempts: 4), never)
            .trigger,
        Cause.lowQuiz);
  });

  test('due check-in bypasses budget and gap', () {
    final d = policy.decide(
        MentorState(now: noon, dueCheckin: true, spokeToday: 9), never);
    expect(d.trigger, Cause.checkin);
  });

  test('streak broken -> firm', () {
    final d = policy.decide(MentorState(now: noon, streakBroken: true), never);
    expect(d.trigger, Cause.streakBroken);
    expect(d.tone, Tone.firm);
  });
}
