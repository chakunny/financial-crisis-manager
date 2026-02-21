import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // <-- NEW: Import dotenv
import 'screens/dashboard_screen.dart';

Future<void> main() async {

    // 1. Try to load the environment variables
    await dotenv.load(fileName: ".env");

    // 2. Try to initialize Supabase
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );

    // 3. If both succeed, run the app
    runApp(const FinCrisisManagerApp());
}

class FinCrisisManagerApp extends StatelessWidget {
  const FinCrisisManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crisis Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: DashboardScreen(),
    );
  }
}