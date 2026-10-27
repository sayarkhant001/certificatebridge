import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../auth/google_auth_service.dart';

class SheetsService {
  final GoogleAuthService _authService = GoogleAuthService();

  static const String _baseUrl = 'https://sheets.googleapis.com/v4/spreadsheets';

  /// Extracts Google Spreadsheet ID from a URL or raw ID
  String extractSpreadsheetId(String input) {
    final trimmed = input.trim();
    final regExp = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)');
    final match = regExp.firstMatch(trimmed);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!;
    }
    return trimmed;
  }

  /// Fetches sheet records from Google Sheets API
  Future<List<Map<String, dynamic>>> fetchSheetData({
    required String spreadsheetId,
    String range = 'A1:ZZ',
  }) async {
    final token = await _authService.getValidAccessToken();
    if (token == null) throw Exception('Google account is not authenticated.');

    final cleanId = extractSpreadsheetId(spreadsheetId);
    final uri = Uri.parse('$_baseUrl/$cleanId/values/$range');

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final values = data['values'] as List<dynamic>? ?? [];
      if (values.isEmpty) return [];

      final headers = (values.first as List<dynamic>)
          .map((e) => e.toString().trim())
          .toList();

      final results = <Map<String, dynamic>>[];
      for (int i = 1; i < values.length; i++) {
        final row = values[i] as List<dynamic>;
        if (row.isEmpty) continue;

        final map = <String, dynamic>{};
        bool hasData = false;
        for (int c = 0; c < headers.length; c++) {
          final header = headers[c];
          final val = c < row.length ? row[c].toString() : '';
          map[header] = val;
          if (val.trim().isNotEmpty) hasData = true;
        }
        if (hasData) {
          results.add(map);
        }
      }
      return results;
    } else {
      throw Exception('Failed to fetch Google Sheet data: ${response.statusCode} ${response.body}');
    }
  }

  /// Appends or updates tracking columns in Google Sheet via single batchUpdate
  Future<bool> writeBackGoogleSheets({
    required String spreadsheetId,
    required String sheetTitle,
    required List<String> currentHeaders,
    required List<Map<String, dynamic>> trackingRows,
  }) async {
    final token = await _authService.getValidAccessToken();
    if (token == null) throw Exception('Google account is not authenticated.');

    final cleanId = extractSpreadsheetId(spreadsheetId);
    final trackingCols = AppConstants.trackingColumns;

    // Determine start column letter (e.g., column index -> A, B, ..., Z, AA)
    int startColIndex = currentHeaders.length;
    final startColLetter = _columnIndexToLetter(startColIndex);
    final endColLetter = _columnIndexToLetter(startColIndex + trackingCols.length - 1);

    final totalRows = trackingRows.length + 1; // including header
    final targetRange = '$sheetTitle!${startColLetter}1:$endColLetter$totalRows';

    // Construct 2D values array
    final List<List<dynamic>> values = [trackingCols];
    for (final row in trackingRows) {
      final rowValues = <dynamic>[];
      for (final col in trackingCols) {
        rowValues.add(row[col]?.toString() ?? '');
      }
      values.add(rowValues);
    }

    final payload = {
      'valueInputOption': 'USER_ENTERED',
      'data': [
        {
          'range': targetRange,
          'values': values,
        }
      ]
    };

    final uri = Uri.parse('$_baseUrl/$cleanId/values:batchUpdate');
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Failed to write back to Google Sheets: ${response.statusCode} ${response.body}');
    }
  }

  String _columnIndexToLetter(int index) {
    String result = '';
    int temp = index;
    while (temp >= 0) {
      result = String.fromCharCode((temp % 26) + 65) + result;
      temp = (temp ~/ 26) - 1;
    }
    return result;
  }
}
