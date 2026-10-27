import 'package:flutter/material.dart';
import '../../services/google/drive_service.dart';

class DriveFolderPickerDialog extends StatefulWidget {
  const DriveFolderPickerDialog({Key? key}) : super(key: key);

  @override
  State<DriveFolderPickerDialog> createState() => _DriveFolderPickerDialogState();
}

class _DriveFolderPickerDialogState extends State<DriveFolderPickerDialog> {
  final DriveService _driveService = DriveService();

  List<DriveFolderItem> _folders = [];
  bool _isLoading = true;
  String? _selectedFolderId;
  String? _selectedFolderName;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _driveService.listFolders();
      setState(() {
        _folders = list;
        if (list.isNotEmpty && _selectedFolderId == null) {
          _selectedFolderId = list.first.id;
          _selectedFolderName = list.first.name;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewFolder() async {
    final nameCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Create New Drive Folder', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            hintText: 'e.g. Certificates 2026',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );

    if (confirm == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        final newFolder = await _driveService.createFolder(
          name: nameCtrl.text.trim(),
          parentFolderId: _selectedFolderId,
        );
        await _loadFolders();
        setState(() {
          _selectedFolderId = newFolder.id;
          _selectedFolderName = newFolder.name;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating folder: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.folder_shared_outlined, color: Colors.amber, size: 24),
                    SizedBox(width: 10),
                    Text('Select Google Drive Folder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Color(0xFF334155), height: 24),

            // Top control bar with New Folder
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedFolderName != null ? 'Selected: $_selectedFolderName' : 'Choose destination folder',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _selectedFolderName != null ? Colors.amber : const Color(0xFF94A3B8),
                  ),
                ),
                TextButton.icon(
                  onPressed: _createNewFolder,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 16, color: Color(0xFF60A5FA)),
                  label: const Text('+ New Folder', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text('Error: $_error', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                            ),
                          )
                        : _folders.isEmpty
                            ? const Center(child: Text('No folders found in Drive', style: TextStyle(color: Colors.white38)))
                            : ListView.builder(
                                itemCount: _folders.length,
                                itemBuilder: (ctx, i) {
                                  final folder = _folders[i];
                                  final isSelected = folder.id == _selectedFolderId;

                                  return ListTile(
                                    leading: Icon(
                                      Icons.folder,
                                      color: isSelected ? Colors.amber : const Color(0xFF64748B),
                                    ),
                                    title: Text(
                                      folder.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? Colors.white : Colors.white70,
                                      ),
                                    ),
                                    selected: isSelected,
                                    selectedTileColor: const Color(0xFF1E3A8A).withOpacity(0.3),
                                    onTap: () {
                                      setState(() {
                                        _selectedFolderId = folder.id;
                                        _selectedFolderName = folder.name;
                                      });
                                    },
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
                ElevatedButton(
                  onPressed: _selectedFolderId != null
                      ? () => Navigator.pop(context, {'id': _selectedFolderId, 'name': _selectedFolderName})
                      : null,
                  child: const Text('Select Destination'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
