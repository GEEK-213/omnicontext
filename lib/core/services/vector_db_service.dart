import 'dart:io';

import 'package:omnicontext/core/models/code_chunk.dart';
import 'package:omnicontext/objectbox.g.dart'; // Created by `flutter pub run build_runner build`
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vector_db_service.g.dart';

@Riverpod(keepAlive: true)
class VectorDbService extends _$VectorDbService {
  Store? _store;
  Box<CodeChunk>? _box;

  @override
  Future<void> build() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final storePath = p.join(docsDir.path, 'omnicontext_vector_db');

    // Ensure directory exists
    if (!Directory(storePath).existsSync()) {
      Directory(storePath).createSync(recursive: true);
    }

    // Initialize Store
    _store = await openStore(directory: storePath);
    _box = _store!.box<CodeChunk>();

    ref.onDispose(() {
      _store?.close();
    });
  }

  // Add or Update a chunk
  Future<int> addChunk(CodeChunk chunk) async {
    if (_box == null) await future; // Wait for init
    return _box!.put(chunk);
  }

  // Add multiple chunks for speed
  Future<List<int>> addChunks(List<CodeChunk> chunks) async {
    if (_box == null) await future;
    return _box!.putMany(chunks);
  }

  // Search using Vector (HNSW)
  // Note: ObjectBox standard vector search API
  Future<List<CodeChunk>> search(
    List<double> queryVector, {
    int limit = 5,
  }) async {
    if (_box == null) await future;

    // Create query
    final query = _box!
        .query(CodeChunk_.embedding.nearestNeighborsF32(queryVector, limit))
        .build();

    final results = query.find();
    query.close();
    return results;
  }

  // Clear DB (for re-indexing)
  Future<void> clear() async {
    if (_box == null) await future;
    _box!.removeAll();
  }

  // Count
  int get count {
    return _box?.count() ?? 0;
  }
}
