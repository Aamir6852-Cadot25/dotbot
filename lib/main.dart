import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/documents/text_extractor.dart';
import 'features/mentor/background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  await scheduleBackgroundTicks();
  runApp(ProviderScope(
    overrides: [extractorProvider.overrideWithValue(extractText)],
    child: const DotbotApp(),
  ));
}
