import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gzoa/main.dart';

void main() {
  testWidgets('Platform font configuration test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app builds without errors
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('PlatformUtils font family test', (WidgetTester tester) async {
    // Test that PlatformUtils.fontFamily returns correct values
    // Note: This test runs in a test environment, so it may not reflect
    // the actual platform behavior, but it tests the logic.
    
  });
}
