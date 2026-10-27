import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/certificate_record.dart';
import 'project_repository.dart';

class QueueRepository {
  final ProjectRepository _projectRepo = ProjectRepository();
  static final List<CertificateRecord> _inMemoryQueue = [];

  Future<Database?> get _db async => await _projectRepo.database;

  Future<void> insertBatch(List<CertificateRecord> records) async {
    if (kIsWeb) {
      for (final record in records) {
        _inMemoryQueue.removeWhere((r) => r.id == record.id);
        _inMemoryQueue.add(record);
      }
      return;
    }
    final db = (await _db)!;
    final batch = db.batch();
    for (final record in records) {
      batch.insert(
        'cert_queue',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<CertificateRecord>> getQueueForProject(String projectId) async {
    if (kIsWeb) {
      final list = _inMemoryQueue.where((r) => r.projectId == projectId).toList();
      list.sort((a, b) => a.rowIndex.compareTo(b.rowIndex));
      return list;
    }
    final db = (await _db)!;
    final maps = await db.query(
      'cert_queue',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'row_index ASC',
    );
    return maps.map((m) => CertificateRecord.fromMap(m)).toList();
  }

  Future<List<CertificateRecord>> getPendingOrInterrupted(String projectId) async {
    if (kIsWeb) {
      final list = _inMemoryQueue.where((r) =>
          r.projectId == projectId &&
          (r.status == CertificateStatus.pending ||
              r.status == CertificateStatus.rendering ||
              r.status == CertificateStatus.failed)).toList();
      list.sort((a, b) => a.rowIndex.compareTo(b.rowIndex));
      return list;
    }
    final db = (await _db)!;
    final maps = await db.query(
      'cert_queue',
      where: 'project_id = ? AND status IN (?, ?, ?)',
      whereArgs: [projectId, 'pending', 'rendering', 'failed'],
      orderBy: 'row_index ASC',
    );
    return maps.map((m) => CertificateRecord.fromMap(m)).toList();
  }

  Future<List<CertificateRecord>> getUnuploaded(String projectId) async {
    if (kIsWeb) {
      final list = _inMemoryQueue.where((r) =>
          r.projectId == projectId && r.status == CertificateStatus.generated).toList();
      list.sort((a, b) => a.rowIndex.compareTo(b.rowIndex));
      return list;
    }
    final db = (await _db)!;
    final maps = await db.query(
      'cert_queue',
      where: 'project_id = ? AND status = ?',
      whereArgs: [projectId, 'generated'],
      orderBy: 'row_index ASC',
    );
    return maps.map((m) => CertificateRecord.fromMap(m)).toList();
  }

  Future<List<CertificateRecord>> getUnsyncedKv(String projectId) async {
    if (kIsWeb) {
      final list = _inMemoryQueue.where((r) =>
          r.projectId == projectId && r.status == CertificateStatus.uploaded).toList();
      list.sort((a, b) => a.rowIndex.compareTo(b.rowIndex));
      return list;
    }
    final db = (await _db)!;
    final maps = await db.query(
      'cert_queue',
      where: 'project_id = ? AND status = ?',
      whereArgs: [projectId, 'uploaded'],
      orderBy: 'row_index ASC',
    );
    return maps.map((m) => CertificateRecord.fromMap(m)).toList();
  }

  Future<void> updateRecord(CertificateRecord record) async {
    if (kIsWeb) {
      final idx = _inMemoryQueue.indexWhere((r) => r.id == record.id);
      if (idx >= 0) {
        _inMemoryQueue[idx] = record;
      } else {
        _inMemoryQueue.add(record);
      }
      return;
    }
    final db = (await _db)!;
    await db.update(
      'cert_queue',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<void> updateStatus({
    required String id,
    required CertificateStatus status,
    String? localPdfPath,
    String? drivePdfLink,
    String? errorMessage,
  }) async {
    if (kIsWeb) {
      final idx = _inMemoryQueue.indexWhere((r) => r.id == id);
      if (idx >= 0) {
        final existing = _inMemoryQueue[idx];
        _inMemoryQueue[idx] = existing.copyWith(
          status: status,
          localPdfPath: localPdfPath ?? existing.localPdfPath,
          drivePdfLink: drivePdfLink ?? existing.drivePdfLink,
          errorMessage: errorMessage ?? existing.errorMessage,
          updatedAt: DateTime.now(),
        );
      }
      return;
    }
    final db = (await _db)!;
    final values = <String, dynamic>{
      'status': status.name,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (localPdfPath != null) values['local_pdf_path'] = localPdfPath;
    if (drivePdfLink != null) values['drive_pdf_link'] = drivePdfLink;
    if (errorMessage != null) values['error_message'] = errorMessage;

    await db.update(
      'cert_queue',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, int>> getStatusCounts(String projectId) async {
    final counts = <String, int>{
      'pending': 0,
      'rendering': 0,
      'generated': 0,
      'uploading': 0,
      'uploaded': 0,
      'synced': 0,
      'failed': 0,
      'total': 0,
    };

    if (kIsWeb) {
      final projectRecords = _inMemoryQueue.where((r) => r.projectId == projectId);
      for (final r in projectRecords) {
        final st = r.status.name;
        counts[st] = (counts[st] ?? 0) + 1;
        counts['total'] = (counts['total'] ?? 0) + 1;
      }
      return counts;
    }

    final db = (await _db)!;
    final results = await db.rawQuery('''
      SELECT status, COUNT(*) as count 
      FROM cert_queue 
      WHERE project_id = ? 
      GROUP BY status
    ''', [projectId]);

    int total = 0;
    for (final row in results) {
      final status = row['status'] as String;
      final count = (row['count'] as num).toInt();
      counts[status] = count;
      total += count;
    }
    counts['total'] = total;
    return counts;
  }

  Future<void> clearQueue(String projectId) async {
    if (kIsWeb) {
      _inMemoryQueue.removeWhere((r) => r.projectId == projectId);
      return;
    }
    final db = (await _db)!;
    await db.delete(
      'cert_queue',
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
  }
}
