import 'package:flutter/material.dart';
import '../../../models/canvas_element.dart';
import '../../../services/engine/font_manager.dart';
import 'color_palette_picker.dart';

class ContextMenuOverlay extends StatefulWidget {
  final CanvasElement element;
  final List<String> availableHeaders;
  final ValueChanged<CanvasElement> onElementUpdated;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const ContextMenuOverlay({
    Key? key,
    required this.element,
    required this.availableHeaders,
    required this.onElementUpdated,
    required this.onDelete,
    required this.onClose,
  }) : super(key: key);

  @override
  State<ContextMenuOverlay> createState() => _ContextMenuOverlayState();
}

class _ContextMenuOverlayState extends State<ContextMenuOverlay> {
  late CanvasElement _el;
  final FontManager _fontManager = FontManager();

  @override
  void initState() {
    super.initState();
    _el = widget.element;
  }

  void _update(CanvasElement updated) {
    setState(() => _el = updated);
    widget.onElementUpdated(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF475569)),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _el.type == CanvasElementType.text
                            ? Icons.text_fields
                            : _el.type == CanvasElementType.photo
                                ? Icons.portrait
                                : Icons.qr_code,
                        color: Colors.blueAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Edit ${_el.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Colors.white54),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
              const Divider(color: Color(0xFF334155), height: 16),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Link to Column Dropdown
                      const Text('Data Source Binding', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String?>(
                        value: widget.availableHeaders.contains(_el.boundColumn) ? _el.boundColumn : null,
                        decoration: const InputDecoration(
                          hintText: 'Select Column (e.g. Student_Name)',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('None (Static / Custom Placeholder)'),
                          ),
                          ...widget.availableHeaders.map((header) {
                            return DropdownMenuItem<String?>(
                              value: header,
                              child: Text(header),
                            );
                          }).toList(),
                        ],
                        onChanged: (val) {
                          _update(_el.copyWith(
                            boundColumn: val,
                            text: val != null ? '{{$val}}' : _el.text,
                          ));
                        },
                      ),
                      const SizedBox(height: 16),

                      // Text Specific Controls
                      if (_el.type == CanvasElementType.text) ...[
                        const Text('Text Content / Template Tag', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                        const SizedBox(height: 6),
                        TextFormField(
                          initialValue: _el.text,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Certificate of Completion',
                            isDense: true,
                          ),
                          onChanged: (val) => _update(_el.copyWith(text: val)),
                        ),
                        const SizedBox(height: 16),

                        // Font Family Picker
                        const Text('Typography & Script Support', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _fontManager.availableFonts.any((f) => f.family == _el.fontFamily)
                              ? _el.fontFamily
                              : null,
                          decoration: const InputDecoration(isDense: true),
                          items: _fontManager.availableFonts.map((f) {
                            final categoryBadge = f.category == FontCategory.myanmarUnicode
                                ? ' [MM Unicode]'
                                : f.category == FontCategory.myanmarWin
                                    ? ' [Win Font]'
                                    : ' [EN]';
                            return DropdownMenuItem<String>(
                              value: f.family,
                              child: Text('${f.name}$categoryBadge', style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) _update(_el.copyWith(fontFamily: val));
                          },
                        ),
                        const SizedBox(height: 12),

                        // Font Size Slider
                        Row(
                          children: [
                            const Text('Font Size: ', style: TextStyle(fontSize: 12, color: Colors.white70)),
                            Text('${_el.fontSize.toInt()} pt', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                            Expanded(
                              child: Slider(
                                value: _el.fontSize.clamp(8.0, 96.0),
                                min: 8.0,
                                max: 96.0,
                                activeColor: Colors.blueAccent,
                                onChanged: (v) => _update(_el.copyWith(fontSize: v)),
                              ),
                            ),
                          ],
                        ),

                        // Style & Alignment Toggles
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.format_bold, color: _el.isBold ? Colors.blueAccent : Colors.white38),
                              onPressed: () => _update(_el.copyWith(isBold: !_el.isBold)),
                            ),
                            IconButton(
                              icon: Icon(Icons.format_italic, color: _el.isItalic ? Colors.blueAccent : Colors.white38),
                              onPressed: () => _update(_el.copyWith(isItalic: !_el.isItalic)),
                            ),
                            const Spacer(),
                            ToggleButtons(
                              isSelected: [
                                _el.textAlign == TextAlignment.left,
                                _el.textAlign == TextAlignment.center,
                                _el.textAlign == TextAlignment.right,
                              ],
                              onPressed: (idx) {
                                final aligns = [TextAlignment.left, TextAlignment.center, TextAlignment.right];
                                _update(_el.copyWith(textAlign: aligns[idx]));
                              },
                              borderRadius: BorderRadius.circular(8),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
                              children: const [
                                Icon(Icons.format_align_left, size: 18),
                                Icon(Icons.format_align_center, size: 18),
                                Icon(Icons.format_align_right, size: 18),
                              ],
                            ),
                          ],
                        ),

