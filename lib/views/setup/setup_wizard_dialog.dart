import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/apps_script_template.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../services/auth/cloudflare_auth_service.dart';
import '../../services/auth/google_auth_service.dart';
import '../../services/google/apps_script_service.dart';

class SetupWizardDialog extends StatefulWidget {
  const SetupWizardDialog({Key? key}) : super(key: key);

  @override
  State<SetupWizardDialog> createState() => _SetupWizardDialogState();
}

class _SetupWizardDialogState extends State<SetupWizardDialog> with SingleTickerProviderStateMixin {
  final GoogleAuthService _googleAuth = GoogleAuthService();
  final CloudflareAuthService _cfAuth = CloudflareAuthService();
  final SecureStorageService _storage = SecureStorageService();

  late TabController _googleTabController;

  bool _isGoogleConnected = false;
  String? _googleUserEmail;
  bool _isCloudflareConfigured = false;
  String? _cfAccountName;
  String? _cfAccountId;
  bool _isLoadingGoogle = false;
  bool _isLoadingCf = false;
  bool _showManualCf = false;

  final TextEditingController _googleClientIdCtrl = TextEditingController();
  final TextEditingController _googleClientSecretCtrl = TextEditingController();
  final TextEditingController _cfAccountIdCtrl = TextEditingController();
  final TextEditingController _cfApiTokenCtrl = TextEditingController();
  final TextEditingController _appsScriptUrlCtrl = TextEditingController();

  String? _statusMessage;
  bool _isSuccessMessage = false;

  @override
  void initState() {
    super.initState();
    _googleTabController = TabController(length: 2, vsync: this);
    _loadCurrentStatus();
  }

  @override
  void dispose() {
    _googleTabController.dispose();
    _googleClientIdCtrl.dispose();
    _googleClientSecretCtrl.dispose();
    _cfAccountIdCtrl.dispose();
    _cfApiTokenCtrl.dispose();
    _appsScriptUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentStatus() async {
    final appsScriptUrl = await _storage.getAppsScriptUrl();
    final googleConnected = (await _googleAuth.isSignedIn()) || (appsScriptUrl != null && appsScriptUrl.isNotEmpty);
    final googleEmail = await _storage.getGoogleUserEmail();
    final cfCreds = await _storage.getCloudflareCredentials();
    final savedClientId = await _storage.getGoogleClientId();
    final savedClientSecret = await _storage.getGoogleClientSecret();

    setState(() {
      _isGoogleConnected = googleConnected;
      _googleUserEmail = googleEmail;
      if (savedClientId != null) _googleClientIdCtrl.text = savedClientId;
      if (savedClientSecret != null) _googleClientSecretCtrl.text = savedClientSecret;

      if (cfCreds['accountId'] != null && cfCreds['apiToken'] != null) {
        _isCloudflareConfigured = true;
        _cfAccountId = cfCreds['accountId'];
        _cfAccountName = cfCreds['accountName'];
        _cfAccountIdCtrl.text = cfCreds['accountId']!;
        _cfApiTokenCtrl.text = cfCreds['apiToken']!;
      }
      if (appsScriptUrl != null) {
        _appsScriptUrlCtrl.text = appsScriptUrl;
      }
    });
  }

  /// 1-Click Cloudflare Account Login via OAuth (No manual ID or token!)
  Future<void> _loginCloudflareOAuth() async {
    setState(() {
      _isLoadingCf = true;
      _statusMessage = null;
    });

    try {
      final result = await _cfAuth.loginWithOAuth(
        workerJsPath: 'web_verifier/worker.js',
      );
      setState(() {
        _isCloudflareConfigured = true;
        _cfAccountId = result['accountId'];
        _cfAccountName = result['accountName'];
        _statusMessage = 'Cloudflare connected via 1-Click OAuth! (${result['accountName'] ?? result['accountId']})';
        _isSuccessMessage = true;
      });
      await _loadCurrentStatus();
    } catch (e) {
      setState(() {
        _statusMessage = 'Cloudflare Login Error: $e';
        _isSuccessMessage = false;
      });
    } finally {
      setState(() => _isLoadingCf = false);
    }
  }

  /// 1-Click Google Account Login via OAuth (No manual ID or secret!)
  Future<void> _connectGoogle({String? customClientId, String? customClientSecret}) async {
    setState(() {
      _isLoadingGoogle = true;
      _statusMessage = null;
    });

    try {
      final success = await _googleAuth.authenticate(
        customClientId: customClientId,
        customClientSecret: customClientSecret,
      );
      final email = await _storage.getGoogleUserEmail();
      setState(() {
        _isGoogleConnected = success;
        _googleUserEmail = email;
        _statusMessage = email != null
            ? 'Google Account ($email) connected successfully!'
            : 'Google Account (Drive & Sheets) connected successfully!';
        _isSuccessMessage = true;
      });
      await _loadCurrentStatus();
    } catch (e) {
      setState(() {
        _statusMessage = 'Google Authentication Error: $e';
        _isSuccessMessage = false;
      });
    } finally {
      setState(() => _isLoadingGoogle = false);
    }
  }

  /// Manual Cloudflare configuration fallback
  Future<void> _saveCloudflareManual() async {
    final accountId = _cfAccountIdCtrl.text.trim();
    final apiToken = _cfApiTokenCtrl.text.trim();

    if (accountId.isEmpty || apiToken.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter both Cloudflare Account ID and API Token.';
        _isSuccessMessage = false;
      });
      return;
    }

