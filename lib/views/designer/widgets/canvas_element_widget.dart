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
  final Function(Rect currentRect)? onDragUpdate;
  final VoidCallback? onDragEnd;
  final VoidCallback? onDoubleTap;

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
    this.onDragUpdate,
    this.onDragEnd,
    this.onDoubleTap,
  }) : super(key: key);

  @override
  State<CanvasElementWidget> createState() => _CanvasElementWidgetState();
}

class _CanvasElementWidgetState extends State<CanvasElementWidget> {
  late double _left;
  late double _top;
  late double _width;
  late double _height;

  bool _isInlineEditing = false;
  late TextEditingController _inlineTextCtrl;
  final FocusNode _inlineFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _inlineTextCtrl = TextEditingController(text: widget.element.text);
    _recalculatePositions();
  }

  @override
  void didUpdateWidget(covariant CanvasElementWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canvasWidth != widget.canvasWidth ||
        oldWidget.canvasHeight != widget.canvasHeight ||
        oldWidget.element != widget.element) {
      _recalculatePositions();
      if (!_isInlineEditing && oldWidget.element.text != widget.element.text) {
        _inlineTextCtrl.text = widget.element.text;
      }
    }
  }

  @override
  void dispose() {
    _inlineTextCtrl.dispose();
    _inlineFocusNode.dispose();
    super.dispose();
  }

  void _startInlineEditing() {
    if (widget.element.type == CanvasElementType.text) {
      setState(() {
        _isInlineEditing = true;
        _inlineTextCtrl.text = widget.element.text;
        _inlineTextCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _inlineTextCtrl.text.length);
      });
      _inlineFocusNode.requestFocus();
    }
    if (widget.onDoubleTap != null) {
      widget.onDoubleTap!();
    }
  }

  void _finishInlineEditing() {
    if (_isInlineEditing) {
      setState(() => _isInlineEditing = false);
      widget.onElementChanged(widget.element.copyWith(text: _inlineTextCtrl.text));
    }
  }

  static Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.black;
    }
  }

  static TextAlign _getTextAlign(TextAlignment align) {
    switch (align) {
      case TextAlignment.left:
        return TextAlign.left;
      case TextAlignment.right:
        return TextAlign.right;
      case TextAlignment.center:
      default:
        return TextAlign.center;
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
        onTap: () {
          if (_isInlineEditing) {
            _finishInlineEditing();
          }
          widget.onSelect();
        },
        onDoubleTap: _startInlineEditing,
        onSecondaryTapUp: (_) => widget.onOpenContextMenu(), // Windows Mouse Right-Click
        onLongPressStart: (_) => widget.onOpenContextMenu(), // Android Long-Press
        onPanUpdate: _isInlineEditing
            ? null
            : (details) {
                setState(() {
                  _left += details.delta.dx;
                  _top += details.delta.dy;
                });
                if (widget.onDragUpdate != null) {
                  widget.onDragUpdate!(Rect.fromLTWH(_left, _top, _width, _height));
                }
              },
        onPanEnd: _isInlineEditing
            ? null
            : (_) {
                if (widget.onDragEnd != null) {
                  widget.onDragEnd!();
                }
                _commitPosition();
              },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Element Content or Inline Text Editor
            Container(
              width: _width,
              height: _height,
              decoration: BoxDecoration(
                border: Border.all(
                  color: widget.isSelected
                      ? const Color(0xFF2563EB)
                      : (_isInlineEditing ? const Color(0xFF38BDF8) : Colors.transparent),
                  width: widget.isSelected ? 1.5 : 1.0,
                ),
                borderRadius: BorderRadius.circular(2),
                color: _isInlineEditing ? Colors.white.withOpacity(0.9) : Colors.transparent,
              ),
              child: _isInlineEditing
                  ? Center(
                      child: TextField(
                        controller: _inlineTextCtrl,
                        focusNode: _inlineFocusNode,
                        autofocus: true,
                        maxLines: null,
                        textAlign: _getTextAlign(widget.element.textAlign),
                        style: TextStyle(
                          fontFamily: widget.element.fontFamily,
                          fontSize: widget.element.fontSize,
                          color: _parseColor(widget.element.colorHex),
                          fontWeight: widget.element.isBold ? FontWeight.bold : FontWeight.normal,
                          fontStyle: widget.element.isItalic ? FontStyle.italic : FontStyle.normal,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        ),
                        onSubmitted: (_) => _finishInlineEditing(),
                        onTapOutside: (_) => _finishInlineEditing(),
                      ),
                    )
                  : CanvasRenderer.buildElementContent(
                      element: widget.element,
                      boxWidth: _width,
                      boxHeight: _height,
                      sampleData: widget.sampleData,
                      certCode: widget.certCode,
                      samplePhotoFile: widget.samplePhotoFile,
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
