/// v0.2: per-app screen-time signal (e.g. distraction detection). No-op for now.
abstract class AppUsageService {
  Future<Map<String, Duration>> todayUsage();
}

class NoopAppUsageService implements AppUsageService {
  const NoopAppUsageService();
  @override
  Future<Map<String, Duration>> todayUsage() async => const {};
}
