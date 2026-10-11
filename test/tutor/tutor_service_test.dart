import 'package:drift/native.dart';
import 'package:dotbot/core/db/database.dart';
import 'package:dotbot/core/llm/llm_provider.dart';
import 'package:dotbot/features/memory/user_model.dart';
import 'package:dotbot/features/tutor/hint_ladder.dart';
import 'package:dotbot/features/tutor/tutor_service.dart';
import 'package:flutter_test/flutter_test.dart';

class Scripted implements LlmProvider {
  Scripted(this.replies);
  final List<String> replies;
  final prompts = <String>[];
  @override
  String get id => 's';
  @override
  Future<LlmResponse> chat(List<ChatMsg> m, {List<ToolSpec> tools = const []}) async {
    prompts.add(m.last.content);
    return LlmResponse(text: replies.removeAt(0));
  }
}

void main() {
  late AppDatabase db;
  late UserModel user;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    user = UserModel(db);
  });
  tearDown(() => db.close());

  test('question difficulty follows mastery; hint uses level instruction', () async {
    final llm = Scripted(['Q?', 'H']);
    final t = TutorService(llm, user);
    expect(await t.newQuestion('arrays'), 'Q?');
    expect(llm.prompts.first, contains('easy'));
    await t.hint('arrays', 'Q?', HintLevel.hint);
    expect(llm.prompts.last, contains(HintLadder.instruction(HintLevel.hint)));
  });

  test('evaluate parses CORRECT / INCORRECT', () async {
    final t = TutorService(Scripted(['CORRECT\nNice.', 'INCORRECT\nCheck bounds.']), user);
    expect((await t.evaluate('q', 'a')).correct, true);
    final e = await t.evaluate('q', 'a');
    expect(e.correct, false);
    expect(e.feedback, 'Check bounds.');
  });

  test('finishing updates mastery', () async {
    final t = TutorService(Scripted([]), user);
    final m = await t.finish('dp', true, null);
    expect(m, greaterThan(0));
  });
}
