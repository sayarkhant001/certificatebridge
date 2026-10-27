import 'package:flutter/material.dart';

class ColorPalettePicker extends StatefulWidget {
  final String initialColorHex;
  final ValueChanged<String> onColorSelected;

  const ColorPalettePicker({
    Key? key,
    required this.initialColorHex,
    required this.onColorSelected,
  }) : super(key: key);

  @override
  State<ColorPalettePicker> createState() => _ColorPalettePickerState();
}

class _ColorPalettePickerState extends State<ColorPalettePicker> {
  late TextEditingController _hexCtrl;
  late String _currentColor;

  static const List<Map<String, String>> presets = [
    {'name': 'Gold', 'hex': '#D97706'},
    {'name': 'Navy', 'hex': '#1E3A8A'},
    {'name': 'Crimson', 'hex': '#DC2626'},
    {'name': 'Emerald', 'hex': '#059669'},
    {'name': 'Charcoal', 'hex': '#1E293B'},
    {'name': 'White', 'hex': '#FFFFFF'},
    {'name': 'Deep Black', 'hex': '#000000'},
    {'name': 'Slate Gray', 'hex': '#64748B'},
  ];

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColorHex;
    _hexCtrl = TextEditingController(text: _currentColor);
  }

  void _selectHex(String hex) {
    setState(() {
      _currentColor = hex;
      _hexCtrl.text = hex;
    });
    widget.onColorSelected(hex);
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Color Palette & Swatches', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((preset) {
            final hex = preset['hex']!;
            final color = _parseColor(hex);
            final isSelected = _currentColor.toUpperCase() == hex.toUpperCase();

            return InkWell(
              onTap: () => _selectHex(hex),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? Colors.blueAccent : Colors.white24,
                    width: isSelected ? 2.5 : 1,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        size: 14,
                        color: hex == '#FFFFFF' ? Colors.black : Colors.white,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _parseColor(_currentColor),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white30),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _hexCtrl,
                  decoration: const InputDecoration(
                    hintText: '#1E3A8A',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  onChanged: (val) {
                    if (val.startsWith('#') && (val.length == 7 || val.length == 9)) {
                      _selectHex(val);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
