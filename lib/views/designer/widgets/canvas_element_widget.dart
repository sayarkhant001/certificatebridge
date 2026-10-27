import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/canvas_element.dart';
import '../../../services/engine/canvas_renderer.dart';

class CanvasElementWidget extends StatefulWidget {
  final CanvasElement element;
  final double canvasWidth;
  final double canvasHeight;
  final bool isSelected;
  final Map<String, dynamic>? sampleData;
  final String? certCode;
  final File? samplePhotoFile;
  final VoidCallback onSelect;
  final ValueChanged<CanvasElement> onElementChanged;
  final VoidCallback onOpenContextMenu;

  const CanvasElementWidget({
    Key? key,
    required this.element,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.isSelected,
    this.sampleData,
    this.certCode,
    this.samplePhotoFile,
    required this.onSelect,
    required this.onElementChanged,
    required this.onOpenContextMenu,
  }) : super(key: key);

  @override
  State<CanvasElementWidget> createState() => _CanvasElementWidgetState();
}

class _CanvasElementWidgetState extends State<CanvasElementWidget> {
  late double _left;
  late double _top;
  late double _width;
  late double _height;

  @override
  void initState() {
    super.initState();
    _recalculatePositions();
  }

  @override
  void didUpdateWidget(covariant CanvasElementWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canvasWidth != widget.canvasWidth ||
        oldWidget.canvasHeight != widget.canvasHeight ||
        oldWidget.element != widget.element) {
      _recalculatePositions();
    }
  }

  void _recalculatePositions() {
    _left = widget.element.x * widget.canvasWidth;
    _top = widget.element.y * widget.canvasHeight;
    _width = widget.element.w * widget.canvasWidth;
    _height = widget.element.h * widget.canvasHeight;
  }

  void _commitPosition() {
    final normX = (_left / widget.canvasWidth).clamp(0.0, 1.0 - widget.element.w);
    final normY = (_top / widget.canvasHeight).clamp(0.0, 1.0 - widget.element.h);
    final normW = (_width / widget.canvasWidth).clamp(0.02, 1.0);
    final normH = (_height / widget.canvasHeight).clamp(0.02, 1.0);

    widget.onElementChanged(
      widget.element.copyWith(
        x: normX,
        y: normY,
        w: normW,
        h: normH,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _left,
      top: _top,
      width: _width,
      height: _height,
      child: GestureDetector(
        onTap: widget.onSelect,
        onSecondaryTapUp: (_) => widget.onOpenContextMenu(), // Windows Mouse Right-Click
        onLongPressStart: (_) => widget.onOpenContextMenu(), // Android Long-Press
        onPanUpdate: (details) {
          setState(() {
            _left += details.delta.dx;
            _top += details.delta.dy;
          });
        },
        onPanEnd: (_) => _commitPosition(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Element Content
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: widget.isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              child: CanvasRenderer.buildElementWidget(
                element: widget.element,
                canvasWidth: widget.canvasWidth,
                canvasHeight: widget.canvasHeight,
                sampleData: widget.sampleData,
                certCode: widget.certCode,
                samplePhotoFile: widget.samplePhotoFile,
                isSelected: false,
              ),
            ),

            // Resize handle on bottom-right corner when selected
            if (widget.isSelected)
              Positioned(
                right: -6,
                bottom: -6,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _width = (_width + details.delta.dx).clamp(20.0, widget.canvasWidth - _left);
                      _height = (_height + details.delta.dy).clamp(16.0, widget.canvasHeight - _top);
                    });
                  },
                  onPanEnd: (_) => _commitPosition(),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