                        // Auto-shrink Switch
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Auto-Shrink to Fit Box Width', style: TextStyle(fontSize: 13, color: Colors.white)),
                          subtitle: const Text('Scales font down automatically to prevent text clipping', style: TextStyle(fontSize: 11, color: Colors.white38)),
                          value: _el.autoShrinkToFit,
                          onChanged: (v) => _update(_el.copyWith(autoShrinkToFit: v)),
                        ),
                        const SizedBox(height: 14),

                        // Text Color Picker
                        ColorPalettePicker(
                          initialColorHex: _el.colorHex,
                          onColorSelected: (hex) => _update(_el.copyWith(colorHex: hex)),
                        ),
                      ],

                      // Photo Specific Controls
                      if (_el.type == CanvasElementType.photo) ...[
                        const Text('Photo Clipping Shape', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                        const SizedBox(height: 8),
                        SegmentedButton<PhotoClippingShape>(
                          segments: const [
                            ButtonSegment(value: PhotoClippingShape.rectangle, label: Text('Rect')),
                            ButtonSegment(value: PhotoClippingShape.roundedRectangle, label: Text('Rounded')),
                            ButtonSegment(value: PhotoClippingShape.circle, label: Text('Circle')),
                          ],
                          selected: {_el.clippingShape},
                          onSelectionChanged: (set) {
                            _update(_el.copyWith(clippingShape: set.first));
                          },
                        ),
                        if (_el.clippingShape == PhotoClippingShape.roundedRectangle) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text('Corner Radius: ', style: TextStyle(fontSize: 12, color: Colors.white70)),
                              Text('${_el.borderRadius.toInt()} px', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                              Expanded(
                                child: Slider(
                                  value: _el.borderRadius.clamp(2.0, 50.0),
                                  min: 2.0,
                                  max: 50.0,
                                  onChanged: (v) => _update(_el.copyWith(borderRadius: v)),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.crop_original, color: Colors.greenAccent, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text('BoxFit.cover Center-Crop enforced to eliminate portrait distortion', style: TextStyle(fontSize: 11, color: Colors.white70)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // QR Code Specific Controls
                      if (_el.type == CanvasElementType.qr) ...[
                        const Text('Edge Redirector URL Pattern', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                        const SizedBox(height: 6),
                        TextFormField(
                          initialValue: _el.qrUrlPattern,
                          decoration: const InputDecoration(
                            hintText: 'https://verify.school.edu/c/{{cert_code}}',
                            isDense: true,
                          ),
                          onChanged: (val) => _update(_el.copyWith(qrUrlPattern: val)),
                        ),
                        const SizedBox(height: 14),
                        ColorPalettePicker(
                          initialColorHex: _el.qrForegroundColorHex,
                          onColorSelected: (hex) => _update(_el.copyWith(qrForegroundColorHex: hex)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Divider(color: Color(0xFF334155), height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFF87171), size: 18),
                    label: const Text('Delete Element', style: TextStyle(color: Color(0xFFF87171))),
                  ),
                  ElevatedButton(
                    onPressed: widget.onClose,
                    child: const Text('Apply Changes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
