import 'package:flutter/material.dart';

class AlignmentGuidelinesOverlay extends StatelessWidget {
  final double width;
  final double height;
  final bool showGrid;
  final double gridSize;
  final List<double> snapLinesX;
  final List<double> snapLinesY;

  const AlignmentGuidelinesOverlay({
    Key? key,
    required this.width,
    required this.height,
    this.showGrid = true,
    this.gridSize = 25.0,
    required this.snapLinesX,
    required this.snapLinesY,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size(width, height),
        painter: _GuidelinesPainter(
          showGrid: showGrid,
          gridSize: gridSize,
          snapLinesX: snapLinesX,
          snapLinesY: snapLinesY,
        ),
      ),
    );
  }
}

class _GuidelinesPainter extends CustomPainter {
  final bool showGrid;
  final double gridSize;
  final List<double> snapLinesX;
  final List<double> snapLinesY;

  _GuidelinesPainter({
    required this.showGrid,
    required this.gridSize,
    required this.snapLinesX,
    required this.snapLinesY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Background Alignment Grid
    if (showGrid) {
      final gridDotPaint = Paint()
        ..color = const Color(0xFF64748B).withOpacity(0.2)
        ..style = PaintingStyle.fill;

      for (double x = gridSize; x < size.width; x += gridSize) {
        for (double y = gridSize; y < size.height; y += gridSize) {
          canvas.drawCircle(Offset(x, y), 1.0, gridDotPaint);
        }
      }
    }

    // 2. Draw Magnetic Vertical Snap Guidelines (Cyan / Magenta)
    final verticalGuidePaint = Paint()
      ..color = const Color(0xFFEC4899) // Magenta guideline
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final x in snapLinesX) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        verticalGuidePaint,
      );
    }

    // 3. Draw Magnetic Horizontal Snap Guidelines
    final horizontalGuidePaint = Paint()
      ..color = const Color(0xFF06B6D4) // Cyan guideline
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final y in snapLinesY) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        horizontalGuidePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GuidelinesPainter oldDelegate) {
    return oldDelegate.showGrid != showGrid ||
        oldDelegate.snapLinesX != snapLinesX ||
        oldDelegate.snapLinesY != snapLinesY;
  }
}
