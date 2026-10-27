import 'package:flutter/material.dart';

class LivePreviewBar extends StatelessWidget {
  final int currentRowIndex;
  final int totalRows;
  final bool isPreviewMode;
  final VoidCallback onPrevRow;
  final VoidCallback onNextRow;
  final ValueChanged<bool> onTogglePreviewMode;
  final VoidCallback onImportDataset;
  final VoidCallback? onOpenDataTableEditor;
  final VoidCallback? onConfigurePrivacy;
  final VoidCallback onStartBatch;

  const LivePreviewBar({
    Key? key,
    required this.currentRowIndex,
    required this.totalRows,
    required this.isPreviewMode,
    required this.onPrevRow,
    required this.onNextRow,
    required this.onTogglePreviewMode,
    required this.onImportDataset,
    this.onOpenDataTableEditor,
    this.onConfigurePrivacy,
    required this.onStartBatch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
      ),
      child: Row(
        children: [
          // Data source button
          OutlinedButton.icon(
            onPressed: onImportDataset,
            icon: const Icon(Icons.table_chart_outlined, size: 16, color: Color(0xFF34D399)),
            label: Text(
              totalRows > 0 ? '$totalRows Records' : 'Import Excel / Sheets',
              style: TextStyle(
                fontSize: 12,
                color: totalRows > 0 ? const Color(0xFF34D399) : Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: BorderSide(
                color: totalRows > 0 ? const Color(0xFF059669) : const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Canva Bulk Create Table Editor Button
          IconButton(
            onPressed: onOpenDataTableEditor,
            icon: const Icon(Icons.edit_note, size: 20, color: Color(0xFF38BDF8)),
            tooltip: 'Canva Bulk Create: Edit Data Table Manually',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFF334155))),
            ),
          ),
          const SizedBox(width: 14),

          // Live Data Switcher: [Prev] Row X of N [Next]
          if (totalRows > 0) ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: currentRowIndex > 0 ? onPrevRow : null,
                    tooltip: 'Previous Record',
                    splashRadius: 18,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Row ${currentRowIndex + 1} of $totalRows',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: currentRowIndex < totalRows - 1 ? onNextRow : null,
                    tooltip: 'Next Record',
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Live Preview Toggle
            FilterChip(
              label: const Text('Live Preview', style: TextStyle(fontSize: 12)),
              selected: isPreviewMode,
              selectedColor: const Color(0xFF1E3A8A),
              checkmarkColor: Colors.white,
              onSelected: onTogglePreviewMode,
            ),
          ],

          const Spacer(),

          // Batch Generation Engine
          ElevatedButton.icon(
            onPressed: totalRows > 0 ? onStartBatch : null,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('10k+ Batch Generator', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
