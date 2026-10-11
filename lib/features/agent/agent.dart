import 'dart:convert';

import '../../core/llm/llm_provider.dart';
import 'tools/tool.dart';

class AgentResult {
  const AgentResult(this.reply, this.messages, this.steps, {this.hitLimit = false});
  final String reply;

  /// Full transcript including tool calls (excluding the system prompt).
  final List<ChatMsg> messages;
  final int steps;
  final bool hitLimit;
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
  }) async {
    final convo = <ChatMsg>[...history, ChatMsg(Role.user, userText)];
    final specs = _tools.values.map((t) => t.spec).toList();
    var steps = 0;

    while (steps < maxSteps) {
      steps++;
      final res = await llm.chat([ChatMsg(Role.system, system), ...convo],
          tools: specs);
      if (res.toolCalls.isEmpty) {
        convo.add(ChatMsg(Role.assistant, res.text));
        return AgentResult(res.text, convo, steps);
      }
      convo.add(ChatMsg(Role.assistant, res.text, toolCalls: res.toolCalls));
      for (final call in res.toolCalls) {
        convo.add(ChatMsg.tool(
            id: call.id, name: call.name, content: await _exec(call)));
      }
    }

    // Step budget exhausted: force a final answer with no tools.
    final fin = await llm.chat([
      ChatMsg(Role.system, system),
      ...convo,
      const ChatMsg(Role.user, 'Stop using tools. Reply to the user now.'),
    ]);
    convo.add(ChatMsg(Role.assistant, fin.text));
    return AgentResult(fin.text, convo, steps, hitLimit: true);
  }

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
