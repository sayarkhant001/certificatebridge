import 'dart:convert';
import '../../core/storage/secure_storage_service.dart';
import '../../models/certificate_record.dart';
import '../../models/display_config.dart';
import 'cloudflare_api.dart';

class KvSyncService {
  final SecureStorageService _storage = SecureStorageService();

  /// Filters record data by DisplayConfig privacy rules and prepares payload
  Map<String, dynamic> preparePublicPayload({
    required CertificateRecord record,
    required DisplayConfig displayConfig,
  }) {
    final filteredData = <String, dynamic>{};

    // Include only authorized public columns
    for (final col in displayConfig.publicColumns) {
      if (record.rawData.containsKey(col)) {
        filteredData[col] = record.rawData[col];
      }
    }

    return {
      'cert_code': record.certCode,
      'status': 'AUTHENTIC',
      'verified_at': DateTime.now().toUtc().toIso8601String(),
      'school_name': displayConfig.institutionName,
      'drive_pdf_link': displayConfig.allowPdfDownload ? record.drivePdfLink : null,
      'fields': filteredData,
    };
  }

  /// Bulk syncs records to Cloudflare KV in chunks of up to 10,000 items
  Future<int> syncRecords({
    required List<CertificateRecord> records,
    required DisplayConfig displayConfig,
    Function(int syncedCount, int totalCount)? onProgress,
  }) async {
    final creds = await _storage.getCloudflareCredentials();
    final accountId = creds['accountId'];
    final apiToken = creds['apiToken'];
    final kvId = creds['kvNamespaceId'];

    if (accountId == null || apiToken == null || kvId == null) {
      throw Exception('Cloudflare credentials or KV namespace ID not configured.');
    }

    final api = CloudflareApi(accountId: accountId, apiToken: apiToken);
    final chunkSize = 10000;
    int totalSynced = 0;

    for (int i = 0; i < records.length; i += chunkSize) {
      final end = (i + chunkSize < records.length) ? i + chunkSize : records.length;
      final chunk = records.sublist(i, end);

      final kvItems = chunk.map((record) {
        final payload = preparePublicPayload(
          record: record,
          displayConfig: displayConfig,
        );
        return {
          'key': record.certCode,
          'value': jsonEncode(payload),
        };
      }).toList();

      await api.bulkWriteKv(namespaceId: kvId, items: kvItems);
      totalSynced += chunk.length;

      if (onProgress != null) {
        onProgress(totalSynced, records.length);
      }
    }

    return totalSynced;
  }
}
