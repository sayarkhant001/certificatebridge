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
import '../batch/google_sheet_picker_dialog.dart';
import '../privacy/verification_page_designer_dialog.dart';
import 'live_preview_bar.dart';
import 'widgets/alignment_guidelines_overlay.dart';
import 'widgets/canvas_element_widget.dart';
import 'widgets/context_menu_overlay.dart';
import 'widgets/properties_inspector_panel.dart';

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

  // Canvas Viewport Controls
  double _zoomLevel = 1.0;
  bool _showGrid = true;
  bool _enableSnapping = true;
  List<double> _snapLinesX = [];
  List<double> _snapLinesY = [];

  // Canva-style Left Navigation Rail
  int _activeLeftTabIndex = 0; // 0: Elements, 1: Data Columns, 2: Layers, 3: Background

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

  void _addElement(CanvasElementType type, {String? text, String? boundColumn}) {
    final currentPage = _templateConfig.pages[_currentPageIndex];
    final id = const Uuid().v4().substring(0, 8);

    CanvasElement newElement;
    switch (type) {
      case CanvasElementType.text:
        newElement = CanvasElement(
          id: id,
          name: boundColumn != null ? 'Data: $boundColumn' : 'Text Field',
          type: CanvasElementType.text,
          pageIndex: _currentPageIndex,
          x: 0.25,
          y: 0.35,
          w: 0.5,
          h: 0.08,
          text: text ?? (boundColumn != null ? '{{$boundColumn}}' : 'New Dynamic Text'),
          boundColumn: boundColumn,
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
          x: 0.78,
          y: 0.72,
          w: 0.15,
          h: 0.20,
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
      if (_selectedElementId == elementId) {
        _selectedElementId = null;
      }
      _contextMenuElement = null;
    });
    _saveProject();
  }

  void _duplicateElement(CanvasElement element) {
    final newId = const Uuid().v4().substring(0, 8);
    final cloned = element.copyWith(
      id: newId,
      name: '${element.name} (Copy)',
      x: (element.x + 0.02).clamp(0.0, 0.9),
      y: (element.y + 0.02).clamp(0.0, 0.9),
    );

    final currentPage = _templateConfig.pages[_currentPageIndex];
    final updatedElements = List<CanvasElement>.from(currentPage.elements)..add(cloned);
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
      _selectedElementId = newId;
    });
    _saveProject();
  }

  void _bringToFront(String id) {
    final currentPage = _templateConfig.pages[_currentPageIndex];
    final el = currentPage.elements.firstWhere((e) => e.id == id, orElse: () => currentPage.elements.first);
    final updatedElements = List<CanvasElement>.from(currentPage.elements)..removeWhere((e) => e.id == id)..add(el);
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

  void _sendToBack(String id) {
    final currentPage = _templateConfig.pages[_currentPageIndex];
    final el = currentPage.elements.firstWhere((e) => e.id == id, orElse: () => currentPage.elements.first);
    final updatedElements = [el, ...currentPage.elements.where((e) => e.id != id)];
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

  void _centerHorizontal(String id) {
    final currentPage = _templateConfig.pages[_currentPageIndex];
    final el = currentPage.elements.firstWhere((e) => e.id == id);
    _updateElement(el.copyWith(x: ((1.0 - el.w) / 2.0).clamp(0.0, 1.0)));
  }

  void _centerVertical(String id) {
    final currentPage = _templateConfig.pages[_currentPageIndex];
    final el = currentPage.elements.firstWhere((e) => e.id == id);
    _updateElement(el.copyWith(y: ((1.0 - el.h) / 2.0).clamp(0.0, 1.0)));
  }

  Future<void> _pickBackground() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final currentPage = _templateConfig.pages[_currentPageIndex];
      final updatedPages = List<TemplatePage>.from(_templateConfig.pages);
      updatedPages[_currentPageIndex] = TemplatePage(
        pageNumber: currentPage.pageNumber,
        backgroundAssetPath: path,
        width: currentPage.width,
        height: currentPage.height,
        dpi: currentPage.dpi,
        elements: currentPage.elements,
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
  }

  void _handleElementDrag(Rect rect, CanvasElement activeElement, TemplatePage page) {
    if (!_enableSnapping) return;

    final double threshold = 8.0;
    final List<double> snapX = [];
    final List<double> snapY = [];

    // 1. Center Snapping
    final canvasCenterX = page.width / 2.0;
    final canvasCenterY = page.height / 2.0;

    if ((rect.center.dx - canvasCenterX).abs() < threshold) {
      snapX.add(canvasCenterX);
    }
    if ((rect.center.dy - canvasCenterY).abs() < threshold) {
      snapY.add(canvasCenterY);
    }

    // 2. Margins Snapping (5% margin)
    final marginX = page.width * 0.05;
    final marginY = page.height * 0.05;
    if ((rect.left - marginX).abs() < threshold) snapX.add(marginX);
    if ((rect.right - (page.width - marginX)).abs() < threshold) snapX.add(page.width - marginX);
    if ((rect.top - marginY).abs() < threshold) snapY.add(marginY);
    if ((rect.bottom - (page.height - marginY)).abs() < threshold) snapY.add(page.height - marginY);

    // 3. Alignment with Other Elements
    for (final other in page.elements) {
      if (other.id == activeElement.id) continue;
      final oLeft = other.x * page.width;
      final oRight = (other.x + other.w) * page.width;
      final oCenterX = oLeft + (other.w * page.width) / 2.0;
      final oTop = other.y * page.height;
      final oBottom = (other.y + other.h) * page.height;
      final oCenterY = oTop + (other.h * page.height) / 2.0;

      if ((rect.left - oLeft).abs() < threshold) snapX.add(oLeft);
      if ((rect.right - oRight).abs() < threshold) snapX.add(oRight);
      if ((rect.center.dx - oCenterX).abs() < threshold) snapX.add(oCenterX);

      if ((rect.top - oTop).abs() < threshold) snapY.add(oTop);
      if ((rect.bottom - oBottom).abs() < threshold) snapY.add(oBottom);
      if ((rect.center.dy - oCenterY).abs() < threshold) snapY.add(oCenterY);
    }

    setState(() {
      _snapLinesX = snapX;
      _snapLinesY = snapY;
    });
  }

  void _handleDragEnd() {
    setState(() {
      _snapLinesX = [];
      _snapLinesY = [];
    });
  }

  Future<void> _handleImportSpreadsheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.input, color: Color(0xFF38BDF8), size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Choose Dataset Source',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF334155)),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.file_present_outlined, color: Color(0xFF34D399), size: 24),
                ),
                title: const Text('Import Local Excel / CSV (.xlsx, .csv)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Fast local parsing on your machine', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, 'excel'),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.table_chart_outlined, color: Color(0xFF60A5FA), size: 24),
                ),
                title: const Text('Google Drive & Multi-Page Sheets', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text('Browse Drive, choose exact worksheet tab, and preview rows live', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, 'sheets'),
              ),
            ],
          ),
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
              _activeLeftTabIndex = 1; // Switch to dynamic data columns tab
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
      final result = await showDialog<GoogleSheetImportResult>(
        context: context,
        builder: (_) => const GoogleSheetPickerDialog(),
      );

      if (result != null && result.rows.isNotEmpty) {
        setState(() {
          _datasetRows = result.rows;
          _datasetHeaders = result.headers;
          _currentRowIndex = 0;
          _isPreviewMode = true;
          _activeLeftTabIndex = 1; // Switch to dynamic data columns tab
        });
        _saveProject();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${result.rows.length} records from ${result.sheetTitle != null ? "Tab: ${result.sheetTitle}" : "Google Sheet"}!',
            ),
            backgroundColor: const Color(0xFF059669),
          ),
        );
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
      builder: (_) => VerificationPageDesignerDialog(
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

  File? _resolvePhotoForSample(Map<String, dynamic>? sampleRow) {
    if (sampleRow == null || _photosDirectory == null) return null;
    final keys = ['Photo', 'photo', 'Image', 'image', 'Student_Photo', 'Student_ID', 'ID'];
    for (final k in keys) {
      if (sampleRow.containsKey(k)) {
        final val = sampleRow[k]?.toString().trim();
        if (val != null && val.isNotEmpty) {
          final f1 = File('$_photosDirectory/$val');
          if (f1.existsSync()) return f1;
          final f2 = File('$_photosDirectory/$val.jpg');
          if (f2.existsSync()) return f2;
          final f3 = File('$_photosDirectory/$val.png');
          if (f3.existsSync()) return f3;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = _templateConfig.pages[_currentPageIndex];
    final sampleRow = _isPreviewMode && _datasetRows.isNotEmpty
        ? _datasetRows[_currentRowIndex]
        : null;
    final samplePhoto = _resolvePhotoForSample(sampleRow);

    final selectedElement = _selectedElementId != null
        ? currentPage.elements.cast<CanvasElement?>().firstWhere(
            (e) => e?.id == _selectedElementId,
            orElse: () => null,
          )
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF06B6D4)]),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('CANVA STUDIO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_project.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(
                  'Page ${_currentPageIndex + 1} of ${_templateConfig.pages.length} • ${currentPage.width.toInt()}x${currentPage.height.toInt()} px • ${currentPage.dpi} DPI',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Alignment Grid Toggle
          IconButton(
            icon: Icon(_showGrid ? Icons.grid_on : Icons.grid_off, size: 20, color: _showGrid ? const Color(0xFF38BDF8) : Colors.white54),
            onPressed: () => setState(() => _showGrid = !_showGrid),
            tooltip: _showGrid ? 'Hide Alignment Grid' : 'Show Alignment Grid (25px)',
          ),

          // Magnetic Snapping Toggle
          IconButton(
            icon: Icon(Icons.filter_center_focus, size: 20, color: _enableSnapping ? const Color(0xFFEC4899) : Colors.white54),
            onPressed: () => setState(() => _enableSnapping = !_enableSnapping),
            tooltip: _enableSnapping ? 'Magnetic Snapping Active' : 'Magnetic Snapping Disabled',
          ),
          const VerticalDivider(color: Color(0xFF334155), indent: 12, endIndent: 12),

          // Zoom Controls
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 20, color: Colors.white70),
            onPressed: () => setState(() => _zoomLevel = (_zoomLevel - 0.1).clamp(0.4, 2.0)),
            tooltip: 'Zoom Out',
          ),
          InkWell(
            onTap: () => setState(() => _zoomLevel = 1.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: Center(
                child: Text(
                  '${(_zoomLevel * 100).toInt()}%',
                  style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 20, color: Colors.white70),
            onPressed: () => setState(() => _zoomLevel = (_zoomLevel + 0.1).clamp(0.4, 2.0)),
            tooltip: 'Zoom In',
          ),
          const VerticalDivider(color: Color(0xFF334155), indent: 12, endIndent: 12),

          // Link Photos Folder
          IconButton(
            icon: Icon(
              Icons.folder_shared_outlined,
              size: 20,
              color: _photosDirectory != null ? const Color(0xFFFBBF24) : Colors.white54,
            ),
            onPressed: _pickPhotosFolder,
            tooltip: _photosDirectory != null ? 'Photos: $_photosDirectory' : 'Link Student Photos Directory',
          ),

          // Verification Landing Page Designer Trigger
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.cloud_upload_outlined, size: 16, color: Color(0xFFF97316)),
              label: const Text('Verification Page', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _openPrivacySettings,
            ),
          ),

          // Quick Save Button
          IconButton(
            icon: const Icon(Icons.save_outlined, color: Color(0xFF34D399), size: 22),
            onPressed: () {
              _saveProject();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Project layout saved!'),
                  backgroundColor: Color(0xFF059669),
                  duration: Duration(milliseconds: 1200),
                ),
              );
            },
            tooltip: 'Save Project',
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

              // Interactive Visual Canvas Workspace (Left Nav + Viewport + Right Inspector)
              Expanded(
                child: Row(
                  children: [
                    // Canva Left Icon Navigation Rail
                    _buildCanvaLeftNavRail(),

                    // Canva Left Expanding Tool Drawer
                    _buildCanvaLeftToolDrawer(),

                    // Central Canvas Viewport
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedElementId = null),
                        child: Container(
                          color: const Color(0xFF0B0F19),
                          child: Center(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Transform.scale(
                                    scale: _zoomLevel,
                                    child: Container(
                                      width: currentPage.width,
                                      height: currentPage.height,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black87, blurRadius: 28, offset: Offset(0, 10)),
                                        ],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          // Background Template Underlay
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
                                                    style: TextStyle(color: Colors.black26, fontSize: 28, fontWeight: FontWeight.bold),
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
                                              samplePhotoFile: samplePhoto,
                                              onSelect: () => setState(() => _selectedElementId = el.id),
                                              onElementChanged: (updated) => _updateElement(updated),
                                              onDragUpdate: (rect) => _handleElementDrag(rect, el, currentPage),
                                              onDragEnd: _handleDragEnd,
                                              onOpenContextMenu: () {
                                                setState(() => _contextMenuElement = el);
                                              },
                                            );
                                          }),

                                          // Magnetic Snapping Guidelines & Dot Grid Overlay
                                          Positioned.fill(
                                            child: AlignmentGuidelinesOverlay(
                                              width: currentPage.width,
                                              height: currentPage.height,
                                              showGrid: _showGrid,
                                              gridSize: 25.0,
                                              snapLinesX: _snapLinesX,
                                              snapLinesY: _snapLinesY,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Right Properties Inspector Panel (Always accessible Canva-style)
                    Container(
                      width: 320,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        border: Border(left: BorderSide(color: Color(0xFF1E293B), width: 1.5)),
                      ),
                      child: PropertiesInspectorPanel(
                        selectedElement: selectedElement,
                        currentPage: currentPage,
                        availableHeaders: _datasetHeaders,
                        onElementUpdated: (updated) => _updateElement(updated),
                        onDeleteElement: () {
                          if (selectedElement != null) {
                            _deleteElement(selectedElement.id);
                          }
                        },
                        onDuplicateElement: () {
                          if (selectedElement != null) {
                            _duplicateElement(selectedElement);
                          }
                        },
                        onBringToFront: () {
                          if (selectedElement != null) {
                            _bringToFront(selectedElement.id);
                          }
                        },
                        onSendToBack: () {
                          if (selectedElement != null) {
                            _sendToBack(selectedElement.id);
                          }
                        },
                        onCenterHorizontal: () {
                          if (selectedElement != null) {
                            _centerHorizontal(selectedElement.id);
                          }
                        },
                        onCenterVertical: () {
                          if (selectedElement != null) {
                            _centerVertical(selectedElement.id);
                          }
                        },
                        onPickBackground: _pickBackground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Context Menu Overlay when right-click is triggered
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

  Widget _buildCanvaLeftNavRail() {
    return Container(
      width: 68,
      decoration: const BoxDecoration(
        color: Color(0xFF090D16),
        border: Border(right: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildNavRailItem(
            index: 0,
            icon: Icons.category_outlined,
            activeIcon: Icons.category,
            label: 'Elements',
          ),
          _buildNavRailItem(
            index: 1,
            icon: Icons.dataset_outlined,
            activeIcon: Icons.dataset,
            label: 'Data',
            badgeCount: _datasetHeaders.length > 0 ? _datasetHeaders.length : null,
          ),
          _buildNavRailItem(
            index: 2,
            icon: Icons.layers_outlined,
            activeIcon: Icons.layers,
            label: 'Layers',
            badgeCount: _templateConfig.pages[_currentPageIndex].elements.length,
          ),
          _buildNavRailItem(
            index: 3,
            icon: Icons.wallpaper_outlined,
            activeIcon: Icons.wallpaper,
            label: 'Design',
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Color(0xFF38BDF8), size: 22),
            onPressed: _handleImportSpreadsheet,
            tooltip: 'Import Spreadsheet',
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildNavRailItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int? badgeCount,
  }) {
    final isSelected = _activeLeftTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _activeLeftTabIndex = index),
      child: Container(
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent,
              width: 3,
            ),
          ),
          color: isSelected ? const Color(0xFF1E293B).withOpacity(0.6) : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(isSelected ? activeIcon : icon, color: isSelected ? const Color(0xFF38BDF8) : Colors.white60, size: 22),
                if (badgeCount != null)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvaLeftToolDrawer() {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(right: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              _activeLeftTabIndex == 0
                  ? 'Add Elements'
                  : _activeLeftTabIndex == 1
                      ? 'Dynamic Data Fields'
                      : _activeLeftTabIndex == 2
                          ? 'Page Layers'
                          : 'Template Background',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(color: Color(0xFF1E293B), height: 1),
          Expanded(child: _buildActiveDrawerContent()),
        ],
      ),
    );
  }

  Widget _buildActiveDrawerContent() {
    switch (_activeLeftTabIndex) {
      case 0:
        return _buildElementsTab();
      case 1:
        return _buildDataColumnsTab();
      case 2:
        return _buildLayersTab();
      case 3:
      default:
        return _buildBackgroundTab();
    }
  }

  Widget _buildElementsTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildElementAddCard(
          icon: Icons.title,
          title: 'Text Box',
          subtitle: 'Double-click to write text directly on canvas',
          color: const Color(0xFF38BDF8),
          onTap: () => _addElement(CanvasElementType.text),
        ),
        const SizedBox(height: 10),
        _buildElementAddCard(
          icon: Icons.account_box,
          title: 'Student Photo',
          subtitle: 'Profile photo with circle or rounded frame',
          color: const Color(0xFF34D399),
          onTap: () => _addElement(CanvasElementType.photo),
        ),
        const SizedBox(height: 10),
        _buildElementAddCard(
          icon: Icons.qr_code_2,
          title: 'Verification QR',
          subtitle: 'Instant tamper-proof scan link to edge',
          color: const Color(0xFFFBBF24),
          onTap: () => _addElement(CanvasElementType.qr),
        ),
      ],
    );
  }

  Widget _buildElementAddCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
            ),
            const Icon(Icons.add, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDataColumnsTab() {
    if (_datasetHeaders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.table_chart_outlined, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            const Text('No Dataset Loaded', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              'Import a Google Sheet or Excel file to drop dynamic columns directly onto the canvas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_download_outlined, size: 16),
              label: const Text('Import Google Sheet', style: TextStyle(fontSize: 12)),
              onPressed: _handleImportSpreadsheet,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'CLICK COLUMN TO ADD TO CANVAS',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        ..._datasetHeaders.map((col) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () => _addElement(CanvasElementType.text, boundColumn: col),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.data_object, size: 14, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        col,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF34D399)),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLayersTab() {
    final currentPage = _templateConfig.pages[_currentPageIndex];
    final elements = currentPage.elements;

    if (elements.isEmpty) {
      return const Center(
        child: Text('No elements on this page', style: TextStyle(color: Colors.white38, fontSize: 12)),
      );
    }

    // Display in reverse order (top of list = topmost z-index)
    final reversedList = elements.reversed.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: reversedList.length,
      itemBuilder: (ctx, i) {
        final el = reversedList[i];
        final isSelected = el.id == _selectedElementId;

        IconData icon;
        Color color;
        switch (el.type) {
          case CanvasElementType.text:
            icon = Icons.title;
            color = const Color(0xFF38BDF8);
            break;
          case CanvasElementType.photo:
            icon = Icons.account_box;
            color = const Color(0xFF34D399);
            break;
          case CanvasElementType.qr:
            icon = Icons.qr_code_2;
            color = const Color(0xFFFBBF24);
            break;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E3A8A).withOpacity(0.5) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155)),
          ),
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            leading: Icon(icon, color: color, size: 18),
            title: Text(
              el.name,
              style: TextStyle(
                color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 14, color: Colors.white54),
                  tooltip: 'Bring to Front',
                  onPressed: () => _bringToFront(el.id),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                  tooltip: 'Delete',
                  onPressed: () => _deleteElement(el.id),
                ),
              ],
            ),
            onTap: () => setState(() => _selectedElementId = el.id),
          ),
        );
      },
    );
  }

  Widget _buildBackgroundTab() {
    final currentPage = _templateConfig.pages[_currentPageIndex];
    final hasBackground = currentPage.backgroundAssetPath != null &&
        File(currentPage.backgroundAssetPath!).existsSync();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (hasBackground) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.file(File(currentPage.backgroundAssetPath!), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentPage.backgroundAssetPath!.split(Platform.pathSeparator).last,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
        ],
        ElevatedButton.icon(
          icon: const Icon(Icons.upload_file, size: 16),
          label: Text(hasBackground ? 'Replace Background Image' : 'Upload Template Background', style: const TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _pickBackground,
        ),
        if (hasBackground) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.clear, size: 16, color: Colors.redAccent),
            label: const Text('Remove Background', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            onPressed: () {
              final updatedPages = List<TemplatePage>.from(_templateConfig.pages);
              updatedPages[_currentPageIndex] = TemplatePage(
                pageNumber: currentPage.pageNumber,
                backgroundAssetPath: null,
                width: currentPage.width,
                height: currentPage.height,
                dpi: currentPage.dpi,
                elements: currentPage.elements,
              );
              setState(() {
                _templateConfig = TemplateConfig(
                  version: _templateConfig.version,
                  orientation: _templateConfig.orientation,
                  pages: updatedPages,
                );
              });
              _saveProject();
            },
          ),
        ],
      ],
    );
  }
}
