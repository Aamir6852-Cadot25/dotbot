import '../../features/memory/user_model.dart';
import '../secure/key_store.dart';
import 'gemini_provider.dart';
import 'llm_provider.dart';
import 'openai_compat_provider.dart';

/// Builds the user's chosen provider, or null if no key is saved yet.
Future<LlmProvider?> buildProvider(KeyStore keys, UserModel user) async {
  final which = await user.getKv('provider') ?? 'gemini';
  final key = await keys.read(which);
  if (key == null || key.isEmpty) return null;
  return which == 'groq'
      ? OpenAiCompatProvider(apiKey: key)
      : GeminiProvider(apiKey: key);
}
