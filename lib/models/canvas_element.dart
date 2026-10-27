import 'dart:convert';

enum CanvasElementType {
  text,
  photo,
  qr,
}

enum TextAlignment {
  left,
  center,
  right,
}

enum PhotoClippingShape {
  rectangle,
  roundedRectangle,
  circle,
}

class CanvasElement {
  final String id;
  final String name;
  final CanvasElementType type;
  final int pageIndex;

  // Normalized coordinates (0.0 to 1.0 relative to page dimensions)
  final double x;
  final double y;
  final double w;
  final double h;
  final int zIndex;

  // Text specific properties
  final String text; // e.g. "Certificate of Excellence" or "{{Student_Name}}"
  final String? boundColumn; // Optional direct binding to data column
  final String fontFamily;
  final double fontSize; // Base pt size when rendered at 1000px height
  final String colorHex;
  final bool isBold;
  final bool isItalic;
  final TextAlignment textAlign;
  final bool autoShrinkToFit;

  // Photo specific properties
  final PhotoClippingShape clippingShape;
  final double borderRadius; // In pixels / percentage relative to box

  // QR Code specific properties
  final String qrUrlPattern; // e.g. "https://verify.school.edu/c/{{cert_code}}"
  final String qrForegroundColorHex;
  final String qrBackgroundColorHex;

  CanvasElement({
    required this.id,
    required this.name,
    required this.type,
    this.pageIndex = 0,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.zIndex = 0,
    this.text = '',
    this.boundColumn,
    this.fontFamily = 'Roboto',
    this.fontSize = 24.0,
    this.colorHex = '#0F172A',
    this.isBold = false,
    this.isItalic = false,
    this.textAlign = TextAlignment.center,
    this.autoShrinkToFit = true,
    this.clippingShape = PhotoClippingShape.rectangle,
    this.borderRadius = 8.0,
    this.qrUrlPattern = 'https://verify.school.edu/c/{{cert_code}}',
    this.qrForegroundColorHex = '#000000',
    this.qrBackgroundColorHex = '#FFFFFF',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'page_index': pageIndex,
      'x': x,
      'y': y,
      'w': w,
      'h': h,
      'z_index': zIndex,
      'text': text,
      'bound_column': boundColumn,
      'font_family': fontFamily,
      'font_size': fontSize,
      'color_hex': colorHex,
      'is_bold': isBold,
      'is_italic': isItalic,
      'text_align': textAlign.name,
      'auto_shrink_to_fit': autoShrinkToFit,
      'clipping_shape': clippingShape.name,
      'border_radius': borderRadius,
      'qr_url_pattern': qrUrlPattern,
      'qr_fg_color_hex': qrForegroundColorHex,
      'qr_bg_color_hex': qrBackgroundColorHex,
    };
  }

  factory CanvasElement.fromMap(Map<String, dynamic> map) {
    return CanvasElement(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Element',
      type: CanvasElementType.values.firstWhere(
        (e) => e.name == (map['type'] as String? ?? 'text'),
        orElse: () => CanvasElementType.text,
      ),
      pageIndex: map['page_index'] as int? ?? 0,
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      w: (map['w'] as num).toDouble(),
      h: (map['h'] as num).toDouble(),
      zIndex: map['z_index'] as int? ?? 0,
      text: map['text'] as String? ?? '',
      boundColumn: map['bound_column'] as String?,
      fontFamily: map['font_family'] as String? ?? 'Roboto',
      fontSize: (map['font_size'] as num?)?.toDouble() ?? 24.0,
      colorHex: map['color_hex'] as String? ?? '#0F172A',
      isBold: map['is_bold'] as bool? ?? false,
      isItalic: map['is_italic'] as bool? ?? false,
      textAlign: TextAlignment.values.firstWhere(
        (e) => e.name == (map['text_align'] as String? ?? 'center'),
        orElse: () => TextAlignment.center,
      ),
      autoShrinkToFit: map['auto_shrink_to_fit'] as bool? ?? true,
      clippingShape: PhotoClippingShape.values.firstWhere(
        (e) => e.name == (map['clipping_shape'] as String? ?? 'rectangle'),
        orElse: () => PhotoClippingShape.rectangle,
      ),
      borderRadius: (map['border_radius'] as num?)?.toDouble() ?? 8.0,
      qrUrlPattern: map['qr_url_pattern'] as String? ??
          'https://verify.school.edu/c/{{cert_code}}',
      qrForegroundColorHex: map['qr_fg_color_hex'] as String? ?? '#000000',
      qrBackgroundColorHex: map['qr_bg_color_hex'] as String? ?? '#FFFFFF',
    );
  }

  CanvasElement copyWith({
    String? id,
    String? name,
    CanvasElementType? type,
    int? pageIndex,
    double? x,
    double? y,
    double? w,
    double? h,
    int? zIndex,
    String? text,
    String? boundColumn,
    String? fontFamily,
    double? fontSize,
    String? colorHex,
    bool? isBold,
    bool? isItalic,
    TextAlignment? textAlign,
    bool? autoShrinkToFit,
    PhotoClippingShape? clippingShape,
    double? borderRadius,
    String? qrUrlPattern,
    String? qrForegroundColorHex,
    String? qrBackgroundColorHex,
  }) {
    return CanvasElement(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      pageIndex: pageIndex ?? this.pageIndex,
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
      zIndex: zIndex ?? this.zIndex,
      text: text ?? this.text,
      boundColumn: boundColumn ?? this.boundColumn,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      colorHex: colorHex ?? this.colorHex,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      textAlign: textAlign ?? this.textAlign,
      autoShrinkToFit: autoShrinkToFit ?? this.autoShrinkToFit,
      clippingShape: clippingShape ?? this.clippingShape,
      borderRadius: borderRadius ?? this.borderRadius,
      qrUrlPattern: qrUrlPattern ?? this.qrUrlPattern,
      qrForegroundColorHex: qrForegroundColorHex ?? this.qrForegroundColorHex,
      qrBackgroundColorHex: qrBackgroundColorHex ?? this.qrBackgroundColorHex,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory CanvasElement.fromJson(String source) =>
      CanvasElement.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
