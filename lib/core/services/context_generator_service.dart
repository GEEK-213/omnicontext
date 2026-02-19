import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:omnicontext/core/services/git_watcher_service.dart';

part 'context_generator_service.g.dart';

@Riverpod(keepAlive: true)
ContextGeneratorService contextGeneratorService(
  ContextGeneratorServiceRef ref,
) {
  final gitWatcher = ref.watch(gitWatcherServiceProvider);
  return ContextGeneratorService(gitWatcher);
}

class ContextGeneratorService {
  final GitWatcherService _gitWatcher;

  ContextGeneratorService(this._gitWatcher);

  Future<String> generateContextPrompt(
    String projectPath, {
    String? figmaUrl,
    bool deepScan = false,
  }) async {
    final branch = await _gitWatcher.getCurrentBranch(projectPath);

    final figmaLine = figmaUrl != null && figmaUrl.isNotEmpty
        ? '\n- Figma Design: $figmaUrl'
        : '';

    String recentWork = '';
    if (deepScan) {
      try {
        recentWork = await _scanRecentChanges(projectPath);
      } catch (e) {
        recentWork = '\n\n--- RECENT WORK (SCAN FAILED) ---\nError: $e';
      }
    }

    return '''
--- BEGIN PROJECT CONTEXT ---
Project: $projectPath
Branch: ${branch ?? 'Not a repo'}
System: Windows 11$figmaLine
$recentWork
--- END CONTEXT ---''';
  }

  Future<String> _scanRecentChanges(String projectPath) async {
    final dir = Directory(projectPath);
    if (!await dir.exists()) return '';

    // Find .dart files modified in last 24 hours
    final now = DateTime.now();
    final oneDayAgo = now.subtract(const Duration(hours: 24));

    List<FileSystemEntity> recentFiles = [];

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        try {
          final stat = await entity.stat();
          if (stat.modified.isAfter(oneDayAgo)) {
            recentFiles.add(entity);
          }
        } catch (e) {
          // Ignore access errors
        }
      }
    }

    // Sort by modification time (newest first)
    recentFiles.sort((a, b) {
      return b.statSync().modified.compareTo(a.statSync().modified);
    });

    // Take top 5
    final topFiles = recentFiles.take(5);

    if (topFiles.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('\n--- RECENT WORK (AUTO-SCANNED) ---');
    buffer.writeln('Files modified in the last 24 hours (Top 5):');

    for (final file in topFiles) {
      if (file is File) {
        final path = file.path.replaceFirst(projectPath, '');
        buffer.writeln('\n[File: $path]');
        try {
          final content = await file.readAsString();
          // Truncate if too long (optional, but good for safety)
          if (content.length > 5000) {
            buffer.writeln('${content.substring(0, 5000)}\n... (truncated)');
          } else {
            buffer.writeln(content);
          }
        } catch (e) {
          buffer.writeln('(Error reading content)');
        }
      }
    }

    return buffer.toString();
  }
}
