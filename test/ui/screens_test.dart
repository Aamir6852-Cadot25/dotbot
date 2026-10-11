import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:dotbot/app/providers.dart';
import 'package:dotbot/core/db/database.dart';
import 'package:dotbot/core/notifications/notifier.dart';
import 'package:dotbot/core/secure/key_store.dart';
import 'package:dotbot/features/chat/chat_screen.dart';
import 'package:dotbot/features/demo/demo_screen.dart';
import 'package:dotbot/features/insights/insights_screen.dart';
import 'package:dotbot/features/memory/memory_screen.dart';
import 'package:dotbot/features/onboarding/onboarding_screen.dart';
import 'package:dotbot/features/settings/you_screen.dart';
import 'package:dotbot/features/today/today_screen.dart';
import 'package:dotbot/features/tutor/learn_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpScreen(WidgetTester t, Widget screen, {Size size = const Size(400, 800)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  final db = AppDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
  await t.pumpWidget(ProviderScope(
    overrides: [
      dbProvider.overrideWithValue(db),
      notifierProvider.overrideWithValue(RecordingNotifier()),
      keyStoreProvider.overrideWithValue(MemoryKeyStore()),
    ],
    child: MaterialApp(home: Scaffold(body: screen)),
  ));
  await t.pump(const Duration(milliseconds: 50));
  await t.pump(const Duration(milliseconds: 50));
  expect(t.takeException(), isNull);
  await t.pumpWidget(const SizedBox());
  await db.close();
  t.view.reset();
}

void main() {
  final screens = <String, Widget>{
    'onboarding': const OnboardingScreen(),
    'today': const TodayScreen(),
    'chat': const ChatScreen(),
    'learn': const LearnScreen(),
    'insights': const InsightsScreen(),
    'you': const YouScreen(),
    'memory': const MemoryScreen(),
    'demo': const DemoScreen(),
  };
  for (final e in screens.entries) {
    testWidgets('${e.key} renders on phone', (t) => pumpScreen(t, e.value));
    testWidgets('${e.key} renders on desktop',
        (t) => pumpScreen(t, e.value, size: const Size(1280, 800)));
  }
}
