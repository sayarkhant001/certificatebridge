import 'package:flutter/material.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../models/display_config.dart';
import '../../services/auth/cloudflare_auth_service.dart';
import '../../services/cloudflare/cloudflare_api.dart';

class VerificationPageDesignerDialog extends StatefulWidget {
  final List<String> availableColumns;
  final DisplayConfig initialConfig;
  final ValueChanged<DisplayConfig> onSaveConfig;

  const VerificationPageDesignerDialog({
    Key? key,
    required this.availableColumns,
    required this.initialConfig,
    required this.onSaveConfig,
  }) : super(key: key);

  @override
  State<VerificationPageDesignerDialog> createState() => _VerificationPageDesignerDialogState();
}

class _VerificationPageDesignerDialogState extends State<VerificationPageDesignerDialog> {
  final CloudflareAuthService _cfAuth = CloudflareAuthService();
  final SecureStorageService _storage = SecureStorageService();

  late DisplayConfig _config;

  final TextEditingController _instNameCtrl = TextEditingController();
  final TextEditingController _headlineCtrl = TextEditingController();
  final TextEditingController _badgeCtrl = TextEditingController();
  final TextEditingController _footerCtrl = TextEditingController();
  final TextEditingController _logoCtrl = TextEditingController();
  final TextEditingController _subdomainCtrl = TextEditingController();

  List<Map<String, dynamic>> _userDomains = [];
  bool _isLoadingDomains = false;
  String? _selectedDomain;
  String? _workersDevSubdomain;

  bool _isDeploying = false;
  String? _deployMessage;
  bool _isDeploySuccess = false;

  final Map<String, Map<String, dynamic>> _themePresets = {
    'emerald': {
      'name': 'Emerald Mint',
      'from': Color(0xFF059669),
      'to': Color(0xFF0D9488),
      'badge': Color(0xFF34D399),
      'hex': '#059669',
    },
    'sapphire': {
      'name': 'Sapphire Blue',
      'from': Color(0xFF1D4ED8),
      'to': Color(0xFF0284C7),
      'badge': Color(0xFF60A5FA),
      'hex': '#1D4ED8',
    },
    'gold': {
      'name': 'Imperial Gold',
      'from': Color(0xFFB45309),
      'to': Color(0xFF78350F),
      'badge': Color(0xFFFBBF24),
      'hex': '#B45309',
    },
    'crimson': {
      'name': 'Ruby Crimson',
      'from': Color(0xFFB91C1C),
      'to': Color(0xFF881337),
      'badge': Color(0xFFF87171),
      'hex': '#B91C1C',
    },
    'obsidian': {
      'name': 'Obsidian Sleek',
      'from': Color(0xFF334155),
      'to': Color(0xFF0F172A),
      'badge': Color(0xFF94A3B8),
      'hex': '#334155',
    },
  };

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    _instNameCtrl.text = _config.institutionName;
    _headlineCtrl.text = _config.headlineText;
    _badgeCtrl.text = _config.badgeText;
    _footerCtrl.text = _config.footerText;
    _logoCtrl.text = _config.logoUrl ?? '';
    _selectedDomain = _config.customDomain;
    _subdomainCtrl.text = _config.customSubdomain ?? '';

