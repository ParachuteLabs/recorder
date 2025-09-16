import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/voice_note_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-initialize services for better performance
  // This happens before the app UI loads

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VoiceNoteProvider(),
      child: MaterialApp(
        title: 'Parachute',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1B5E4A),
            brightness: Brightness.dark,
          ).copyWith(
            primary: const Color(0xFF1B5E4A),
            secondary: const Color(0xFF4CAF50),
            surface: const Color(0xFF1B5E4A),
            background: const Color(0xFF1B5E4A),
          ),
          scaffoldBackgroundColor: const Color(0xFF1B5E4A),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
