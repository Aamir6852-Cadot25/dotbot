import 'package:flutter/material.dart';

class DotbotApp extends StatelessWidget {
  const DotbotApp({super.key});

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
      home: const Scaffold(body: Center(child: Text('Dotbot'))),
    );
  }
}
