import 'dart:convert';

import 'package:dotbot/core/llm/gemini_provider.dart';
import 'package:dotbot/core/llm/llm_provider.dart';
import 'package:dotbot/core/llm/openai_compat_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const spec = ToolSpec('create_task', 'd', {'type': 'object', 'properties': {}});

void main() {
  test('groq: sends tools + bearer, parses tool_calls', () async {
    late http.Request seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': null,
                  'tool_calls': [
                    {
                      'id': 'x1',
                      'function': {
                        'name': 'create_task',
                        'arguments': '{"title":"a"}'
                      }
                    }
                  ]
                }
              }
            ]
          }),
          200);
    });
    final p = OpenAiCompatProvider(apiKey: 'k', client: client);
    final r = await p.chat([const ChatMsg(Role.user, 'hi')], tools: [spec]);
    expect(seen.headers['Authorization'], 'Bearer k');
    expect(jsonDecode(seen.body)['tools'], hasLength(1));
    expect(r.toolCalls.single.args['title'], 'a');
  });

  test('gemini: maps system, tool results and function calls', () async {
    late Map body;
    final client = MockClient((req) async {
      body = jsonDecode(req.body) as Map;
      expect(req.headers['x-goog-api-key'], 'k');
      return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'hello'},
                    {
                      'functionCall': {'name': 'create_task', 'args': {'title': 'b'}}
                    }
                  ]
                }
              }
            ]
          }),
          200);
    });
    final p = GeminiProvider(apiKey: 'k', client: client);
    final r = await p.chat([
      const ChatMsg(Role.system, 'be brief'),
      const ChatMsg(Role.user, 'hi'),
      const ChatMsg.tool(id: 'c', name: 'create_task', content: '{}'),
    ], tools: [spec]);
    expect(body['systemInstruction'], isNotNull);
    expect((body['contents'] as List), hasLength(2));
    expect(r.text, 'hello');
    expect(r.toolCalls.single.name, 'create_task');
  });

  test('http errors surface as LlmException', () async {
    final p = OpenAiCompatProvider(
        apiKey: 'k', client: MockClient((_) async => http.Response('nope', 429)));
    expect(() => p.chat([const ChatMsg(Role.user, 'x')]),
        throwsA(isA<LlmException>()));
  });
}
