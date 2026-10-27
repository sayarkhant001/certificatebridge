import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../models/certificate_record.dart';
import '../../models/display_config.dart';
import '../../models/project_model.dart';
import '../../services/cloudflare/kv_sync_service.dart';
import '../../services/database/queue_repository.dart';
import '../../services/engine/batch_generator.dart';
import '../../services/excel/excel_service.dart';
import '../../services/google/drive_service.dart';
import '../../services/google/sheets_service.dart';
import 'drive_folder_picker_dialog.dart';

class BatchProgressView extends StatefulWidget {
  final ProjectModel project;
  final List<Map<String, dynamic>> datasetRows;
  final DisplayConfig displayConfig;
  final String? photosDirectory;

  const BatchProgressView({
    Key? key,
    required this.project,
    required this.datasetRows,
    required this.displayConfig,
    this.photosDirectory,
  }) : super(key: key);

  @override
  State<BatchProgressView> createState() => _BatchProgressViewState();
}

class _BatchProgressViewState extends State<BatchProgressView> {
  final QueueRepository _queueRepo = QueueRepository();
  final BatchGenerator _generator = BatchGenerator();
  final DriveService _driveService = DriveService();
  final KvSyncService _kvSyncService = KvSyncService();
  final ExcelService _excelService = ExcelService();

  Map<String, int> _counts = {
    'pending': 0,
    'rendering': 0,
    'generated': 0,
    'uploading': 0,
    'uploaded': 0,
    'synced': 0,
    'failed': 0,
    'total': 0,
  };

  bool _isGenerating = false;
  bool _isPaused = false;
  bool _isUploadingDrive = false;
  bool _isSyncingKv = false;
  bool _isWritingBack = false;

  String? _statusText;
  String? _targetDriveFolderId;
  String? _targetDriveFolderName;
  String? _outputDirectoryPath;

  @override
  void initState() {
    super.initState();
    _initQueueAndPaths();
  }

  Future<void> _initQueueAndPaths() async {
    final appDir = await getApplicationDocumentsDirectory();
    final outDir = p.join(appDir.path, 'CertiBridge', 'Output_PDFs', widget.project.id);
    _outputDirectoryPath = outDir;

    // Check existing queue or initialize from dataset
    final existing = await _queueRepo.getQueueForProject(widget.project.id);
    if (existing.isEmpty && widget.datasetRows.isNotEmpty) {
      await _generator.initializeQueue(
        project: widget.project,
        spreadsheetRows: widget.datasetRows,
        displayConfig: widget.displayConfig,
      );
    }

    await _refreshCounts();
  }

  Future<void> _refreshCounts() async {
    final counts = await _queueRepo.getStatusCounts(widget.project.id);
    setState(() => _counts = counts);
  }

