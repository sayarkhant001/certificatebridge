import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

enum FontCategory {
  english,
  myanmarUnicode,
  myanmarWin,
}

class AppFontInfo {
  final String name;
  final String family;
  final FontCategory category;
  final String path;
  final bool isAsset;

  AppFontInfo({
    required this.name,
    required this.family,
    required this.category,
    required this.path,
    this.isAsset = false,
  });
}

class FontManager {
  static final FontManager _instance = FontManager._internal();
  factory FontManager() => _instance;
  FontManager._internal();

  final Map<String, AppFontInfo> _registeredFonts = {};
  final Set<String> _loadedFontFamilies = {};

  List<AppFontInfo> get availableFonts => _registeredFonts.values.toList();

  List<AppFontInfo> get englishFonts => _registeredFonts.values
      .where((f) => f.category == FontCategory.english)
      .toList();

  List<AppFontInfo> get myanmarUnicodeFonts => _registeredFonts.values
      .where((f) => f.category == FontCategory.myanmarUnicode)
      .toList();

  List<AppFontInfo> get myanmarWinFonts => _registeredFonts.values
      .where((f) => f.category == FontCategory.myanmarWin)
      .toList();

  /// Initialize default known fonts and scan directories
  Future<void> initialize({List<String>? additionalDirectories}) async {
    _registerDefaultFonts();

    if (kIsWeb) {
      try {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        final assets = manifest.listAssets();
        for (final assetPath in assets) {
          if (assetPath.startsWith('assets/fonts/') &&
              (assetPath.endsWith('.ttf') || assetPath.endsWith('.otf'))) {
            final filename = p.basenameWithoutExtension(assetPath);
            final family = _cleanFamilyName(filename);
            final category = _categorizeFont(assetPath);
            _addFont(AppFontInfo(
              name: family,
              family: family,
              category: category,
              path: assetPath,
              isAsset: true,
            ));
          }
        }
      } catch (_) {
        // Fallback gracefully on web
      }
      return;
    }

    // Automatically scan the bundled asset font directories on the filesystem
    final defaultAssetDirs = [
      'assets/fonts/Myanmar_Unicode',
      'assets/fonts/Myanmar_WinFonts',
      'assets/fonts/English',
      'assets/fonts',
    ];

    for (final dir in defaultAssetDirs) {
      await scanDirectory(dir);
    }

    // Scan additional directories if provided
    if (additionalDirectories != null) {
      for (final dir in additionalDirectories) {
        await scanDirectory(dir);
      }
    }
  }

  void _registerDefaultFonts() {
    _addFont(AppFontInfo(
      name: 'Roboto',
      family: 'Roboto',
      category: FontCategory.english,
      path: 'assets/fonts/English/Roboto-Regular.ttf',
      isAsset: true,
    ));

    _addFont(AppFontInfo(
      name: 'Cinzel (Serif)',
      family: 'Cinzel',
      category: FontCategory.english,
      path: 'assets/fonts/English/Cinzel-Regular.ttf',
      isAsset: true,
    ));

    _addFont(AppFontInfo(
      name: 'Padauk',
      family: 'Padauk',
      category: FontCategory.myanmarUnicode,
      path: 'assets/fonts/Myanmar_Unicode/Padauk-Regular.ttf',
      isAsset: true,
    ));

    _addFont(AppFontInfo(
      name: 'Pyidaungsu',
      family: 'Pyidaungsu',
      category: FontCategory.myanmarUnicode,
      path: 'assets/fonts/Myanmar_Unicode/Pyidaungsu-2.5_Regular.ttf',
      isAsset: true,
    ));

    _addFont(AppFontInfo(
      name: 'WinInnwa (Win Font)',
      family: 'WinInnwa',
      category: FontCategory.myanmarWin,
      path: 'assets/fonts/Myanmar_WinFonts/WinInnwa.ttf',
      isAsset: true,
    ));
  }

  void _addFont(AppFontInfo font) {
    _registeredFonts[font.family] = font;
  }

  /// Scans a local filesystem folder for .ttf and .otf font files
  Future<void> scanDirectory(String directoryPath) async {
    if (kIsWeb) return;
    final dir = Directory(directoryPath);
    if (!await dir.exists()) return;

    final files = dir.listSync(recursive: true);
    for (final entity in files) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (ext == '.ttf' || ext == '.otf') {
          await registerExternalFontFile(entity);
        }
      }
    }
  }

  /// Dynamically register a font file with Flutter's FontLoader runtime
  Future<void> registerExternalFontFile(File fontFile) async {
    if (kIsWeb) return;
    final filename = p.basenameWithoutExtension(fontFile.path);
    final ext = p.extension(fontFile.path).toLowerCase();
    if (ext != '.ttf' && ext != '.otf') return;

    final family = _cleanFamilyName(filename);
    if (_loadedFontFamilies.contains(family)) return;

    try {
      final bytes = await fontFile.readAsBytes();
      final fontLoader = FontLoader(family);
      fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
      await fontLoader.load();
      _loadedFontFamilies.add(family);

      final category = _categorizeFont(family);
      _addFont(AppFontInfo(
        name: family,
        family: family,
        category: category,
        path: fontFile.path,
        isAsset: false,
      ));
    } catch (e) {
      // Graceful fallback if runtime load encounters error
    }
  }

  /// Reads font raw byte data for PDF embedding
  Future<Uint8List?> getFontBytes(String familyName) async {
    final fontInfo = _registeredFonts[familyName];
    if (fontInfo == null) return null;

    if (fontInfo.isAsset) {
      try {
        final byteData = await rootBundle.load(fontInfo.path);
        return byteData.buffer.asUint8List();
      } catch (_) {
        return null;
      }
    } else {
      if (kIsWeb) return null;
      final file = File(fontInfo.path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    }
  }

  FontCategory _categorizeFont(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('win') || lower.contains('innwa') || lower.contains('mon')) {
      return FontCategory.myanmarWin;
    }
    if (lower.contains('padauk') ||
        lower.contains('pyidaungsu') ||
        lower.contains('myanmar') ||
        lower.contains('noto')) {
      return FontCategory.myanmarUnicode;
    }
    return FontCategory.english;
  }

  String _cleanFamilyName(String filename) {
    return filename
        .replaceAll('-Regular', '')
        .replaceAll('-Bold', '')
        .replaceAll('_', ' ')
        .trim();
  }
}
