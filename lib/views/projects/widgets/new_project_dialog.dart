import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../models/display_config.dart';
import '../../../models/project_model.dart';
import '../../../models/template_config.dart';
import '../../../services/engine/template_importer.dart';

class NewProjectDialog extends StatefulWidget {
  const NewProjectDialog({Key? key}) : super(key: key);

  @override
  State<NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<NewProjectDialog> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TemplateImporter _importer = TemplateImporter();

  String? _selectedTemplatePath;
  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _pickTemplateFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedTemplatePath = result.files.single.path;
        if (_nameCtrl.text.isEmpty) {
          _nameCtrl.text = p.basenameWithoutExtension(_selectedTemplatePath!);
        }
      });
    }
  }

  Future<void> _createProject() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Project name is required.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final projectId = const Uuid().v4();
      final appDir = await getApplicationDocumentsDirectory();
      final projectDir = Directory(p.join(appDir.path, 'CertiBridge', 'projects', projectId));
      final assetsDir = p.join(projectDir.path, 'assets');
      await Directory(assetsDir).create(recursive: true);

      TemplateConfig templateConfig;
      String? templateFirstPageBg;

      if (_selectedTemplatePath != null) {
        final importedPages = await _importer.importTemplate(
          templateFile: File(_selectedTemplatePath!),
          targetAssetsDir: assetsDir,
        );

        final templatePages = importedPages.map((pageInfo) {
          final defaultConfig = TemplateConfig.defaultConfig();
          return TemplatePage(
            pageNumber: pageInfo.pageNumber,
            backgroundAssetPath: pageInfo.imagePath,
            width: pageInfo.width,
            height: pageInfo.height,
            elements: pageInfo.pageNumber == 1 ? defaultConfig.pages.first.elements : [],
          );
        }).toList();

        templateConfig = TemplateConfig(pages: templatePages);
        templateFirstPageBg = importedPages.first.imagePath;
      } else {
        templateConfig = TemplateConfig.defaultConfig();
      }

      final newProject = ProjectModel(
        id: projectId,
        name: name,
        description: _descCtrl.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        templatePath: templateFirstPageBg,
        layoutJson: templateConfig.toJson(),
        displayConfigJson: DisplayConfig.defaultConfig().toJson(),
      );

      Navigator.pop(context, newProject);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to create project: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create New Project Workspace',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              'Projects isolate templates, typography, and data into portable .cbproj bundles.',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            const Divider(color: Color(0xFF334155), height: 28),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF991B1B).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFDC2626)),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
              ),

            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Project Name *',
                hintText: 'e.g. Graduation 2026, Robotics Bootcamp',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'e.g. Annual graduation diploma certificates batch',
              ),
            ),
            const SizedBox(height: 18),

            // Template File Picker Box
            InkWell(
              onTap: _pickTemplateFile,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF475569), style: BorderStyle.solid),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF60A5FA), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedTemplatePath != null
                                ? p.basename(_selectedTemplatePath!)
                                : 'Select Certificate Template Underlay',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _selectedTemplatePath != null ? Colors.white : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _selectedTemplatePath != null
                                ? _selectedTemplatePath!
                                : 'Supports Multi-Page PDF (300 DPI rasterized) or PNG/JPG',
                            style: const TextStyle(fontSize: 11, color: Colors.white38),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.folder_open, color: Colors.white54),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _createProject,
                  child: _isProcessing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Project'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
