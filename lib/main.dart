import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opus_dart/opus_dart.dart' as opus_dart;
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;
import 'package:parachute/screens/home_screen.dart';
import 'package:parachute/theme.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Opus codec for audio decoding (required for Omi device recordings)
  try {
    await opus_dart.initOpus(await opus_flutter.load());
    debugPrint('[Main] Opus codec initialized successfully');
  } catch (e) {
    debugPrint('[Main] Failed to initialize Opus codec: $e');
    // Continue anyway - only affects Omi device recordings with Opus codec
  }
  // Set up global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log the error
    FlutterError.presentError(details);

    // In production, you could send to crash reporting service
    if (kReleaseMode) {
      // TODO: Send to crash reporting (Firebase Crashlytics, Sentry, etc.)
      debugPrint('Error caught in release mode: ${details.exception}');
    }
  };

  // Catch errors not caught by Flutter
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error');
    debugPrint('Stack trace: $stack');

    // In production, send to crash reporting
    if (kReleaseMode) {
      // TODO: Send to crash reporting
    }

    return true; // Prevents error from propagating
  };

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parachute',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
      },
    );
  }
}
