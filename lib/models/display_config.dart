import 'dart:convert';

class DisplayConfig {
  final List<String> publicColumns;
  final List<String> emailColumns;
  final bool allowPdfDownload;
  final bool allowEmailReceipt;
  final String institutionName;
  final String supportEmail;
  final String? customDomain; // e.g. verify.school.edu
  final String primaryColorHex;
  final String emailSubjectTemplate;
  final String emailBodyTemplate;

  final String? logoUrl;
  final String badgeText;
  final String headlineText;
  final String footerText;
  final String themePreset; // emerald, sapphire, gold, crimson, obsidian
  final bool allowPrint;
  final String? customSubdomain;
  final bool allowVerifierEmail;
  final String verifierInstructions;
  final int slugEntropyLength;
  final bool enableRateLimiting;

  DisplayConfig({
    required this.publicColumns,
    required this.emailColumns,
    this.allowPdfDownload = true,
    this.allowEmailReceipt = true,
    this.institutionName = 'CertiBridge Academy',
    this.supportEmail = 'admin@school.edu',
    this.customDomain,
    this.primaryColorHex = '#059669',
    this.emailSubjectTemplate = 'Official Certificate of Completion: {{Certificate_Code}}',
    this.emailBodyTemplate =
        'Dear {{Student_Name}},\n\nYour certificate for {{Course_Name}} has been officially issued.\nVerification Link: {{Verification_URL}}\n\nBest regards,\n{{Institution_Name}}',
    this.logoUrl,
    this.badgeText = 'Official Edge Verified',
    this.headlineText = 'Permanent Cryptographic Record Verified',
    this.footerText = 'Secured by CertiBridge Zero-Cost Local-First Architecture &bull; Powered by Cloudflare KV Edge',
    this.themePreset = 'emerald',
    this.allowPrint = false,
    this.customSubdomain,
    this.allowVerifierEmail = true,
    this.verifierInstructions = 'Enter your email address to receive an official cryptographic verification report.',
    this.slugEntropyLength = 40,
    this.enableRateLimiting = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'public_columns': publicColumns,
      'email_columns': emailColumns,
      'allow_pdf_download': allowPdfDownload,
      'allow_email_receipt': allowEmailReceipt,
      'institution_name': institutionName,
      'support_email': supportEmail,
      'custom_domain': customDomain,
      'primary_color_hex': primaryColorHex,
      'email_subject_template': emailSubjectTemplate,
      'email_body_template': emailBodyTemplate,
      'logo_url': logoUrl,
      'badge_text': badgeText,
      'headline_text': headlineText,
      'footer_text': footerText,
      'theme_preset': themePreset,
      'allow_print': allowPrint,
      'custom_subdomain': customSubdomain,
      'allow_verifier_email': allowVerifierEmail,
      'verifier_instructions': verifierInstructions,
      'slug_entropy_length': slugEntropyLength,
      'enable_rate_limiting': enableRateLimiting,
    };
  }

  factory DisplayConfig.fromMap(Map<String, dynamic> map) {
    return DisplayConfig(
      publicColumns: (map['public_columns'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      emailColumns: (map['email_columns'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      allowPdfDownload: map['allow_pdf_download'] as bool? ?? true,
      allowEmailReceipt: map['allow_email_receipt'] as bool? ?? true,
      institutionName: map['institution_name'] as String? ?? 'CertiBridge Academy',
      supportEmail: map['support_email'] as String? ?? 'admin@school.edu',
      customDomain: map['custom_domain'] as String?,
      primaryColorHex: map['primary_color_hex'] as String? ?? '#059669',
      emailSubjectTemplate: map['email_subject_template'] as String? ??
          'Official Certificate of Completion: {{Certificate_Code}}',
      emailBodyTemplate: map['email_body_template'] as String? ??
          'Dear {{Student_Name}},\n\nYour certificate has been issued.',
      logoUrl: map['logo_url'] as String?,
      badgeText: map['badge_text'] as String? ?? 'Official Edge Verified',
      headlineText: map['headline_text'] as String? ?? 'Permanent Cryptographic Record Verified',
      footerText: map['footer_text'] as String? ?? 'Secured by CertiBridge Zero-Cost Local-First Architecture &bull; Powered by Cloudflare KV Edge',
      themePreset: map['theme_preset'] as String? ?? 'emerald',
      allowPrint: map['allow_print'] as bool? ?? false,
      customSubdomain: map['custom_subdomain'] as String?,
      allowVerifierEmail: map['allow_verifier_email'] as bool? ?? true,
      verifierInstructions: map['verifier_instructions'] as String? ??
          'Enter your email address to receive an official cryptographic verification report.',
      slugEntropyLength: map['slug_entropy_length'] as int? ?? 40,
      enableRateLimiting: map['enable_rate_limiting'] as bool? ?? true,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory DisplayConfig.fromJson(String source) {
    if (source.trim().isEmpty || source.trim() == '{}') {
      return DisplayConfig.defaultConfig();
    }
    return DisplayConfig.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }

  static DisplayConfig defaultConfig() {
    return DisplayConfig(
      publicColumns: ['Student_Name', 'Course_Name', 'Issue_Date', 'Certificate_Code'],
      emailColumns: ['Student_Name', 'Course_Name', 'Issue_Date', 'Certificate_Code', 'Student_Email'],
    );
  }

  DisplayConfig copyWith({
    List<String>? publicColumns,
    List<String>? emailColumns,
    bool? allowPdfDownload,
    bool? allowEmailReceipt,
    String? institutionName,
    String? supportEmail,
    String? customDomain,
    String? primaryColorHex,
    String? emailSubjectTemplate,
    String? emailBodyTemplate,
    String? logoUrl,
    String? badgeText,
    String? headlineText,
    String? footerText,
    String? themePreset,
    bool? allowPrint,
    String? customSubdomain,
    bool? allowVerifierEmail,
    String? verifierInstructions,
    int? slugEntropyLength,
    bool? enableRateLimiting,
  }) {
    return DisplayConfig(
      publicColumns: publicColumns ?? this.publicColumns,
      emailColumns: emailColumns ?? this.emailColumns,
      allowPdfDownload: allowPdfDownload ?? this.allowPdfDownload,
      allowEmailReceipt: allowEmailReceipt ?? this.allowEmailReceipt,
      institutionName: institutionName ?? this.institutionName,
      supportEmail: supportEmail ?? this.supportEmail,
      customDomain: customDomain ?? this.customDomain,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      emailSubjectTemplate: emailSubjectTemplate ?? this.emailSubjectTemplate,
      emailBodyTemplate: emailBodyTemplate ?? this.emailBodyTemplate,
      logoUrl: logoUrl ?? this.logoUrl,
      badgeText: badgeText ?? this.badgeText,
      headlineText: headlineText ?? this.headlineText,
      footerText: footerText ?? this.footerText,
      themePreset: themePreset ?? this.themePreset,
      allowPrint: allowPrint ?? this.allowPrint,
      customSubdomain: customSubdomain ?? this.customSubdomain,
      allowVerifierEmail: allowVerifierEmail ?? this.allowVerifierEmail,
      verifierInstructions: verifierInstructions ?? this.verifierInstructions,
      slugEntropyLength: slugEntropyLength ?? this.slugEntropyLength,
      enableRateLimiting: enableRateLimiting ?? this.enableRateLimiting,
    );
  }
}
