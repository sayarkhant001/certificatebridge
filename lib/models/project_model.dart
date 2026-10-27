import 'dart:convert';

class ProjectModel {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int totalCertificates;
  final String? templatePath;
  final String layoutJson;
  final String displayConfigJson;

  ProjectModel({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.totalCertificates = 0,
    this.templatePath,
    required this.layoutJson,
    required this.displayConfigJson,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'total_certificates': totalCertificates,
      'template_path': templatePath,
      'layout_json': layoutJson,
      'display_config_json': displayConfigJson,
    };
  }

  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    return ProjectModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      totalCertificates: map['total_certificates'] as int? ?? 0,
      templatePath: map['template_path'] as String?,
      layoutJson: map['layout_json'] as String? ?? '{}',
      displayConfigJson: map['display_config_json'] as String? ?? '{}',
    );
  }

  String toJson() => json.encode(toMap());

  factory ProjectModel.fromJson(String source) =>
      ProjectModel.fromMap(json.decode(source) as Map<String, dynamic>);

  ProjectModel copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalCertificates,
    String? templatePath,
    String? layoutJson,
    String? displayConfigJson,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalCertificates: totalCertificates ?? this.totalCertificates,
      templatePath: templatePath ?? this.templatePath,
      layoutJson: layoutJson ?? this.layoutJson,
      displayConfigJson: displayConfigJson ?? this.displayConfigJson,
    );
  }
}
