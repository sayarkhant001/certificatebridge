import 'package:flutter/material.dart';
import '../../../services/engine/font_manager.dart';

class FontPickerModal extends StatefulWidget {
  final String currentFontFamily;
  final ValueChanged<String> onFontSelected;

  const FontPickerModal({
    Key? key,
    required this.currentFontFamily,
    required this.onFontSelected,
  }) : super(key: key);

  @override
  State<FontPickerModal> createState() => _FontPickerModalState();
}

class _FontPickerModalState extends State<FontPickerModal> with SingleTickerProviderStateMixin {
  final FontManager _fontManager = FontManager();
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AppFontInfo> _filterFonts(List<AppFontInfo> fonts) {
    if (_searchQuery.trim().isEmpty) return fonts;
    final q = _searchQuery.toLowerCase().trim();
    return fonts.where((f) => f.name.toLowerCase().contains(q) || f.family.toLowerCase().contains(q)).toList();
  }

  Widget _buildFontList(List<AppFontInfo> fonts, {required bool isMyanmar}) {
    final filtered = _filterFonts(fonts);

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty ? 'No fonts found in this category' : 'No fonts match "$_searchQuery"',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final font = filtered[i];
        final isSelected = font.family == widget.currentFontFamily;
        _fontManager.ensureFontLoaded(font);

        final previewText = font.category == FontCategory.myanmarUnicode
            ? 'ဂုဏ်ထူးဆောင်လက်မှတ် (မောင်ကျော်ဇော - ၂၀၂၆)'
            : font.category == FontCategory.myanmarWin
                ? 'ဂုဏ်ထူးဆောင်လက်မှတ် (WinFont ABC)'
                : 'Certificate of Achievement (ABC 123)';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E3A8A).withOpacity(0.4) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    font.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: font.category == FontCategory.myanmarUnicode
                        ? const Color(0xFF065F46)
                        : font.category == FontCategory.myanmarWin
                            ? const Color(0xFF854D0E)
                            : const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    font.category == FontCategory.myanmarUnicode
                        ? 'MM Unicode'
                        : font.category == FontCategory.myanmarWin
                            ? 'Win Font'
                            : 'English',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                previewText,
                style: TextStyle(
                  fontFamily: font.family,
                  fontSize: 18,
                  color: const Color(0xFFE2E8F0),
                ),
              ),
            ),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: Color(0xFF38BDF8), size: 22)
                : const Icon(Icons.radio_button_unchecked, color: Colors.white30, size: 20),
            onTap: () {
              widget.onFontSelected(font.family);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mmUnicode = _fontManager.myanmarUnicodeFonts;
    final mmWin = _fontManager.myanmarWinFonts;
    final english = _fontManager.englishFonts;
    final allFonts = _fontManager.availableFonts;

    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 720,
        height: 620,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.font_download_outlined, color: Color(0xFF38BDF8), size: 24),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Typography & Font Library',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          'Choose from Myanmar Unicode, Win/Zawgyi, or English calligraphies',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Color(0xFF334155), height: 20),

            // Search Bar
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search fonts by name...',
                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.white60),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Colors.white60),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 12),

            // Category Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF38BDF8),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: '🇲🇲 Myanmar Unicode (${mmUnicode.length})'),
                Tab(text: '🇲🇲 Myanmar Win (${mmWin.length})'),
                Tab(text: '🔤 English (${english.length})'),
                Tab(text: '⭐ All (${allFonts.length})'),
              ],
            ),
            const SizedBox(height: 10),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFontList(mmUnicode, isMyanmar: true),
                  _buildFontList(mmWin, isMyanmar: true),
                  _buildFontList(english, isMyanmar: false),
                  _buildFontList(allFonts, isMyanmar: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
