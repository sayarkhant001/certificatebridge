import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../../models/project_model.dart';

class ProjectExportService {
  /// Packages project configuration, backgrounds, and embedded fonts into a .cbproj bundle.
  Future<List<int>> exportBundle({
    required ProjectModel project,
    required List<File> templatePages,
    required List<File> usedFonts,
  }) async {
    final archive = Archive();

    // 1. Manifest Entry
    final manifest = {
      'app': 'CertiBridge',
      'version': '1.0.0',
      'project_id': project.id,
      'name': project.name,
      'exported_at': DateTime.now().toIso8601String(),
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(
        ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    // 2. Layout & Display Settings
    final layoutBytes = utf8.encode(project.layoutJson);
    archive.addFile(
        ArchiveFile('layout.json', layoutBytes.length, layoutBytes));

    final configBytes = utf8.encode(project.displayConfigJson);
    archive.addFile(
        ArchiveFile('display_config.json', configBytes.length, configBytes));

    // 3. Asset Background Underlays
    for (int i = 0; i < templatePages.length; i++) {
      final file = templatePages[i];
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final ext = p.extension(file.path);
        archive.addFile(ArchiveFile(
            'assets/page_${i + 1}_bg$ext', bytes.length, bytes));
      }
    }

    // 4. Embedded TrueType Font Files
    for (final fontFile in usedFonts) {
      if (await fontFile.exists()) {
        final bytes = await fontFile.readAsBytes();
        final filename = p.basename(fontFile.path);
        archive.addFile(
            ArchiveFile('fonts/$filename', bytes.length, bytes));
      }
    }

    // 5. Zip Compress Bundle
    final encoder = ZipEncoder();
    return encoder.encode(archive) ?? <int>[];
  }

  /// Writes the .cbproj bytes to a destination file on disk.
  Future<File> saveBundleToFile({
    required List<int> bundleBytes,
    required String targetFilePath,
  }) async {
    final file = File(targetFilePath);
    await file.parent.create(recursive: true);
    return await file.writeAsBytes(bundleBytes);
  }
}
