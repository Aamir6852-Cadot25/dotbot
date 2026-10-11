import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/chat/chat_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/you_screen.dart';
import '../features/today/today_screen.dart';
import '../features/tutor/learn_screen.dart';
import 'providers.dart';

class DotbotApp extends StatelessWidget {
  const DotbotApp({super.key, this.home});

  /// Override for tests.
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    const seed = Colors.indigo;
    return MaterialApp(
      title: 'Dotbot',
      themeMode: ThemeMode.system,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: home ?? const _Gate(),
    );
  }
}

class _Gate extends ConsumerWidget {
  const _Gate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(onboardedProvider);
    return onboarded.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (ok) => ok ? const HomeShell() : const OnboardingScreen(),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<HomeShell> {
  int _i = 0;
  Timer? _timer;

  static const _tabs = [
    ('Today', Icons.today_outlined, Icons.today),
    ('Chat', Icons.chat_bubble_outline, Icons.chat_bubble),
    ('Learn', Icons.school_outlined, Icons.school),
    ('Insights', Icons.insights_outlined, Icons.insights),
    ('You', Icons.person_outline, Icons.person),
  ];

  @override
  void initState() {
    super.initState();
    // Desktop has no background scheduler yet: tick while the app is open.
    // On Android WorkManager handles it, but a foreground tick is harmless.
    _tick();
    _timer = Timer.periodic(
        Duration(minutes: Platform.isAndroid ? 30 : 15), (_) => _tick());
  }

  void _tick() => unawaited(
      ref.read(mentorProvider).tick().then((_) {}, onError: (Object _) {}));

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const pages = [
      TodayScreen(),
      ChatScreen(),
      LearnScreen(),
      InsightsScreen(),
      YouScreen(),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final body = IndexedStack(index: _i, children: pages);
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _i,
            onDestinationSelected: (i) => setState(() => _i = i),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final t in _tabs)
                NavigationRailDestination(
                    icon: Icon(t.$2), selectedIcon: Icon(t.$3), label: Text(t.$1))
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_tabs[_i].$1)),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
                icon: Icon(t.$2), selectedIcon: Icon(t.$3), label: t.$1)
        ],
      ),
    );
  }
}
