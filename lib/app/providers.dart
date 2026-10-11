import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Notifier;
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../core/db/database.dart';
import '../core/llm/llm_provider.dart';
import '../core/llm/provider_factory.dart';
import '../core/notifications/notifier.dart';
import '../core/secure/key_store.dart';
import '../features/agent/agent.dart';
import '../features/agent/tools/tool.dart';
import '../features/agent/tools/tools.dart';
import '../features/memory/user_model.dart';
import '../features/mentor/mentor_service.dart';
import '../features/tutor/tutor_service.dart';
import 'composition.dart';

final dbProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final userProvider = Provider((ref) => UserModel(ref.watch(dbProvider)));
final keyStoreProvider = Provider<KeyStore>((_) => const SecureKeyStore());
final notifierProvider = Provider<Notifier>((_) => LocalNotifier());

/// Bump after saving a key/provider so dependants rebuild.
final llmEpochProvider = StateProvider<int>((_) => 0);

final llmProvider = FutureProvider<LlmProvider?>((ref) {
  ref.watch(llmEpochProvider);
  return buildProvider(ref.watch(keyStoreProvider), ref.watch(userProvider));
});

final agentProvider = FutureProvider<Agent?>((ref) async {
  final llm = await ref.watch(llmProvider.future);
  if (llm == null) return null;
  final ctx = ToolContext(ref.watch(dbProvider), ref.watch(userProvider));
  return Agent(llm, defaultTools(extract: ref.watch(extractorProvider)), ctx);
});

final tutorProvider = FutureProvider<TutorService?>((ref) async {
  final llm = await ref.watch(llmProvider.future);
  return llm == null ? null : TutorService(llm, ref.watch(userProvider));
});

/// Replaced with a PDF-capable extractor in main (see pdf_text.dart).
final extractorProvider =
    Provider<Future<String> Function(String path)>((_) => (p) async => throw UnsupportedError('PDF not available'));

final mentorProvider = Provider<MentorService>((ref) =>
    createMentorService(ref.watch(dbProvider), ref.watch(notifierProvider),
        keys: ref.watch(keyStoreProvider)));

final onboardedProvider = FutureProvider<bool>(
    (ref) => ref.watch(userProvider).onboarded);

/// Reactive lists for screens.
final tasksProvider = StreamProvider((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.tasks)..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();
});

final chatProvider = StreamProvider((ref) {
  final db = ref.watch(dbProvider);
  return (db.select(db.chatMessages)..orderBy([(t) => OrderingTerm.asc(t.id)])).watch();
});
