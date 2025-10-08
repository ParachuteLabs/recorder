import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:parachute/screens/home_screen.dart';
import 'package:parachute/theme.dart';

void main() {
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
