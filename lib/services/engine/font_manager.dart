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

    // 1. Load from Flutter AssetManifest across all platforms (Web and Desktop)
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();
      for (final assetPath in assets) {
        if (assetPath.startsWith('assets/fonts/') &&
            (assetPath.endsWith('.ttf') || assetPath.endsWith('.otf'))) {
          final filename = p.basenameWithoutExtension(assetPath);
          final family = _cleanFamilyName(filename);
          final category = _categorizeFontByPath(assetPath, family);
          _addFont(AppFontInfo(
            name: family,
            family: family,
            category: category,
            path: assetPath,
            isAsset: true,
          ));
        }
      }
    } catch (e) {
      debugPrint('AssetManifest font loading note: $e');
    }

    // 2. Also scan disk paths on native desktop
    if (!kIsWeb) {
      final possibleDirs = <String>[
        'assets/fonts/Myanmar_Unicode',
        'assets/fonts/Myanmar_WinFonts',
        'assets/fonts/English',
        'assets/fonts',
      ];
      try {
        final exeDir = p.dirname(Platform.resolvedExecutable);
        possibleDirs.add(p.join(exeDir, 'data', 'flutter_assets', 'assets', 'fonts', 'Myanmar_Unicode'));
        possibleDirs.add(p.join(exeDir, 'data', 'flutter_assets', 'assets', 'fonts', 'Myanmar_WinFonts'));
        possibleDirs.add(p.join(exeDir, 'data', 'flutter_assets', 'assets', 'fonts', 'English'));
        possibleDirs.add(p.join(exeDir, 'data', 'flutter_assets', 'assets', 'fonts'));
        possibleDirs.add(p.join(Directory.current.path, 'assets', 'fonts'));
      } catch (_) {}

      for (final dir in possibleDirs) {
        await scanDirectory(dir);
      }
    }

    // Scan additional directories if provided
    if (additionalDirectories != null) {
      for (final dir in additionalDirectories) {
        await scanDirectory(dir);
      }
    }
  }

  /// Ensure font is registered dynamically with Flutter's FontLoader runtime
  Future<void> ensureFontLoaded(AppFontInfo font) async {
    if (_loadedFontFamilies.contains(font.family)) return;
    try {
      final fontLoader = FontLoader(font.family);
      if (font.isAsset) {
        fontLoader.addFont(rootBundle.load(font.path));
      } else {
        final file = File(font.path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          fontLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
        } else {
          return;
        }
      }
      await fontLoader.load();
      _loadedFontFamilies.add(font.family);
    } catch (_) {}
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

      final category = _categorizeFontByPath(fontFile.path, family);
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

  FontCategory _categorizeFontByPath(String path, String name) {
    final pathNormalized = path.replaceAll('\\', '/').toLowerCase();
    if (pathNormalized.contains('myanmar_unicode')) {
      return FontCategory.myanmarUnicode;
    }
    if (pathNormalized.contains('myanmar_winfonts') || pathNormalized.contains('winfonts')) {
      return FontCategory.myanmarWin;
    }
    if (pathNormalized.contains('english')) {
      return FontCategory.english;
    }

    final lower = name.toLowerCase();
    if (lower.contains('win') || lower.contains('innwa') || lower.contains('mon') || lower.contains('zawgyi')) {
      return FontCategory.myanmarWin;
    }
    if (lower.contains('padauk') ||
        lower.contains('pyidaungsu') ||
        lower.contains('myanmar') ||
        lower.contains('noto') ||
        lower.contains('ayar') ||
        lower.contains('masterpiece') ||
        lower.contains('tharlon') ||
        lower.contains('walone')) {
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
