import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/storage/secure_storage_service.dart';

class AppsScriptService {
  final SecureStorageService _storage = SecureStorageService();

  /// Send POST request to Google Apps Script Web App following 302 redirects
  Future<http.Response> _sendRequest(String url, Map<String, dynamic> body) async {
    final client = http.Client();
    try {
      var response = await client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      // Google Apps Script redirects with 302 to script.googleusercontent.com
      if (response.statusCode == 302 || response.statusCode == 301 || response.statusCode == 307) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          response = await client.get(Uri.parse(redirectUrl));
        }
      }
      return response;
    } finally {
      client.close();
    }
  }

  /// Pings Google Apps Script Web App to verify connectivity and get the account email
  Future<Map<String, dynamic>> ping(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) {
      throw Exception('Apps Script URL is empty.');
    }

    final response = await _sendRequest(cleanUrl, {'action': 'ping'});

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data;
      } catch (e) {
        return {
          'success': true,
          'email': 'Google Apps Script Account',
          'raw': response.body,
        };
      }
    } else {
      throw Exception('Apps Script responded with status: ${response.statusCode}');
    }
  }

  /// Uploads PDF file to user's Google Drive via Apps Script ($0 operational cost, never blocked)
  Future<String> uploadCertificate({
    required File file,
    String? folderName,
  }) async {
    final url = await _storage.getAppsScriptUrl();
    if (url == null || url.isEmpty) {
      throw Exception('Apps Script URL is not configured.');
    }

    final fileBytes = await file.readAsBytes();
    final base64Pdf = base64Encode(fileBytes);
    final filename = file.path.split(Platform.pathSeparator).last;

    final response = await _sendRequest(url, {
      'action': 'upload_cert',
      'file_name': filename,
      'base64_pdf': base64Pdf,
      if (folderName != null) 'folder_name': folderName,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['view_url'] ?? data['download_url'] ?? '') as String;
      } else {
        throw Exception(data['error'] ?? 'Apps Script upload failed.');
      }
    } else {
      throw Exception('Upload failed with status: ${response.statusCode}');
    }
  }

  /// List Google Spreadsheets from Google Drive
  Future<List<Map<String, dynamic>>> listDriveSpreadsheets({String? query}) async {
    final url = await _storage.getAppsScriptUrl();
    if (url == null || url.isEmpty) {
      throw Exception('Apps Script URL is not configured.');
    }

    final response = await _sendRequest(url, {
      'action': 'list_drive_spreadsheets',
      if (query != null && query.isNotEmpty) 'query': query,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final files = data['files'] as List<dynamic>? ?? [];
        return files.map((f) => Map<String, dynamic>.from(f as Map)).toList();
      } else {
        throw Exception(data['error'] ?? 'Failed to list Google Drive spreadsheets.');
      }
    } else {
      throw Exception('Apps Script returned status: ${response.statusCode}');
    }
  }

  /// List all worksheets/pages (tabs) inside a Google Sheet
  Future<List<Map<String, dynamic>>> listSpreadsheetTabs(String spreadsheetId) async {
    final url = await _storage.getAppsScriptUrl();
    if (url == null || url.isEmpty) {
      throw Exception('Apps Script URL is not configured.');
    }

    final response = await _sendRequest(url, {
      'action': 'list_sheets',
      'spreadsheet_id': spreadsheetId,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final sheets = data['sheets'] as List<dynamic>? ?? [];
        return sheets.map((s) => Map<String, dynamic>.from(s as Map)).toList();
      } else {
        final err = data['error']?.toString() ?? '';
        if (err.contains('Unrecognized action')) {
          // Gracefully fallback to default sheet tab for older Apps Script deployments
          return [{'name': 'Default Sheet', 'sheet_id': 0, 'rows': 0, 'cols': 0}];
        }
        throw Exception(data['error'] ?? 'Failed to list spreadsheet tabs.');
      }
    } else {
      throw Exception('Apps Script returned status: ${response.statusCode}');
    }
  }

  /// Reads spreadsheet rows via Apps Script
  Future<List<Map<String, dynamic>>> readSheet({
    required String spreadsheetId,
    String? sheetName,
  }) async {
    final url = await _storage.getAppsScriptUrl();
    if (url == null || url.isEmpty) {
      throw Exception('Apps Script URL is not configured.');
    }

    final response = await _sendRequest(url, {
      'action': 'read_sheet',
      'spreadsheet_id': spreadsheetId,
      if (sheetName != null) 'sheet_name': sheetName,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        final rows = data['rows'] as List<dynamic>? ?? [];
        return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      } else {
        throw Exception(data['error'] ?? 'Failed to read sheet via Apps Script.');
      }
    } else {
      throw Exception('Apps Script returned status: ${response.statusCode}');
    }
  }

  /// Writes back tracking data to Google Sheets via Apps Script
  Future<bool> writeSheet({
    required String spreadsheetId,
    required int rowIndex,
    required Map<String, dynamic> updates,
    String? sheetName,
  }) async {
    final url = await _storage.getAppsScriptUrl();
    if (url == null || url.isEmpty) {
      throw Exception('Apps Script URL is not configured.');
    }

    final response = await _sendRequest(url, {
      'action': 'write_sheet',
      'spreadsheet_id': spreadsheetId,
      'row_index': rowIndex,
      'updates': updates,
      if (sheetName != null) 'sheet_name': sheetName,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['success'] == true;
    }
    return false;
  }

  /// Dispatches email verification receipt via Apps Script MailApp
  Future<bool> sendEmailReceipt({
    required String recipientEmail,
    required String certCode,
    required Map<String, dynamic> fields,
    String? pdfLink,
    String? schoolName,
  }) async {
    final url = await _storage.getAppsScriptUrl();
    if (url == null || url.isEmpty) {
      throw Exception('Apps Script URL is not configured.');
    }

    final response = await _sendRequest(url, {
      'action': 'send_email',
      'recipient_email': recipientEmail,
      'cert_code': certCode,
      'fields': fields,
      if (pdfLink != null) 'pdf_link': pdfLink,
      if (schoolName != null) 'school_name': schoolName,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['success'] == true;
    }
    return false;
  }
}
