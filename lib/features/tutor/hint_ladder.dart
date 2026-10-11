/// Socratic hint ladder. Higher mastery => the tutor holds back longer and
/// may never reveal the answer ("productive struggle").
enum HintLevel { question, hint, partial, answer }

class HintLadder {
  const HintLadder._();

  /// Highest level the tutor may offer for a learner at [mastery] (0..1).
  static HintLevel cap(double mastery) {
    if (mastery >= 0.7) return HintLevel.hint;
    if (mastery >= 0.4) return HintLevel.partial;
    return HintLevel.answer;
  }

  /// Where the ladder starts: complete beginners skip the bare question.
  static HintLevel start(double mastery) =>
      mastery < 0.2 ? HintLevel.hint : HintLevel.question;

  /// Next rung after [current], or null when the cap says "keep struggling".
  static HintLevel? next(HintLevel current, double mastery) {
    if (current.index >= cap(mastery).index) return null;
    return HintLevel.values[current.index + 1];
  }

  /// Instruction handed to the LLM for the given rung.
  static String instruction(HintLevel level) => switch (level) {
        HintLevel.question =>
          'Ask ONE guiding question. Do not hint at the solution.',
        HintLevel.hint =>
          'Give ONE small hint (a concept or direction). No code, no solution.',
        HintLevel.partial =>
          'Show the first step or a skeleton with blanks. Leave the key insight to the learner.',
        HintLevel.answer =>
          'Explain the full solution step by step, then ask the learner to restate it.',
      };
}
