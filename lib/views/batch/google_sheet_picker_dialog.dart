import 'package:flutter/material.dart';
import '../../services/google/sheets_service.dart';

class GoogleSheetImportResult {
  final String spreadsheetId;
  final String? sheetTitle;
  final List<String> headers;
  final List<Map<String, dynamic>> rows;

  GoogleSheetImportResult({
    required this.spreadsheetId,
    this.sheetTitle,
    required this.headers,
    required this.rows,
  });
}

class GoogleSheetPickerDialog extends StatefulWidget {
  const GoogleSheetPickerDialog({Key? key}) : super(key: key);

  @override
  State<GoogleSheetPickerDialog> createState() => _GoogleSheetPickerDialogState();
}

class _GoogleSheetPickerDialogState extends State<GoogleSheetPickerDialog>
    with SingleTickerProviderStateMixin {
  final SheetsService _sheetsService = SheetsService();

  late TabController _tabController;
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _driveFiles = [];
  bool _isLoadingDrive = false;
  String? _driveError;

  String? _selectedSpreadsheetId;
  String? _selectedSpreadsheetTitle;

  List<Map<String, dynamic>> _pages = [];
  bool _isLoadingPages = false;
  String? _selectedPageName;

  List<Map<String, dynamic>> _previewRows = [];
  List<String> _previewHeaders = [];
  bool _isLoadingPreview = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDriveFiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDriveFiles({String? query}) async {
    setState(() {
      _isLoadingDrive = true;
      _driveError = null;
    });

    try {
      final files = await _sheetsService.listDriveSpreadsheets(query: query);
      setState(() {
        _driveFiles = files;
        _isLoadingDrive = false;
      });
    } catch (e) {
      setState(() {
        _driveError = e.toString();
        _isLoadingDrive = false;
      });
    }
  }

  Future<void> _selectSpreadsheet(String spreadsheetId, [String? title]) async {
    setState(() {
      _selectedSpreadsheetId = spreadsheetId;
      _selectedSpreadsheetTitle = title;
      _pages = [];
      _selectedPageName = null;
      _previewRows = [];
      _previewHeaders = [];
      _isLoadingPages = true;
      _error = null;
    });

    try {
      final tabs = await _sheetsService.listSpreadsheetTabs(spreadsheetId);
      setState(() {
        _pages = tabs;
        _isLoadingPages = false;
        if (tabs.isNotEmpty) {
          _selectPage(tabs.first['name'] as String);
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingPages = false;
        _error = 'Failed to inspect spreadsheet pages: $e';
      });
    }
  }

  Future<void> _selectPage(String pageName) async {
    if (_selectedSpreadsheetId == null) return;

    setState(() {
      _selectedPageName = pageName;
      _isLoadingPreview = true;
      _error = null;
    });

    try {
      final rows = await _sheetsService.fetchSheetData(
        spreadsheetId: _selectedSpreadsheetId!,
        sheetName: pageName,
      );

      setState(() {
        _previewRows = rows;
        _previewHeaders = rows.isNotEmpty ? rows.first.keys.toList() : [];
        _isLoadingPreview = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPreview = false;
        _error = 'Failed to load data from page "$pageName": $e';
      });
    }
  }

  void _confirmSelection() {
    if (_selectedSpreadsheetId == null || _previewRows.isEmpty) return;

    final result = GoogleSheetImportResult(
      spreadsheetId: _selectedSpreadsheetId!,
      sheetTitle: _selectedPageName,
      headers: _previewHeaders,
      rows: _previewRows,
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 840,
        height: 640,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.table_view_rounded, color: Color(0xFF34D399), size: 26),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Google Sheet & Page Tab',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Choose the exact worksheet tab to ensure 100% data accuracy',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Color(0xFF334155), height: 24),

            // Top Tab Selector: Browse Drive vs Paste URL
            if (_selectedSpreadsheetId == null) ...[
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF10B981),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                tabs: const [
                  Tab(icon: Icon(Icons.add_to_drive, size: 18), text: 'Browse Google Drive'),
                  Tab(icon: Icon(Icons.link, size: 18), text: 'Paste Sheet URL / ID'),
                ],
              ),
              const SizedBox(height: 14),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Drive Browser
                    Column(
                      children: [
                        TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search spreadsheets in your Google Drive...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.refresh, size: 18),
                              onPressed: () => _loadDriveFiles(query: _searchCtrl.text.trim()),
                            ),
                            isDense: true,
                          ),
                          onSubmitted: (q) => _loadDriveFiles(query: q.trim()),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _isLoadingDrive
                              ? const Center(child: CircularProgressIndicator())
                              : _driveError != null
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(_driveError!, style: const TextStyle(color: Color(0xFFF87171), fontSize: 12)),
                                          const SizedBox(height: 8),
                                          ElevatedButton.icon(
                                            onPressed: _loadDriveFiles,
                                            icon: const Icon(Icons.refresh, size: 16),
                                            label: const Text('Retry'),
                                          ),
                                        ],
                                      ),
                                    )
                                  : _driveFiles.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No Google Sheets found. Try searching or paste the URL on the next tab.',
                                            style: TextStyle(color: Colors.white54, fontSize: 13),
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount: _driveFiles.length,
                                          itemBuilder: (ctx, i) {
                                            final file = _driveFiles[i];
                                            return Card(
                                              color: const Color(0xFF0F172A),
                                              margin: const EdgeInsets.only(bottom: 8),
                                              child: ListTile(
                                                leading: const Icon(Icons.description, color: Color(0xFF10B981)),
                                                title: Text(
                                                  file['name'] ?? 'Untitled Sheet',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                                ),
                                                subtitle: Text(
                                                  'ID: ${file['id']}',
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                ),
                                                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white54),
                                                onTap: () => _selectSpreadsheet(file['id'], file['name']),
                                              ),
                                            );
                                          },
                                        ),
                        ),
                      ],
                    ),

                    // Tab 2: Paste URL
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextField(
                          controller: _urlCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Google Sheet URL or Spreadsheet ID',
                            hintText: 'https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit',
                            prefixIcon: Icon(Icons.link),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            final raw = _urlCtrl.text.trim();
                            if (raw.isNotEmpty) {
                              _selectSpreadsheet(raw);
                            }
                          },
                          icon: const Icon(Icons.file_download_outlined),
                          label: const Text('Inspect Spreadsheet Pages & Tabs'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Spreadsheet Selected: Multi-Page Selector View
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _selectedSpreadsheetId = null),
                    icon: const Icon(Icons.arrow_back, size: 14),
                    label: const Text('Change Sheet', style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedSpreadsheetTitle ?? 'Spreadsheet ID: $_selectedSpreadsheetId',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Page Tabs List
              const Text(
                'Select Worksheet / Page Tab:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 8),

              if (_isLoadingPages)
                const LinearProgressIndicator()
              else if (_pages.isEmpty)
                const Text('No pages found or could not read sheet tabs.', style: TextStyle(color: Colors.redAccent, fontSize: 12))
              else
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, idx) {
                      final p = _pages[idx];
                      final name = p['name'] as String;
                      final isSelected = _selectedPageName == name;
                      return ChoiceChip(
                        label: Text(
                          '$name (${p['rows'] ?? '?'} rows)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: const Color(0xFF059669),
                        backgroundColor: const Color(0xFF0F172A),
                        onSelected: (_) => _selectPage(name),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 14),

              // Preview Data Table from selected page
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: _isLoadingPreview
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)))
                          : _previewRows.isEmpty
                              ? const Center(child: Text('Selected page has no records.', style: TextStyle(color: Colors.white54)))
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: const BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Preview: Page "$_selectedPageName" (${_previewRows.length} rows, ${_previewHeaders.length} columns)',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF34D399)),
                                          ),
                                          Text(
                                            'First 5 rows shown below',
                                            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: SingleChildScrollView(
                                          child: DataTable(
                                            headingRowHeight: 36,
                                            dataRowMinHeight: 30,
                                            dataRowMaxHeight: 36,
                                            headingTextStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 11),
                                            dataTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
                                            columns: _previewHeaders
                                                .map((h) => DataColumn(label: Text(h)))
                                                .toList(),
                                            rows: _previewRows.take(5).map((row) {
                                              return DataRow(
                                                cells: _previewHeaders.map((h) {
                                                  final val = row[h]?.toString() ?? '';
                                                  return DataCell(Text(val));
                                                }).toList(),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                ),
              ),

              const SizedBox(height: 16),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _previewRows.isEmpty ? null : _confirmSelection,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      'Import ${_previewRows.length} Records from "${_selectedPageName ?? 'Page'}"',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
