import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    mOptions: MacOsOptions(),
    wOptions: WindowsOptions(
      useBackwardCompatibility: false,
    ),
  );

  static const String _keyGoogleAccessToken = 'google_access_token';
  static const String _keyGoogleRefreshToken = 'google_refresh_token';
  static const String _keyGoogleTokenExpiry = 'google_token_expiry';
  static const String _keyCloudflareAccountId = 'cloudflare_account_id';
  static const String _keyCloudflareApiToken = 'cloudflare_api_token';
  static const String _keyCloudflareKvId = 'cloudflare_kv_id';
  static const String _keyCloudflareWorkerUrl = 'cloudflare_worker_url';
  static const String _keyAppsScriptUrl = 'apps_script_url';

  Future<void> saveGoogleTokens({
    required String accessToken,
    String? refreshToken,
    int? expiresInSeconds,
  }) async {
    await _storage.write(key: _keyGoogleAccessToken, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _keyGoogleRefreshToken, value: refreshToken);
    }
    if (expiresInSeconds != null) {
      final expiryTime =
          DateTime.now().add(Duration(seconds: expiresInSeconds)).toIso8601String();
      await _storage.write(key: _keyGoogleTokenExpiry, value: expiryTime);
    }
  }

  Future<String?> getGoogleAccessToken() async {
    return await _storage.read(key: _keyGoogleAccessToken);
  }

  Future<String?> getGoogleRefreshToken() async {
    return await _storage.read(key: _keyGoogleRefreshToken);
  }

  Future<bool> isGoogleTokenExpired() async {
    final expiryStr = await _storage.read(key: _keyGoogleTokenExpiry);
    if (expiryStr == null) return true;
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return true;
    return DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 2)));
  }

  Future<void> saveCloudflareCredentials({
    required String accountId,
    required String apiToken,
    String? kvNamespaceId,
    String? workerUrl,
  }) async {
    await _storage.write(key: _keyCloudflareAccountId, value: accountId);
    await _storage.write(key: _keyCloudflareApiToken, value: apiToken);
    if (kvNamespaceId != null) {
      await _storage.write(key: _keyCloudflareKvId, value: kvNamespaceId);
    }
    if (workerUrl != null) {
      await _storage.write(key: _keyCloudflareWorkerUrl, value: workerUrl);
    }
  }

  Future<Map<String, String?>> getCloudflareCredentials() async {
    final accountId = await _storage.read(key: _keyCloudflareAccountId);
    final apiToken = await _storage.read(key: _keyCloudflareApiToken);
    final kvId = await _storage.read(key: _keyCloudflareKvId);
    final workerUrl = await _storage.read(key: _keyCloudflareWorkerUrl);
    return {
      'accountId': accountId,
      'apiToken': apiToken,
      'kvNamespaceId': kvId,
      'workerUrl': workerUrl,
    };
  }

  Future<void> saveAppsScriptUrl(String url) async {
    await _storage.write(key: _keyAppsScriptUrl, value: url);
  }

  Future<String?> getAppsScriptUrl() async {
    return await _storage.read(key: _keyAppsScriptUrl);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
