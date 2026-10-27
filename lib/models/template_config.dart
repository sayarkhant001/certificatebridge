import 'dart:convert';
import 'canvas_element.dart';

class TemplatePage {
  final int pageNumber;
  final String? backgroundAssetPath;
  final double width;
  final double height;
  final int dpi;
  final List<CanvasElement> elements;

  TemplatePage({
    required this.pageNumber,
    this.backgroundAssetPath,
    this.width = 841.89, // A4 Landscape points (297mm)
    this.height = 595.28, // A4 Landscape points (210mm)
    this.dpi = 300,
    required this.elements,
  });

  Map<String, dynamic> toMap() {
    return {
      'page_number': pageNumber,
      'background_asset_path': backgroundAssetPath,
      'width': width,
      'height': height,
      'dpi': dpi,
      'elements': elements.map((e) => e.toMap()).toList(),
    };
  }

  factory TemplatePage.fromMap(Map<String, dynamic> map) {
    return TemplatePage(
      pageNumber: map['page_number'] as int? ?? 1,
      backgroundAssetPath: map['background_asset_path'] as String?,
      width: (map['width'] as num?)?.toDouble() ?? 841.89,
      height: (map['height'] as num?)?.toDouble() ?? 595.28,
      dpi: map['dpi'] as int? ?? 300,
      elements: (map['elements'] as List<dynamic>? ?? [])
          .map((e) => CanvasElement.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TemplateConfig {
  final String version;
  final String orientation; // 'landscape' or 'portrait'
  final List<TemplatePage> pages;

  TemplateConfig({
    this.version = '1.0.0',
    this.orientation = 'landscape',
    required this.pages,
  });

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'orientation': orientation,
      'pages': pages.map((p) => p.toMap()).toList(),
    };
  }

  factory TemplateConfig.fromMap(Map<String, dynamic> map) {
    return TemplateConfig(
      version: map['version'] as String? ?? '1.0.0',
      orientation: map['orientation'] as String? ?? 'landscape',
      pages: (map['pages'] as List<dynamic>? ?? [])
          .map((p) => TemplatePage.fromMap(p as Map<String, dynamic>))
          .toList(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory TemplateConfig.fromJson(String source) {
    if (source.trim().isEmpty || source.trim() == '{}') {
      return TemplateConfig.defaultConfig();
    }
    return TemplateConfig.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }

  static TemplateConfig defaultConfig() {
    return TemplateConfig(
      pages: [
        TemplatePage(
          pageNumber: 1,
          elements: [
            CanvasElement(
              id: 'title_1',
              name: 'Title Text',
              type: CanvasElementType.text,
              x: 0.1,
              y: 0.22,
              w: 0.8,
              h: 0.08,
              text: 'CERTIFICATE OF COMPLETION',
              fontFamily: 'Cinzel',
              fontSize: 34.0,
              isBold: true,
              colorHex: '#1E3A8A',
            ),
            CanvasElement(
              id: 'recipient_name',
              name: 'Recipient Name',
              type: CanvasElementType.text,
              x: 0.1,
              y: 0.45,
              w: 0.8,
              h: 0.10,
              text: '{{Student_Name}}',
              boundColumn: 'Student_Name',
              fontFamily: 'Padauk',
              fontSize: 38.0,
              isBold: true,
              colorHex: '#B45309',
            ),
            CanvasElement(
              id: 'course_desc',
              name: 'Course Description',
              type: CanvasElementType.text,
              x: 0.15,
              y: 0.60,
              w: 0.7,
              h: 0.08,
              text: 'has successfully completed the {{Course_Name}} program',
              boundColumn: 'Course_Name',
              fontFamily: 'Roboto',
              fontSize: 20.0,
              colorHex: '#334155',
            ),
            CanvasElement(
              id: 'qr_verification',
              name: 'Verification QR',
              type: CanvasElementType.qr,
              x: 0.82,
              y: 0.76,
              w: 0.12,
              h: 0.16,
              qrUrlPattern: 'https://verify.school.edu/c/{{cert_code}}',
            ),
          ],
        ),
      ],
    );
  }
}