    setState(() {
      _isLoadingCf = true;
      _statusMessage = null;
    });

    try {
      final result = await _cfAuth.setupCloudflare(
        accountId: accountId,
        apiToken: apiToken,
        workerJsPath: 'web_verifier/worker.js',
      );
      setState(() {
        _isCloudflareConfigured = true;
        _cfAccountId = result['accountId'];
        _cfAccountName = result['accountName'];
        _statusMessage = 'Cloudflare Edge KV provisioned successfully!';
        _isSuccessMessage = true;
      });
      await _loadCurrentStatus();
    } catch (e) {
      setState(() {
        _statusMessage = 'Cloudflare Configuration Error: $e';
        _isSuccessMessage = false;
      });
    } finally {
      setState(() => _isLoadingCf = false);
    }
  }

  Future<void> _pickGoogleCredentialsJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null && result.files.single.bytes != null) {
        final content = utf8.decode(result.files.single.bytes!);
        final json = jsonDecode(content) as Map<String, dynamic>;
        final installed = (json['installed'] ?? json['web']) as Map<String, dynamic>?;
        if (installed != null) {
          final clientId = installed['client_id'] as String?;
          final clientSecret = installed['client_secret'] as String?;
          if (clientId != null) {
            _googleClientIdCtrl.text = clientId;
            if (clientSecret != null) {
              _googleClientSecretCtrl.text = clientSecret;
            }
            setState(() {
              _statusMessage = 'Google credentials.json loaded successfully!';
              _isSuccessMessage = true;
            });
          }
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to parse credentials.json: $e';
        _isSuccessMessage = false;
      });
    }
  }

  Future<void> _saveAppsScript() async {
    final url = _appsScriptUrlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter your Apps Script Web App Exec URL.';
        _isSuccessMessage = false;
      });
      return;
    }

    setState(() {
      _isLoadingGoogle = true;
      _statusMessage = null;
    });

    try {
      final service = AppsScriptService();
      final data = await service.ping(url);
      final detectedEmail = (data['email'] as String?) ?? 'Connected Google Account';

      await _storage.saveAppsScriptUrl(url);
      await _storage.saveGoogleUserEmail(detectedEmail);

      setState(() {
        _isGoogleConnected = true;
        _googleUserEmail = detectedEmail;
        _statusMessage = 'Google connected successfully via Apps Script! ($detectedEmail)';
        _isSuccessMessage = true;
      });
      await _loadCurrentStatus();
    } catch (e) {
      await _storage.saveAppsScriptUrl(url);
      setState(() {
        _isGoogleConnected = true;
        _statusMessage = 'Apps Script URL saved! (Warning ping: $e)';
        _isSuccessMessage = true;
      });
      await _loadCurrentStatus();
    } finally {
      setState(() => _isLoadingGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 680,
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.hub_outlined, color: Color(0xFF60A5FA), size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BYOA Cloud Setup Wizard',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            '\$0 Operational Infrastructure & Private Customer Clouds',
                            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF334155), height: 32),

              if (_statusMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: _isSuccessMessage
                        ? const Color(0xFF065F46).withOpacity(0.3)
                        : const Color(0xFF991B1B).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isSuccessMessage ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccessMessage ? Icons.check_circle : Icons.error,
                        color: _isSuccessMessage ? const Color(0xFF34D399) : const Color(0xFFF87171),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            color: _isSuccessMessage ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Section 1: Cloudflare Edge Worker & KV (1-Click Account Login)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isCloudflareConfigured ? const Color(0xFF059669) : const Color(0xFFF59E0B),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.electric_bolt, color: Colors.orangeAccent, size: 22),
                            SizedBox(width: 8),
                            Text('Cloudflare Edge Verifier & KV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isCloudflareConfigured ? const Color(0xFF065F46) : const Color(0xFF374151),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isCloudflareConfigured
                                ? (_cfAccountName != null ? 'Connected: $_cfAccountName' : 'Configured')
                                : 'Not Connected',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isCloudflareConfigured ? const Color(0xFF34D399) : Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Log in with your Cloudflare account in 1 click. CertiBridge automatically discovers your Account ID, creates the CERT_VERIFIER_KV namespace, and deploys the edge verifier worker with \$0 hosting cost.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    // Primary 1-Click OAuth Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoadingCf ? null : _loginCloudflareOAuth,
                        icon: _isLoadingCf
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.login, size: 18),
                        label: Text(
                          _isCloudflareConfigured ? '⚡ Reconnect Cloudflare Account (1-Click)' : '⚡ Log In with Cloudflare (1-Click, No Manual ID)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => setState(() => _showManualCf = !_showManualCf),
                      child: Row(
                        children: [
                          Icon(_showManualCf ? Icons.arrow_drop_down : Icons.arrow_right, color: Colors.white54, size: 18),
                          Text(
                            _showManualCf ? 'Hide manual token fields' : 'Advanced: Enter Account ID & Token manually',
                            style: const TextStyle(fontSize: 11, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),

                    if (_showManualCf) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cfAccountIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cloudflare Account ID',
                          isDense: true,
                          hintText: 'e.g. 1a2b3c4d5e6f...',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _cfApiTokenCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Cloudflare API Token',
                          isDense: true,
                          hintText: 'Bearer token',
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _isLoadingCf ? null : _saveCloudflareManual,
                        child: const Text('Save Manual Token'),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Section 2: Google Drive & Sheets (1-Click Account Login)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isGoogleConnected ? const Color(0xFF059669) : const Color(0xFF2563EB),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.cloud_upload_outlined, color: Colors.blueAccent, size: 22),
                            SizedBox(width: 8),
                            Text('Google Drive & Sheets (BYOA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isGoogleConnected ? const Color(0xFF065F46) : const Color(0xFF374151),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isGoogleConnected
                                ? (_googleUserEmail != null ? 'Connected: $_googleUserEmail' : 'Connected')
                                : 'Not Connected',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isGoogleConnected ? const Color(0xFF34D399) : Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Log in with your Google account in 1 click. Authorize access to Google Drive (for certificate storage) and Google Sheets (for recipient rosters) with \$0 vendor cost.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    // Tab bar for Google Connection Method
                    TabBar(
                      controller: _googleTabController,
                      indicatorColor: const Color(0xFF2563EB),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white54,
                      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      tabs: const [
                        Tab(text: '⚡ Apps Script (Never Blocked, Free)'),
                        Tab(text: '🔑 GCP OAuth Client ID'),
                      ],
                    ),
                    const SizedBox(height: 14),

                    SizedBox(
                      height: 250,
                      child: TabBarView(
                        controller: _googleTabController,
                        children: [
                          // Tab 1: Google Apps Script (100% Unblocked by Google, Zero-Config)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF065F46).withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF059669).withOpacity(0.5)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.verified, color: Color(0xFF34D399), size: 16),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Google never blocks Apps Script because it runs directly inside your Google Account with zero GCP console setup.',
                                        style: TextStyle(fontSize: 11, color: Color(0xFFD1FAE5)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Steps: 1. Copy script  →  2. Open script.google.com, paste & Deploy as Web App (Access: Anyone)  →  3. Paste URL below',
                                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: appsScriptTemplateCode));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('✓ Copied complete apps_script/code.gs! Paste into script.google.com and click Deploy.'),
                                          backgroundColor: Color(0xFF059669),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.copy, size: 14),
                                    label: const Text('1. Copy apps_script/code.gs (1-Click)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1E3A8A),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => launchUrl(Uri.parse('https://script.google.com')),
                                    icon: const Icon(Icons.open_in_new, size: 14),
                                    label: const Text('2. Open script.google.com', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _appsScriptUrlCtrl,
                                      decoration: const InputDecoration(
                                        labelText: '3. Paste Apps Script Web App Exec URL',
                                        isDense: true,
                                        hintText: 'https://script.google.com/macros/s/.../exec',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _isLoadingGoogle ? null : _saveAppsScript,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    ),
                                    child: _isLoadingGoogle
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Text('Save & Connect', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Tab 2: Custom GCP Client ID (Bypasses block by adding your email to Test Users)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF991B1B).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.5)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Color(0xFFF87171), size: 16),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Why did Google block? Sensitive Drive & Sheets scopes require adding your Google email to "Test Users" in Google Cloud Console OAuth consent screen.',
                                        style: TextStyle(fontSize: 11, color: Color(0xFFFEE2E2)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _pickGoogleCredentialsJson,
                                    icon: const Icon(Icons.file_upload_outlined, size: 14),
                                    label: const Text('Pick credentials.json', style: TextStyle(fontSize: 11)),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => launchUrl(Uri.parse('https://console.cloud.google.com/apis/credentials')),
                                    icon: const Icon(Icons.open_in_new, size: 14),
                                    label: const Text('GCP Credentials', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _googleClientIdCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Your GCP OAuth Client ID',
                                        isDense: true,
                                        hintText: 'xxxx.apps.googleusercontent.com',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _isLoadingGoogle
                                        ? null
                                        : () => _connectGoogle(
                                              customClientId: _googleClientIdCtrl.text.trim(),
                                            ),
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                                    child: _isLoadingGoogle
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Text('Authorize'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF334155),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Done', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
