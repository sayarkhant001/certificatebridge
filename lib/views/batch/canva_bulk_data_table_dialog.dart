import 'package:flutter/material.dart';

class CanvaBulkDataTableDialog extends StatefulWidget {
  final List<String> initialHeaders;
  final List<Map<String, dynamic>> initialRows;
  final Function(List<String> headers, List<Map<String, dynamic>> rows) onSave;

  const CanvaBulkDataTableDialog({
    Key? key,
    required this.initialHeaders,
    required this.initialRows,
    required this.onSave,
  }) : super(key: key);

  @override
  State<CanvaBulkDataTableDialog> createState() => _CanvaBulkDataTableDialogState();
}

class _CanvaBulkDataTableDialogState extends State<CanvaBulkDataTableDialog> {
  late List<String> _headers;
  late List<Map<String, dynamic>> _rows;
  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _verticalScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _headers = List<String>.from(widget.initialHeaders);
    if (_headers.isEmpty) {
      _headers = ['Student_Name', 'Course_Name', 'Grade', 'Issue_Date'];
    }

    _rows = widget.initialRows.map((r) => Map<String, dynamic>.from(r)).toList();
    if (_rows.isEmpty) {
      // Provide default template rows if empty
      _rows = [
        {'Student_Name': 'Aung Aung', 'Course_Name': 'AI & Robotics', 'Grade': 'Distinction', 'Issue_Date': '2026-10-27'},
        {'Student_Name': 'Su Su', 'Course_Name': 'Cloud Engineering', 'Grade': 'High Pass', 'Issue_Date': '2026-10-27'},
        {'Student_Name': 'Min Min', 'Course_Name': 'Full Stack Dev', 'Grade': 'Pass', 'Issue_Date': '2026-10-27'},
      ];
    }
  }

  @override
  void dispose() {
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  void _addRow() {
    setState(() {
      final newRow = <String, dynamic>{};
      for (final h in _headers) {
        newRow[h] = '';
      }
      _rows.add(newRow);
    });
    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_verticalScroll.hasClients) {
        _verticalScroll.animateTo(
          _verticalScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _deleteRow(int index) {
    setState(() {
      _rows.removeAt(index);
    });
  }

  void _addColumn() {
    final nameCtrl = TextEditingController(text: 'Column_${_headers.length + 1}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Add Column Header', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Column Name',
            hintText: 'e.g. Student_Email, Certificate_ID',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty && !_headers.contains(newName)) {
                setState(() {
                  _headers.add(newName);
                  for (final r in _rows) {
                    r[newName] = '';
                  }
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add Column'),
          ),
        ],
      ),
    );
  }

  void _deleteColumn(String header) {
    if (_headers.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one column is required.'), backgroundColor: Colors.amber),
      );
      return;
    }
    setState(() {
      _headers.remove(header);
      for (final r in _rows) {
        r.remove(header);
      }
    });
  }

  void _renameColumn(String oldHeader) {
    final nameCtrl = TextEditingController(text: oldHeader);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Rename Column', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New Column Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty && newName != oldHeader) {
                setState(() {
                  final idx = _headers.indexOf(oldHeader);
                  if (idx != -1) _headers[idx] = newName;
                  for (final r in _rows) {
                    final val = r.remove(oldHeader);
                    r[newName] = val;
                  }
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _clearTable() {
    setState(() {
      _rows.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1050,
        height: 680,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF06B6D4)]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.table_chart, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Canva Bulk Create • Interactive Data Table',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Edit imported dataset cells with your keyboard, add rows & columns, and apply directly to canvas',
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
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
            const Divider(color: Color(0xFF334155), height: 20),

            // Toolbar Controls
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Row'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: _addRow,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.view_column_outlined, size: 16, color: Color(0xFF38BDF8)),
                  label: const Text('Add Column', style: TextStyle(color: Color(0xFF38BDF8))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: _addColumn,
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: Colors.white54),
                  label: const Text('Clear All', style: TextStyle(color: Colors.white54)),
                  onPressed: _rows.isNotEmpty ? _clearTable : null,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Text(
                    '${_rows.length} rows &bull; ${_headers.length} columns',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Editable Spreadsheet Grid
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Scrollbar(
                  controller: _horizontalScroll,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalScroll,
                    scrollDirection: Axis.horizontal,
                    child: Scrollbar(
                      controller: _verticalScroll,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _verticalScroll,
                        scrollDirection: Axis.vertical,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Table Header Row
                            Container(
                              color: const Color(0xFF0F172A),
                              child: Row(
                                children: [
                                  // Row Number Header
                                  Container(
                                    width: 48,
                                    height: 42,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        right: BorderSide(color: Color(0xFF334155)),
                                        bottom: BorderSide(color: Color(0xFF334155)),
                                      ),
                                    ),
                                    child: const Text('#', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),

                                  // Column Headers
                                  ..._headers.map((h) {
                                    return Container(
                                      width: 180,
                                      height: 42,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      decoration: const BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: Color(0xFF334155)),
                                          bottom: BorderSide(color: Color(0xFF334155)),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.data_object, size: 13, color: Color(0xFF38BDF8)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              h,
                                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert, size: 14, color: Colors.white54),
                                            color: const Color(0xFF1E293B),
                                            itemBuilder: (_) => [
                                              const PopupMenuItem(value: 'rename', child: Text('Rename Column', style: TextStyle(color: Colors.white, fontSize: 12))),
                                              const PopupMenuItem(value: 'delete', child: Text('Delete Column', style: TextStyle(color: Colors.redAccent, fontSize: 12))),
                                            ],
                                            onSelected: (val) {
                                              if (val == 'rename') _renameColumn(h);
                                              if (val == 'delete') _deleteColumn(h);
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  }),

                                  // Action Header
                                  Container(
                                    width: 48,
                                    height: 42,
                                    decoration: const BoxDecoration(
                                      border: Border(bottom: BorderSide(color: Color(0xFF334155))),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Table Data Rows
                            if (_rows.isEmpty)
                              Container(
                                width: 48 + _headers.length * 180.0 + 48,
                                padding: const EdgeInsets.all(40),
                                alignment: Alignment.center,
                                child: const Column(
                                  children: [
                                    Icon(Icons.table_rows_outlined, color: Colors.white24, size: 40),
                                    SizedBox(height: 10),
                                    Text('Table is empty. Click "+ Add Row" above to enter records manually.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              )
                            else
                              ..._rows.asMap().entries.map((entry) {
                                final rowIdx = entry.key;
                                final rowData = entry.value;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: rowIdx % 2 == 0 ? Colors.transparent : const Color(0xFF162032),
                                    border: const Border(bottom: BorderSide(color: Color(0xFF334155), width: 0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      // Row Index
                                      Container(
                                        width: 48,
                                        height: 40,
                                        alignment: Alignment.center,
                                        decoration: const BoxDecoration(
                                          border: Border(right: BorderSide(color: Color(0xFF334155))),
                                        ),
                                        child: Text('${rowIdx + 1}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                      ),

                                      // Cells
                                      ..._headers.map((h) {
                                        return Container(
                                          width: 180,
                                          height: 40,
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          decoration: const BoxDecoration(
                                            border: Border(right: BorderSide(color: Color(0xFF334155), width: 0.5)),
                                          ),
                                          alignment: Alignment.centerLeft,
                                          child: TextFormField(
                                            initialValue: rowData[h]?.toString() ?? '',
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            onChanged: (newVal) {
                                              rowData[h] = newVal;
                                            },
                                          ),
                                        );
                                      }),

                                      // Delete Row Button
                                      Container(
                                        width: 48,
                                        height: 40,
                                        alignment: Alignment.center,
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                                          tooltip: 'Delete Row',
                                          splashRadius: 16,
                                          onPressed: () => _deleteRow(rowIdx),
                                        ),
                                      ),
                                    ],
                                  ),
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
            const SizedBox(height: 16),

            // Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Apply Changes to Canvas', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () {
                    widget.onSave(_headers, _rows);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
