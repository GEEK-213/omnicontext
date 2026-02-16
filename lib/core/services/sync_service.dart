import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_service.g.dart';

@Riverpod(keepAlive: true)
SyncService syncService(SyncServiceRef ref) {
  return SyncService();
}

class SyncService {
  Stream<Map<String, dynamic>> watchSyncEvents(String projectPath) {
    // We watch .antigravity/sync_events.json
    // Ideally we'd watch the file itself, but FileSystemWatcher on Windows can be flaky for single files sometimes,
    // watching the directory is safer.

    final syncDir = p.join(projectPath, '.antigravity');
    final syncFile = p.join(syncDir, 'sync_events.json');
    final directory = Directory(syncDir);

    if (!directory.existsSync()) {
      return const Stream.empty();
    }

    // Initialize controller for stream
    final controller = StreamController<Map<String, dynamic>>();

    final watcher = directory.watch(events: FileSystemEvent.modify);

    final subscription = watcher.listen((event) async {
      if (event.path.endsWith('sync_events.json')) {
        try {
          final file = File(syncFile);
          if (file.existsSync()) {
            final content = await file.readAsString();
            if (content.isNotEmpty) {
              final json = jsonDecode(content) as Map<String, dynamic>;
              controller.add(json);
            }
          }
        } catch (e) {
          debugPrint('Error reading sync file: $e');
        }
      }
    });

    controller.onCancel = () {
      subscription.cancel();
    };

    return controller.stream;
  }
}

@riverpod
Stream<Map<String, dynamic>> syncEvents(SyncEventsRef ref) {
  final service = ref.watch(syncServiceProvider);
  final projectPath = Directory.current.path;
  return service.watchSyncEvents(projectPath);
}
