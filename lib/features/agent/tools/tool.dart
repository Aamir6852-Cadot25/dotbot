import '../../../core/db/database.dart';
import '../../../core/llm/llm_provider.dart';
import '../../memory/user_model.dart';

class ToolContext {
  ToolContext(this.db, this.user, {DateTime Function()? clock})
      : now = clock ?? DateTime.now;
  final AppDatabase db;
  final UserModel user;
  final DateTime Function() now;
}

abstract class AgentTool {
  ToolSpec get spec;
  String get name => spec.name;

  /// Result is JSON-encodable and is fed back to the LLM as the observation.
  Future<Object?> run(Map<String, dynamic> args, ToolContext ctx);
}

Map<String, dynamic> objectSchema(Map<String, Map<String, dynamic>> props,
        {List<String> required = const []}) =>
    {'type': 'object', 'properties': props, 'required': required};

const str = {'type': 'string'};
const integer = {'type': 'integer'};
