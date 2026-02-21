import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class UploadScreen extends StatefulWidget {
  // 1. Added the key constructor
  const UploadScreen({super.key});

  @override
  // 2. Changed the return type from _UploadScreenState to State<UploadScreen>
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isUploading = false;
  String _statusMessage = "Select your Bank Statement (CSV or XLSX)";

  Future<void> _pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      await _uploadToServer(file);
    }
  }

  Future<void> _uploadToServer(File file) async {
    setState(() {
      _isUploading = true;
      _statusMessage = "Uploading & Analyzing...";
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        // If you are using the Android Emulator, use 10.0.2.2
        // If you are testing on Chrome (Web) or iOS Simulator, use localhost
        Uri.parse('http://10.0.2.2:3000/transactions/upload'),
      );
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();

      if (response.statusCode == 201) {
        setState(() => _statusMessage = "Success! Transactions Synced.");
        await Future.delayed(Duration(seconds: 1));
        if (mounted) Navigator.pop(context, true); // Go back to dashboard
      } else {
        throw Exception('Server rejected the file');
      }
    } catch (e) {
      setState(() => _statusMessage = "Error: \nWe need to deploy the backend first!");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Import Bank Statement")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_upload_outlined, size: 80, color: Colors.blueAccent),
              SizedBox(height: 20),
              Text(_statusMessage, textAlign: TextAlign.center),
              SizedBox(height: 30),
              if (_isUploading)
                CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _pickAndUploadFile,
                  icon: Icon(Icons.folder_open),
                  label: Text("Select File"),
                ),
            ],
          ),
        ),
      ),
    );
  }
}