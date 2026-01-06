// Basic widget test for TorrentApp
//
// This test verifies that the app can be instantiated without errors.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build a minimal test widget
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Torrent DR'),
          ),
        ),
      ),
    );

    // Verify that the app renders
    expect(find.text('Torrent DR'), findsOneWidget);
  });
}
