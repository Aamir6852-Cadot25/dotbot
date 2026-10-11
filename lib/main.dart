import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'features/mentor/background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await scheduleBackgroundTicks();
  runApp(const ProviderScope(child: DotbotApp()));
}
