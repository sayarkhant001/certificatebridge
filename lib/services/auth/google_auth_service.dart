import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/storage/secure_storage_service.dart';
import 'loopback_server.dart';

class GoogleAuthService {
  final SecureStorageService _storage = SecureStorageService();

  // Standard OAuth 2.0 endpoints
  static const String _authEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const String _tokenEndpoint = 'https://oauth2.googleapis.com/token';

  // Scopes requested
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/spreadsheets',
  ];

  static const String defaultClientId = '367116221053-7n0vf5akeru7on6o2fjinrecpdoe99eg.apps.googleusercontent.com';
  static const String defaultClientSecret = '1qsNodXNaWq1mQuBjUjmvhoO';

  String? _clientId;
  String? _clientSecret;

  void setCustomClientId(String clientId, [String? clientSecret]) {
    _clientId = clientId;
    _clientSecret = clientSecret;
  }

  /// Generate cryptographically secure PKCE code verifier
  String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  /// Generate S256 code challenge from verifier
  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  /// Executes the 1-Click PKCE OAuth Loopback flow
  Future<bool> authenticate({String? customClientId, String? customClientSecret}) async {
    final savedClientId = await _storage.getGoogleClientId();
    final savedClientSecret = await _storage.getGoogleClientSecret();

    final clientId = (customClientId != null && customClientId.trim().isNotEmpty)
        ? customClientId.trim()
        : (savedClientId ?? defaultClientId);

    final clientSecret = (customClientSecret != null && customClientSecret.trim().isNotEmpty)
        ? customClientSecret.trim()
        : (savedClientSecret ?? defaultClientSecret);

    _clientId = clientId;
    _clientSecret = clientSecret;
    await _storage.saveGoogleClientConfig(clientId: _clientId!, clientSecret: _clientSecret);

    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);
    final state = _generateCodeVerifier().substring(0, 16);

    final authUri = Uri.parse(_authEndpoint).replace(queryParameters: {
      'client_id': _clientId,
      'redirect_uri': AppConstants.loopbackRedirectUri,
      'response_type': 'code',
      'scope': _scopes.join(' '),
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'state': state,
      'access_type': 'offline',
      'prompt': 'consent',
    });

    final server = LoopbackAuthServer(port: AppConstants.loopbackPort);

    // Launch system default browser
    if (await canLaunchUrl(authUri)) {
      await launchUrl(authUri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch system browser for URL: $authUri');
    }

    // Wait for callback on loopback
    final callbackParams = await server.waitForCallback();

    if (callbackParams.containsKey('error')) {
      throw Exception('OAuth Error: ${callbackParams['error']}');
    }

    final code = callbackParams['code'];
    if (code == null) {
      throw Exception('No authorization code returned from Google.');
    }

    // Exchange auth code for tokens
    final response = await http.post(
      Uri.parse(_tokenEndpoint),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'client_id': _clientId!,
        if (_clientSecret != null && _clientSecret!.isNotEmpty) 'client_secret': _clientSecret!,
        'code': code,
        'code_verifier': codeVerifier,
        'grant_type': 'authorization_code',
        'redirect_uri': AppConstants.loopbackRedirectUri,
      },
    );

    if (response.statusCode == 200) {
      final tokenData = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = tokenData['access_token'] as String;
      final refreshToken = tokenData['refresh_token'] as String?;
      final expiresIn = tokenData['expires_in'] as int? ?? 3600;

      await _storage.saveGoogleTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresInSeconds: expiresIn,
      );

      try {
        final userinfoRes = await http.get(
          Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
          headers: {'Authorization': 'Bearer $accessToken'},
        );
        if (userinfoRes.statusCode == 200) {
          final userInfo = jsonDecode(userinfoRes.body) as Map<String, dynamic>;
          final email = userInfo['email'] as String?;
          if (email != null && email.isNotEmpty) {
            await _storage.saveGoogleUserEmail(email);
          }
        }
      } catch (_) {
        // Fallback gracefully
      }

      return true;
    } else {
      throw Exception(
        'Failed to exchange authorization code: ${response.statusCode} - ${response.body}',
      );
    }
  }

  /// Refreshes access token using stored refresh token
  Future<String?> getValidAccessToken() async {
    final isExpired = await _storage.isGoogleTokenExpired();
    final currentToken = await _storage.getGoogleAccessToken();

    if (!isExpired && currentToken != null) {
      return currentToken;
    }

    final refreshToken = await _storage.getGoogleRefreshToken();
    if (refreshToken == null) {
      return currentToken; // fallback
    }

    try {
      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _clientId,
          'refresh_token': refreshToken,
          'grant_type': 'refresh_token',
        },
      );

      if (response.statusCode == 200) {
        final tokenData = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccessToken = tokenData['access_token'] as String;
        final expiresIn = tokenData['expires_in'] as int? ?? 3600;

        await _storage.saveGoogleTokens(
          accessToken: newAccessToken,
          expiresInSeconds: expiresIn,
        );

        return newAccessToken;
      }
    } catch (_) {
      // Fallback to existing token
    }

    return currentToken;
  }

  Future<bool> isSignedIn() async {
    final token = await _storage.getGoogleAccessToken();
    return token != null && token.isNotEmpty;
  }
}
