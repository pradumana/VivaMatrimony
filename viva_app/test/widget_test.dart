import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viva_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Just verify the app widget tree can be built without crashing
    await tester.pumpWidget(const ProviderScope(child: VivaApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
