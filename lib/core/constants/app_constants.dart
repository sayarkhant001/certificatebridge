class AppConstants {
  static const String appName = 'CertiBridge';
  static const String appVersion = '1.0.0';
  static const String appTagline =
      'Local-First, Zero-Cost Bulk Certificate Engine & Permanent Edge Verifier';

  // Network & OAuth PKCE
  static const int loopbackPort = 54321;
  static const String loopbackPath = '/callback';
  static const String loopbackRedirectUri = 'http://127.0.0.1:54321/callback';

  // Cloudflare Defaults
  static const String defaultKvNamespaceName = 'CERT_VERIFIER_KV';
  static const String defaultKvBinding = 'CERT_KV';

  // Tracking Output Columns
  static const String colCertCode = 'Certificate_Code';
  static const String colVerificationUrl = 'Verification_URL';
  static const String colDrivePdfLink = 'Drive_PDF_Link';
  static const String colIssueDate = 'Issue_Date';
  static const String colSyncStatus = 'Sync_Status';

  static const List<String> trackingColumns = [
    colCertCode,
    colVerificationUrl,
    colDrivePdfLink,
    colIssueDate,
    colSyncStatus,
  ];

  // Bundles
  static const String bundleExtension = '.cbproj';
  static const String manifestFileName = 'manifest.json';
  static const String layoutFileName = 'layout.json';
  static const String displayConfigFileName = 'display_config.json';
}
