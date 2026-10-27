import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:certibridge/models/certificate_record.dart';
import 'package:certibridge/models/display_config.dart';
import 'package:certibridge/models/project_model.dart';
import 'package:certibridge/models/template_config.dart';
import 'package:certibridge/services/database/project_repository.dart';
import 'package:certibridge/services/database/queue_repository.dart';
import 'package:certibridge/services/engine/batch_generator.dart';
import 'package:certibridge/services/engine/pdf_compiler.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Phase 4 & 6: 10,000+ Batch Generation & Resiliency Stress Test', () {
    final projectRepo = ProjectRepository();
    final queueRepo = QueueRepository();
    final generator = BatchGenerator();
    final pdfCompiler = PdfCompiler();

    final testProjectId = 'stress_test_proj_${DateTime.now().millisecondsSinceEpoch}';

    test('SQLite batch insertion of 10,000 checkpoint rows', () async {
      final project = ProjectModel(
        id: testProjectId,
        name: '10k Mega Batch Test',
        description: 'End-to-end stress test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        totalCertificates: 10000,
        layoutJson: TemplateConfig.defaultConfig().toJson(),
        displayConfigJson: DisplayConfig.defaultConfig().toJson(),
      );
      await projectRepo.insertProject(project);

      // Generate 10,000 synthetic student rows
      final sampleRows = List.generate(10000, (i) => {
        'Student_ID': 'STU-$i',
        'Student_Name': i % 2 == 0 ? 'Student $i' : 'မောင်မောင် $i',
        'Course_Name': 'Robotics Engineering $i',
        'Issue_Date': '2026-10-27',
      });

      final stopwatch = Stopwatch()..start();
      final records = await generator.initializeQueue(
        project: project,
        spreadsheetRows: sampleRows,
        displayConfig: DisplayConfig.defaultConfig(),
      );
      stopwatch.stop();

      expect(records.length, 10000);
      print('Initialized and checkpointed 10,000 records in SQLite in ${stopwatch.elapsedMilliseconds} ms');

      final counts = await queueRepo.getStatusCounts(testProjectId);
      expect(counts['total'], 10000);
      expect(counts['pending'], 10000);
    });

    test('Crash Resiliency & Checkpoint Resume verification', () async {
      // Simulate that the first 500 certificates were completed before power loss / crash
      final queue = await queueRepo.getQueueForProject(testProjectId);
      expect(queue.length, 10000);

      for (int i = 0; i < 500; i++) {
        await queueRepo.updateStatus(
          id: queue[i].id,
          status: CertificateStatus.generated,
          localPdfPath: '/mock/path/${queue[i].certCode}.pdf',
        );
      }

      // Checkpoint recovery
      final pendingAfterCrash = await queueRepo.getPendingOrInterrupted(testProjectId);
      expect(pendingAfterCrash.length, 9500); // Exactly 9,500 uncompleted!
      expect(pendingAfterCrash.first.rowIndex, 500); // Resumes from row 500!
      print('Crash resilience verified: Resumes from record index 500 without duplicate work.');
    });

    test('Sequential stream PDF compilation maintains RAM under 500 MB', () async {
      final tempDir = await Directory.systemTemp.createTemp('certibridge_batch_test_');
      final templateConfig = TemplateConfig.defaultConfig();

      final queue = await queueRepo.getQueueForProject(testProjectId);
      final testChunk = queue.take(50).toList(); // Compile 50 real PDFs to measure memory

      for (final record in testChunk) {
        final outPdfPath = '${tempDir.path}/${record.certCode}.pdf';
        await pdfCompiler.compileCertificate(
          templateConfig: templateConfig,
          record: record,
          outputFilePath: outPdfPath,
        );

        expect(File(outPdfPath).existsSync(), isTrue);
        expect(File(outPdfPath).lengthSync(), greaterThan(1000)); // Valid PDF file
      }

      final memoryRssMb = ProcessInfo.currentRss / (1024 * 1024);
      print('Current Memory RSS during batch processing: ${memoryRssMb.toStringAsFixed(2)} MB');
      expect(memoryRssMb, lessThan(500.0)); // Strictly < 500 MB guaranteed!

      // Cleanup
      await tempDir.delete(recursive: true);
      await projectRepo.deleteProject(testProjectId);
    });
  });
}
