import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/canvas_element.dart';
import '../../models/display_config.dart';
import '../../models/project_model.dart';
import '../../models/template_config.dart';
import '../../services/database/project_repository.dart';
import '../../services/engine/font_manager.dart';
import '../../services/excel/excel_service.dart';
import '../../services/google/sheets_service.dart';
import '../batch/batch_progress_view.dart';
import '../privacy/verifier_display_table.dart';
import 'live_preview_bar.dart';
import 'widgets/canvas_element_widget.dart';
import 'widgets/context_menu_overlay.dart';

class VisualCanvasView extends StatefulWidget {
  final ProjectModel project;

  const VisualCanvasView({Key? key, required this.project}) : super(key: key);

  @override
  State<VisualCanvasView> createState() => _VisualCanvasViewState();
}

class _VisualCanvasViewState extends State<VisualCanvasView> {
  final ProjectRepository _projectRepo = ProjectRepository();
  final ExcelService _excelService = ExcelService();
  final SheetsService _sheetsService = SheetsService();
  final FontManager _fontManager = FontManager();

  late ProjectModel _project;
  late TemplateConfig _templateConfig;
  late DisplayConfig _displayConfig;

  int _currentPageIndex = 0;
  String? _selectedElementId;
  CanvasElement? _contextMenuElement;

  // Ingested Dataset
  List<Map<String, dynamic>> _datasetRows = [];
  List<String> _datasetHeaders = [];
  int _currentRowIndex = 0;
  bool _isPreviewMode = false;
  String? _photosDirectory;

