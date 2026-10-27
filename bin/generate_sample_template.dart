import 'dart:io';
import 'package:image/image.dart' as img;

void main() async {
  // A4 Landscape proportions at 150 DPI: 1754 x 1240
  final width = 1754;
  final height = 1240;
  final image = img.Image(width: width, height: height);

  // Background: Warm ivory parchment color (#FCFBF7)
  img.fill(image, color: img.ColorRgb8(252, 251, 247));

  // Outer Navy Border (thickness 12)
  final navyColor = img.ColorRgb8(15, 23, 42); // #0F172A
  img.drawRect(image, x1: 30, y1: 30, x2: width - 30, y2: height - 30, color: navyColor, thickness: 8);

  // Inner Gold Border (thickness 6)
  final goldColor = img.ColorRgb8(217, 119, 6); // #D97706
  img.drawRect(image, x1: 50, y1: 50, x2: width - 50, y2: height - 50, color: goldColor, thickness: 4);

  // Corner Accent Flourishes
  const cornerSize = 40;
  // Top-Left
  img.fillRect(image, x1: 50, y1: 50, x2: 50 + cornerSize, y2: 50 + cornerSize, color: goldColor);
  // Top-Right
  img.fillRect(image, x1: width - 50 - cornerSize, y1: 50, x2: width - 50, y2: 50 + cornerSize, color: goldColor);
  // Bottom-Left
  img.fillRect(image, x1: 50, y1: height - 50 - cornerSize, x2: 50 + cornerSize, y2: height - 50, color: goldColor);
  // Bottom-Right
  img.fillRect(image, x1: width - 50 - cornerSize, y1: height - 50 - cornerSize, x2: width - 50, y2: height - 50, color: goldColor);

  final pngBytes = img.encodePng(image);
  await File('assets/templates/sample_certificate_template.png').writeAsBytes(pngBytes);
  print('Generated assets/templates/sample_certificate_template.png successfully');
}
