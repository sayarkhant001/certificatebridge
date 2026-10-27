import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdfx/pdfx.dart' as pdfx;

class ImportedPageInfo {
  final int pageNumber;
  final String imagePath;
  final double width;
  final double height;

  ImportedPageInfo({
    required this.pageNumber,
    required this.imagePath,
    required this.width,
    required this.height,
  });
}

class TemplateImporter {
  /// Imports a template file (.pdf, .png, .jpg, .jpeg) and converts each page into a high-res image underlay
  Future<List<ImportedPageInfo>> importTemplate({
    required File templateFile,
    required String targetAssetsDir,
    int targetDpi = 300,
  }) async {
    final assetsDir = Directory(targetAssetsDir);
    if (!await assetsDir.exists()) {
      await assetsDir.create(recursive: true);
    }

    final ext = p.extension(templateFile.path).toLowerCase();
    if (ext == '.pdf') {
      return await _importPdfTemplate(templateFile, targetAssetsDir, targetDpi);
    } else if (ext == '.png' || ext == '.jpg' || ext == '.jpeg') {
      return await _importImageTemplate(templateFile, targetAssetsDir);
    } else {
      throw FormatException('Unsupported template format: $ext. Use PDF, PNG, or JPG.');
    }
  }

  Future<List<ImportedPageInfo>> _importPdfTemplate(
    File pdfFile,
    String targetAssetsDir,
    int targetDpi,
  ) async {
    final document = await pdfx.PdfDocument.openFile(pdfFile.path);
    final pageCount = document.pagesCount;
    final results = <ImportedPageInfo>[];

    // Scale factor for 300 DPI (72 points per inch default: 300 / 72 ≈ 4.167)
    final scale = targetDpi / 72.0;

    for (int i = 1; i <= pageCount; i++) {
      final page = await document.getPage(i);
      final renderWidth = (page.width * scale).toInt();
      final renderHeight = (page.height * scale).toInt();

      final pageImage = await page.render(
        width: renderWidth.toDouble(),
        height: renderHeight.toDouble(),
        format: pdfx.PdfPageImageFormat.png,
      );

      await page.close();

      if (pageImage != null) {
        final outPath = p.join(targetAssetsDir, 'page_${i}_bg.png');
        final outFile = File(outPath);
        await outFile.writeAsBytes(pageImage.bytes);

        results.add(ImportedPageInfo(
          pageNumber: i,
          imagePath: outPath,
          width: page.width.toDouble(),
          height: page.height.toDouble(),
        ));
      }
    }

    await document.close();
    return results;
  }

  Future<List<ImportedPageInfo>> _importImageTemplate(
    File imageFile,
    String targetAssetsDir,
  ) async {
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Could not decode template image.');
    }

    final outPath = p.join(targetAssetsDir, 'page_1_bg.png');
    final outFile = File(outPath);
    await outFile.writeAsBytes(img.encodePng(decoded));

    // Standard PDF points conversion (assume 150 DPI for initial pt calculation)
    final ptWidth = (decoded.width * 72.0 / 150.0);
    final ptHeight = (decoded.height * 72.0 / 150.0);

    return [
      ImportedPageInfo(
        pageNumber: 1,
        imagePath: outPath,
        width: ptWidth,
        height: ptHeight,
      ),
    ];
  }
}
