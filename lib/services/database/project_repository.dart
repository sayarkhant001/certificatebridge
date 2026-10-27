import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import '../../models/project_model.dart';

class ProjectRepository {
  static Database? _database;

  static void initializeFfiIfNeeded() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    initializeFfiIfNeeded();
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'certibridge_projects.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE projects (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            total_certificates INTEGER DEFAULT 0,
            template_path TEXT,
            layout_json TEXT NOT NULL,
            display_config_json TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE cert_queue (
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            row_index INTEGER NOT NULL,
            raw_json TEXT NOT NULL,
            cert_code TEXT NOT NULL,
            short_url TEXT,
            local_pdf_path TEXT,
            drive_pdf_link TEXT,
            status TEXT NOT NULL,
            error_message TEXT,
            updated_at TEXT,
            FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  Future<void> insertProject(ProjectModel project) async {
    final db = await database;
    await db.insert(
      'projects',
      project.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ProjectModel>> getAllProjects() async {
    final db = await database;
    final maps = await db.query('projects', orderBy: 'updated_at DESC');
    return List.generate(maps.length, (i) => ProjectModel.fromMap(maps[i]));
  }

  Future<ProjectModel?> getProjectById(String id) async {
    final db = await database;
    final maps = await db.query('projects', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return ProjectModel.fromMap(maps.first);
  }

  Future<void> updateProject(ProjectModel project) async {
    final db = await database;
    await db.update(
      'projects',
      project.toMap(),
      where: 'id = ?',
      whereArgs: [project.id],
    );
  }

  Future<void> deleteProject(String id) async {
    final db = await database;
    await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }
}
