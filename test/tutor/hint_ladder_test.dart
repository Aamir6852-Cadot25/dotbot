import 'package:dotbot/features/tutor/hint_ladder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cap tightens as mastery grows', () {
    expect(HintLadder.cap(0.1), HintLevel.answer);
    expect(HintLadder.cap(0.5), HintLevel.partial);
    expect(HintLadder.cap(0.9), HintLevel.hint);
  });

  test('beginners skip the bare question', () {
    expect(HintLadder.start(0.0), HintLevel.hint);
    expect(HintLadder.start(0.5), HintLevel.question);
  });

  test('ladder climbs question->hint->partial->answer for weak learners', () {
    var l = HintLevel.question;
    final seen = [l];
    while (true) {
      final n = HintLadder.next(l, 0.1);
      if (n == null) break;
      l = n;
      seen.add(l);
    }
    expect(seen, HintLevel.values);
  });

  test('strong learner is never given the answer (productive struggle)', () {
    expect(HintLadder.next(HintLevel.hint, 0.9), isNull);
    expect(HintLadder.next(HintLevel.partial, 0.5), isNull);
  });
}
