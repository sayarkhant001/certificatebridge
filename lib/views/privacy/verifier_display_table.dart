import 'package:flutter/material.dart';
import '../../models/display_config.dart';

class VerifierDisplayTable extends StatefulWidget {
  final List<String> availableColumns;
  final DisplayConfig initialConfig;
  final ValueChanged<DisplayConfig> onSaveConfig;

  const VerifierDisplayTable({
    Key? key,
    required this.availableColumns,
    required this.initialConfig,
    required this.onSaveConfig,
  }) : super(key: key);

  @override
  State<VerifierDisplayTable> createState() => _VerifierDisplayTableState();
}

class _VerifierDisplayTableState extends State<VerifierDisplayTable> {
  late DisplayConfig _config;
  late Set<String> _publicCols;
  late Set<String> _emailCols;
  late TextEditingController _schoolNameCtrl;
  late TextEditingController _customDomainCtrl;
  late TextEditingController _supportEmailCtrl;

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    _publicCols = Set<String>.from(_config.publicColumns);
    _emailCols = Set<String>.from(_config.emailColumns);
    _schoolNameCtrl = TextEditingController(text: _config.institutionName);
    _customDomainCtrl = TextEditingController(text: _config.customDomain ?? '');
    _supportEmailCtrl = TextEditingController(text: _config.supportEmail);
  }

  void _save() {
    final updated = _config.copyWith(
      publicColumns: _publicCols.toList(),
      emailColumns: _emailCols.toList(),
      institutionName: _schoolNameCtrl.text.trim(),
      customDomain: _customDomainCtrl.text.trim().isNotEmpty ? _customDomainCtrl.text.trim() : null,
      supportEmail: _supportEmailCtrl.text.trim(),
    );
    widget.onSaveConfig(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 680,
        height: 640,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFF34D399), size: 24),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Privacy Rules & Verifier Visibility', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('Strict zero-leakage filter: unselected columns are stripped before internet sync', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
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
            const Divider(color: Color(0xFF334155), height: 28),

            // Institution Branding inputs
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _schoolNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Issuing Institution Name',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _customDomainCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Edge Domain (Cloudflare Worker)',
                      hintText: 'e.g. verify.school.edu',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Global Toggles
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Allow Public PDF Download', style: TextStyle(fontSize: 13, color: Colors.white)),
                    subtitle: const Text('Expose Drive PDF button on web verifier', style: TextStyle(fontSize: 11, color: Colors.white38)),
                    value: _config.allowPdfDownload,
                    onChanged: (v) => setState(() => _config = _config.copyWith(allowPdfDownload: v ?? true)),
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Email Receipts', style: TextStyle(fontSize: 13, color: Colors.white)),
                    subtitle: const Text('Allow verifiers to request email receipts', style: TextStyle(fontSize: 11, color: Colors.white38)),
                    value: _config.allowEmailReceipt,
                    onChanged: (v) => setState(() => _config = _config.copyWith(allowEmailReceipt: v ?? true)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Discovered Column Privacy Matrix Table
            const Text(
              'Column Privacy Matrix (Checked = Publicly Transmitted to Edge KV)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24)),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: widget.availableColumns.isEmpty
                    ? const Center(
                        child: Text('No spreadsheet columns loaded yet.', style: TextStyle(color: Colors.white38)),
                      )
                    : ListView.separated(
                        itemCount: widget.availableColumns.length,
                        separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E293B), height: 1),
                        itemBuilder: (ctx, i) {
                          final col = widget.availableColumns[i];
                          final isPublic = _publicCols.contains(col);
                          final isEmail = _emailCols.contains(col);

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      Icon(
                                        isPublic ? Icons.visibility : Icons.visibility_off,
                                        size: 16,
                                        color: isPublic ? const Color(0xFF34D399) : Colors.white24,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        col,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: isPublic ? Colors.white : Colors.white54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Checkbox(
                                      value: isPublic,
                                      activeColor: const Color(0xFF059669),
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            _publicCols.add(col);
                                          } else {
                                            _publicCols.remove(col);
                                          }
                                        });
                                      },
                                    ),
                                    const Text('Public Verifier Web', style: TextStyle(fontSize: 12, color: Colors.white70)),
                                    const SizedBox(width: 16),
                                    Checkbox(
                                      value: isEmail,
                                      activeColor: const Color(0xFF2563EB),
                                      onChanged: (v) {
                                        setState(() {
                                          if (v == true) {
                                            _emailCols.add(col);
                                          } else {
                                            _emailCols.remove(col);
                                          }
                                        });
                                      },
                                    ),
                                    const Text('Email Receipt', style: TextStyle(fontSize: 12, color: Colors.white70)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),

            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Save Privacy Rules'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
