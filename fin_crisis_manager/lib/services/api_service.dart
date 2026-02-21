import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // <-- NEW: Import Supabase

class ApiService {
  // Use 10.0.2.2 for Android Emulator. Use localhost for iOS Simulator.
  final String baseUrl = 'http://10.0.2.2:3000';

  // --- NEW: THE SECURITY GUARD INTERFACE ---
  // This helper function grabs the current user's session token
  // and formats it exactly how NestJS's Passport module expects it.
  Map<String, String> _getAuthHeaders({Map<String, String>? additionalHeaders}) {
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken;
    // print('🚨 DEBUG: JWT Token is: ${token != null ? "PRESENT" : "NULL"}');
    final headers = <String, String>{};

    // Attach the JWT Token
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    // Merge any extra headers (like Content-Type)
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  // 1. UPLOAD CSV FILE
  Future<void> uploadFile(PlatformFile file) async {
    var uri = Uri.parse('$baseUrl/transactions/upload');
    var request = http.MultipartRequest('POST', uri);

    // <-- NEW: Attach the JWT token to the multipart request
    request.headers.addAll(_getAuthHeaders());

    if (file.path != null) {
      request.files.add(await http.MultipartFile.fromPath('file', file.path!));
    } else {
      request.files.add(http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name
      ));
    }

    var response = await request.send();

    if (response.statusCode != 200 && response.statusCode != 201) {
      // --- NEW: Read the actual error message from NestJS ---
      final errorBody = await response.stream.bytesToString();
      print('\n==================================');
      print('🚨 UPLOAD REJECTED BY BACKEND 🚨');
      print('Status Code: ${response.statusCode}');
      print('Backend Response: $errorBody');
      print('==================================\n');

      throw Exception('Backend rejected upload: ${response.statusCode}');
    }
  }

  // 2. FETCH ALL TRANSACTIONS
  Future<List<dynamic>> fetchTransactions() async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions'),
      headers: _getAuthHeaders(), // <-- NEW: Send the JWT token
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load transactions');
    }
  }

  // 3. FETCH SUMMARY (Income vs Expense)
  Future<Map<String, dynamic>> fetchSummary() async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions/summary'),
      headers: _getAuthHeaders(), // <-- NEW: Send the JWT token
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load summary');
    }
  }

  // 4. CATEGORIZE TRANSACTION (The Smart Brain)
  // <-- FIX: Changed 'int id' to 'String id' to match the database UUIDs
  Future<void> categorizeTransaction(String id, String classification) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/transactions/$id/categorize'),
      // <-- NEW: Send the JWT token alongside the Content-Type
      headers: _getAuthHeaders(additionalHeaders: {'Content-Type': 'application/json'}),
      body: jsonEncode({'classification': classification}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to categorize transaction');
    }
  }
}