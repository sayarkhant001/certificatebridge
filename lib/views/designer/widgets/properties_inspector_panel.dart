import 'package:flutter/material.dart';
import '../../../models/canvas_element.dart';
import '../../../models/template_config.dart';
import '../../../services/engine/font_manager.dart';
import 'color_palette_picker.dart';
import 'font_picker_modal.dart';

class PropertiesInspectorPanel extends StatelessWidget {
  final CanvasElement? selectedElement;
  final TemplatePage currentPage;
  final List<String> availableHeaders;
  final ValueChanged<CanvasElement> onElementUpdated;
  final VoidCallback onDeleteElement;
  final VoidCallback onDuplicateElement;
  final VoidCallback onBringToFront;
  final VoidCallback onSendToBack;
  final VoidCallback onCenterHorizontal;
  final VoidCallback onCenterVertical;
  final VoidCallback onPickBackground;

  const PropertiesInspectorPanel({
    Key? key,
    required this.selectedElement,
    required this.currentPage,
    required this.availableHeaders,
    required this.onElementUpdated,
    required this.onDeleteElement,
    required this.onDuplicateElement,
    required this.onBringToFront,
    required this.onSendToBack,
    required this.onCenterHorizontal,
    required this.onCenterVertical,
    required this.onPickBackground,
  }) : super(key: key);

  void _openFontPicker(BuildContext context, CanvasElement el) {
    showDialog(
      context: context,
      builder: (_) => FontPickerModal(
        currentFontFamily: el.fontFamily,
        onFontSelected: (newFamily) {
          onElementUpdated(el.copyWith(fontFamily: newFamily));
        },
      ),
    );
  }

