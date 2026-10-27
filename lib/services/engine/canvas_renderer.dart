import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/canvas_element.dart';

class CanvasRenderer {
  /// Builds a rendered Flutter Widget for a CanvasElement inside the visual designer or live preview
  static Widget buildElementWidget({
    required CanvasElement element,
    required double canvasWidth,
    required double canvasHeight,
    Map<String, dynamic>? sampleData,
    String? certCode,
    File? samplePhotoFile,
    bool isSelected = false,
  }) {
    final left = element.x * canvasWidth;
    final top = element.y * canvasHeight;
    final width = element.w * canvasWidth;
    final height = element.h * canvasHeight;

    Widget child;

    switch (element.type) {
      case CanvasElementType.text:
        child = _buildText(element, sampleData, certCode, width, height);
        break;
      case CanvasElementType.photo:
        child = _buildPhoto(element, samplePhotoFile, width, height);
        break;
      case CanvasElementType.qr:
        child = _buildQr(element, certCode, width, height);
        break;
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: isSelected
            ? BoxDecoration(
                border: Border.all(color: Colors.blueAccent, width: 2),
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        child: child,
      ),
    );
  }

  static Widget _buildText(
    CanvasElement element,
    Map<String, dynamic>? sampleData,
    String? certCode,
    double boxWidth,
    double boxHeight,
  ) {
    String text = element.text;

    if (element.boundColumn != null &&
        sampleData != null &&
        sampleData.containsKey(element.boundColumn)) {
      text = sampleData[element.boundColumn]?.toString() ?? '';
    } else if (sampleData != null) {
      sampleData.forEach((k, v) {
        text = text.replaceAll('{{$k}}', v?.toString() ?? '');
      });
      if (certCode != null) {
        text = text.replaceAll('{{Certificate_Code}}', certCode);
      }
    }

    final color = _parseColor(element.colorHex);
    TextAlign align;
    switch (element.textAlign) {
      case TextAlignment.left:
        align = TextAlign.left;
        break;
      case TextAlignment.right:
        align = TextAlign.right;
        break;
      case TextAlignment.center:
      default:
        align = TextAlign.center;
        break;
    }

    final textStyle = TextStyle(
      fontFamily: element.fontFamily,
      fontSize: element.fontSize,
      color: color,
      fontWeight: element.isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: element.isItalic ? FontStyle.italic : FontStyle.normal,
    );

    if (element.autoShrinkToFit) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: _flutterAlignment(element.textAlign),
        child: Text(text, textAlign: align, style: textStyle),
      );
    }

    return Text(text, textAlign: align, style: textStyle);
  }

  static Widget _buildPhoto(
    CanvasElement element,
    File? photoFile,
    double boxWidth,
    double boxHeight,
  ) {
    Widget imageContent;
    if (photoFile != null && photoFile.existsSync()) {
      imageContent = Image.file(photoFile, fit: BoxFit.cover, width: boxWidth, height: boxHeight);
    } else {
      imageContent = Container(
        color: const Color(0xFF334155),
        child: const Center(
          child: Icon(Icons.person, color: Colors.white54, size: 36),
        ),
      );
    }

    switch (element.clippingShape) {
      case PhotoClippingShape.circle:
        return ClipOval(child: imageContent);
      case PhotoClippingShape.roundedRectangle:
        return ClipRRect(
          borderRadius: BorderRadius.circular(element.borderRadius),
          child: imageContent,
        );
      case PhotoClippingShape.rectangle:
      default:
        return imageContent;
    }
  }

  static Widget _buildQr(
    CanvasElement element,
    String? certCode,
    double boxWidth,
    double boxHeight,
  ) {
    String data = element.qrUrlPattern;
    if (certCode != null) {
      data = data.replaceAll('{{cert_code}}', certCode);
      data = data.replaceAll('{{Certificate_Code}}', certCode);
    }

    return Container(
      color: _parseColor(element.qrBackgroundColorHex),
      padding: const EdgeInsets.all(4),
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: _parseColor(element.qrForegroundColorHex),
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: _parseColor(element.qrForegroundColorHex),
        ),
      ),
    );
  }

  static Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.black;
    }
  }

  static Alignment _flutterAlignment(TextAlignment align) {
    switch (align) {
      case TextAlignment.left:
        return Alignment.centerLeft;
      case TextAlignment.right:
        return Alignment.centerRight;
      case TextAlignment.center:
      default:
        return Alignment.center;
    }
  }
}
