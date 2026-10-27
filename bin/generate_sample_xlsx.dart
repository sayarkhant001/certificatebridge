import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

void main() async {
  final csvFile = File('assets/sample_students.csv');
  final csvContent = await csvFile.readAsString();
  final rows = const CsvToListConverter().convert(csvContent);

  final excel = Excel.createExcel();
  final sheetName = 'Certificates';
  excel.rename('Sheet1', sheetName);
  final sheet = excel[sheetName];

  for (int r = 0; r < rows.length; r++) {
    final row = rows[r];
    for (int c = 0; c < row.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
      cell.value = TextCellValue(row[c].toString());
    }
  }

  final bytes = excel.encode();
  if (bytes != null) {
    await File('assets/sample_students.xlsx').writeAsBytes(bytes);
    print('Generated assets/sample_students.xlsx successfully');
  }
}
