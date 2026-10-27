import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/canvas_element.dart';
import '../../models/certificate_record.dart';
import '../../models/template_config.dart';
import 'font_manager.dart';

class PdfCompiler {
  final FontManager _fontManager = FontManager();
  final Map<String, pw.Font> _fontCache = {};

  /// Compiles a single certificate PDF and writes it directly to disk
  Future<File> compileCertificate({
    required TemplateConfig templateConfig,
    required CertificateRecord record,
    required String outputFilePath,
    File? resolvedPhotoFile,
  }) async {
    final pdf = pw.Document();

    for (final page in templateConfig.pages) {
      // 1. Load Background Underlay Image if present
      pw.MemoryImage? bgImage;
      if (page.backgroundAssetPath != null) {
        final bgFile = File(page.backgroundAssetPath!);
        if (await bgFile.exists()) {
          final bytes = await bgFile.readAsBytes();
          bgImage = pw.MemoryImage(bytes);
        }
      }

      // Page format based on template dimensions
      final pageFormat = PdfPageFormat(
        page.width,
        page.height,
        marginAll: 0,
      );

      // 2. Preload required fonts for this page
      for (final el in page.elements) {
        if (el.type == CanvasElementType.text && !_fontCache.containsKey(el.fontFamily)) {
          final fontBytes = await _fontManager.getFontBytes(el.fontFamily);
          if (fontBytes != null) {
            try {
              _fontCache[el.fontFamily] = pw.Font.ttf(ByteData.view(fontBytes.buffer));
            } catch (_) {}
          }
        }
      }

      // 3. Build page layout with absolute positioned overlay widgets
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (pw.Context context) {
            return pw.Stack(
              fit: pw.StackFit.expand,
              children: [
                // Background Layer
                if (bgImage != null)
                  pw.Positioned.fill(
                    child: pw.Image(bgImage, fit: pw.BoxFit.fill),
                  ),

                // Overlaid Canvas Elements
                ...page.elements.map((element) {
                  return _buildElementWidget(
                    element: element,
                    pageWidth: page.width,
                    pageHeight: page.height,
                    record: record,
                    photoFile: resolvedPhotoFile,
                  );
                }),
              ],
            );
          },
        ),
      );
    }

    final outFile = File(outputFilePath);
    await outFile.parent.create(recursive: true);
    final pdfBytes = await pdf.save();
    return await outFile.writeAsBytes(pdfBytes, flush: true);
  }

  pw.Widget _buildElementWidget({
    required CanvasElement element,
    required double pageWidth,
    required double pageHeight,
    required CertificateRecord record,
    File? photoFile,
  }) {
    final left = element.x * pageWidth;
    final top = element.y * pageHeight;
    final width = element.w * pageWidth;
    final height = element.h * pageHeight;

    pw.Widget contentWidget;

    switch (element.type) {
      case CanvasElementType.text:
        contentWidget = _buildTextWidget(element, record, width, height);
        break;
      case CanvasElementType.photo:
        contentWidget = _buildPhotoWidget(element, photoFile, width, height);
        break;
      case CanvasElementType.qr:
        contentWidget = _buildQrWidget(element, record, width, height);
        break;
    }

    return pw.Positioned(
      left: left,
      top: top,
      child: pw.SizedBox(
        width: width,
        height: height,
        child: contentWidget,
      ),
    );
  }

  pw.Widget _buildTextWidget(
    CanvasElement element,
    CertificateRecord record,
    double boxWidth,
    double boxHeight,
  ) {
    // Resolve dynamic placeholder tags e.g. {{Student_Name}}
    String displayText = element.text;

    // Check direct bound column first
    if (element.boundColumn != null && record.rawData.containsKey(element.boundColumn)) {
      displayText = record.rawData[element.boundColumn]?.toString() ?? '';
    } else {
      record.rawData.forEach((key, val) {
        displayText = displayText.replaceAll('{{$key}}', val?.toString() ?? '');
      });
      displayText = displayText.replaceAll('{{Certificate_Code}}', record.certCode);
    }

    final font = _fontCache[element.fontFamily] ?? pw.Font.helvetica();
    final color = _parseColor(element.colorHex);

    pw.TextAlign align;
    switch (element.textAlign) {
      case TextAlignment.left:
        align = pw.TextAlign.left;
        break;
      case TextAlignment.right:
        align = pw.TextAlign.right;
        break;
      case TextAlignment.center:
      default:
        align = pw.TextAlign.center;
        break;
    }

    final textWidget = pw.Text(
      displayText,
      textAlign: align,
      style: pw.TextStyle(
        font: font,
        fontSize: element.fontSize,
        color: color,
        fontWeight: element.isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        fontStyle: element.isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
      ),
    );

    if (element.autoShrinkToFit) {
      return pw.FittedBox(
        fit: pw.BoxFit.scaleDown,
        alignment: _pdfAlignment(element.textAlign),
        child: textWidget,
      );
    }

    return textWidget;
  }

  pw.Widget _buildPhotoWidget(
    CanvasElement element,
    File? photoFile,
    double boxWidth,
    double boxHeight,
  ) {
    if (photoFile == null || !photoFile.existsSync()) {
      return pw.Container(
        width: boxWidth,
        height: boxHeight,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 1),
          color: PdfColors.grey200,
        ),
      );
    }

    final bytes = photoFile.readAsBytesSync();
    final img = pw.MemoryImage(bytes);

    pw.BoxDecoration decoration;
    switch (element.clippingShape) {
      case PhotoClippingShape.circle:
        decoration = const pw.BoxDecoration(shape: pw.BoxShape.circle);
        return pw.ClipOval(
          child: pw.Image(img, width: boxWidth, height: boxHeight, fit: pw.BoxFit.cover),
        );
      case PhotoClippingShape.roundedRectangle:
        return pw.ClipRRect(
          horizontalRadius: element.borderRadius,
          verticalRadius: element.borderRadius,
          child: pw.Image(img, width: boxWidth, height: boxHeight, fit: pw.BoxFit.cover),
        );
      case PhotoClippingShape.rectangle:
      default:
        return pw.Image(img, width: boxWidth, height: boxHeight, fit: pw.BoxFit.cover);
    }
  }

  pw.Widget _buildQrWidget(
    CanvasElement element,
    CertificateRecord record,
    double boxWidth,
    double boxHeight,
  ) {
    String qrData = element.qrUrlPattern;
    qrData = qrData.replaceAll('{{cert_code}}', record.certCode);
    qrData = qrData.replaceAll('{{Certificate_Code}}', record.certCode);
    if (record.shortUrl != null && record.shortUrl!.isNotEmpty) {
      qrData = record.shortUrl!;
    }

    final fgColor = _parseColor(element.qrForegroundColorHex);
    final bgColor = _parseColor(element.qrBackgroundColorHex);

    return pw.Container(
      color: bgColor,
      child: pw.BarcodeWidget(
        barcode: pw.Barcode.qrCode(),
        data: qrData,
        color: fgColor,
        backgroundColor: bgColor,
      ),
    );
  }

  PdfColor _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return PdfColor.fromHex(clean.length == 6 ? clean : '000000');
    } catch (_) {
      return PdfColors.black;
    }
  }

  pw.Alignment _pdfAlignment(TextAlignment align) {
    switch (align) {
      case TextAlignment.left:
        return pw.Alignment.centerLeft;
      case TextAlignment.right:
        return pw.Alignment.centerRight;
      case TextAlignment.center:
      default:
        return pw.Alignment.center;
    }
  }
}