  double _zoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _templateConfig = TemplateConfig.fromJson(_project.layoutJson);
    _displayConfig = DisplayConfig.fromJson(_project.displayConfigJson);
    _fontManager.initialize();
  }

  Future<void> _saveProject() async {
    final updated = _project.copyWith(
      layoutJson: _templateConfig.toJson(),
      displayConfigJson: _displayConfig.toJson(),
      updatedAt: DateTime.now(),
      totalCertificates: _datasetRows.length,
    );
    await _projectRepo.updateProject(updated);
    setState(() => _project = updated);
  }

  void _addElement(CanvasElementType type) {
    final currentPage = _templateConfig.pages[_currentPageIndex];
    final id = const Uuid().v4().substring(0, 8);

    CanvasElement newElement;
    switch (type) {
      case CanvasElementType.text:
        newElement = CanvasElement(
          id: id,
          name: 'Text Field',
          type: CanvasElementType.text,
          pageIndex: _currentPageIndex,
          x: 0.2,
          y: 0.3,
          w: 0.6,
          h: 0.08,
          text: 'New Dynamic Text',
          fontSize: 26.0,
        );
        break;
      case CanvasElementType.photo:
        newElement = CanvasElement(
          id: id,
          name: 'Student Photo',
          type: CanvasElementType.photo,
          pageIndex: _currentPageIndex,
          x: 0.08,
          y: 0.15,
          w: 0.18,
          h: 0.24,
          clippingShape: PhotoClippingShape.roundedRectangle,
          borderRadius: 8.0,
        );
        break;
      case CanvasElementType.qr:
        newElement = CanvasElement(
          id: id,
          name: 'Verification QR',
          type: CanvasElementType.qr,
          pageIndex: _currentPageIndex,
          x: 0.8,
          y: 0.75,
          w: 0.14,
          h: 0.18,
        );
        break;
    }

    final updatedElements = List<CanvasElement>.from(currentPage.elements)..add(newElement);
    final updatedPages = List<TemplatePage>.from(_templateConfig.pages);
    updatedPages[_currentPageIndex] = TemplatePage(
      pageNumber: currentPage.pageNumber,
      backgroundAssetPath: currentPage.backgroundAssetPath,
      width: currentPage.width,
      height: currentPage.height,
      dpi: currentPage.dpi,
      elements: updatedElements,
    );

    setState(() {
      _templateConfig = TemplateConfig(
        version: _templateConfig.version,
        orientation: _templateConfig.orientation,
        pages: updatedPages,
      );
      _selectedElementId = id;
    });
    _saveProject();
  }

  void _updateElement(CanvasElement element) {
    final currentPage = _templateConfig.pages[_currentPageIndex];
    final updatedElements = currentPage.elements.map((e) => e.id == element.id ? element : e).toList();
    final updatedPages = List<TemplatePage>.from(_templateConfig.pages);
    updatedPages[_currentPageIndex] = TemplatePage(
      pageNumber: currentPage.pageNumber,
      backgroundAssetPath: currentPage.backgroundAssetPath,
      width: currentPage.width,
      height: currentPage.height,
      dpi: currentPage.dpi,
      elements: updatedElements,
    );

    setState(() {
      _templateConfig = TemplateConfig(
        version: _templateConfig.version,
        orientation: _templateConfig.orientation,
        pages: updatedPages,
      );
    });
    _saveProject();
  }

  void _deleteElement(String elementId) {
    final currentPage = _templateConfig.pages[_currentPageIndex];
    final updatedElements = currentPage.elements.where((e) => e.id != elementId).toList();
    final updatedPages = List<TemplatePage>.from(_templateConfig.pages);
    updatedPages[_currentPageIndex] = TemplatePage(
      pageNumber: currentPage.pageNumber,
      backgroundAssetPath: currentPage.backgroundAssetPath,
      width: currentPage.width,
      height: currentPage.height,
      dpi: currentPage.dpi,
      elements: updatedElements,
    );

    setState(() {
      _templateConfig = TemplateConfig(
        version: _templateConfig.version,
        orientation: _templateConfig.orientation,
        pages: updatedPages,
      );
      _selectedElementId = null;
      _contextMenuElement = null;
    });
    _saveProject();
  }

  Future<void> _handleImportSpreadsheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_present_outlined, color: Colors.greenAccent),
              title: const Text('Import Local Excel / CSV (.xlsx, .csv)'),
              subtitle: const Text('Parse dataset natively on local machine'),
              onTap: () => Navigator.pop(ctx, 'excel'),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download_outlined, color: Colors.blueAccent),
              title: const Text('Import Live Google Sheet'),
              subtitle: const Text('Direct URL parser & Google Sheets API'),
              onTap: () => Navigator.pop(ctx, 'sheets'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'excel') {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        try {
          final rows = await _excelService.readSpreadsheet(path);
          if (rows.isNotEmpty) {
            final headers = rows.first.keys.toList();
            setState(() {
              _datasetRows = rows;
              _datasetHeaders = headers;
              _currentRowIndex = 0;
              _isPreviewMode = true;
            });
            _saveProject();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Loaded ${rows.length} records with ${headers.length} columns!'),
                backgroundColor: const Color(0xFF059669),
              ),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error reading spreadsheet: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } else if (choice == 'sheets') {
      final urlCtrl = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Import Google Sheet'),
          content: TextField(
            controller: urlCtrl,
            decoration: const InputDecoration(
              labelText: 'Google Sheet URL or Spreadsheet ID',
              hintText: 'https://docs.google.com/spreadsheets/d/.../edit',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Fetch Data')),
          ],
        ),
      );

      if (confirm == true && urlCtrl.text.trim().isNotEmpty) {
        try {
          final rows = await _sheetsService.fetchSheetData(spreadsheetId: urlCtrl.text.trim());
          if (rows.isNotEmpty) {
            setState(() {
              _datasetRows = rows;
              _datasetHeaders = rows.first.keys.toList();
              _currentRowIndex = 0;
              _isPreviewMode = true;
            });
            _saveProject();
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Google Sheets error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _pickPhotosFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select Student Photos Directory');
    if (path != null) {
      setState(() => _photosDirectory = path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photos folder linked: $path'), backgroundColor: const Color(0xFF059669)),
      );
    }
  }

  void _openPrivacySettings() {
    showDialog(
      context: context,
      builder: (_) => VerifierDisplayTable(
        availableColumns: _datasetHeaders.isNotEmpty
            ? _datasetHeaders
            : ['Student_Name', 'Course_Name', 'Issue_Date', 'Certificate_Code', 'Student_Email', 'Photo'],
        initialConfig: _displayConfig,
        onSaveConfig: (updated) {
          setState(() => _displayConfig = updated);
          _saveProject();
        },
      ),
    );
  }

  void _openBatchGenerator() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BatchProgressView(
          project: _project,
          datasetRows: _datasetRows,
          displayConfig: _displayConfig,
          photosDirectory: _photosDirectory,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = _templateConfig.pages[_currentPageIndex];
    final sampleRow = _isPreviewMode && _datasetRows.isNotEmpty
        ? _datasetRows[_currentRowIndex]
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_project.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              'Page ${_currentPageIndex + 1} of ${_templateConfig.pages.length} &bull; Normalized Resolution-Independent Canvas',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 20),
            onPressed: () => setState(() => _zoomLevel = (_zoomLevel - 0.1).clamp(0.5, 2.0)),
            tooltip: 'Zoom Out',
          ),
          Center(
            child: Text(
              '${(_zoomLevel * 100).toInt()}%',
              style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: 'monospace'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 20),
            onPressed: () => setState(() => _zoomLevel = (_zoomLevel + 0.1).clamp(0.5, 2.0)),
            tooltip: 'Zoom In',
          ),
          const VerticalDivider(color: Color(0xFF334155), indent: 12, endIndent: 12),
          IconButton(
            icon: const Icon(Icons.folder_shared_outlined, size: 20, color: Color(0xFFFBBF24)),
            onPressed: _pickPhotosFolder,
            tooltip: _photosDirectory != null ? 'Photos: $_photosDirectory' : 'Link Photos Directory',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Live Data Control Bar
              LivePreviewBar(
                currentRowIndex: _currentRowIndex,
                totalRows: _datasetRows.length,
                isPreviewMode: _isPreviewMode,
                onPrevRow: () => setState(() => _currentRowIndex--),
                onNextRow: () => setState(() => _currentRowIndex++),
                onTogglePreviewMode: (v) => setState(() => _isPreviewMode = v),
                onImportDataset: _handleImportSpreadsheet,
                onConfigurePrivacy: _openPrivacySettings,
                onStartBatch: _openBatchGenerator,
              ),

              // Interactive Visual Canvas Workspace
              Expanded(
                child: Row(
                  children: [
                    // Left Tool Palette
                    Container(
                      width: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        border: Border(right: BorderSide(color: Color(0xFF334155))),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          IconButton(
                            icon: const Icon(Icons.text_fields, color: Colors.white70),
                            onPressed: () => _addElement(CanvasElementType.text),
                            tooltip: 'Add Dynamic Text',
                          ),
                          IconButton(
                            icon: const Icon(Icons.portrait, color: Colors.white70),
                            onPressed: () => _addElement(CanvasElementType.photo),
                            tooltip: 'Add Photo Box',
                          ),
                          IconButton(
                            icon: const Icon(Icons.qr_code, color: Colors.white70),
                            onPressed: () => _addElement(CanvasElementType.qr),
                            tooltip: 'Add QR Code',
                          ),
                          const Divider(color: Color(0xFF334155), indent: 12, endIndent: 12),
                          IconButton(
                            icon: const Icon(Icons.save_outlined, color: Color(0xFF34D399)),
                            onPressed: _saveProject,
                            tooltip: 'Save Layout',
                          ),
                        ],
                      ),
                    ),

                    // Canvas Viewport
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedElementId = null),
                        child: Container(
                          color: const Color(0xFF0B0F19),
                          child: Center(
                            child: Transform.scale(
                              scale: _zoomLevel,
                              child: Container(
                                width: currentPage.width,
                                height: currentPage.height,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, 8)),
                                  ],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // Template Underlay Background
                                    if (currentPage.backgroundAssetPath != null &&
                                        File(currentPage.backgroundAssetPath!).existsSync())
                                      Positioned.fill(
                                        child: Image.file(
                                          File(currentPage.backgroundAssetPath!),
                                          fit: BoxFit.fill,
                                        ),
                                      )
                                    else
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(color: const Color(0xFFD4AF37), width: 8),
                                            color: const Color(0xFFFAFAF9),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              'Certificate Canvas Template',
                                              style: TextStyle(color: Colors.black26, fontSize: 24, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ),

                                    // Render all interactive canvas elements
                                    ...currentPage.elements.map((el) {
                                      return CanvasElementWidget(
                                        key: ValueKey(el.id),
                                        element: el,
                                        canvasWidth: currentPage.width,
                                        canvasHeight: currentPage.height,
                                        isSelected: _selectedElementId == el.id,
                                        sampleData: sampleRow,
                                        certCode: sampleRow != null ? 'CERT-2026-X89J' : null,
                                        onSelect: () => setState(() => _selectedElementId = el.id),
                                        onElementChanged: (updated) => _updateElement(updated),
                                        onOpenContextMenu: () {
                                          setState(() => _contextMenuElement = el);
                                        },
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Context Menu Overlay when right-click or long-press is triggered
          if (_contextMenuElement != null)
            ContextMenuOverlay(
              element: _contextMenuElement!,
              availableHeaders: _datasetHeaders,
              onElementUpdated: (updated) {
                _updateElement(updated);
                setState(() => _contextMenuElement = updated);
              },
              onDelete: () => _deleteElement(_contextMenuElement!.id),
              onClose: () => setState(() => _contextMenuElement = null),
            ),
        ],
      ),
    );
  }
}
