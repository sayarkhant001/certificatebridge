import 'package:flutter/material.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../services/auth/cloudflare_auth_service.dart';
import '../../services/auth/google_auth_service.dart';

class SetupWizardDialog extends StatefulWidget {
  const SetupWizardDialog({Key? key}) : super(key: key);

  @override
  State<SetupWizardDialog> createState() => _SetupWizardDialogState();
}

class _SetupWizardDialogState extends State<SetupWizardDialog> {
  final GoogleAuthService _googleAuth = GoogleAuthService();
  final CloudflareAuthService _cfAuth = CloudflareAuthService();
  final SecureStorageService _storage = SecureStorageService();

  bool _isGoogleConnected = false;
  bool _isCloudflareConfigured = false;
  bool _isLoadingGoogle = false;
  bool _isLoadingCf = false;

  final TextEditingController _cfAccountIdCtrl = TextEditingController();
  final TextEditingController _cfApiTokenCtrl = TextEditingController();
  final TextEditingController _appsScriptUrlCtrl = TextEditingController();

  String? _statusMessage;
  bool _isSuccessMessage = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentStatus();
  }

  Future<void> _loadCurrentStatus() async {
    final googleConnected = await _googleAuth.isSignedIn();
    final cfCreds = await _storage.getCloudflareCredentials();
    final appsScriptUrl = await _storage.getAppsScriptUrl();

    setState(() {
      _isGoogleConnected = googleConnected;
      if (cfCreds['accountId'] != null && cfCreds['apiToken'] != null) {
        _isCloudflareConfigured = true;
        _cfAccountIdCtrl.text = cfCreds['accountId']!;
        _cfApiTokenCtrl.text = cfCreds['apiToken']!;
      }
      if (appsScriptUrl != null) {
        _appsScriptUrlCtrl.text = appsScriptUrl;
      }
    });
  }

  Future<void> _connectGoogle() async {
    setState(() {
      _isLoadingGoogle = true;
      _statusMessage = null;
    });

    try {
      final success = await _googleAuth.authenticate();
      setState(() {
        _isGoogleConnected = success;
        _statusMessage = 'Google Account (Drive & Sheets) connected successfully!';
        _isSuccessMessage = true;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Google Authentication Error: $e';
        _isSuccessMessage = false;
      });
    } finally {
      setState(() => _isLoadingGoogle = false);
    }
  }

  Future<void> _saveCloudflare() async {
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
      );
      setState(() {
        _isCloudflareConfigured = true;
        _statusMessage = 'Cloudflare Edge KV provisioned successfully! (${result['kvNamespaceId']})';
        _isSuccessMessage = true;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Cloudflare Configuration Error: $e';
        _isSuccessMessage = false;
      });
    } finally {
      setState(() => _isLoadingCf = false);
    }
  }

  Future<void> _saveAppsScript() async {
    final url = _appsScriptUrlCtrl.text.trim();
    if (url.isNotEmpty) {
      await _storage.saveAppsScriptUrl(url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apps Script URL saved!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
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

              // Section 1: Google OAuth Loopback
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.cloud_upload_outlined, color: Colors.amber, size: 20),
                            SizedBox(width: 8),
                            Text('Google Drive & Sheets (BYOA)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isGoogleConnected ? const Color(0xFF065F46) : const Color(0xFF374151),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isGoogleConnected ? 'Connected' : 'Not Connected',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isGoogleConnected ? const Color(0xFF34D399) : Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1-Click OAuth 2.0 PKCE loopback server on 127.0.0.1:54321. Stores encrypted tokens for automated batch Drive uploads and Sheets write-back.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _isLoadingGoogle ? null : _connectGoogle,
                      icon: _isLoadingGoogle
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.login, size: 16),
                      label: Text(_isGoogleConnected ? 'Reconnect Google Account' : '1-Click Connect Google'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Section 2: Cloudflare Edge KV
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.electric_bolt, color: Colors.orangeAccent, size: 20),
                            SizedBox(width: 8),
                            Text('Cloudflare Edge Worker & KV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isCloudflareConfigured ? const Color(0xFF065F46) : const Color(0xFF374151),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isCloudflareConfigured ? 'Configured' : 'Required',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _isCloudflareConfigured ? const Color(0xFF34D399) : Colors.white60,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Auto-provisions CERT_VERIFIER_KV namespace and deploys edge verifier worker for permanent zero-cost QR resolution.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _cfAccountIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cloudflare Account ID',
                        isDense: true,
                        hintText: 'e.g. 1a2b3c4d5e6f...',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _cfApiTokenCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Cloudflare API Token (Workers:Edit, KV:Edit)',
                        isDense: true,
                        hintText: 'Bearer token',
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _isLoadingCf ? null : _saveCloudflare,
                      icon: _isLoadingCf
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.settings_suggest, size: 16),
                      label: const Text('Provision KV & Verify Token'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Section 3: Google Apps Script Dispatcher (Optional)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.mail_outline, color: Colors.cyanAccent, size: 20),
                        SizedBox(width: 8),
                        Text('Google Apps Script Web App (Email Dispatcher)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'URL of your deployed Apps Script web app (apps_script/code.gs) for \$0 email verification receipts.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _appsScriptUrlCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Apps Script Web App Exec URL',
                              isDense: true,
                              hintText: 'https://script.google.com/macros/s/.../exec',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveAppsScript,
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done', style: TextStyle(color: Colors.white70)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
