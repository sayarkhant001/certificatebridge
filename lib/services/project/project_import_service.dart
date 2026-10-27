import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../../models/project_model.dart';
import '../../models/template_config.dart';
import '../database/project_repository.dart';
import '../engine/font_manager.dart';

class ProjectImportService {
  final ProjectRepository _repository = ProjectRepository();
  final FontManager _fontManager = FontManager();

  /// Unpacks a .cbproj archive into the target project directory and saves to database
  Future<ProjectModel> importBundle(
      List<int> bundleBytes, String targetDir) async {
    final decoder = ZipDecoder();
    final archive = decoder.decodeBytes(bundleBytes);

    Map<String, dynamic>? manifest;
    String layoutJson = '{}';
    String displayConfigJson = '{}';
    final extractedFonts = <File>[];
    String? templateUnderlayPath;

    final projectDir = Directory(targetDir);
    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
    }

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        final outFile = File(p.join(targetDir, filename));
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(data);

        if (filename == 'manifest.json') {
          manifest = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
        } else if (filename == 'layout.json') {
          layoutJson = utf8.decode(data);
        } else if (filename == 'display_config.json') {
          displayConfigJson = utf8.decode(data);
        } else if (filename.startsWith('fonts/')) {
          extractedFonts.add(outFile);
        } else if (filename.startsWith('assets/page_1_bg')) {
          templateUnderlayPath = outFile.path;
        }
      }
    }

    if (manifest == null) {
      throw const FormatException('Invalid .cbproj file: Missing manifest.json');
    }

    // Register all unpacked fonts into Flutter runtime
    for (final fontFile in extractedFonts) {
      await _fontManager.registerExternalFontFile(fontFile);
    }

    final projectId = manifest['project_id'] as String? ??
        DateTime.now().millisecondsSinceEpoch.toString();

    final importedProject = ProjectModel(
      id: projectId,
      name: manifest['name'] as String? ?? 'Imported Project',
      description: 'Imported from .cbproj on ${DateTime.now().toLocal()}',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      templatePath: templateUnderlayPath,
      layoutJson: layoutJson,
      displayConfigJson: displayConfigJson,
    );

    await _repository.insertProject(importedProject);
    return importedProject;
  }

  /// Automatically binds spreadsheet headers to canvas layout elements
  /// where {{Tag}} or boundColumn matches spreadsheet header names.
  String autoBindHeaders({
    required String layoutJson,
    required List<String> availableHeaders,
  }) {
    if (availableHeaders.isEmpty || layoutJson.isEmpty || layoutJson == '{}') {
      return layoutJson;
    }

    try {
      final config = TemplateConfig.fromJson(layoutJson);
      final updatedPages = config.pages.map((page) {
        final updatedElements = page.elements.map((el) {
          // If already bound to existing header, keep it
          if (el.boundColumn != null &&
              availableHeaders.contains(el.boundColumn)) {
            return el;
          }

          // Check if placeholder matches a header, e.g. {{Student_Name}}
          for (final header in availableHeaders) {
            final tag = '{{$header}}';
            if (el.text.contains(tag) ||
                el.name.toLowerCase() == header.toLowerCase()) {
              return el.copyWith(boundColumn: header);
            }
          }
          return el;
        }).toList();

        return TemplatePage(
          pageNumber: page.pageNumber,
          backgroundAssetPath: page.backgroundAssetPath,
          width: page.width,
          height: page.height,
          dpi: page.dpi,
          elements: updatedElements,
        );
      }).toList();

      final updatedConfig = TemplateConfig(
        version: config.version,
        orientation: config.orientation,
        pages: updatedPages,
      );

      return updatedConfig.toJson();
    } catch (_) {
      return layoutJson;
    }
  }
}
