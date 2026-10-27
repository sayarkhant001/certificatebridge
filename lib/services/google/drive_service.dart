import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../auth/google_auth_service.dart';

import 'apps_script_service.dart';

class DriveFolderItem {
  final String id;
  final String name;
  final String? parentId;

  DriveFolderItem({
    required this.id,
    required this.name,
    this.parentId,
  });

  factory DriveFolderItem.fromJson(Map<String, dynamic> json) {
    final parents = json['parents'] as List<dynamic>?;
    return DriveFolderItem(
      id: json['id'] as String,
      name: json['name'] as String,
      parentId: (parents != null && parents.isNotEmpty) ? parents.first as String : null,
    );
  }
}

class DriveService {
  final GoogleAuthService _authService = GoogleAuthService();
  final AppsScriptService _appsScriptService = AppsScriptService();
  final Random _random = Random();

  /// Fetches folder hierarchy accessible in user's Drive
  Future<List<DriveFolderItem>> listFolders() async {
    final token = await _authService.getValidAccessToken();
    if (token == null) {
      return [
        DriveFolderItem(
          id: 'certibridge_drive_folder',
          name: 'CertiBridge Certificates (Google Drive)',
        ),
      ];
    }

    final query = "mimeType = 'application/vnd.google-apps.folder' and trashed = false";
    final uri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files?q=${Uri.encodeComponent(query)}&fields=files(id,name,parents)&pageSize=100',
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final files = data['files'] as List<dynamic>? ?? [];
      return files.map((f) => DriveFolderItem.fromJson(f as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to list Drive folders: ${response.statusCode} ${response.body}');
    }
  }

  /// Creates a new subfolder in Drive
  Future<DriveFolderItem> createFolder({
    required String name,
    String? parentFolderId,
  }) async {
    final token = await _authService.getValidAccessToken();
    if (token == null) throw Exception('Google account is not authenticated.');

    final metadata = <String, dynamic>{
      'name': name,
      'mimeType': 'application/vnd.google-apps.folder',
    };
    if (parentFolderId != null && parentFolderId.isNotEmpty) {
      metadata['parents'] = [parentFolderId];
    }

    final response = await http.post(
      Uri.parse('https://www.googleapis.com/drive/v3/files?fields=id,name,parents'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(metadata),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return DriveFolderItem.fromJson(data);
    } else {
      throw Exception('Failed to create folder: ${response.statusCode} ${response.body}');
    }
  }

  /// Uploads a single PDF file using Google Drive Resumable Upload protocol with exponential backoff & jitter
  Future<String> uploadPdfResumable({
    required File file,
    required String targetFolderId,
    int maxRetries = 5,
  }) async {
    final token = await _authService.getValidAccessToken();
    if (token == null) {
      try {
        return await _appsScriptService.uploadCertificate(file: file);
      } catch (e) {
        throw Exception('Google Account is not connected (OAuth or Apps Script): $e');
      }
    }

    final fileSize = await file.length();
    final filename = file.path.split(Platform.pathSeparator).last;

    // 1. Initiate Resumable Upload Session
    final initUri = Uri.parse(
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&fields=id,name,webViewLink',
    );

    final metadata = {
      'name': filename,
      'parents': [targetFolderId],
      'mimeType': 'application/pdf',
    };

    final initResponse = await http.post(
      initUri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': 'application/pdf',
        'X-Upload-Content-Length': fileSize.toString(),
      },
      body: jsonEncode(metadata),
    );

    if (initResponse.statusCode != 200) {
      throw Exception('Failed to initiate resumable upload session: ${initResponse.statusCode}');
    }

    final uploadLocation = initResponse.headers['location'];
    if (uploadLocation == null) {
      throw Exception('Missing Location header in resumable upload response.');
    }

    // 2. Upload file bytes with exponential backoff & jitter
    final fileBytes = await file.readAsBytes();

    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        final uploadResponse = await http.put(
          Uri.parse(uploadLocation),
          headers: {
            'Content-Length': fileSize.toString(),
            'Content-Type': 'application/pdf',
          },
          body: fileBytes,
        );

        if (uploadResponse.statusCode == 200 || uploadResponse.statusCode == 201) {
          final data = jsonDecode(uploadResponse.body);
          final webViewLink = data['webViewLink'] as String? ??
              'https://drive.google.com/file/d/${data['id']}/view';
          return webViewLink;
        } else if (uploadResponse.statusCode == 429 || uploadResponse.statusCode >= 500) {
          attempt++;
          final delayMs = (pow(2, attempt) * 1000).toInt() + _random.nextInt(500);
          await Future.delayed(Duration(milliseconds: delayMs));
        } else {
          throw Exception('Upload failed with status: ${uploadResponse.statusCode}');
        }
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;
        final delayMs = (pow(2, attempt) * 1000).toInt() + _random.nextInt(500);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    throw Exception('Upload exceeded maximum retry limit.');
  }

  /// Concurrent 4-worker upload pool for bulk certificate processing
  Future<List<String>> uploadBatchConcurrent({
    required List<File> files,
    required String targetFolderId,
    int concurrency = 4,
    Function(int completed, int total)? onProgress,
  }) async {
    final results = List<String>.filled(files.length, '');
    int nextIndex = 0;
    int completedCount = 0;

    Future<void> worker() async {
      while (true) {
        int currentIndex;
        if (nextIndex >= files.length) break;
        currentIndex = nextIndex++;

        final file = files[currentIndex];
        try {
          final link = await uploadPdfResumable(
            file: file,
            targetFolderId: targetFolderId,
          );
          results[currentIndex] = link;
        } catch (e) {
          results[currentIndex] = '';
        }

        completedCount++;
        if (onProgress != null) {
          onProgress(completedCount, files.length);
        }
      }
    }

    final workers = List.generate(concurrency, (_) => worker());
    await Future.wait(workers);

    return results;
  }
}
