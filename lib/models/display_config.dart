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

  DisplayConfig({
    required this.publicColumns,
    required this.emailColumns,
    this.allowPdfDownload = true,
    this.allowEmailReceipt = true,
    this.institutionName = 'CertiBridge Academy',
    this.supportEmail = 'admin@school.edu',
    this.customDomain,
    this.primaryColorHex = '#1E3A8A',
    this.emailSubjectTemplate = 'Official Certificate of Completion: {{Certificate_Code}}',
    this.emailBodyTemplate =
        'Dear {{Student_Name}},\n\nYour certificate for {{Course_Name}} has been officially issued.\nVerification Link: {{Verification_URL}}\n\nBest regards,\n{{Institution_Name}}',
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
      primaryColorHex: map['primary_color_hex'] as String? ?? '#1E3A8A',
      emailSubjectTemplate: map['email_subject_template'] as String? ??
          'Official Certificate of Completion: {{Certificate_Code}}',
      emailBodyTemplate: map['email_body_template'] as String? ??
          'Dear {{Student_Name}},\n\nYour certificate has been issued.',
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
    );
  }
}
