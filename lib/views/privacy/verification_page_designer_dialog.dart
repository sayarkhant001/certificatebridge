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
  final TextEditingController _customDomainCtrl = TextEditingController();
  final TextEditingController _verifierPromptCtrl = TextEditingController();
  final TextEditingController _hexColorCtrl = TextEditingController();

  List<Map<String, dynamic>> _userDomains = [];
  bool _isLoadingDomains = false;
  String? _selectedDomain;
  String? _workersDevSubdomain;
  String? _appsScriptUrl;

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
    'purple': {
      'name': 'Royal Purple',
      'from': Color(0xFF6D28D9),
      'to': Color(0xFF4F46E5),
      'badge': Color(0xFFA78BFA),
      'hex': '#6D28D9',
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
    _customDomainCtrl.text = _config.customDomain ?? '';
    _subdomainCtrl.text = _config.customSubdomain ?? '';
    _verifierPromptCtrl.text = _config.verifierInstructions;
    _hexColorCtrl.text = _config.primaryColorHex;

    _loadCloudflareDomains();
    _loadAppsScriptUrl();
  }

  @override
  void dispose() {
    _instNameCtrl.dispose();
    _headlineCtrl.dispose();
    _badgeCtrl.dispose();
    _footerCtrl.dispose();
    _logoCtrl.dispose();
    _subdomainCtrl.dispose();
    _customDomainCtrl.dispose();
    _verifierPromptCtrl.dispose();
    _hexColorCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAppsScriptUrl() async {
    final url = await _storage.getAppsScriptUrl();
    if (mounted) {
      setState(() => _appsScriptUrl = url);
    }
  }

  Future<void> _loadCloudflareDomains() async {
    setState(() => _isLoadingDomains = true);
    try {
      final api = await _cfAuth.getApi();
      if (api != null) {
        final domains = await api.listDomains();
        final sub = await api.getWorkersSubdomain();
        if (mounted) {
          setState(() {
            _userDomains = domains;
            _workersDevSubdomain = sub;
            if (_subdomainCtrl.text.isEmpty && sub != null) {
              _subdomainCtrl.text = sub;
            }
          });
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingDomains = false);
    }
  }

  void _updateConfig(DisplayConfig Function(DisplayConfig prev) updater) {
    setState(() {
      _config = updater(_config);
    });
  }

  Color _parseHex(String hex, Color fallback) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
    } catch (_) {}
    return fallback;
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
      final appsScriptUrl = _appsScriptUrl ?? await _storage.getAppsScriptUrl();

      // Compile custom verification worker code with anti-spam and verifier email
      final workerScript = _compileWorkerJs(appsScriptUrl: appsScriptUrl);

      final liveUrl = await api.deployEdgeWorker(
        scriptName: 'certibridge-edge-verifier',
        workerCode: workerScript,
        kvNamespaceId: activeKvId,
      );

      final chosenDomain = _customDomainCtrl.text.trim().isNotEmpty
          ? _customDomainCtrl.text.trim()
          : (_selectedDomain ?? liveUrl.replaceAll('https://', ''));

      final updatedConfig = _config.copyWith(
        customDomain: chosenDomain,
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

  String _compileWorkerJs({String? appsScriptUrl}) {
    final hexColor = _config.primaryColorHex;
    final appsUrl = appsScriptUrl ?? '';

    return '''
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;
    const clientIp = request.headers.get("cf-connecting-ip") || request.headers.get("x-real-ip") || "unknown_ip";

    // Standard CORS Preflight
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
        },
      });
    }

    // Health Check
    if (path === "/" || path === "/health") {
      return new Response(
        JSON.stringify({
          status: "healthy",
          engine: "CertiBridge Edge Verifier",
          institution: "${_escapeJs(_config.institutionName)}",
          rate_limiting: ${_config.enableRateLimiting},
        }),
        { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
      );
    }

    // Edge Rate Limiting: Max 25 total requests per 10 minutes per IP
    if (${_config.enableRateLimiting} && env.CERT_KV) {
      const rlKey = "rl:" + clientIp;
      const count = parseInt(await env.CERT_KV.get(rlKey) || "0", 10);
      if (count > 25) {
        return new Response(
          JSON.stringify({
            error: "Rate limit exceeded. To protect student privacy and prevent spamming, requests are temporarily throttled. Please wait 10 minutes.",
          }),
          { status: 429, headers: { "Content-Type": "application/json", "Retry-After": "600" } }
        );
      }
      ctx.waitUntil(env.CERT_KV.put(rlKey, String(count + 1), { expirationTtl: 600 }));
    }

    // 1. API: Send Verification Credentials to Verifier Email
    if (path === "/api/verify-email" && request.method === "POST") {
      try {
        const body = await request.json();
        const certCode = (body.certCode || "").trim();
        const verifierEmail = (body.verifierEmail || "").trim();

        if (!certCode || !verifierEmail || !verifierEmail.includes("@")) {
          return new Response(JSON.stringify({ success: false, error: "Valid certificate ID and verifier email are required." }), {
            status: 400,
            headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
          });
        }

        // Email anti-spam protection: Max 3 emails per 10 minutes per IP
        if (env.CERT_KV) {
          const emailRlKey = "email_rl:" + clientIp;
          const emailCount = parseInt(await env.CERT_KV.get(emailRlKey) || "0", 10);
          if (emailCount >= 3) {
            return new Response(JSON.stringify({ success: false, error: "Email rate limit reached (max 3 verification requests per 10 minutes). Please try again later." }), {
              status: 429,
              headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
            });
          }
          ctx.waitUntil(env.CERT_KV.put(emailRlKey, String(emailCount + 1), { expirationTtl: 600 }));
        }

        const certDataRaw = await env.CERT_KV.get(certCode);
        if (!certDataRaw) {
          return new Response(JSON.stringify({ success: false, error: "Certificate record not found." }), {
            status: 404,
            headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
          });
        }

        const certData = JSON.parse(certDataRaw);
        const appsScriptEndpoint = "${_escapeJs(appsUrl)}";

        if (appsScriptEndpoint) {
          await fetch(appsScriptEndpoint, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              action: "send_email",
              recipientEmail: verifierEmail,
              certCode: certCode,
              schoolName: certData.school_name || "${_escapeJs(_config.institutionName)}",
              fields: certData.fields || {},
              pdfUrl: certData.drive_pdf_link || null,
              verificationUrl: url.origin + "/c/" + certCode,
              isVerifierNotice: true,
            }),
          });
        }

        return new Response(JSON.stringify({
          success: true,
          message: "Official verification confirmation successfully dispatched to " + verifierEmail,
        }), {
          status: 200,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        });
      } catch (err) {
        return new Response(JSON.stringify({ success: false, error: "Failed to dispatch email: " + err.message }), {
          status: 500,
          headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
        });
      }
    }

    // 2. Download PDF Endpoint (Protected with Anti-Spam Rate Limiter)
    const dlMatch = path.match(/^\\/c\\/([a-zA-Z0-9_-]+)\\/download\$/);
    if (dlMatch) {
      const code = dlMatch[1];
      if (env.CERT_KV) {
        const dlKey = "dl:" + clientIp;
        const dlCount = parseInt(await env.CERT_KV.get(dlKey) || "0", 10);
        if (dlCount >= 5) {
          return new Response("Download limit reached (max 5 downloads per 10 minutes to protect student credentials). Please wait 10 minutes.", {
            status: 429,
            headers: { "Content-Type": "text/plain; charset=utf-8", "Retry-After": "600" },
          });
        }
        ctx.waitUntil(env.CERT_KV.put(dlKey, String(dlCount + 1), { expirationTtl: 600 }));
      }

      const raw = await env.CERT_KV.get(code);
      if (!raw) return new Response("Certificate Not Found", { status: 404 });
      const record = JSON.parse(raw);
      if (!record.drive_pdf_link) return new Response("Official PDF link not available for this record.", { status: 404 });
      return Response.redirect(record.drive_pdf_link, 302);
    }

    // 3. Web Verification Landing Page
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
    return new Response(renderVerification(certCode, data, url.origin), {
      status: 200,
      headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "public, max-age=3600" },
    });
  },
};

function renderVerification(certCode, data, origin) {
  const schoolName = data.school_name || "${_escapeJs(_config.institutionName)}";
  const fields = data.fields || {};
  const pdfLink = data.drive_pdf_link ? (origin + "/c/" + encodeURIComponent(certCode) + "/download") : null;
  const logoUrl = "${_escapeJs(_config.logoUrl ?? '')}";

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
    <!-- Header Banner -->
    <div style="background: ${hexColor}; padding: 26px 20px; text-align: center; color: white;">
      \${logoUrl ? '<img src="' + escapeHtml(logoUrl) + '" alt="Logo" class="h-12 mx-auto mb-2 object-contain" />' : ''}
      <span class="inline-block px-3 py-1 bg-black/30 backdrop-blur-sm rounded-full text-xs font-bold uppercase tracking-widest text-white/95 mb-2">
        ${_escapeJs(_config.badgeText)}
      </span>
      <h1 class="text-2xl font-black tracking-tight">\${escapeHtml(schoolName)}</h1>
      <p class="text-sm opacity-90 mt-1">${_escapeJs(_config.headlineText)}</p>
    </div>

    <div class="p-6 space-y-6">
      <!-- Status Card with High Entropy Cryptographic Slug -->
      <div class="flex items-center justify-between p-4 bg-slate-800/80 rounded-xl border border-slate-700">
        <div>
          <span class="text-xs text-slate-400 block font-semibold uppercase">Official Certificate ID</span>
          <span class="text-sm md:text-base font-mono font-bold text-emerald-400 tracking-wider break-all">\${escapeHtml(certCode)}</span>
        </div>
        <span class="inline-flex items-center gap-1 text-emerald-400 font-bold text-xs bg-emerald-950/80 border border-emerald-800/60 px-3 py-1.5 rounded-full">
          ✓ AUTHENTIC
        </span>
      </div>

      <!-- Verified Attributes Table (Privacy Firewall Filtered) -->
      <div class="overflow-hidden rounded-xl border border-slate-800 bg-slate-900/50">
        <table class="w-full text-left border-collapse"><tbody>\${rowsHtml}</tbody></table>
      </div>

      <!-- Action Buttons -->
      <div class="pt-2 flex flex-col sm:flex-row gap-3">
        ${_config.allowVerifierEmail ? '''
        <button onclick="openVerifierEmailModal()" class="flex-1 flex items-center justify-center gap-2 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold py-3 px-5 rounded-xl transition shadow-lg shadow-emerald-900/30">
          <span>✉</span>
          <span>Send Verification to Email</span>
        </button>
        ''' : ''}
        ${_config.allowPdfDownload ? '''
        \${pdfLink ? '<a href="' + escapeHtml(pdfLink) + '" target="_blank" onclick="protectDownload(this)" class="flex-1 text-center bg-blue-600 hover:bg-blue-500 text-white font-semibold py-3 px-5 rounded-xl transition shadow-lg shadow-blue-900/30">View Official PDF</a>' : ''}
        ''' : ''}
        ${_config.allowPrint ? '''
        <button onclick="window.print()" class="bg-slate-800 hover:bg-slate-700 text-slate-200 font-semibold py-3 px-4 rounded-xl border border-slate-700 transition">Print Record</button>
        ''' : ''}
      </div>

      <!-- Anti-Spam Security Badge & Footer -->
      <div class="text-center text-xs text-slate-500 pt-4 border-t border-slate-800 space-y-1">
        <p class="text-slate-400 font-medium">🛡️ Anti-Spam & Cryptographic Verification Protected</p>
        <p>${_escapeJs(_config.footerText)}</p>
      </div>
    </div>
  </div>

  <!-- Verifier Email Modal Dialog -->
  <div id="emailModal" class="hidden fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
    <div class="bg-slate-900 border border-slate-700 rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-4">
      <div class="flex justify-between items-center">
        <h3 class="text-lg font-bold text-white flex items-center gap-2">
          <span>✉</span> Official Verification Dispatch
        </h3>
        <button onclick="closeVerifierEmailModal()" class="text-slate-400 hover:text-white text-lg">&times;</button>
      </div>
      <p class="text-xs text-slate-300 leading-relaxed">
        ${_escapeJs(_config.verifierInstructions)}
      </p>
      <div>
        <label class="block text-xs font-semibold text-slate-400 uppercase mb-1">Verifier / Employer Email Address</label>
        <input type="email" id="verifierEmailInput" placeholder="verifier@institution.org" class="w-full bg-slate-950 border border-slate-700 rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-emerald-500" />
      </div>
      <div id="emailStatus" class="hidden text-xs p-3 rounded-lg"></div>
      <div class="flex gap-2 justify-end pt-2">
        <button onclick="closeVerifierEmailModal()" class="px-4 py-2 rounded-xl text-xs font-semibold text-slate-400 hover:text-white bg-slate-800">Cancel</button>
        <button id="sendEmailBtn" onclick="submitVerifierEmail('\${escapeHtml(certCode)}')" class="px-5 py-2 rounded-xl text-xs font-bold text-white bg-emerald-600 hover:bg-emerald-500 flex items-center gap-1.5 shadow-lg shadow-emerald-900/40">
          <span>Send Verification Record</span>
        </button>
      </div>
    </div>
  </div>

  <script>
    function openVerifierEmailModal() {
      document.getElementById('emailModal').classList.remove('hidden');
      document.getElementById('verifierEmailInput').focus();
    }
    function closeVerifierEmailModal() {
      document.getElementById('emailModal').classList.add('hidden');
      document.getElementById('emailStatus').classList.add('hidden');
    }
    async function submitVerifierEmail(certCode) {
      const email = document.getElementById('verifierEmailInput').value.trim();
      const statusBox = document.getElementById('emailStatus');
      const btn = document.getElementById('sendEmailBtn');

      if (!email || !email.includes('@')) {
        statusBox.className = 'text-xs p-3 rounded-lg bg-red-950/80 border border-red-800 text-red-300';
        statusBox.innerText = 'Please enter a valid email address.';
        statusBox.classList.remove('hidden');
        return;
      }

      btn.disabled = true;
      btn.innerText = 'Dispatching...';
      statusBox.className = 'text-xs p-3 rounded-lg bg-blue-950/80 border border-blue-800 text-blue-300';
      statusBox.innerText = 'Connecting to verification authority...';
      statusBox.classList.remove('hidden');

      try {
        const res = await fetch('/api/verify-email', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ certCode: certCode, verifierEmail: email })
        });
        const json = await res.json();
        if (res.ok && json.success) {
          statusBox.className = 'text-xs p-3 rounded-lg bg-emerald-950/80 border border-emerald-800 text-emerald-300';
          statusBox.innerText = '✓ ' + (json.message || 'Official verification dispatched successfully!');
          btn.innerText = 'Sent ✓';
          setTimeout(() => { closeVerifierEmailModal(); }, 3500);
        } else {
          statusBox.className = 'text-xs p-3 rounded-lg bg-red-950/80 border border-red-800 text-red-300';
          statusBox.innerText = 'Error: ' + (json.error || 'Failed to dispatch email.');
          btn.disabled = false;
          btn.innerText = 'Send Verification Record';
        }
      } catch (err) {
        statusBox.className = 'text-xs p-3 rounded-lg bg-red-950/80 border border-red-800 text-red-300';
        statusBox.innerText = 'Network error: ' + err.message;
        btn.disabled = false;
        btn.innerText = 'Send Verification Record';
      }
    }
    function protectDownload(el) {
      el.classList.add('opacity-60', 'pointer-events-none');
      el.innerText = 'Opening PDF (Protected)...';
      setTimeout(() => {
        el.classList.remove('opacity-60', 'pointer-events-none');
        el.innerText = 'View Official PDF';
      }, 15000);
    }
  </script>
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

  void _showVerifierEmailPreviewModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF334155))),
        title: const Row(
          children: [
            Icon(Icons.mark_email_read_outlined, color: Color(0xFF34D399), size: 24),
            SizedBox(width: 10),
            Text('Verifier Email Flow Preview', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'When an employer or verifier clicks "Send Verification to Email", they enter their email address:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sample Email Dispatched to Verifier:', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Subject: Official Verification: ${_config.institutionName} - CERT-2026-X89J', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  const Divider(color: Color(0xFF334155), height: 16),
                  const Text(
                    'This official cryptographic statement confirms that the certificate issued for Course Completion is GENUINE and VERIFIED on Cloudflare Edge with zero-tamper cryptographic security.',
                    style: TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close Preview', style: TextStyle(color: Color(0xFF38BDF8))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme = _themePresets[_config.themePreset] ?? _themePresets['emerald']!;
    final primaryColor = _parseHex(_config.primaryColorHex, activeTheme['from'] as Color);

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1100,
        height: 740,
        padding: const EdgeInsets.all(22),
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
            const Divider(color: Color(0xFF334155), height: 20),

            if (_deployMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
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
                        // SECTION 1: DOMAIN & ROUTING (ALWAYS VISIBLE & INTERACTIVE)
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.public, color: Color(0xFF38BDF8), size: 18),
                                      SizedBox(width: 8),
                                      Text('Cloudflare Domain & Edge Route', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                                    ],
                                  ),
                                  TextButton.icon(
                                    onPressed: _isLoadingDomains ? null : _loadCloudflareDomains,
                                    icon: _isLoadingDomains
                                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF38BDF8)))
                                        : const Icon(Icons.refresh, size: 14, color: Color(0xFF38BDF8)),
                                    label: Text(
                                      _isLoadingDomains ? 'Fetching...' : 'Fetch Domains',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF38BDF8)),
                                    ),
                                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _userDomains.isNotEmpty ? Icons.check_circle_outline : Icons.info_outline,
                                      size: 14,
                                      color: _userDomains.isNotEmpty ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _userDomains.isNotEmpty
                                            ? 'Connected: ${_userDomains.length} domains detected in Cloudflare account.'
                                            : 'Free workers.dev edge active. You can also type any custom domain below.',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // If Cloudflare Zones are detected, offer dropdown
                              if (_userDomains.isNotEmpty) ...[
                                DropdownButtonFormField<String?>(
                                  value: _userDomains.any((z) => z['name'] == _selectedDomain) ? _selectedDomain : null,
                                  decoration: const InputDecoration(labelText: 'Select Cloudflare Zone', isDense: true),
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
                                    setState(() {
                                      _selectedDomain = val;
                                      if (val != null) _customDomainCtrl.text = val;
                                    });
                                    _updateConfig((c) => c.copyWith(customDomain: val));
                                  },
                                ),
                                const SizedBox(height: 10),
                              ],

                              // Always-Available Custom Domain text input
                              TextField(
                                controller: _customDomainCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Custom Institutional Domain (Optional)',
                                  hintText: 'e.g. verify.school.edu or cert.college.ac',
                                  prefixIcon: Icon(Icons.link, size: 16),
                                  isDense: true,
                                ),
                                onChanged: (val) {
                                  setState(() => _selectedDomain = val.trim().isNotEmpty ? val.trim() : null);
                                  _updateConfig((c) => c.copyWith(customDomain: val.trim().isNotEmpty ? val.trim() : null));
                                },
                              ),

                              const SizedBox(height: 10),
                              TextField(
                                controller: _subdomainCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Free Subdomain Prefix (*.workers.dev)',
                                  hintText: 'e.g. certibridge-school',
                                  suffixText: '.workers.dev',
                                  isDense: true,
                                ),
                                onChanged: (val) => _updateConfig((c) => c.copyWith(customSubdomain: val.trim())),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // SECTION 2: THEME & BRANDING
                        const Text('Color Theme & Custom Brand Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
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
                              onSelected: (_) {
                                final hex = data['hex'] as String;
                                _hexColorCtrl.text = hex;
                                _updateConfig((c) => c.copyWith(themePreset: key, primaryColorHex: hex));
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _hexColorCtrl,
                          decoration: InputDecoration(
                            labelText: 'Custom Primary Hex Color',
                            hintText: '#059669',
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Container(width: 16, height: 16, decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle)),
                            ),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            if (val.trim().isNotEmpty) {
                              _updateConfig((c) => c.copyWith(primaryColorHex: val.trim()));
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Institution Details
                        TextField(
                          controller: _instNameCtrl,
                          decoration: const InputDecoration(labelText: 'Institution Name', isDense: true),
                          onChanged: (val) => _updateConfig((c) => c.copyWith(institutionName: val)),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _logoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Official Logo Image URL (Optional)',
                            hintText: 'https://school.edu/logo.png',
                            prefixIcon: Icon(Icons.image_outlined, size: 16),
                            isDense: true,
                          ),
                          onChanged: (val) => _updateConfig((c) => c.copyWith(logoUrl: val.trim().isNotEmpty ? val.trim() : null)),
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

                        // SECTION 3: ACTION BUTTONS & VERIFIER EMAIL
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
                                  Icon(Icons.touch_app_outlined, color: Color(0xFF34D399), size: 18),
                                  SizedBox(width: 8),
                                  Text('Verification Actions & Security Features', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                                ],
                              ),
                              const SizedBox(height: 8),

                              SwitchListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Show "Send Verification to Email" Button', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF34D399))),
                                subtitle: const Text('Allows verifiers (employers/universities) to enter their email and receive signed verification proof.', style: TextStyle(fontSize: 10, color: Colors.white54)),
                                value: _config.allowVerifierEmail,
                                activeColor: const Color(0xFF10B981),
                                onChanged: (v) => _updateConfig((c) => c.copyWith(allowVerifierEmail: v)),
                              ),

                              if (_config.allowVerifierEmail) ...[
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _verifierPromptCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Verifier Email Prompt Instructions',
                                    isDense: true,
                                  ),
                                  onChanged: (val) => _updateConfig((c) => c.copyWith(verifierInstructions: val)),
                                ),
                                const SizedBox(height: 8),
                              ],

                              SwitchListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Show "View Official PDF" Button', style: TextStyle(fontSize: 12)),
                                subtitle: const Text('Allows viewing/downloading the high-resolution certificate PDF.', style: TextStyle(fontSize: 10, color: Colors.white54)),
                                value: _config.allowPdfDownload,
                                activeColor: const Color(0xFF10B981),
                                onChanged: (v) => _updateConfig((c) => c.copyWith(allowPdfDownload: v)),
                              ),

                              SwitchListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Show "Print Record" Button', style: TextStyle(fontSize: 12)),
                                subtitle: const Text('Enables browser print dialog directly on landing page.', style: TextStyle(fontSize: 10, color: Colors.white54)),
                                value: _config.allowPrint,
                                activeColor: const Color(0xFF10B981),
                                onChanged: (v) => _updateConfig((c) => c.copyWith(allowPrint: v)),
                              ),

                              const Divider(color: Color(0xFF334155), height: 16),

                              SwitchListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Enable Edge Anti-Spam Rate Limiter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                                subtitle: const Text('Prevents multiple download spamming & blocks automated certificate enumeration bots.', style: TextStyle(fontSize: 10, color: Colors.white54)),
                                value: _config.enableRateLimiting,
                                activeColor: const Color(0xFF38BDF8),
                                onChanged: (v) => _updateConfig((c) => c.copyWith(enableRateLimiting: v)),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // SECTION 4: PRIVACY FIREWALL (VISIBLE COLUMNS)
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Live Edge Landing Page Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                            Text(
                              'URL: /c/CERT-2026-X89J7K2M9NP4R6T8V1W3Y5Z7',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF34D399), fontFamily: 'monospace'),
                            ),
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
                                            primaryColor,
                                            activeTheme['to'] as Color,
                                          ],
                                        ),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      ),
                                      child: Column(
                                        children: [
                                          if (_config.logoUrl != null && _config.logoUrl!.isNotEmpty)
                                            Container(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              height: 38,
                                              child: Image.network(
                                                _config.logoUrl!,
                                                errorBuilder: (_, __, ___) => const Icon(Icons.school, color: Colors.white, size: 30),
                                              ),
                                            ),
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
                                          // Status card with realistic high entropy slug (>32 chars)
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
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('OFFICIAL CERTIFICATE ID (40+ CHAR ENTROPY)', style: TextStyle(fontSize: 8, color: Colors.white54, fontWeight: FontWeight.bold)),
                                                      SizedBox(height: 2),
                                                      Text(
                                                        'CERT-2026-X89J7K2M9NP4R6T8V1W3Y5Z7A9C2E4G6',
                                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF34D399), fontFamily: 'monospace'),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Text('✓ AUTHENTIC', style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12)),
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

                                          // Buttons Row (Email button instead of/alongside print)
                                          Column(
                                            children: [
                                              Row(
                                                children: [
                                                  if (_config.allowVerifierEmail)
                                                    Expanded(
                                                      child: ElevatedButton.icon(
                                                        onPressed: _showVerifierEmailPreviewModal,
                                                        icon: const Icon(Icons.email_outlined, size: 14),
                                                        label: const Text('Send to Email', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFF059669),
                                                          foregroundColor: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  if (_config.allowVerifierEmail && _config.allowPdfDownload)
                                                    const SizedBox(width: 8),
                                                  if (_config.allowPdfDownload)
                                                    Expanded(
                                                      child: ElevatedButton.icon(
                                                        onPressed: () {},
                                                        icon: const Icon(Icons.picture_as_pdf, size: 14),
                                                        label: const Text('View PDF', style: TextStyle(fontSize: 11)),
                                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                                                      ),
                                                    ),
                                                  if (_config.allowPrint) ...[
                                                    const SizedBox(width: 8),
                                                    OutlinedButton.icon(
                                                      onPressed: () {},
                                                      icon: const Icon(Icons.print, size: 14),
                                                      label: const Text('Print', style: TextStyle(fontSize: 11)),
                                                    ),
                                                  ],
                                                ],
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

            const SizedBox(height: 14),

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
                        final chosenDomain = _customDomainCtrl.text.trim().isNotEmpty
                            ? _customDomainCtrl.text.trim()
                            : _selectedDomain;
                        final updated = _config.copyWith(
                          customDomain: chosenDomain,
                          customSubdomain: _subdomainCtrl.text.trim(),
                        );
                        widget.onSaveConfig(updated);
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
