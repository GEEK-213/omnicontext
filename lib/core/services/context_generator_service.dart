import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:omnicontext/core/services/git_watcher_service.dart';

import 'package:path/path.dart' as path;

import 'package:omnicontext/core/services/ai_summarizer_service.dart';

part 'context_generator_service.g.dart';

@Riverpod(keepAlive: true)
ContextGeneratorService contextGeneratorService(
  ContextGeneratorServiceRef ref,
) {
  final gitWatcher = ref.watch(gitWatcherServiceProvider);
  final aiSummarizer = ref.watch(aiSummarizerProvider.notifier);
  return ContextGeneratorService(gitWatcher, aiSummarizer);
}

class ContextGeneratorService {
  final GitWatcherService _gitWatcher;
  final AiSummarizer _aiSummarizer;

  ContextGeneratorService(this._gitWatcher, this._aiSummarizer);

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
    // 1. Scan the root project path (no longer restricted to lib/)
    final rootDir = Directory(projectPath);

    if (!await rootDir.exists()) {
      return '';
    }

    // Find .dart files modified in last 24 hours
    final now = DateTime.now();
    final oneDayAgo = now.subtract(const Duration(hours: 24));

    List<FileSystemEntity> recentFiles = [];

    // 2. Add Error Handling - Manual Recursion with Smart Ignore
    await _manualScan(rootDir, recentFiles, oneDayAgo);

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

    int processedCount = 0;
    for (final file in topFiles) {
      processedCount++;
      if (file is File) {
        final relativePath = file.path.replaceFirst(projectPath, '');
        buffer.writeln('\n[File: $relativePath]');

        try {
          final content = await file.readAsString();

          bool aiSuccess = false;
          if (_aiSummarizer.isConfigured) {
            final summary = await _aiSummarizer.summarizeCode(content);
            if (!summary.startsWith('Error')) {
              buffer.writeln('AI SUMMARY:');
              buffer.writeln(summary);
              aiSuccess = true;

              // Add delay to respect free tier limits
              if (processedCount < topFiles.length) {
                await Future.delayed(const Duration(seconds: 4));
              }
            } else {
              buffer.writeln('// AI ERROR: ${summary.split(':').last.trim()}');
            }
          }

          if (!aiSuccess) {
            // Fallback to raw code
            if (content.length > 5000) {
              buffer.writeln('${content.substring(0, 5000)}\n... (truncated)');
            } else {
              buffer.writeln(content);
            }
          }
        } catch (e) {
          buffer.writeln('(Error reading content)');
        }
      }
    }

    return buffer.toString();
  }

  Future<void> _manualScan(
    Directory dir,
    List<FileSystemEntity> recentFiles,
    DateTime cutoff,
  ) async {
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
            try {
              final stat = await entity.stat();
              if (stat.modified.isAfter(cutoff)) {
                recentFiles.add(entity);
              }
            } catch (_) {}
          }
        } else if (entity is Directory) {
          final name = entity.uri.pathSegments.lastWhere(
            (s) => s.isNotEmpty,
            orElse: () => '',
          );

          if (!ignoreList.contains(name) && !name.startsWith('.')) {
            await _manualScan(entity, recentFiles, cutoff);
          }
        }
      }
    } catch (e) {
      // Ignore access errors
    }
  }
}
