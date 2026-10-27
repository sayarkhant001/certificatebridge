import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static const String _keyGoogleAccessToken = 'sec_google_access_token';
  static const String _keyGoogleRefreshToken = 'sec_google_refresh_token';
  static const String _keyGoogleTokenExpiry = 'sec_google_token_expiry';
  static const String _keyGoogleUserEmail = 'sec_google_user_email';
  static const String _keyGoogleClientId = 'sec_google_client_id';
  static const String _keyGoogleClientSecret = 'sec_google_client_secret';
  static const String _keyCloudflareAccountId = 'sec_cloudflare_account_id';
  static const String _keyCloudflareAccountName = 'sec_cloudflare_account_name';
  static const String _keyCloudflareApiToken = 'sec_cloudflare_api_token';
  static const String _keyCloudflareKvId = 'sec_cloudflare_kv_id';
  static const String _keyCloudflareWorkerUrl = 'sec_cloudflare_worker_url';
  static const String _keyAppsScriptUrl = 'sec_apps_script_url';

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  String _encrypt(String value) {
    final bytes = utf8.encode(value);
    // Simple reversible XOR obfuscation with app seed
    final obfuscated = bytes.map((b) => b ^ 0x5A).toList();
    return base64Encode(obfuscated);
  }

  String _decrypt(String encoded) {
    try {
      final bytes = base64Decode(encoded);
      final deobfuscated = bytes.map((b) => b ^ 0x5A).toList();
      return utf8.decode(deobfuscated);
    } catch (_) {
      return encoded;
    }
  }

  Future<void> saveGoogleTokens({
    required String accessToken,
    String? refreshToken,
    int? expiresInSeconds,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(_keyGoogleAccessToken, _encrypt(accessToken));
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await prefs.setString(_keyGoogleRefreshToken, _encrypt(refreshToken));
    }
    if (expiresInSeconds != null) {
      final expiryTime =
          DateTime.now().add(Duration(seconds: expiresInSeconds)).toIso8601String();
      await prefs.setString(_keyGoogleTokenExpiry, _encrypt(expiryTime));
    }
  }

  Future<String?> getGoogleAccessToken() async {
    final prefs = await _prefs;
    final val = prefs.getString(_keyGoogleAccessToken);
    if (val == null) return null;
    return _decrypt(val);
  }

  Future<String?> getGoogleRefreshToken() async {
    final prefs = await _prefs;
    final val = prefs.getString(_keyGoogleRefreshToken);
    if (val == null) return null;
    return _decrypt(val);
  }

  Future<void> saveGoogleUserEmail(String email) async {
    final prefs = await _prefs;
    await prefs.setString(_keyGoogleUserEmail, _encrypt(email));
  }

  Future<String?> getGoogleUserEmail() async {
    final prefs = await _prefs;
    final val = prefs.getString(_keyGoogleUserEmail);
    if (val == null) return null;
    return _decrypt(val);
  }

  Future<void> saveGoogleClientConfig({
    required String clientId,
    String? clientSecret,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(_keyGoogleClientId, _encrypt(clientId));
    if (clientSecret != null && clientSecret.isNotEmpty) {
      await prefs.setString(_keyGoogleClientSecret, _encrypt(clientSecret));
    }
  }

  Future<String?> getGoogleClientId() async {
    final prefs = await _prefs;
    final val = prefs.getString(_keyGoogleClientId);
    if (val == null) return null;
    return _decrypt(val);
  }

  Future<String?> getGoogleClientSecret() async {
    final prefs = await _prefs;
    final val = prefs.getString(_keyGoogleClientSecret);
    if (val == null) return null;
    return _decrypt(val);
  }

  Future<bool> isGoogleTokenExpired() async {
    final prefs = await _prefs;
    final val = prefs.getString(_keyGoogleTokenExpiry);
    if (val == null) return true;
    final expiryStr = _decrypt(val);
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return true;
    return DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 2)));
  }

  Future<void> saveCloudflareCredentials({
    required String accountId,
    required String apiToken,
    String? accountName,
    String? kvNamespaceId,
    String? workerUrl,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(_keyCloudflareAccountId, _encrypt(accountId));
    await prefs.setString(_keyCloudflareApiToken, _encrypt(apiToken));
    if (accountName != null) {
      await prefs.setString(_keyCloudflareAccountName, _encrypt(accountName));
    }
    if (kvNamespaceId != null) {
      await prefs.setString(_keyCloudflareKvId, _encrypt(kvNamespaceId));
    }
    if (workerUrl != null) {
      await prefs.setString(_keyCloudflareWorkerUrl, _encrypt(workerUrl));
    }
  }

  Future<Map<String, String?>> getCloudflareCredentials() async {
    final prefs = await _prefs;
    final accountIdRaw = prefs.getString(_keyCloudflareAccountId);
    final accountNameRaw = prefs.getString(_keyCloudflareAccountName);
    final apiTokenRaw = prefs.getString(_keyCloudflareApiToken);
    final kvIdRaw = prefs.getString(_keyCloudflareKvId);
    final workerUrlRaw = prefs.getString(_keyCloudflareWorkerUrl);

    return {
      'accountId': accountIdRaw != null ? _decrypt(accountIdRaw) : null,
      'accountName': accountNameRaw != null ? _decrypt(accountNameRaw) : null,
      'apiToken': apiTokenRaw != null ? _decrypt(apiTokenRaw) : null,
      'kvNamespaceId': kvIdRaw != null ? _decrypt(kvIdRaw) : null,
      'workerUrl': workerUrlRaw != null ? _decrypt(workerUrlRaw) : null,
    };
  }

  Future<void> saveAppsScriptUrl(String url) async {
    final prefs = await _prefs;
    await prefs.setString(_keyAppsScriptUrl, _encrypt(url));
  }

  Future<String?> getAppsScriptUrl() async {
    final prefs = await _prefs;
    final val = prefs.getString(_keyAppsScriptUrl);
    if (val == null) return null;
    return _decrypt(val);
  }

  Future<void> clearAll() async {
    final prefs = await _prefs;
    await prefs.remove(_keyGoogleAccessToken);
    await prefs.remove(_keyGoogleRefreshToken);
    await prefs.remove(_keyGoogleTokenExpiry);
    await prefs.remove(_keyCloudflareAccountId);
    await prefs.remove(_keyCloudflareApiToken);
    await prefs.remove(_keyCloudflareKvId);
    await prefs.remove(_keyCloudflareWorkerUrl);
    await prefs.remove(_keyAppsScriptUrl);
  }
}
