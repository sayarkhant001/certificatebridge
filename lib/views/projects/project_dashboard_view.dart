import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/project_model.dart';
import '../../services/database/project_repository.dart';
import '../../services/project/project_export_service.dart';
import '../../services/project/project_import_service.dart';
import '../designer/visual_canvas_view.dart';
import '../setup/setup_wizard_dialog.dart';
import 'widgets/new_project_dialog.dart';
import 'widgets/project_card.dart';

class ProjectDashboardView extends StatefulWidget {
  const ProjectDashboardView({Key? key}) : super(key: key);

  @override
  State<ProjectDashboardView> createState() => _ProjectDashboardViewState();
}

class _ProjectDashboardViewState extends State<ProjectDashboardView> {
  final ProjectRepository _projectRepo = ProjectRepository();
  final ProjectExportService _exportService = ProjectExportService();
  final ProjectImportService _importService = ProjectImportService();

  List<ProjectModel> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _isLoading = true);
    final list = await _projectRepo.getAllProjects();
    setState(() {
      _projects = list;
      _isLoading = false;
    });
  }

  Future<void> _handleCreateProject() async {
    final newProject = await showDialog<ProjectModel>(
      context: context,
      builder: (_) => const NewProjectDialog(),
    );

    if (newProject != null) {
      await _projectRepo.insertProject(newProject);
      await _loadProjects();
      _openProject(newProject);
    }
  }

  Future<void> _handleImportBundle() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['cbproj', 'zip'],
    );

    if (result != null && result.files.single.path != null) {
      final bundleFile = File(result.files.single.path!);
      final bundleBytes = await bundleFile.readAsBytes();

      final appDir = await getApplicationDocumentsDirectory();
      final targetDir = p.join(appDir.path, 'CertiBridge', 'projects', const Uuid().v4());

      try {
        final imported = await _importService.importBundle(bundleBytes, targetDir);
        await _loadProjects();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Project "${imported.name}" imported! Connect your Google Sheet or Excel dataset to continue.'),
              backgroundColor: const Color(0xFF059669),
              duration: const Duration(seconds: 4),
            ),
          );
          _openProject(imported);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import Failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handleExportBundle(ProjectModel project) async {
    try {
      final templateFiles = <File>[];
      if (project.templatePath != null) {
        final bg = File(project.templatePath!);
        if (bg.existsSync()) templateFiles.add(bg);
      }

      // Collect fonts if stored in project or bundle
      final usedFonts = <File>[];

      final bundleBytes = await _exportService.exportBundle(
        project: project,
        templatePages: templateFiles,
        usedFonts: usedFonts,
      );

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export CertiBridge Bundle',
        fileName: '${project.name.replaceAll(' ', '_')}.cbproj',
        type: FileType.custom,
        allowedExtensions: ['cbproj'],
      );

      if (savePath != null) {
        await _exportService.saveBundleToFile(
          bundleBytes: bundleBytes,
          targetFilePath: savePath,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exported bundle: $savePath'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleCloneProject(ProjectModel project) async {
    final cloned = project.copyWith(
      id: const Uuid().v4(),
      name: '${project.name} (Copy)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _projectRepo.insertProject(cloned);
    await _loadProjects();
  }

  Future<void> _handleDeleteProject(ProjectModel project) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Project?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete "${project.name}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _projectRepo.deleteProject(project.id);
      await _loadProjects();
    }
  }

  void _openProject(ProjectModel project) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VisualCanvasView(project: project),
      ),
    ).then((_) => _loadProjects());
  }

  void _openSetupWizard() {
    showDialog(
      context: context,
      builder: (_) => const SetupWizardDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.workspace_premium, color: Color(0xFFFBBF24), size: 20),
            ),
            const SizedBox(width: 8),
            const Text('CertiBridge'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openSetupWizard,
            icon: const Icon(Icons.cloud_sync_outlined, size: 20, color: Color(0xFF60A5FA)),
            tooltip: 'BYOA Cloud Setup',
          ),
          const SizedBox(width: 4),
          OutlinedButton.icon(
            onPressed: _handleImportBundle,
            icon: const Icon(Icons.unarchive_outlined, size: 14),
            label: const Text('Import', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _handleCreateProject,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New Project', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? _buildEmptyState()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 360,
                      childAspectRatio: 0.95,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: _projects.length,
                    itemBuilder: (ctx, i) {
                      final proj = _projects[i];
                      return ProjectCard(
                        project: proj,
                        onOpen: () => _openProject(proj),
                        onExport: () => _handleExportBundle(proj),
                        onClone: () => _handleCloneProject(proj),
                        onDelete: () => _handleDeleteProject(proj),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF334155), width: 1.5),
            ),
            child: const Icon(Icons.workspace_premium_outlined, size: 64, color: Color(0xFF60A5FA)),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Certificate Projects Yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a new project workspace or import a portable .cbproj bundle.',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: _handleImportBundle,
                icon: const Icon(Icons.unarchive_outlined),
                label: const Text('Import Project Bundle'),
              ),
              const SizedBox(width: 14),
              ElevatedButton.icon(
                onPressed: _handleCreateProject,
                icon: const Icon(Icons.add),
                label: const Text('Create New Project'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
