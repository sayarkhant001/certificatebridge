import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:certibridge/models/certificate_record.dart';
import 'package:certibridge/models/display_config.dart';
import 'package:certibridge/models/project_model.dart';
import 'package:certibridge/models/template_config.dart';
import 'package:certibridge/services/cloudflare/kv_sync_service.dart';
import 'package:certibridge/services/engine/batch_generator.dart';
import 'package:certibridge/services/engine/font_manager.dart';
import 'package:certibridge/services/project/project_export_service.dart';
import 'package:certibridge/services/project/project_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1: Project & Bundle Serialization', () {
    test('ProjectModel JSON serialization and deserialization', () {
      final now = DateTime.now();
      final project = ProjectModel(
        id: 'proj_123',
        name: 'Graduation 2026',
        description: 'Batch of 1000 certificates',
        createdAt: now,
        updatedAt: now,
        totalCertificates: 100,
        layoutJson: '{"test": 1}',
        displayConfigJson: '{"public_columns": ["Student_Name"]}',
      );

      final jsonStr = project.toJson();
      final decoded = ProjectModel.fromJson(jsonStr);

      expect(decoded.id, 'proj_123');
      expect(decoded.name, 'Graduation 2026');
      expect(decoded.totalCertificates, 100);
      expect(decoded.layoutJson, '{"test": 1}');
    });

    test('Intelligent Auto-Binding in ProjectImportService', () {
      final importService = ProjectImportService();
      final initialLayout = TemplateConfig.defaultConfig().toJson();
      final availableHeaders = ['Student_Name', 'Course_Name', 'Issue_Date'];

      final boundLayout = importService.autoBindHeaders(
        layoutJson: initialLayout,
        availableHeaders: availableHeaders,
      );

      final config = TemplateConfig.fromJson(boundLayout);
      final recipientNameEl = config.pages.first.elements.firstWhere((e) => e.id == 'recipient_name');
      expect(recipientNameEl.boundColumn, 'Student_Name');
    });
  });

  group('Phase 2 & 4: Batch Generator & Canonical Slugs', () {
    test('Canonical slug generator produces URL-safe strings without ambiguous characters', () {
      final generator = BatchGenerator();
      final slug = generator.generateCanonicalSlug(prefix: 'CERT-2026');

      expect(slug.startsWith('CERT-2026-'), isTrue);
      final randomPart = slug.replaceFirst('CERT-2026-', '');
      expect(randomPart.length >= 32, isTrue);
      expect(randomPart.length, 40);
      expect(randomPart.contains('0'), isFalse);
      expect(randomPart.contains('1'), isFalse);
      expect(randomPart.contains('I'), isFalse);
      expect(randomPart.contains('O'), isFalse);

      final hmacSlug = generator.generateCryptographicHmacSlug(
        certId: 'rec_1001',
        studentName: 'Aung Kyaw',
        courseName: 'Machine Learning',
      );
      expect(hmacSlug.startsWith('CERT-'), isTrue);
      expect(hmacSlug.length, greaterThan(64));
    });
  });

  group('Phase 2: Privacy Filter & Cloudflare KV Sync', () {
    test('KvSyncService strictly strips unchecked private columns from edge payload', () {
      final syncService = KvSyncService();
      final displayConfig = DisplayConfig(
        publicColumns: ['Student_Name', 'Course_Name'],
        emailColumns: ['Student_Name', 'Course_Name', 'Student_Email'],
        institutionName: 'Yangon Tech Academy',
      );

      final record = CertificateRecord(
        id: 'rec_1',
        projectId: 'proj_1',
        rowIndex: 0,
        rawData: {
          'Student_Name': 'Mg Mg',
          'Course_Name': 'Full Stack Robotics',
          'Student_DOB': '2005-01-15', // Private
          'Phone_Number': '+95912345678', // Private
          'Student_Email': 'mgmg@example.com',
        },
        certCode: 'CERT-2026-A8K9',
        shortUrl: 'https://verify.school.edu/c/CERT-2026-A8K9',
      );

      final payload = syncService.preparePublicPayload(
        record: record,
        displayConfig: displayConfig,
      );

      expect(payload['cert_code'], 'CERT-2026-A8K9');
      expect(payload['status'], 'AUTHENTIC');
      expect(payload['school_name'], 'Yangon Tech Academy');

      final fields = payload['fields'] as Map<String, dynamic>;
      expect(fields.containsKey('Student_Name'), isTrue);
      expect(fields.containsKey('Course_Name'), isTrue);
      // Strictly verify sensitive fields were stripped!
      expect(fields.containsKey('Student_DOB'), isFalse);
      expect(fields.containsKey('Phone_Number'), isFalse);
    });
  });

  group('Phase 5: Domain Isolation & Export Sanitization', () {
    test('Project export bundle strictly strips custom domains to prevent conflicts between users', () async {
      final exportService = ProjectExportService();
      final originalConfig = DisplayConfig(
        publicColumns: ['Student_Name', 'Course_Name'],
        emailColumns: ['Student_Name', 'Course_Name'],
        institutionName: 'Stanford Engineering',
        customDomain: 'verify.stanford.edu',
        customSubdomain: 'stanford-badges',
        themePreset: 'sapphire',
        headlineText: 'Official Academic Credential',
        badgeText: 'INSTITUTIONALLY VERIFIED',
      );

      final project = ProjectModel(
        id: 'proj_stanford_1',
        name: 'Diploma Batch',
        description: 'Engineering diplomas',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        totalCertificates: 50,
        layoutJson: '{"version": 1}',
        displayConfigJson: originalConfig.toJson(),
      );

      final bundleBytes = await exportService.exportBundle(
        project: project,
        templatePages: [],
        usedFonts: [],
      );

      expect(bundleBytes, isNotEmpty);

      // Verify the archive contains display_config.json with stripped custom domains
      final archive = ZipDecoder().decodeBytes(bundleBytes);
      final configFile = archive.findFile('display_config.json');
      expect(configFile, isNotNull);

      final configJsonStr = utf8.decode(configFile!.content as List<int>);
      final exportedConfig = DisplayConfig.fromJson(configJsonStr);

      expect(exportedConfig.institutionName, 'Stanford Engineering');
      expect(exportedConfig.themePreset, 'sapphire');
      expect(exportedConfig.headlineText, 'Official Academic Credential');
      // Crucial: Domain and subdomain must be sanitized / null!
      expect(exportedConfig.customDomain, isNull);
      expect(exportedConfig.customSubdomain, isNull);
    });
  });

  group('Phase 6: Multi-Tab Sheets & Categorized Font Manager', () {
    test('DisplayConfig correctly persists themePreset, allowPrint, and badgeText', () {
      final config = DisplayConfig(
        publicColumns: ['Student_Name'],
        emailColumns: ['Student_Name'],
        themePreset: 'emerald',
        allowPrint: true,
        allowVerifierEmail: true,
        enableRateLimiting: true,
        slugEntropyLength: 40,
        badgeText: 'VERIFIED CREDENTIAL',
        headlineText: 'Official Completion Certificate',
        footerText: 'Issued by CertiBridge Engine',
      );

      final json = config.toJson();
      final restored = DisplayConfig.fromJson(json);

      expect(restored.themePreset, 'emerald');
      expect(restored.allowPrint, isTrue);
      expect(restored.allowVerifierEmail, isTrue);
      expect(restored.enableRateLimiting, isTrue);
      expect(restored.slugEntropyLength, 40);
      expect(restored.badgeText, 'VERIFIED CREDENTIAL');
      expect(restored.headlineText, 'Official Completion Certificate');
      expect(restored.footerText, 'Issued by CertiBridge Engine');
    });

    test('FontManager initializes and categorizes fonts into Myanmar Unicode, Win, and English', () async {
      final fontManager = FontManager();
      await fontManager.initialize();

      expect(fontManager.availableFonts, isNotEmpty);
      expect(fontManager.myanmarUnicodeFonts, isNotEmpty);
      expect(fontManager.myanmarWinFonts, isNotEmpty);
      expect(fontManager.englishFonts, isNotEmpty);

      // Verify categories
      for (final f in fontManager.myanmarUnicodeFonts) {
        expect(f.category, FontCategory.myanmarUnicode);
      }
      for (final f in fontManager.myanmarWinFonts) {
        expect(f.category, FontCategory.myanmarWin);
      }
      for (final f in fontManager.englishFonts) {
        expect(f.category, FontCategory.english);
      }
    });
  });
}

