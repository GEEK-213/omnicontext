import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(docsDir.path, 'omnicontext.db');
    
    // Ensure the directory exists
    final dbFile = File(dbPath);
    if (!await dbFile.parent.exists()) {
      await dbFile.parent.create(recursive: true);
    }

    final db = sqlite3.open(dbPath);
    
    _createTables(db);
    
    return db;
  }

  void _createTables(Database db) {
    db.execute('''
      -- 1. USERS (For Team Sync)
      CREATE TABLE IF NOT EXISTS users (
          id TEXT PRIMARY KEY, -- UUID
          username TEXT NOT NULL,
          email TEXT UNIQUE, -- Encrypted locally
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );

      -- 2. PROJECTS (Your VS Code Workspaces)
      CREATE TABLE IF NOT EXISTS projects (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          local_path TEXT NOT NULL, -- "C:/Users/Faaris/Code/LumenAI"
          git_repo_url TEXT,
          figma_file_key TEXT, -- The ID from the Figma URL
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );

      -- 3. CONTEXT_SNAPSHOTS (The "Memory" Layer)
      CREATE TABLE IF NOT EXISTS context_snapshots (
          id TEXT PRIMARY KEY,
          project_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          git_branch TEXT,
          git_commit_hash TEXT,
          active_file_path TEXT, -- "lib/screens/login.dart"
          ai_model_used TEXT, -- "Gemini 1.5 Flash", "Claude 3.5"
          summary_text TEXT, -- "Fixed the auth loop bug"
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY(project_id) REFERENCES projects(id)
      );

      -- 4. CHAT_LOGS (Unified History)
      CREATE TABLE IF NOT EXISTS chat_logs (
          id TEXT PRIMARY KEY,
          snapshot_id TEXT,
          role TEXT CHECK(role IN ('user', 'assistant')),
          content TEXT NOT NULL, -- The actual chat message
          is_solution BOOLEAN DEFAULT 0, -- Checked if this fixed the bug
          FOREIGN KEY(snapshot_id) REFERENCES context_snapshots(id)
      );

      -- 5. JIRA_TASKS (The Collision Radar)
      CREATE TABLE IF NOT EXISTS jira_tasks (
          id TEXT PRIMARY KEY,
          project_id TEXT,
          jira_ticket_id TEXT, -- "PROJ-102"
          status TEXT, -- "In Progress", "Done"
          assigned_user_id TEXT,
          linked_file_path TEXT, -- "lib/auth_service.dart"
          last_updated DATETIME DEFAULT CURRENT_TIMESTAMP
      );
    ''');
  }

  void close() {
    _database?.dispose();
    _database = null;
  }
}
