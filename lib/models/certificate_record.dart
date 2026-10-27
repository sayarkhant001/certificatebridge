import 'dart:convert';

enum CertificateStatus {
  pending,
  rendering,
  generated,
  uploading,
  uploaded,
  synced,
  failed,
}

class CertificateRecord {
  final String id;
  final String projectId;
  final int rowIndex;
  final Map<String, dynamic> rawData;
  final String certCode;
  final String? shortUrl;
  final String? localPdfPath;
  final String? drivePdfLink;
  final CertificateStatus status;
  final String? errorMessage;
  final DateTime? updatedAt;

  CertificateRecord({
    required this.id,
    required this.projectId,
    required this.rowIndex,
    required this.rawData,
    required this.certCode,
    this.shortUrl,
    this.localPdfPath,
    this.drivePdfLink,
    this.status = CertificateStatus.pending,
    this.errorMessage,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'row_index': rowIndex,
      'raw_json': jsonEncode(rawData),
      'cert_code': certCode,
      'short_url': shortUrl,
      'local_pdf_path': localPdfPath,
      'drive_pdf_link': drivePdfLink,
      'status': status.name,
      'error_message': errorMessage,
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory CertificateRecord.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> data = {};
    if (map['raw_json'] != null) {
      try {
        data = jsonDecode(map['raw_json'] as String) as Map<String, dynamic>;
      } catch (_) {
        data = {};
      }
    }

    return CertificateRecord(
      id: map['id'] as String,
      projectId: map['project_id'] as String,
      rowIndex: map['row_index'] as int? ?? 0,
      rawData: data,
      certCode: map['cert_code'] as String,
      shortUrl: map['short_url'] as String?,
      localPdfPath: map['local_pdf_path'] as String?,
      drivePdfLink: map['drive_pdf_link'] as String?,
      status: CertificateStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? 'pending'),
        orElse: () => CertificateStatus.pending,
      ),
      errorMessage: map['error_message'] as String?,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }

  CertificateRecord copyWith({
    String? id,
    String? projectId,
    int? rowIndex,
    Map<String, dynamic>? rawData,
    String? certCode,
    String? shortUrl,
    String? localPdfPath,
    String? drivePdfLink,
    CertificateStatus? status,
    String? errorMessage,
    DateTime? updatedAt,
  }) {
    return CertificateRecord(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      rowIndex: rowIndex ?? this.rowIndex,
      rawData: rawData ?? this.rawData,
      certCode: certCode ?? this.certCode,
      shortUrl: shortUrl ?? this.shortUrl,
      localPdfPath: localPdfPath ?? this.localPdfPath,
      drivePdfLink: drivePdfLink ?? this.drivePdfLink,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
