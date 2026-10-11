import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../../app/composition.dart';
import '../../core/db/database.dart';
import '../../core/notifications/notifier.dart';

const _task = 'dotbot.mentor.tick';

/// Runs in a background isolate (Android, ~every 15 min).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    final db = AppDatabase.open();
    try {
      await createMentorService(db, LocalNotifier()).tick();
      return true;
    } catch (e) {
      debugPrint('mentor tick failed: $e');
      return false;
    } finally {
      await db.close();
    }
  });
}

/// Android: periodic background evaluation. Windows: the app shell ticks
/// with a Timer while open (see ADR 0003).
Future<void> scheduleBackgroundTicks() async {
  if (kIsWeb || !Platform.isAndroid) return;
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _task,
    _task,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
}
