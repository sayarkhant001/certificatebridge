import 'dart:convert';
import 'package:http/http.dart' as http;

class CloudflareApi {
  final String accountId;
  final String apiToken;

  static const String _baseUrl = 'https://api.cloudflare.com/client/v4';

  CloudflareApi({required this.accountId, required this.apiToken});

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiToken',
        'Content-Type': 'application/json',
      };

  /// Verify API token validity (supports both User API Tokens and OAuth Bearer tokens)
  Future<bool> verifyToken() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user/tokens/verify'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return true;
      }
    } catch (_) {}

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/accounts/$accountId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return true;
      }
    } catch (_) {}

    return false;
  }

  /// List all KV namespaces in the account
  Future<List<Map<String, dynamic>>> listKvNamespaces() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/accounts/$accountId/storage/kv/namespaces'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final list = data['result'] as List<dynamic>? ?? [];
      return list.map((e) => e as Map<String, dynamic>).toList();
    }
    throw Exception('Failed to list KV namespaces: ${response.statusCode} ${response.body}');
  }

  /// Find or create the KV namespace (default: CERT_VERIFIER_KV)
  Future<String> findOrCreateKvNamespace({String title = 'CERT_VERIFIER_KV'}) async {
    final namespaces = await listKvNamespaces();
    for (final ns in namespaces) {
      if (ns['title'] == title) {
        return ns['id'] as String;
      }
    }

    // Create if not found
    final response = await http.post(
      Uri.parse('$_baseUrl/accounts/$accountId/storage/kv/namespaces'),
      headers: _headers,
      body: jsonEncode({'title': title}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['result']['id'] as String;
    }
    throw Exception('Failed to create KV namespace: ${response.statusCode} ${response.body}');
  }

  /// Bulk write key-value pairs into KV (up to 10,000 per request)
  Future<bool> bulkWriteKv({
    required String namespaceId,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/accounts/$accountId/storage/kv/namespaces/$namespaceId/bulk'),
      headers: _headers,
      body: jsonEncode(items),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['success'] == true;
    }
    throw Exception('Failed bulk write to KV: ${response.statusCode} ${response.body}');
  }

  /// Upload/Deploy Edge Worker script with KV binding
  Future<String> deployEdgeWorker({
    required String scriptName,
    required String workerCode,
    required String kvNamespaceId,
    String kvBindingName = 'CERT_KV',
  }) async {
    final uri = Uri.parse('$_baseUrl/accounts/$accountId/workers/scripts/$scriptName');

    // Cloudflare Workers multi-part upload with bindings metadata
    final request = http.MultipartRequest('PUT', uri);
    request.headers['Authorization'] = 'Bearer $apiToken';

    final metadata = {
      'main_module': 'worker.js',
      'bindings': [
        {
          'type': 'kv_namespace',
          'name': kvBindingName,
          'namespace_id': kvNamespaceId,
        }
      ]
    };

    request.fields['metadata'] = jsonEncode(metadata);
    request.files.add(
      http.MultipartFile.fromString(
        'worker.js',
        workerCode,
        filename: 'worker.js',
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      // Subdomain worker URL pattern
      return 'https://$scriptName.$accountId.workers.dev';
    } else {
      throw Exception('Failed to deploy worker: ${response.statusCode} ${response.body}');
    }
  }

  /// Fetch all active domains/zones in the user's Cloudflare account
  Future<List<Map<String, dynamic>>> listDomains() async {
    final domainMap = <String, Map<String, dynamic>>{};

    // 1. Try listing Cloudflare DNS Zones (Global & Account Scoped)
    try {
      var response = await http.get(
        Uri.parse('$_baseUrl/zones?per_page=50'),
        headers: _headers,
      );
      if (response.statusCode != 200 && accountId.isNotEmpty) {
        response = await http.get(
          Uri.parse('$_baseUrl/zones?account.id=$accountId&per_page=50'),
          headers: _headers,
        );
      }
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'] as List<dynamic>? ?? [];
        for (final z in result) {
          final name = z['name'] as String;
          domainMap[name] = {
            'id': z['id'] as String,
            'name': name,
            'status': z['status'] as String? ?? 'active',
            'type': 'zone',
          };
        }
      }
    } catch (_) {}

    // 2. Try listing Workers Custom Domains attached to this account
    if (accountId.isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/accounts/$accountId/workers/domains'),
          headers: _headers,
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final result = data['result'] as List<dynamic>? ?? [];
          for (final d in result) {
            final hostname = d['hostname'] as String?;
            if (hostname != null && !domainMap.containsKey(hostname)) {
              domainMap[hostname] = {
                'id': d['id'] as String? ?? hostname,
                'name': hostname,
                'status': 'active',
                'type': 'workers_custom_domain',
              };
            }
          }
        }
      } catch (_) {}
    }

    return domainMap.values.toList();
  }

  /// Get user's Cloudflare workers.dev subdomain
  Future<String?> getWorkersSubdomain() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/accounts/$accountId/workers/subdomain'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['result']?['subdomain'] as String?;
      }
    } catch (_) {}
    return null;
  }
}
