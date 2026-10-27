import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_constants.dart';

class ExcelService {
  /// Reads a local .xlsx or .csv file and normalizes into List<Map<String, dynamic>>
  Future<List<Map<String, dynamic>>> readSpreadsheet(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Spreadsheet file not found', filePath);
    }

    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.csv') {
      return await _readCsv(file);
    } else if (ext == '.xlsx' || ext == '.xls') {
      return await _readExcel(file);
    } else {
      throw FormatException('Unsupported spreadsheet format: $ext. Use .xlsx or .csv');
    }
  }

  Future<List<Map<String, dynamic>>> _readCsv(File file) async {
    final input = await file.readAsString();
    final rows = const CsvToListConverter(shouldParseNumbers: false).convert(input);
    if (rows.isEmpty) return [];

    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final result = <Map<String, dynamic>>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || (row.length == 1 && row[0].toString().trim().isEmpty)) {
        continue;
      }
      final map = <String, dynamic>{};
      for (int c = 0; c < headers.length; c++) {
        final key = headers[c];
        final val = c < row.length ? row[c] : '';
        map[key] = val;
      }
      result.add(map);
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _readExcel(File file) async {
    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) return [];
    // Read the first table/sheet
    final sheet = excel.tables[excel.tables.keys.first]!;
    if (sheet.rows.isEmpty) return [];

    final headers = sheet.rows.first.map((cell) => cell?.value?.toString().trim() ?? '').toList();
    final result = <Map<String, dynamic>>[];

    for (int r = 1; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      if (row.isEmpty) continue;

      final map = <String, dynamic>{};
      bool hasData = false;
      for (int c = 0; c < headers.length; c++) {
        final key = headers[c];
        if (key.isEmpty) continue;
        final cellVal = c < row.length ? row[c]?.value : null;
        if (cellVal != null && cellVal.toString().trim().isNotEmpty) {
          hasData = true;
        }
        map[key] = cellVal?.toString() ?? '';
      }
      if (hasData) {
        result.add(map);
      }
    }
    return result;
  }

  /// Extracts column header names from spreadsheet
  Future<List<String>> extractHeaders(String filePath) async {
    final data = await readSpreadsheet(filePath);
    if (data.isEmpty) return [];
    return data.first.keys.toList();
  }

  /// Appends tracking columns back to local Excel (.xlsx) file with Windows file-lock handling
  Future<String> writeBackExcel({
    required String filePath,
    required List<Map<String, dynamic>> trackingRows,
    String? fallbackSaveAsPath,
  }) async {
    final file = File(filePath);
    final ext = p.extension(filePath).toLowerCase();

    if (ext == '.csv') {
      return await _writeBackCsv(file, trackingRows, fallbackSaveAsPath);
    }

    try {
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName]!;

      // Find current header row
      final currentHeaders = sheet.rows.first.map((c) => c?.value?.toString().trim() ?? '').toList();
      final appendedHeaders = AppConstants.trackingColumns;

      final headerIndices = <String, int>{};
      for (int i = 0; i < appendedHeaders.length; i++) {
        final colName = appendedHeaders[i];
        int colIdx = currentHeaders.indexOf(colName);
        if (colIdx == -1) {
          colIdx = currentHeaders.length;
          currentHeaders.add(colName);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: 0))
            ..value = TextCellValue(colName);
        }
        headerIndices[colName] = colIdx;
      }

      // Write tracking row data
      for (int r = 0; r < trackingRows.length; r++) {
        final rowIndex = r + 1; // 1-indexed (row 0 is header)
        final rowData = trackingRows[r];

        for (final colName in appendedHeaders) {
          final colIdx = headerIndices[colName]!;
          final val = rowData[colName]?.toString() ?? '';
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: rowIndex))
            ..value = TextCellValue(val);
        }
      }

      final encoded = excel.encode();
      if (encoded == null) {
        throw Exception('Failed to encode updated Excel file');
      }

      try {
        await file.writeAsBytes(encoded, flush: true);
        return file.path;
      } on FileSystemException {
        // Handled file-lock: if open in Excel, save to fallback path
        final savePath = fallbackSaveAsPath ??
            p.join(
              p.dirname(filePath),
              '${p.basenameWithoutExtension(filePath)}_verified_${DateTime.now().millisecondsSinceEpoch}.xlsx',
            );
        final fallbackFile = File(savePath);
        await fallbackFile.writeAsBytes(encoded, flush: true);
        return savePath;
      }
    } catch (e) {
      if (e is FileSystemException) {
        rethrow;
      }
      throw Exception('Excel write-back error: $e');
    }
  }

  Future<String> _writeBackCsv(
    File file,
    List<Map<String, dynamic>> trackingRows,
    String? fallbackSaveAsPath,
  ) async {
    final content = await file.readAsString();
    final rows = const CsvToListConverter(shouldParseNumbers: false).convert(content);
    if (rows.isEmpty) return file.path;

    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final trackingCols = AppConstants.trackingColumns;
    for (final col in trackingCols) {
      if (!headers.contains(col)) {
        headers.add(col);
      }
    }

    final outputRows = <List<dynamic>>[headers];
    for (int r = 0; r < trackingRows.length; r++) {
      final originalRow = (r + 1 < rows.length) ? List<dynamic>.from(rows[r + 1]) : [];
      while (originalRow.length < headers.length - trackingCols.length) {
        originalRow.add('');
      }

      final trackData = trackingRows[r];
      for (final col in trackingCols) {
        originalRow.add(trackData[col]?.toString() ?? '');
      }
      outputRows.add(originalRow);
    }

    final csvString = const ListToCsvConverter().convert(outputRows);
    try {
      await file.writeAsString(csvString, flush: true);
      return file.path;
    } on FileSystemException {
      final savePath = fallbackSaveAsPath ??
          p.join(
            p.dirname(file.path),
            '${p.basenameWithoutExtension(file.path)}_verified_${DateTime.now().millisecondsSinceEpoch}.csv',
          );
      final fallbackFile = File(savePath);
      await fallbackFile.writeAsString(csvString, flush: true);
      return savePath;
    }
  }
}
