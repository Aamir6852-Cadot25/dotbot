/// v0.2: optional cloud sync (Supabase planned). v0.1 is local-only.
abstract class SyncService {
  Future<void> push();
  Future<void> pull();
}

class NoopSyncService implements SyncService {
  const NoopSyncService();
  @override
  Future<void> push() async {}
  @override
  Future<void> pull() async {}
}
