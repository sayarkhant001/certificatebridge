import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/project_model.dart';

class ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback onOpen;
  final VoidCallback onExport;
  final VoidCallback onClone;
  final VoidCallback onDelete;

  const ProjectCard({
    Key? key,
    required this.project,
    required this.onOpen,
    required this.onExport,
    required this.onClone,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview Header
            Container(
              height: 140,
              width: double.infinity,
              color: const Color(0xFF0F172A),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (project.templatePath != null && File(project.templatePath!).existsSync())
                    Image.file(
                      File(project.templatePath!),
                      fit: BoxFit.cover,
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.workspace_premium_outlined, color: Colors.blueAccent.withOpacity(0.5), size: 48),
                          const SizedBox(height: 6),
                          const Text(
                            '.cbproj Bundle',
                            style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.confirmation_number_outlined, size: 12, color: Color(0xFFFBBF24)),
                          const SizedBox(width: 4),
                          Text(
                            '${project.totalCertificates} certs',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Card Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    project.description.isNotEmpty ? project.description : 'No description provided.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Updated: ${_formatDate(project.updatedAt)}',
                        style: const TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18, color: Colors.white54),
                        color: const Color(0xFF1E293B),
                        onSelected: (val) {
                          if (val == 'export') onExport();
                          if (val == 'clone') onClone();
                          if (val == 'delete') onDelete();
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'export',
                            child: Row(
                              children: [
                                Icon(Icons.archive_outlined, size: 16, color: Color(0xFF60A5FA)),
                                SizedBox(width: 8),
                                Text('Export Bundle (.cbproj)', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'clone',
                            child: Row(
                              children: [
                                Icon(Icons.copy, size: 16, color: Color(0xFF34D399)),
                                SizedBox(width: 8),
                                Text('Clone Project', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 16, color: Color(0xFFF87171)),
                                SizedBox(width: 8),
                                Text('Delete Project', style: TextStyle(fontSize: 13, color: Color(0xFFF87171))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
