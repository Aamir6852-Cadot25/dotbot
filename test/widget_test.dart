import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dotbot/app/app.dart';

void main() {
  testWidgets('app boots with Material 3 theme', (tester) async {
    await tester.pumpWidget(const ProviderScope(
        child: DotbotApp(home: Scaffold(body: Center(child: Text('Dotbot'))))));
    expect(find.text('Dotbot'), findsOneWidget);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.useMaterial3, true);
  });
}
