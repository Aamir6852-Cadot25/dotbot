import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_provider.dart';

/// Google Gemini via the REST generateContent endpoint.
class GeminiProvider implements LlmProvider {
  GeminiProvider({
    required this.apiKey,
    this.model = 'gemini-2.5-flash',
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
    http.Client? client,
  }) : _http = client ?? http.Client();

  final String apiKey;
  final String model;
  final String baseUrl;
  final http.Client _http;

  @override
  String get id => 'gemini';

  @override
  Future<LlmResponse> chat(List<ChatMsg> messages,
      {List<ToolSpec> tools = const []}) async {
    final system = messages
        .where((m) => m.role == Role.system)
        .map((m) => m.content)
        .join('\n\n');
    final body = <String, dynamic>{
      if (system.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': system}
          ]
        },
      'contents': [
        for (final m in messages)
          if (m.role != Role.system) _content(m)
      ],
      if (tools.isNotEmpty)
        'tools': [
          {
            'functionDeclarations': [
              for (final t in tools)
                {
                  'name': t.name,
                  'description': t.description,
                  'parameters': t.parameters,
                }
            ]
          }
        ],
    };
    final res = await _http.post(
      Uri.parse('$baseUrl/models/$model:generateContent'),
      headers: {'x-goog-api-key': apiKey, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw LlmException(res.body, statusCode: res.statusCode);
    }
    final cands = jsonDecode(res.body)['candidates'] as List?;
    final parts = (cands == null || cands.isEmpty
            ? const []
            : (cands.first['content']?['parts'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final text = StringBuffer();
    final calls = <ToolCall>[];
    for (final p in parts) {
      if (p['text'] != null) text.write(p['text']);
      final fc = p['functionCall'] as Map<String, dynamic>?;
      if (fc != null) {
        calls.add(ToolCall(
          id: 'call_${calls.length}_${fc['name']}',
          name: fc['name'] as String,
          args: Map<String, dynamic>.from((fc['args'] as Map?) ?? const {}),
        ));
      }
    }
    return LlmResponse(text: text.toString(), toolCalls: calls);
  }

  Map<String, dynamic> _content(ChatMsg m) {
    switch (m.role) {
      case Role.tool:
        return {
          'role': 'user',
          'parts': [
            {
              'functionResponse': {
                'name': m.name,
                'response': {'result': m.content},
              }
            }
          ]
        };
      case Role.assistant:
        return {
          'role': 'model',
          'parts': [
            if (m.content.isNotEmpty) {'text': m.content},
            for (final c in m.toolCalls)
              {
                'functionCall': {'name': c.name, 'args': c.args}
              },
          ]
        };
      default:
        return {
          'role': 'user',
          'parts': [
            {'text': m.content}
          ]
        };
    }
  }
}
