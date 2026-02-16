import 'package:omnicontext/core/database/db_helper.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'context_repository.g.dart';

@Riverpod(keepAlive: true)
ContextRepository contextRepository(ContextRepositoryRef ref) {
  return ContextRepository();
}

@riverpod
Future<List<Map<String, dynamic>>> recentSnapshots(
  RecentSnapshotsRef ref,
) async {
  final repo = ref.watch(contextRepositoryProvider);
  return repo.getRecentSnapshots();
}

class ContextRepository {
  final _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  Future<void> saveSnapshot({
    required String projectPath,
    required String branch,
    required String summary,
    String? figmaUrl,
  }) async {
    final db = await _dbHelper.database;

    // Ensure Default User Exists (Simulated for now)
    const userId = 'default-user-id';
    db.execute(
      '''
      INSERT OR IGNORE INTO users (id, username, email) 
      VALUES (?, ?, ?)
    ''',
      [userId, 'User', 'user@local.dev'],
    );

    // Ensure Project Exists
    // We use the projectPath as a simplified distinct key for now, or generate a UUID based on it.
    // Ideally we should look it up.
    // Let's check if project exists by path.
    final projectResult = db.select(
      'SELECT id FROM projects WHERE local_path = ?',
      [projectPath],
    );

    String projectId;
    if (projectResult.isEmpty) {
      projectId = _uuid.v4();
      db.execute(
        '''
        INSERT INTO projects (id, name, local_path) 
        VALUES (?, ?, ?)
      ''',
        [projectId, projectPath.split(r'\').last, projectPath],
      );
    } else {
      projectId = projectResult.first['id'] as String;
    }

    // Insert Snapshot
    final snapshotId = _uuid.v4();
    db.execute(
      '''
      INSERT INTO context_snapshots (id, project_id, user_id, git_branch, active_file_path, summary_text)
      VALUES (?, ?, ?, ?, ?, ?)
    ''',
      [snapshotId, projectId, userId, branch, 'dashboard', summary],
    );
  }

  Future<List<Map<String, dynamic>>> getRecentSnapshots() async {
    final db = await _dbHelper.database;
    final results = db.select('''
      SELECT * FROM context_snapshots 
      ORDER BY created_at DESC 
      LIMIT 10
    ''');
    return results;
  }
}
