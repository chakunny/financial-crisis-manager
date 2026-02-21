import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // <-- NEW: Import dotenv
import 'screens/dashboard_screen.dart';
import 'dart:io';

Future<void> main() async {

    // 1. Try to load the environment variables
    await dotenv.load(fileName: ".env");

    // Apply the proxy settings globally
    HttpOverrides.global = MyHttpOverrides();

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

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..findProxy = (uri) {
        // Replace with your actual proxy IP address and port
        return "PROXY 192.168.1.100:8080;";
      }
    // CRITICAL: Corporate proxies often intercept SSL certificates.
    // This line prevents SSL handshake errors during local development.
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}