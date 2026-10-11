/// Provider-neutral chat + function-calling types.
enum Role { system, user, assistant, tool }

class ToolCall {
  const ToolCall({required this.id, required this.name, required this.args});
  final String id;
  final String name;
  final Map<String, dynamic> args;
}

class ChatMsg {
  const ChatMsg(this.role, this.content,
      {this.toolCalls = const [], this.toolCallId, this.name});

  /// Result of running a tool; [name] is the tool name.
  const ChatMsg.tool({required String id, required String this.name, required this.content})
      : role = Role.tool,
        toolCalls = const [],
        toolCallId = id;

  final Role role;
  final String content;
  final List<ToolCall> toolCalls;
  final String? toolCallId;
  final String? name;
}

class ToolSpec {
  const ToolSpec(this.name, this.description, this.parameters);
  final String name;
  final String description;

  /// JSON-schema object: {"type":"object","properties":{...},"required":[...]}.
  final Map<String, dynamic> parameters;
}

class LlmResponse {
  const LlmResponse({this.text = '', this.toolCalls = const []});
  final String text;
  final List<ToolCall> toolCalls;
}

class LlmException implements Exception {
  LlmException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => 'LlmException($statusCode): $message';
}

abstract class LlmProvider {
  String get id;
  Future<LlmResponse> chat(List<ChatMsg> messages,
      {List<ToolSpec> tools = const []});
}
