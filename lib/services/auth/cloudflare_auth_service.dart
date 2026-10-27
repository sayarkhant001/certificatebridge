import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/storage/secure_storage_service.dart';
import '../cloudflare/cloudflare_api.dart';
import 'loopback_server.dart';

class CloudflareAuthService {
  final SecureStorageService _storage = SecureStorageService();

  static const String _cfOAuthClientId = '54d11594-84e4-41aa-b438-e81b8fa78ee7';
  static const String _cfOAuthRedirectUri = 'http://localhost:8976/oauth/callback';
  static const String _cfAuthEndpoint = 'https://dash.cloudflare.com/oauth2/auth';
  static const String _cfTokenEndpoint = 'https://dash.cloudflare.com/oauth2/token';

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

  String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// 1-Click Cloudflare Account Login via official OAuth flow.
  /// Automatically fetches user's Account ID and provisions KV namespace.
  /// No Account ID or manual API Token entry required!
  Future<Map<String, dynamic>> loginWithOAuth({String? workerJsPath}) async {
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);
    final state = _generateCodeVerifier().substring(0, 16);

    final authUri = Uri.parse(_cfAuthEndpoint).replace(queryParameters: {
      'response_type': 'code',
      'client_id': _cfOAuthClientId,
      'redirect_uri': _cfOAuthRedirectUri,
      'scope': 'account:read user:read workers:write workers_kv:write workers_routes:write zone:read',
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'state': state,
    });

    final server = LoopbackAuthServer(port: 8976);

    if (await canLaunchUrl(authUri)) {
      await launchUrl(authUri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not open browser for Cloudflare login: $authUri');
    }

    final callbackParams = await server.waitForCallback();
    await server.stop();

    final code = callbackParams['code'];
    if (code == null) {
      final error = callbackParams['error'] ?? 'Unknown Cloudflare OAuth error';
      throw Exception('Cloudflare OAuth authorization failed: $error');
    }

    // Exchange auth code for access token
    final tokenResponse = await http.post(
      Uri.parse(_cfTokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _cfOAuthRedirectUri,
        'client_id': _cfOAuthClientId,
        'code_verifier': codeVerifier,
      },
    );

    if (tokenResponse.statusCode != 200) {
      throw Exception(
        'Failed to exchange Cloudflare token (${tokenResponse.statusCode}): ${tokenResponse.body}',
      );
    }

    final tokenJson = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
    final accessToken = tokenJson['access_token'] as String;

    // Automatically fetch user's Cloudflare accounts
    final accountsResponse = await http.get(
      Uri.parse('https://api.cloudflare.com/client/v4/accounts'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (accountsResponse.statusCode != 200) {
      throw Exception(
        'Failed to query Cloudflare accounts: ${accountsResponse.statusCode} - ${accountsResponse.body}',
      );
    }

    final accountsJson = jsonDecode(accountsResponse.body) as Map<String, dynamic>;
    final accountsList = accountsJson['result'] as List<dynamic>?;
    if (accountsList == null || accountsList.isEmpty) {
      throw Exception('No Cloudflare accounts found on this user profile.');
    }

    final primaryAccount = accountsList.first as Map<String, dynamic>;
    final accountId = primaryAccount['id'] as String;
    final accountName = primaryAccount['name'] as String? ?? 'Cloudflare Account';

    // Auto-provision KV & edge worker
    final result = await setupCloudflare(
      accountId: accountId,
      apiToken: accessToken,
      accountName: accountName,
      workerJsPath: workerJsPath,
    );

    return {
      'accountId': accountId,
      'accountName': accountName,
      'kvNamespaceId': result['kvNamespaceId'],
      'workerUrl': result['workerUrl'],
    };
  }

  /// Validates and saves credentials, then provisions KV namespace if needed
  Future<Map<String, dynamic>> setupCloudflare({
    required String accountId,
    required String apiToken,
    String? accountName,
    String? workerJsPath,
  }) async {
    final api = CloudflareApi(accountId: accountId, apiToken: apiToken);
    final isValid = await api.verifyToken();
    if (!isValid) {
      throw Exception('Could not verify Cloudflare credentials for Account ID: $accountId');
    }

    // Auto-provision KV namespace (gracefully catch errors to prevent dropping auth)
    String? kvId;
    try {
      kvId = await api.findOrCreateKvNamespace(
        title: AppConstants.defaultKvNamespaceName,
      );
    } catch (e) {
      // If KV creation is deferred or requires setup, log and proceed
    }

    String? workerUrl;
    if (workerJsPath != null && kvId != null) {
      try {
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
      } catch (e) {
        // If worker deploy is deferred, log and proceed
      }
    }

    await _storage.saveCloudflareCredentials(
      accountId: accountId,
      apiToken: apiToken,
      accountName: accountName,
      kvNamespaceId: kvId,
      workerUrl: workerUrl,
    );

    return {
      'accountId': accountId,
      'accountName': accountName,
      'kvNamespaceId': kvId,
      'workerUrl': workerUrl,
    };
  }
}