    _loadCloudflareDomains();
  }

  @override
  void dispose() {
    _instNameCtrl.dispose();
    _headlineCtrl.dispose();
    _badgeCtrl.dispose();
    _footerCtrl.dispose();
    _logoCtrl.dispose();
    _subdomainCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCloudflareDomains() async {
    setState(() => _isLoadingDomains = true);
    final api = await _cfAuth.getApi();
    if (api != null) {
      try {
        final domains = await api.listDomains();
        final sub = await api.getWorkersSubdomain();
        setState(() {
          _userDomains = domains;
          _workersDevSubdomain = sub;
          if (_subdomainCtrl.text.isEmpty && sub != null) {
            _subdomainCtrl.text = sub;
          }
        });
      } catch (_) {}
    }
    setState(() => _isLoadingDomains = false);
  }

  void _updateConfig(DisplayConfig Function(DisplayConfig prev) updater) {
    setState(() {
      _config = updater(_config);
    });
  }

  Future<void> _deployToCloudflare() async {
    setState(() {
      _isDeploying = true;
      _deployMessage = null;
    });

    try {
      final creds = await _storage.getCloudflareCredentials();
      final accountId = creds['accountId'];
      final apiToken = creds['apiToken'];
      final kvId = creds['kvNamespaceId'];

      if (accountId == null || apiToken == null) {
        throw Exception('Cloudflare account is not connected. Please log in via Setup Wizard.');
      }

      final api = CloudflareApi(accountId: accountId, apiToken: apiToken);
      final activeKvId = kvId ?? await api.findOrCreateKvNamespace();

      // Compile custom verification worker code
      final workerScript = _compileWorkerJs();

      final liveUrl = await api.deployEdgeWorker(
        scriptName: 'certibridge-edge-verifier',
        workerCode: workerScript,
        kvNamespaceId: activeKvId,
      );

      final updatedConfig = _config.copyWith(
        customDomain: _selectedDomain ?? liveUrl.replaceAll('https://', ''),
        customSubdomain: _subdomainCtrl.text.trim(),
      );

      widget.onSaveConfig(updatedConfig);

      setState(() {
        _config = updatedConfig;
        _isDeploySuccess = true;
        _deployMessage = 'Successfully deployed custom verification edge worker! Live at: $liveUrl';
      });
    } catch (e) {
      setState(() {
        _isDeploySuccess = false;
        _deployMessage = 'Deployment failed: $e';
      });
    } finally {
      setState(() => _isDeploying = false);
    }
  }

  String _compileWorkerJs() {
    final theme = _themePresets[_config.themePreset] ?? _themePresets['emerald']!;
    final hexColor = theme['hex'];

    return '''
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;

    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
        },
      });
    }

    if (path === "/" || path === "/health") {
      return new Response(
        JSON.stringify({
          status: "healthy",
          engine: "CertiBridge Edge Verifier",
          institution: "${_escapeJs(_config.institutionName)}",
        }),
        { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
      );
    }

    const match = path.match(/^\\/c\\/([a-zA-Z0-9_-]+)/);
    if (!match) return new Response("Not Found", { status: 404 });
    const certCode = match[1];

    if (!env.CERT_KV) {
      return new Response("CERT_KV namespace not bound.", { status: 500 });
    }

    const certDataRaw = await env.CERT_KV.get(certCode);
    if (!certDataRaw) {
      return new Response(renderNotFound(certCode), {
        status: 404,
        headers: { "Content-Type": "text/html; charset=utf-8" },
      });
    }

    const data = JSON.parse(certDataRaw);
    return new Response(renderVerification(certCode, data), {
      status: 200,
      headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "public, max-age=3600" },
    });
  },
};

function renderVerification(certCode, data) {
  const schoolName = data.school_name || "${_escapeJs(_config.institutionName)}";
  const fields = data.fields || {};
  const pdfLink = data.drive_pdf_link || null;

  let rowsHtml = "";
  for (const [k, v] of Object.entries(fields)) {
    rowsHtml += '<tr class="border-b border-slate-700/60"><td class="py-3 px-4 text-xs font-semibold uppercase tracking-wider text-slate-400">' +
      escapeHtml(k.replace(/_/g, ' ')) +
      '</td><td class="py-3 px-4 text-sm font-medium text-slate-100">' +
      escapeHtml(String(v)) +
      '</td></tr>';
  }

  return `<!DOCTYPE html>
<html lang="en" class="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Verified Certificate: \${escapeHtml(certCode)} | \${escapeHtml(schoolName)}</title>
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-slate-950 text-slate-100 min-h-screen flex flex-col items-center justify-center p-4">
  <div class="max-w-xl w-full bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl overflow-hidden">
    <div style="background: ${hexColor}; padding: 24px; text-align: center; color: white;">
      <span class="inline-block px-3 py-1 bg-black/30 rounded-full text-xs font-bold uppercase tracking-widest text-white/90 mb-2">
        ${_escapeJs(_config.badgeText)}
      </span>
      <h1 class="text-2xl font-black tracking-tight">\${escapeHtml(schoolName)}</h1>
      <p class="text-sm opacity-90 mt-1">${_escapeJs(_config.headlineText)}</p>
    </div>
    <div class="p-6 space-y-6">
      <div class="flex items-center justify-between p-4 bg-slate-800 rounded-xl border border-slate-700">
        <div>
          <span class="text-xs text-slate-400 block font-semibold uppercase">Certificate ID</span>
          <span class="text-lg font-mono font-bold text-emerald-400 tracking-wider">\${escapeHtml(certCode)}</span>
        </div>
        <span class="text-emerald-400 font-bold text-sm">✓ AUTHENTIC</span>
      </div>
      <div class="overflow-hidden rounded-xl border border-slate-800 bg-slate-900/50">
        <table class="w-full text-left border-collapse"><tbody>\${rowsHtml}</tbody></table>
      </div>
      <div class="pt-2 flex gap-3">
        \${pdfLink ? '<a href="' + escapeHtml(pdfLink) + '" target="_blank" class="flex-1 text-center bg-blue-600 hover:bg-blue-500 text-white font-semibold py-3 px-5 rounded-xl">View Official PDF</a>' : ''}
        ${_config.allowPrint ? '<button onclick="window.print()" class="bg-slate-800 hover:bg-slate-700 text-slate-200 font-semibold py-3 px-5 rounded-xl border border-slate-700">Print Record</button>' : ''}
      </div>
      <div class="text-center text-xs text-slate-500 pt-4 border-t border-slate-800">
        ${_escapeJs(_config.footerText)}
      </div>
    </div>
  </div>
</body>
</html>`;
}

function renderNotFound(certCode) {
  return `<!DOCTYPE html><html class="dark"><body class="bg-slate-950 text-white flex items-center justify-center min-h-screen p-4"><div class="bg-slate-900 border border-red-900 p-8 rounded-2xl max-w-md text-center"><h1 class="text-xl font-bold mb-2">Certificate Not Found</h1><p class="text-slate-400 text-sm mb-4">Record for \${escapeHtml(certCode)} could not be verified.</p><a href="/" class="text-blue-400 text-sm">Return Home</a></div></body></html>`;
}

function escapeHtml(str) {
  return String(str).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
''';
  }

  String _escapeJs(String val) {
    return val.replaceAll('"', '\\"').replaceAll('\n', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = _themePresets[_config.themePreset] ?? _themePresets['emerald']!;

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1040,
        height: 720,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.palette_outlined, color: Color(0xFF38BDF8), size: 26),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verification Page Designer & Cloudflare Edge Routing',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          'Customize the recipient verification landing page & deploy to your Cloudflare domain with \$0 cost',
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
            const Divider(color: Color(0xFF334155), height: 24),

            if (_deployMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _isDeploySuccess
                      ? const Color(0xFF065F46).withOpacity(0.3)
                      : const Color(0xFF991B1B).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isDeploySuccess ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isDeploySuccess ? Icons.check_circle : Icons.error,
                      color: _isDeploySuccess ? const Color(0xFF34D399) : const Color(0xFFF87171),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _deployMessage!,
                        style: TextStyle(
                          color: _isDeploySuccess ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Main 2-Column Workspace: Left Controls vs Right Live Preview
            Expanded(
              child: Row(
                children: [
                  // Left Settings Column
                  Expanded(
                    flex: 5,
                    child: ListView(
                      padding: const EdgeInsets.only(right: 18),
                      children: [
                        // SECTION 1: DOMAIN & ROUTING
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.public, color: Color(0xFF38BDF8), size: 18),
                                  SizedBox(width: 8),
                                  Text('Cloudflare Domain & Edge Route', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Select a custom domain from your Cloudflare account, or use free *.workers.dev subdomain.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 10),

                              if (_isLoadingDomains)
                                const LinearProgressIndicator()
                              else if (_userDomains.isNotEmpty)
                                DropdownButtonFormField<String?>(
                                  value: _selectedDomain,
                                  decoration: const InputDecoration(labelText: 'Custom Domain (Cloudflare Zones)', isDense: true),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Free Workers Edge Subdomain (*.workers.dev)'),
                                    ),
                                    ..._userDomains.map((z) {
                                      final name = z['name'] as String;
                                      return DropdownMenuItem<String?>(
                                        value: name,
                                        child: Text(name),
                                      );
                                    }).toList(),
                                  ],
                                  onChanged: (val) {
                                    setState(() => _selectedDomain = val);
                                    _updateConfig((c) => c.copyWith(customDomain: val));
                                  },
                                ),

                              const SizedBox(height: 10),
                              TextField(
                                controller: _subdomainCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Free Subdomain Prefix',
                                  hintText: 'e.g. yangon-institute',
                                  suffixText: '.workers.dev',
                                  isDense: true,
                                ),
                                onChanged: (val) => _updateConfig((c) => c.copyWith(customSubdomain: val)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // SECTION 2: THEME & BRANDING
                        const Text('Color Theme & Header Style', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _themePresets.entries.map((entry) {
                            final key = entry.key;
                            final data = entry.value;
                            final isSelected = _config.themePreset == key;
                            return ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(width: 12, height: 12, decoration: BoxDecoration(color: data['from'] as Color, shape: BoxShape.circle)),
                                  const SizedBox(width: 6),
                                  Text(data['name'] as String, style: const TextStyle(fontSize: 11)),
                                ],
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF1E3A8A),
                              onSelected: (_) => _updateConfig((c) => c.copyWith(themePreset: key, primaryColorHex: data['hex'] as String)),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _instNameCtrl,
                          decoration: const InputDecoration(labelText: 'Institution Name', isDense: true),
                          onChanged: (val) => _updateConfig((c) => c.copyWith(institutionName: val)),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _badgeCtrl,
                          decoration: const InputDecoration(labelText: 'Badge Title', isDense: true),
                          onChanged: (val) => _updateConfig((c) => c.copyWith(badgeText: val)),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _headlineCtrl,
                          decoration: const InputDecoration(labelText: 'Subtitle / Headline', isDense: true),
                          onChanged: (val) => _updateConfig((c) => c.copyWith(headlineText: val)),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _footerCtrl,
                          decoration: const InputDecoration(labelText: 'Footer Disclaimer', isDense: true),
                          onChanged: (val) => _updateConfig((c) => c.copyWith(footerText: val)),
                        ),

                        const SizedBox(height: 16),

                        // SECTION 3: PRIVACY & VISIBLE ATTRIBUTES
                        const Text('Visible Public Columns (Privacy Firewall)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                        const SizedBox(height: 4),
                        const Text('Only checked attributes enter the edge KV. All other columns are kept 100% private.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        const SizedBox(height: 8),

                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.availableColumns.map((col) {
                            final isPublic = _config.publicColumns.contains(col);
                            return FilterChip(
                              label: Text(col, style: TextStyle(fontSize: 11, color: isPublic ? Colors.white : Colors.white60)),
                              selected: isPublic,
                              selectedColor: const Color(0xFF059669),
                              checkmarkColor: Colors.white,
                              onSelected: (selected) {
                                final updated = List<String>.from(_config.publicColumns);
                                if (selected) {
                                  updated.add(col);
                                } else {
                                  updated.remove(col);
                                }
                                _updateConfig((c) => c.copyWith(publicColumns: updated));
                              },
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 12),
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Show "View Official PDF" Button', style: TextStyle(fontSize: 12)),
                          value: _config.allowPdfDownload,
                          activeColor: const Color(0xFF10B981),
                          onChanged: (v) => _updateConfig((c) => c.copyWith(allowPdfDownload: v)),
                        ),
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Show "Print Record" Button', style: TextStyle(fontSize: 12)),
                          value: _config.allowPrint,
                          activeColor: const Color(0xFF10B981),
                          onChanged: (v) => _updateConfig((c) => c.copyWith(allowPrint: v)),
                        ),
                      ],
                    ),
                  ),

                  const VerticalDivider(color: Color(0xFF334155)),

                  // Right Live Preview Column
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Live Edge Landing Page Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                            Text('Previewing /c/CERT-2026-X89J', style: TextStyle(fontSize: 11, color: Color(0xFF34D399), fontFamily: 'monospace')),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF020617),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF1E293B)),
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFF1E293B)),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 6)),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Header banner
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            activeTheme['from'] as Color,
                                            activeTheme['to'] as Color,
                                          ],
                                        ),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.black26,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              _config.badgeText,
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _config.institutionName,
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _config.headlineText,
                                            style: const TextStyle(fontSize: 11, color: Colors.white70),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Content
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          // Status card
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E293B),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0xFF334155)),
                                            ),
                                            child: const Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('CERTIFICATE ID', style: TextStyle(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.bold)),
                                                    Text('CERT-2026-X89J', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF34D399), fontFamily: 'monospace')),
                                                  ],
                                                ),
                                                Text('✓ AUTHENTIC', style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 13)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 14),

                                          // Table
                                          Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0B0F19),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFF1E293B)),
                                            ),
                                            child: Column(
                                              children: _config.publicColumns.map((col) {
                                                return Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(col.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)),
                                                      Text('Sample $col', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                          const SizedBox(height: 14),

                                          // Buttons
                                          Row(
                                            children: [
                                              if (_config.allowPdfDownload)
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () {},
                                                    icon: const Icon(Icons.picture_as_pdf, size: 14),
                                                    label: const Text('View Official PDF', style: TextStyle(fontSize: 11)),
                                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                                                  ),
                                                ),
                                              if (_config.allowPdfDownload && _config.allowPrint)
                                                const SizedBox(width: 8),
                                              if (_config.allowPrint)
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    onPressed: () {},
                                                    icon: const Icon(Icons.print, size: 14),
                                                    label: const Text('Print Record', style: TextStyle(fontSize: 11)),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            _config.footerText,
                                            style: const TextStyle(fontSize: 9, color: Colors.white38),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Bottom Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Cancel'),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        widget.onSaveConfig(_config);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.save, size: 16),
                      label: const Text('Save Design Settings'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _isDeploying ? null : _deployToCloudflare,
                      icon: _isDeploying
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cloud_upload, size: 16),
                      label: const Text('⚡ Publish to Cloudflare Edge (\$0 Cost)', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
