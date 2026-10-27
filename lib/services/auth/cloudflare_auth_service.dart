import 'dart:io';
import '../../core/constants/app_constants.dart';
import '../../core/storage/secure_storage_service.dart';
import '../cloudflare/cloudflare_api.dart';

class CloudflareAuthService {
  final SecureStorageService _storage = SecureStorageService();

  Future<bool> hasCredentials() async {
    final creds = await _storage.getCloudflareCredentials();
    return creds['accountId'] != null && creds['apiToken'] != null;
  }

  Future<CloudflareApi?> getApi() async {
    final creds = await _storage.getCloudflareCredentials();
    final accountId = creds['accountId'];
    final apiToken = creds['apiToken'];
    if (accountId == null || apiToken == null) return null;
    return CloudflareApi(accountId: accountId, apiToken: apiToken);
  }

  /// Validates and saves credentials, then provisions KV namespace if needed
  Future<Map<String, dynamic>> setupCloudflare({
    required String accountId,
    required String apiToken,
    String? workerJsPath,
  }) async {
    final api = CloudflareApi(accountId: accountId, apiToken: apiToken);
    final isValid = await api.verifyToken();
    if (!isValid) {
      throw Exception('Invalid Cloudflare API Token or Account ID.');
    }

    // Auto-provision KV namespace
    final kvId = await api.findOrCreateKvNamespace(
      title: AppConstants.defaultKvNamespaceName,
    );

    String? workerUrl;
    if (workerJsPath != null) {
      final file = File(workerJsPath);
      if (await file.exists()) {
        final code = await file.readAsString();
        workerUrl = await api.deployEdgeWorker(
          scriptName: 'certibridge-edge-verifier',
          workerCode: code,
          kvNamespaceId: kvId,
          kvBindingName: AppConstants.defaultKvBinding,
        );
      }
    }

    await _storage.saveCloudflareCredentials(
      accountId: accountId,
      apiToken: apiToken,
      kvNamespaceId: kvId,
      workerUrl: workerUrl,
    );

    return {
      'accountId': accountId,
      'kvNamespaceId': kvId,
      'workerUrl': workerUrl,
    };
  }
}
