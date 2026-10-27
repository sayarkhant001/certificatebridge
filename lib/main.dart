import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'services/database/project_repository.dart';
import 'services/engine/font_manager.dart';
import 'views/projects/project_dashboard_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI on desktop platforms (Windows, Linux, macOS)
  ProjectRepository.initializeFfiIfNeeded();

  // Initialize dynamic multi-script font manager
  await FontManager().initialize();

  runApp(const CertiBridgeApp());
}

class CertiBridgeApp extends StatelessWidget {
  const CertiBridgeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CertiBridge - Bulk Certificate Engine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const ProjectDashboardView(),
    );
  }
}
