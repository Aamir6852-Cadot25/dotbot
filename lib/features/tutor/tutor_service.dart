import '../../core/llm/llm_provider.dart';
import '../memory/user_model.dart';
import 'hint_ladder.dart';

class Evaluation {
  const Evaluation(this.correct, this.feedback);
  final bool correct;
  final String feedback;
}

/// Socratic tutor on top of a plain LlmProvider (no tools needed).
class TutorService {
  TutorService(this.llm, this.user);
  final LlmProvider llm;
  final UserModel user;

  static const _sys =
      'You are a Socratic Java/DSA tutor for a placement-prep student. '
      'Be concise. Never reveal more than the requested level allows.';

  Future<String> _ask(String prompt) async =>
      (await llm.chat([const ChatMsg(Role.system, _sys), ChatMsg(Role.user, prompt)]))
          .text
          .trim();

  Future<String> newQuestion(String topic) async {
    final m = await user.mastery(topic);
    final difficulty = m < 0.3 ? 'easy' : (m < 0.7 ? 'medium' : 'hard');
    return _ask('Ask ONE $difficulty interview-style question about "$topic". '
        'Question only, no answer, no hints.');
  }

  Future<String> hint(String topic, String question, HintLevel level) =>
      _ask('Topic: $topic\nQuestion: $question\n${HintLadder.instruction(level)}');

  /// First line of the model reply must be CORRECT or INCORRECT.
  Future<Evaluation> evaluate(String question, String answer) async {
    final r = await _ask('Question: $question\nStudent answer: $answer\n'
        'Reply with the single word CORRECT or INCORRECT on the first line, '
        'then one sentence of feedback (do not give the full solution if incorrect).');
    final lines = r.split('\n');
    final ok = lines.first.trim().toUpperCase().startsWith('CORRECT');
    return Evaluation(ok, lines.skip(1).join(' ').trim());
  }

  /// Grade and update the user model. Hint use lowers credit.
  Future<double> finish(String topic, bool correct, HintLevel? used) =>
      user.recordQuiz(topic: topic, correct: correct, hintLevel: used?.index ?? 0);
}
