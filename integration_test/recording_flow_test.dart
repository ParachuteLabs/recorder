import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parachute/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Recording Flow Integration Tests', () {
    testWidgets('Complete recording flow test', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Verify home screen is displayed
      expect(find.text('Parachute'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);

      // Tap the record button
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pumpAndSettle();

      // Verify recording screen is displayed
      expect(find.text('Recording'), findsOneWidget);
      expect(find.text('Recording...'), findsOneWidget);

      // Wait for 3 seconds to simulate recording
      await Future.delayed(const Duration(seconds: 3));
      await tester.pump();

      // Tap pause button
      final pauseButton = find.byIcon(Icons.pause);
      if (pauseButton.evaluate().isNotEmpty) {
        await tester.tap(pauseButton);
        await tester.pumpAndSettle();

        // Verify paused state
        expect(find.text('Paused'), findsOneWidget);

        // Resume recording
        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pumpAndSettle();
      }

      // Stop recording
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pumpAndSettle();

      // Verify post-recording screen
      expect(find.text('Recording Complete'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);

      // Enter title and tags
      await tester.enterText(find.byType(TextField).first, 'Test Recording');
      await tester.enterText(
          find.byType(TextField).last, 'test, integration, automated');

      // Save recording
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify returned to home screen with new recording
      expect(find.text('Parachute'), findsOneWidget);
      expect(find.text('Test Recording'), findsOneWidget);
      expect(find.text('test'), findsOneWidget);
    });

    testWidgets('Play recording test', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Check if there are any recordings
      final recordings = find.byType(Card);
      if (recordings.evaluate().isNotEmpty) {
        // Tap on first recording
        await tester.tap(recordings.first);
        await tester.pumpAndSettle();

        // Verify recording detail screen
        expect(find.byIcon(Icons.play_circle_filled), findsOneWidget);

        // Tap play button
        await tester.tap(find.byIcon(Icons.play_circle_filled));
        await tester.pumpAndSettle();

        // Wait a bit for playback
        await Future.delayed(const Duration(seconds: 2));

        // Stop playback if playing
        final stopButton = find.byIcon(Icons.stop);
        if (stopButton.evaluate().isNotEmpty) {
          await tester.tap(stopButton);
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('Edit recording metadata test', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Check if there are any recordings
      final recordings = find.byType(Card);
      if (recordings.evaluate().isNotEmpty) {
        // Tap on first recording
        await tester.tap(recordings.first);
        await tester.pumpAndSettle();

        // Open more options menu
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // Tap edit option
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        // Modify title
        final titleField = find.byType(TextField).first;
        await tester.tap(titleField);
        await tester.enterText(titleField, 'Updated Title');

        // Save changes
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Verify changes were saved
        expect(find.text('Recording updated'), findsOneWidget);
      }
    });

    testWidgets('Delete recording test', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Check if there are any recordings
      final recordings = find.byType(Card);
      if (recordings.evaluate().length > 1) {
        // Remember the initial count
        final initialCount = recordings.evaluate().length;

        // Tap on first recording
        await tester.tap(recordings.first);
        await tester.pumpAndSettle();

        // Open more options menu
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // Tap delete option
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        // Confirm deletion
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();

        // Verify recording was deleted
        expect(find.text('Recording deleted'), findsOneWidget);

        // Verify count decreased
        final newCount = find.byType(Card).evaluate().length;
        expect(newCount, initialCount - 1);
      }
    });
  });
}