  void _openColorPicker(BuildContext context, String currentHex, ValueChanged<String> onSelected) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Choose Color', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: SizedBox(
          width: 320,
          child: ColorPalettePicker(
            initialColorHex: currentHex,
            onColorSelected: (newHex) {
              onSelected(newHex);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 290,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(left: BorderSide(color: Color(0xFF334155))),
      ),
      child: selectedElement == null
          ? _buildPageProperties(context)
          : _buildElementProperties(context, selectedElement!),
    );
  }

  Widget _buildPageProperties(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: Color(0xFF38BDF8), size: 20),
              SizedBox(width: 8),
              Text(
                'Canvas Page Settings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
              ),
            ],
          ),
          const Divider(color: Color(0xFF334155), height: 24),
          Text(
            'Resolution: ${currentPage.width.toInt()} × ${currentPage.height.toInt()} px',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 6),
          Text(
            'DPI: ${currentPage.dpi} &bull; Page Number: ${currentPage.pageNumber}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 6),
          Text(
            'Elements on Canvas: ${currentPage.elements.length}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onPickBackground,
            icon: const Icon(Icons.image_outlined, size: 16),
            label: const Text('Replace Background Underlay', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Row(
              children: [
                Icon(Icons.touch_app_outlined, color: Colors.white54, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Click any element on canvas to inspect & edit its options directly here.',
                    style: TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElementProperties(BuildContext context, CanvasElement el) {
    Color textColor;
    try {
      final hex = el.colorHex.replaceAll('#', '');
      textColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      textColor = Colors.black;
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Element Title & Type
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  el.type == CanvasElementType.text
                      ? Icons.text_fields
                      : el.type == CanvasElementType.photo
                          ? Icons.portrait
                          : Icons.qr_code,
                  color: const Color(0xFF38BDF8),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  el.type == CanvasElementType.text
                      ? 'Text Box Options'
                      : el.type == CanvasElementType.photo
                          ? 'Photo Box Options'
                          : 'QR Code Options',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFF87171), size: 20),
              onPressed: onDeleteElement,
              tooltip: 'Delete Element',
            ),
          ],
        ),
        const Divider(color: Color(0xFF334155), height: 16),

        // TEXT ELEMENT CONTROLS
        if (el.type == CanvasElementType.text) ...[
          // Text Content
          const Text('Text Content / Dynamic Formula', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey('text_${el.id}'),
            initialValue: el.text,
            maxLines: 2,
            style: const TextStyle(fontSize: 13, color: Colors.white),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'e.g. {{Student_Name}} or Certificate of Excellence',
            ),
            onChanged: (val) => onElementUpdated(el.copyWith(text: val)),
          ),
          const SizedBox(height: 8),

          // Dynamic Column Quick Inserters
          if (availableHeaders.isNotEmpty) ...[
            const Text('Insert Dynamic Column:', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: availableHeaders.map((header) {
                return InkWell(
                  onTap: () {
                    final newText = el.text.isEmpty ? '{{$header}}' : '${el.text} {{$header}}';
                    onElementUpdated(el.copyWith(text: newText, boundColumn: header));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                    ),
                    child: Text('+$header', style: const TextStyle(fontSize: 10, color: Color(0xFF38BDF8))),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Typography Section
          const Text('Font Family & Script', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _openFontPicker(context, el),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      el.fontFamily,
                      style: TextStyle(
                        fontFamily: el.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Font Size & Formatting
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Size (${el.fontSize.toInt()}pt)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                    Slider(
                      value: el.fontSize.clamp(8.0, 96.0),
                      min: 8.0,
                      max: 96.0,
                      divisions: 88,
                      activeColor: const Color(0xFF38BDF8),
                      onChanged: (val) => onElementUpdated(el.copyWith(fontSize: val)),
                    ),
                  ],
                ),
              ),
              // Color swatch button
              InkWell(
                onTap: () => _openColorPicker(context, el.colorHex, (hex) {
                  onElementUpdated(el.copyWith(colorHex: hex));
                }),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: textColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70, width: 2),
                  ),
                ),
              ),
            ],
          ),

          // Style Row (Bold, Italic, Alignment)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.format_bold),
                color: el.isBold ? const Color(0xFF38BDF8) : Colors.white38,
                onPressed: () => onElementUpdated(el.copyWith(isBold: !el.isBold)),
                tooltip: 'Bold',
              ),
              IconButton(
                icon: const Icon(Icons.format_italic),
                color: el.isItalic ? const Color(0xFF38BDF8) : Colors.white38,
                onPressed: () => onElementUpdated(el.copyWith(isItalic: !el.isItalic)),
                tooltip: 'Italic',
              ),
              IconButton(
                icon: const Icon(Icons.format_align_left),
                color: el.textAlign == TextAlignment.left ? const Color(0xFF38BDF8) : Colors.white38,
                onPressed: () => onElementUpdated(el.copyWith(textAlign: TextAlignment.left)),
                tooltip: 'Align Left',
              ),
              IconButton(
                icon: const Icon(Icons.format_align_center),
                color: el.textAlign == TextAlignment.center ? const Color(0xFF38BDF8) : Colors.white38,
                onPressed: () => onElementUpdated(el.copyWith(textAlign: TextAlignment.center)),
                tooltip: 'Align Center',
              ),
              IconButton(
                icon: const Icon(Icons.format_align_right),
                color: el.textAlign == TextAlignment.right ? const Color(0xFF38BDF8) : Colors.white38,
                onPressed: () => onElementUpdated(el.copyWith(textAlign: TextAlignment.right)),
                tooltip: 'Align Right',
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto Shrink Long Text to Fit Box', style: TextStyle(fontSize: 11, color: Colors.white70)),
            value: el.autoShrinkToFit,
            activeColor: const Color(0xFF38BDF8),
            onChanged: (v) => onElementUpdated(el.copyWith(autoShrinkToFit: v)),
          ),
        ],

        // PHOTO ELEMENT CONTROLS
        if (el.type == CanvasElementType.photo) ...[
          const Text('Clipping Shape', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Rectangle', style: TextStyle(fontSize: 10)),
                  selected: el.clippingShape == PhotoClippingShape.rectangle,
                  onSelected: (_) => onElementUpdated(el.copyWith(clippingShape: PhotoClippingShape.rectangle)),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Rounded', style: TextStyle(fontSize: 10)),
                  selected: el.clippingShape == PhotoClippingShape.roundedRectangle,
                  onSelected: (_) => onElementUpdated(el.copyWith(clippingShape: PhotoClippingShape.roundedRectangle)),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Circle', style: TextStyle(fontSize: 10)),
                  selected: el.clippingShape == PhotoClippingShape.circle,
                  onSelected: (_) => onElementUpdated(el.copyWith(clippingShape: PhotoClippingShape.circle)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Corner Radius (${el.borderRadius.toInt()}px)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
          Slider(
            value: el.borderRadius.clamp(0.0, 40.0),
            min: 0.0,
            max: 40.0,
            divisions: 40,
            activeColor: const Color(0xFF38BDF8),
            onChanged: (val) => onElementUpdated(el.copyWith(borderRadius: val)),
          ),
        ],

        // QR CODE CONTROLS
        if (el.type == CanvasElementType.qr) ...[
          const Text('Short Verification URL Pattern', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey('qr_${el.id}'),
            initialValue: el.qrUrlPattern,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: const InputDecoration(isDense: true, hintText: 'https://verify.school.edu/c/{{cert_code}}'),
            onChanged: (val) => onElementUpdated(el.copyWith(qrUrlPattern: val)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('QR Foreground Color', style: TextStyle(fontSize: 11, color: Colors.white70)),
              InkWell(
                onTap: () => _openColorPicker(context, el.qrForegroundColorHex, (hex) {
                  onElementUpdated(el.copyWith(qrForegroundColorHex: hex));
                }),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _parseHex(el.qrForegroundColorHex),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ],

        const Divider(color: Color(0xFF334155), height: 24),

        // QUICK ALIGNMENT ON CANVAS
        const Text('Align & Center on Canvas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCenterHorizontal,
                icon: const Icon(Icons.align_horizontal_center, size: 14),
                label: const Text('Center X', style: TextStyle(fontSize: 11)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCenterVertical,
                icon: const Icon(Icons.align_vertical_center, size: 14),
                label: const Text('Center Y', style: TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // LAYER ORDERING & DUPLICATE
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onBringToFront,
                icon: const Icon(Icons.flip_to_front, size: 14),
                label: const Text('Front', style: TextStyle(fontSize: 11)),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onSendToBack,
                icon: const Icon(Icons.flip_to_back, size: 14),
                label: const Text('Back', style: TextStyle(fontSize: 11)),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: Colors.white70),
              onPressed: onDuplicateElement,
              tooltip: 'Duplicate Element',
            ),
          ],
        ),
      ],
    );
  }

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.black;
    }
  }
}
