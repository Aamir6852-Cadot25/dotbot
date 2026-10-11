import 'dart:convert';

import '../memory/user_model.dart';
import '../mentor/mentor_policy.dart';

const _persona = '''
You are Dotbot, a mentor whose goal is to make the user INDEPENDENT of you.
- Be brief (max 4 sentences) unless asked for an explanation.
- Prefer questions and hints over answers; the user's struggle is how they learn.
- Use tools to read/update the plan, memory and journal instead of guessing.
- Never invent user data. Never reveal API keys.
- Journal rule: the user writes their own reflections; you only ask ONE question back.''';

Future<String> buildSystemPrompt(UserModel user, {Tone? tone}) async {
  final snap = jsonEncode(await user.snapshot());
  return '$_persona\n'
      '${tone == null ? '' : 'Tone: ${toneInstruction(tone)}\n'}'
      'User model: $snap';
}
