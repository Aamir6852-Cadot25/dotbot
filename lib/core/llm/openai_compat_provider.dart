import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_provider.dart';

/// OpenAI-compatible chat completions (Groq by default).
class OpenAiCompatProvider implements LlmProvider {
  OpenAiCompatProvider({
    required this.apiKey,
    this.baseUrl = 'https://api.groq.com/openai/v1',
    this.model = 'llama-3.3-70b-versatile',
    this.id = 'groq',
    http.Client? client,
  }) : _http = client ?? http.Client();

  final String apiKey;
  final String baseUrl;
  final String model;
  @override
  final String id;
  final http.Client _http;

  @override
  Future<LlmResponse> chat(List<ChatMsg> messages,
      {List<ToolSpec> tools = const []}) async {
    final body = <String, dynamic>{
      'model': model,
      'messages': messages.map(_msg).toList(),
      if (tools.isNotEmpty)
        'tools': [
          for (final t in tools)
            {
              'type': 'function',
              'function': {
                'name': t.name,
                'description': t.description,
                'parameters': t.parameters,
              }
            }
        ],
    };
    final res = await _http.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw LlmException(res.body, statusCode: res.statusCode);
    }
    final msg = (jsonDecode(res.body)['choices'] as List).first['message']
        as Map<String, dynamic>;
    final calls = <ToolCall>[];
    for (final c in (msg['tool_calls'] as List?) ?? const []) {
      final fn = c['function'] as Map<String, dynamic>;
      final raw = fn['arguments'];
      calls.add(ToolCall(
        id: c['id'] as String,
        name: fn['name'] as String,
        args: raw is String && raw.isNotEmpty
            ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
            : <String, dynamic>{},
      ));
    }
    return LlmResponse(text: (msg['content'] as String?) ?? '', toolCalls: calls);
  }

  Map<String, dynamic> _msg(ChatMsg m) {
    switch (m.role) {
      case Role.tool:
        return {
          'role': 'tool',
          'tool_call_id': m.toolCallId,
          'content': m.content,
        };
      case Role.assistant:
        return {
          'role': 'assistant',
          'content': m.content.isEmpty ? null : m.content,
          if (m.toolCalls.isNotEmpty)
            'tool_calls': [
              for (final c in m.toolCalls)
                {
                  'id': c.id,
                  'type': 'function',
                  'function': {'name': c.name, 'arguments': jsonEncode(c.args)},
                }
            ],
        };
      default:
        return {'role': m.role.name, 'content': m.content};
    }
  }
}
