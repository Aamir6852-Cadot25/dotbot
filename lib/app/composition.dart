import '../core/db/database.dart';
import '../core/llm/provider_factory.dart';
import '../core/notifications/notifier.dart';
import '../core/secure/key_store.dart';
import '../features/agent/agent.dart';
import '../features/agent/tools/tool.dart';
import '../features/agent/tools/tools.dart';
import '../features/memory/user_model.dart';
import '../features/mentor/mentor_service.dart';

/// Agent for the user's chosen provider, or null if no key yet.
Future<Agent?> agentFromKeys(KeyStore keys, UserModel user, ToolContext ctx,
    {Future<String> Function(String path)? extract}) async {
  final llm = await buildProvider(keys, user);
  return llm == null ? null : Agent(llm, defaultTools(extract: extract), ctx);
}

MentorService createMentorService(AppDatabase db, Notifier notifier,
    {KeyStore keys = const SecureKeyStore()}) {
  final user = UserModel(db);
  return MentorService(
    db: db,
    user: user,
    notifier: notifier,
    agentFor: (ctx) => agentFromKeys(keys, user, ctx),
  );
}
