import 'dart:io';

import 'package:omnicontext/core/database/db_helper.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:omnicontext/core/services/vector_db_service.dart';
import 'package:omnicontext/core/services/embedding_service.dart';
import 'package:omnicontext/core/models/code_chunk.dart';
import 'package:omnicontext/core/services/git_service.dart';

part 'context_repository.g.dart';

@Riverpod(keepAlive: true)
ContextRepository contextRepository(ContextRepositoryRef ref) {
  return ContextRepository(ref);
}

@riverpod
Future<List<Map<String, dynamic>>> recentSnapshots(
  RecentSnapshotsRef ref,
) async {
  final repo = ref.watch(contextRepositoryProvider);
  return repo.getRecentSnapshots();
}

class ContextRepository {
  final ContextRepositoryRef _ref;
  final _dbHelper = DatabaseHelper();
  final _uuid = const Uuid();

  ContextRepository(this._ref);

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

  // --- FTS5 Search Logic ---

  Future<int> indexGitFiles(String projectPath) async {
    final gitService = _ref.read(gitServiceProvider);
    final files = await gitService.getTrackedFiles(projectPath);

    final List<File> dartFiles = [];
    for (final path in files) {
      // git paths are relative, e.g. "lib/main.dart"
      final file = File('$projectPath${Platform.pathSeparator}$path');
      if (file.path.endsWith('.dart') &&
          !file.path.contains('.g.dart') &&
          !file.path.contains('.freezed.dart')) {
        dartFiles.add(file);
      }
    }

    return _indexFiles(dartFiles);
  }

  Future<int> indexLocalFiles(String projectPath) async {
    final dir = Directory(projectPath);
    if (!await dir.exists()) {
      return 0;
    }

    // 1. Scan .dart files
    final List<File> dartFiles = [];
    await _scanDirectory(dir, dartFiles);

    return _indexFiles(dartFiles);
  }

  Future<int> _indexFiles(List<File> dartFiles) async {
    final vectorDb = _ref.read(vectorDbServiceProvider.notifier);
    final embeddingService = _ref.read(embeddingServiceProvider.notifier);

    // 2. Sort by last modified (newest first) & take top 10 to avoid excessive API limits
    dartFiles.sort(
      (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
    );
    final topFiles = dartFiles.take(15).toList();

    // 3. Re-build Index (Clear old vectors)
    await vectorDb.clear();

    int indexedCount = 0;

    for (final file in topFiles) {
      try {
        final content = await file.readAsString();
        if (content.trim().isEmpty) continue;

        // Restrict chunk sizes to standard window to respect prompt tokens and rate limits.
        final chunkText = content.length > 2000
            ? content.substring(0, 2000)
            : content;

        final embedding = await embeddingService.getEmbedding(chunkText);

        await vectorDb.addChunk(
          CodeChunk(
            filePath: file.path,
            content: chunkText,
            embedding: embedding,
          ),
        );

        indexedCount++;
        // Very slight artificial delay to gracefully respect potential API rate bounds.
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        print('Error indexing ${file.path}: $e');
        if (e.toString().contains('API Key')) {
          rethrow; // Elevate critical auth errors
        }
      }
    }

    return indexedCount;
  }

  Future<void> _scanDirectory(Directory dir, List<File> dartFiles) async {
    const ignoreList = [
      'build',
      '.git',
      '.dart_tool',
      'node_modules',
      'android',
      'ios',
      'windows',
      'macos',
      'linux',
    ];

    try {
      final entities = dir.list(recursive: false, followLinks: false);
      await for (final entity in entities) {
        if (entity is File) {
          if (entity.path.endsWith('.dart') &&
              !entity.path.contains('.g.dart') &&
              !entity.path.contains('.freezed.dart')) {
            dartFiles.add(entity);
          }
        } else if (entity is Directory) {
          final name = entity.uri.pathSegments.lastWhere(
            (s) => s.isNotEmpty,
            orElse: () => '',
          );
          // Smart Ignore List
          if (!ignoreList.contains(name) && !name.startsWith('.')) {
            await _scanDirectory(entity, dartFiles);
          }
        }
      }
    } catch (e) {
      print('Error scanning directory ${dir.path}: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchCodebase(String query) async {
    if (query.trim().isEmpty) return [];

    final vectorDb = _ref.read(vectorDbServiceProvider.notifier);
    final embeddingService = _ref.read(embeddingServiceProvider.notifier);

    try {
      final queryEmbedding = await embeddingService.getEmbedding(query);
      final results = await vectorDb.search(queryEmbedding, limit: 10);

      return results.map((chunk) {
        return {
          'file_path': chunk.filePath,
          'match_snippet': chunk.content.length > 150
              ? '${chunk.content.substring(0, 150).replaceAll('\n', ' ')}...'
              : chunk.content.replaceAll('\n', ' '),
          'full_snippet':
              chunk.content, // Provide full snippet if the UI needs it
        };
      }).toList();
    } catch (e) {
      print('Semantic Search Error: $e');
      throw Exception('Search failed: $e');
    }
  }
}
