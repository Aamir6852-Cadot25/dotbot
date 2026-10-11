import 'dart:convert';

import '../../core/llm/llm_provider.dart';
import 'tools/tool.dart';

/// One visible step of the agent's reasoning, for the trace panel.
class AgentStep {
  const AgentStep(this.kind, this.text, {this.tool});

  /// think | tool | observe | answer | limit
  final String kind;
  final String text;
  final String? tool;

  Map<String, Object?> toJson() => {'kind': kind, 'text': text, 'tool': tool};
  factory AgentStep.fromJson(Map<String, dynamic> j) =>
      AgentStep(j['kind'] as String, j['text'] as String, tool: j['tool'] as String?);

  static String encode(List<AgentStep> s) =>
      jsonEncode(s.map((e) => e.toJson()).toList());
  static List<AgentStep> decode(String? raw) => raw == null
      ? const []
      : (jsonDecode(raw) as List)
          .map((e) => AgentStep.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
}

class AgentResult {
  const AgentResult(this.reply, this.messages, this.steps,
      {this.hitLimit = false, this.trace = const []});
  final String reply;

  /// Full transcript including tool calls (excluding the system prompt).
  final List<ChatMsg> messages;
  final int steps;
  final bool hitLimit;
  final List<AgentStep> trace;
}

/// Plan -> call tool -> observe, at most [maxSteps] LLM round trips.
class Agent {
  Agent(this.llm, List<AgentTool> tools, this.ctx, {this.maxSteps = 6})
      : _tools = {for (final t in tools) t.name: t};

  final LlmProvider llm;
  final ToolContext ctx;
  final int maxSteps;
  final Map<String, AgentTool> _tools;

  Future<AgentResult> run({
    required String system,
    required List<ChatMsg> history,
    required String userText,
    void Function(AgentStep step)? onStep,
  }) async {
    final convo = <ChatMsg>[...history, ChatMsg(Role.user, userText)];
    final specs = _tools.values.map((t) => t.spec).toList();
    final trace = <AgentStep>[];
    void emit(AgentStep s) {
      trace.add(s);
      onStep?.call(s);
    }

    var steps = 0;
    while (steps < maxSteps) {
      steps++;
      final res = await llm.chat([ChatMsg(Role.system, system), ...convo],
          tools: specs);
      if (res.toolCalls.isEmpty) {
        convo.add(ChatMsg(Role.assistant, res.text));
        emit(AgentStep('answer', res.text));
        return AgentResult(res.text, convo, steps, trace: trace);
      }
      if (res.text.trim().isNotEmpty) emit(AgentStep('think', res.text.trim()));
      convo.add(ChatMsg(Role.assistant, res.text, toolCalls: res.toolCalls));
      for (final call in res.toolCalls) {
        emit(AgentStep('tool', jsonEncode(call.args), tool: call.name));
        final obs = await _exec(call);
        emit(AgentStep('observe', _clip(obs), tool: call.name));
        convo.add(ChatMsg.tool(id: call.id, name: call.name, content: obs));
      }
    }

    // Step budget exhausted: force a final answer with no tools.
    emit(AgentStep('limit', 'Reached $maxSteps steps; answering without tools.'));
    final fin = await llm.chat([
      ChatMsg(Role.system, system),
      ...convo,
      const ChatMsg(Role.user, 'Stop using tools. Reply to the user now.'),
    ]);
    convo.add(ChatMsg(Role.assistant, fin.text));
    emit(AgentStep('answer', fin.text));
    return AgentResult(fin.text, convo, steps, hitLimit: true, trace: trace);
  }

  static String _clip(String s) => s.length > 400 ? '${s.substring(0, 400)}…' : s;

  Future<String> _exec(ToolCall call) async {
    final tool = _tools[call.name];
    if (tool == null) return jsonEncode({'error': 'unknown tool ${call.name}'});
    try {
      return jsonEncode(await tool.run(call.args, ctx));
    } catch (e) {
      return jsonEncode({'error': e.toString()});
    }
  }
}