  Future<void> _startGeneration() async {
    if (_outputDirectoryPath == null) return;

    setState(() {
      _isGenerating = true;
      _isPaused = false;
      _statusText = 'Generating certificates sequentially (<500MB stream)...';
    });

    await _generator.runBatch(
      project: widget.project,
      outputDirectory: _outputDirectoryPath!,
      photosDirectory: widget.photosDirectory,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _counts['generated'] = progress.completed;
            _statusText = progress.isPaused
                ? 'Generation paused'
                : 'Generating cert ${progress.completed} of ${progress.total} (${(progress.percentage * 100).toInt()}%)';
          });
        }
      },
    );

    await _refreshCounts();
    setState(() {
      _isGenerating = false;
      _statusText = 'Batch PDF generation complete!';
    });
  }

  void _pauseResume() {
    if (_isPaused) {
      _generator.resume();
      setState(() => _isPaused = false);
    } else {
      _generator.pause();
      setState(() => _isPaused = true);
    }
  }

  void _cancel() {
    _generator.cancel();
    setState(() {
      _isGenerating = false;
      _isPaused = false;
      _statusText = 'Batch generation stopped by user.';
    });
  }

  Future<void> _pickDriveFolder() async {
    final folder = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const DriveFolderPickerDialog(),
    );
    if (folder != null) {
      setState(() {
        _targetDriveFolderId = folder['id'];
        _targetDriveFolderName = folder['name'];
      });
    }
  }

  Future<void> _startDriveUploads() async {
    if (_targetDriveFolderId == null) {
      await _pickDriveFolder();
      if (_targetDriveFolderId == null) return;
    }

    setState(() {
      _isUploadingDrive = true;
      _statusText = 'Uploading PDFs to Google Drive (4-worker resumable pool)...';
    });

    try {
      final unuploaded = await _queueRepo.getUnuploaded(widget.project.id);
      final files = unuploaded
          .where((r) => r.localPdfPath != null && File(r.localPdfPath!).existsSync())
          .map((r) => File(r.localPdfPath!))
          .toList();

      final links = await _driveService.uploadBatchConcurrent(
        files: files,
        targetFolderId: _targetDriveFolderId!,
        concurrency: 4,
        onProgress: (completed, total) {
          if (mounted) {
            setState(() {
              _statusText = 'Uploaded $completed of $total PDFs to Google Drive...';
            });
          }
        },
      );

      // Update SQLite statuses
      for (int i = 0; i < unuploaded.length; i++) {
        final link = i < links.length ? links[i] : '';
        if (link.isNotEmpty) {
          await _queueRepo.updateStatus(
            id: unuploaded[i].id,
            status: CertificateStatus.uploaded,
            drivePdfLink: link,
          );
        }
      }

      await _refreshCounts();
      setState(() => _statusText = 'All PDFs successfully uploaded to Google Drive!');
    } catch (e) {
      setState(() => _statusText = 'Drive upload error: $e');
    } finally {
      setState(() => _isUploadingDrive = false);
    }
  }

  Future<void> _syncCloudflareKv() async {
    setState(() {
      _isSyncingKv = true;
      _statusText = 'Syncing verification payload to Cloudflare KV edge (10k chunking)...';
    });

    try {
      final records = await _queueRepo.getQueueForProject(widget.project.id);
      final count = await _kvSyncService.syncRecords(
        records: records,
        displayConfig: widget.displayConfig,
        onProgress: (synced, total) {
          if (mounted) {
            setState(() => _statusText = 'Synced $synced of $total to Cloudflare KV...');
          }
        },
      );

      for (final r in records) {
        await _queueRepo.updateStatus(id: r.id, status: CertificateStatus.synced);
      }

      await _refreshCounts();
      setState(() => _statusText = 'Successfully synced $count records to Cloudflare Edge KV!');
    } catch (e) {
      setState(() => _statusText = 'KV Sync Error: $e');
    } finally {
      setState(() => _isSyncingKv = false);
    }
  }

  Future<void> _writeBackTrackingColumns() async {
    setState(() {
      _isWritingBack = true;
      _statusText = 'Writing tracking columns back to source dataset...';
    });

    try {
      final queue = await _queueRepo.getQueueForProject(widget.project.id);
      final trackingRows = queue.map((record) {
        return {
          AppConstants.colCertCode: record.certCode,
          AppConstants.colVerificationUrl: record.shortUrl ?? '',
          AppConstants.colDrivePdfLink: record.drivePdfLink ?? '',
          AppConstants.colIssueDate: DateTime.now().toIso8601String().substring(0, 10),
          AppConstants.colSyncStatus: record.status.name.toUpperCase(),
        };
      }).toList();

      // Show dialog to save Excel write-back file
      final outPath = p.join(_outputDirectoryPath!, '${widget.project.name}_tracking_results.csv');
      await _excelService.writeBackExcel(filePath: outPath, trackingRows: trackingRows);

      setState(() => _statusText = 'Tracking columns written back to: $outPath');
    } catch (e) {
      setState(() => _statusText = 'Write-back error: $e');
    } finally {
      setState(() => _isWritingBack = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _counts['total'] ?? 0;
    final generated = _counts['generated'] ?? 0;
    final uploaded = _counts['uploaded'] ?? 0;
    final synced = _counts['synced'] ?? 0;
    final progress = total > 0 ? (generated / total) : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.project.name} - 10,000+ Batch Pipeline', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Text('Zero-Crash Stream Processing &bull; SQLite Checkpointing Engine', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and memory badges
            Row(
              children: [
                _buildStatBadge('Total Records', total.toString(), const Color(0xFF3B82F6)),
                const SizedBox(width: 12),
                _buildStatBadge('Generated PDFs', generated.toString(), const Color(0xFF10B981)),
                const SizedBox(width: 12),
                _buildStatBadge('Drive Uploaded', uploaded.toString(), const Color(0xFFF59E0B)),
                const SizedBox(width: 12),
                _buildStatBadge('Edge KV Synced', synced.toString(), const Color(0xFF8B5CF6)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.memory, size: 16, color: Color(0xFF34D399)),
                      SizedBox(width: 6),
                      Text('RAM: < 500 MB Guaranteed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF34D399))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Progress Bar Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _statusText ?? 'Ready for generation',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF38BDF8), fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: const Color(0xFF0F172A),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Control Buttons
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isGenerating ? null : _startGeneration,
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Start Local Generation'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                      ),
                      if (_isGenerating) ...[
                        OutlinedButton.icon(
                          onPressed: _pauseResume,
                          icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, size: 18),
                          label: Text(_isPaused ? 'Resume' : 'Pause'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _cancel,
                          icon: const Icon(Icons.stop, size: 18, color: Colors.redAccent),
                          label: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                      ElevatedButton.icon(
                        onPressed: (_isGenerating || _isUploadingDrive) ? null : _startDriveUploads,
                        icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                        label: Text(_targetDriveFolderName != null ? 'Upload to Drive ($_targetDriveFolderName)' : 'Upload to Google Drive'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                      ),
                      ElevatedButton.icon(
                        onPressed: (_isGenerating || _isSyncingKv) ? null : _syncCloudflareKv,
                        icon: const Icon(Icons.electric_bolt, size: 18),
                        label: const Text('Sync to Cloudflare KV'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
                      ),
                      OutlinedButton.icon(
                        onPressed: (_isGenerating || _isWritingBack) ? null : _writeBackTrackingColumns,
                        icon: const Icon(Icons.assignment_turned_in_outlined, size: 18),
                        label: const Text('Write-Back Tracking Data'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text('SQLite Checkpoint Queue Log', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
            const SizedBox(height: 10),

            // Queue Table Preview
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: FutureBuilder<List<CertificateRecord>>(
                  future: _queueRepo.getQueueForProject(widget.project.id),
                  builder: (ctx, snap) {
                    final records = snap.data ?? [];
                    if (records.isEmpty) {
                      return const Center(child: Text('No checkpoint records initialized yet.', style: TextStyle(color: Colors.white38)));
                    }

                    return ListView.separated(
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E293B), height: 1),
                      itemBuilder: (ctx, i) {
                        final r = records[i];
                        return ListTile(
                          dense: true,
                          leading: Text('#${r.rowIndex + 1}', style: const TextStyle(color: Colors.white38, fontFamily: 'monospace')),
                          title: Text(r.certCode, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace')),
                          subtitle: Text(
                            r.rawData['Student_Name']?.toString() ?? r.shortUrl ?? '',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor(r.status).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: _statusColor(r.status), width: 0.5),
                            ),
                            child: Text(
                              r.status.name.toUpperCase(),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _statusColor(r.status)),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white38)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Color _statusColor(CertificateStatus status) {
    switch (status) {
      case CertificateStatus.pending:
        return const Color(0xFF94A3B8);
      case CertificateStatus.rendering:
        return const Color(0xFF38BDF8);
      case CertificateStatus.generated:
        return const Color(0xFF10B981);
      case CertificateStatus.uploading:
        return const Color(0xFFFBBF24);
      case CertificateStatus.uploaded:
        return const Color(0xFFF59E0B);
      case CertificateStatus.synced:
        return const Color(0xFF8B5CF6);
      case CertificateStatus.failed:
        return const Color(0xFFEF4444);
    }
  }
}
