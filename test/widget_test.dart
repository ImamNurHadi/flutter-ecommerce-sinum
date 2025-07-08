// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sinum/main.dart';

void main() {
  testWidgets('SinumApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SinumApp());

    // Verify that our app loads properly with expected elements
    expect(find.text('Hello, Foodies!'), findsOneWidget);
    expect(find.text('Jakarta, Indonesia'), findsOneWidget);

    // Verify that bottom navigation bar exists
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    // Verify that navigation items exist (some might appear multiple times)
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Categories'), findsWidgets);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Cart'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
    
    // Verify that main screen widget exists
    expect(find.byType(MainScreen), findsOneWidget);
  });
}
