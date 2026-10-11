import 'package:drift/native.dart';
import 'package:dotbot/core/db/database.dart';
import 'package:dotbot/core/llm/llm_provider.dart';
import 'package:dotbot/features/agent/agent.dart';
import 'package:dotbot/features/agent/tools/tool.dart';
import 'package:dotbot/features/agent/tools/tools.dart';
import 'package:dotbot/features/memory/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scripted LLM: returns queued responses and records what it was sent.
class FakeLlm implements LlmProvider {
  FakeLlm(this.script);
  final List<LlmResponse> script;
  final calls = <List<ChatMsg>>[];
  final toolsSeen = <int>[];

  @override
  String get id => 'fake';

  @override
  Future<LlmResponse> chat(List<ChatMsg> messages,
      {List<ToolSpec> tools = const []}) async {
    calls.add(messages);
    toolsSeen.add(tools.length);
    return script.removeAt(0);
  }
}

LlmResponse call(String name, Map<String, dynamic> args, [String id = 'c1']) =>
    LlmResponse(toolCalls: [ToolCall(id: id, name: name, args: args)]);

void main() {
  late AppDatabase db;
  late ToolContext ctx;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    ctx = ToolContext(db, UserModel(db));
  });
  tearDown(() => db.close());

  test('plan -> tool -> observe -> answer', () async {
    final llm = FakeLlm([
      call('create_task', {'title': 'Solve 2 array problems'}),
      const LlmResponse(text: 'Added. Go.'),
    ]);
    final agent = Agent(llm, defaultTools(), ctx);
    final r = await agent.run(system: 'sys', history: [], userText: 'plan');

    expect(r.reply, 'Added. Go.');
    expect(r.steps, 2);
    expect((await db.select(db.tasks).get()).single.title,
        'Solve 2 array problems');
    // The second LLM call saw the tool observation.
    expect(llm.calls[1].last.role, Role.tool);
    expect(llm.calls[1].last.content, contains('"id":1'));
  });

  test('stops after maxSteps and forces a tool-free answer', () async {
    final llm = FakeLlm([
      for (var i = 0; i < 6; i++) call('list_tasks', {}, 'c$i'),
      const LlmResponse(text: 'done looping'),
    ]);
    final r = await Agent(llm, defaultTools(), ctx)
        .run(system: 's', history: [], userText: 'x');
    expect(r.hitLimit, true);
    expect(r.steps, 6);
    expect(r.reply, 'done looping');
    expect(llm.calls.length, 7);
    expect(llm.toolsSeen.last, 0);
  });

  test('unknown tool and tool errors become observations, not crashes',
      () async {
    final llm = FakeLlm([
      LlmResponse(toolCalls: [
        const ToolCall(id: 'a', name: 'nope', args: {}),
        const ToolCall(id: 'b', name: 'complete_task', args: {'id': 'oops'}),
      ]),
      const LlmResponse(text: 'ok'),
    ]);
    final r = await Agent(llm, defaultTools(), ctx)
        .run(system: 's', history: [], userText: 'x');
    expect(r.reply, 'ok');
    final obs = llm.calls[1].where((m) => m.role == Role.tool).toList();
    expect(obs[0].content, contains('unknown tool'));
    expect(obs[1].content, contains('error'));
  });

  test('tutor_quiz tool updates mastery and reports hint cap', () async {
    final tool = TutorQuizTool();
    final out = await tool.run(
        {'topic': 'trees', 'correct': true, 'hint_level': 0}, ctx) as Map;
    expect(out['mastery'], greaterThan(0));
    expect(out['max_level'], 'answer'); // low mastery -> may reveal
  });

  test('offline challenge works without any LLM', () async {
    final out = await OfflineChallengeTool().run({}, ctx) as Map;
    expect(out['prompt'], isNotEmpty);
  });
}
