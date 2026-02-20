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
    String strategy = 'local', // 'local' or 'git'
  }) async {
    final branch = await _gitWatcher.getCurrentBranch(projectPath);

    final figmaLine = figmaUrl != null && figmaUrl.isNotEmpty
        ? '\n- Figma Design: $figmaUrl'
        : '';

    String recentWork = '';
    if (deepScan) {
      try {
        if (strategy == 'git') {
          // TODO: Implement actual git diff reading. For now, we fan-out to local scan if git fails or is empty,
          // but strictly we should try git first.
          // recentWork = await _scanGitChanges(projectPath);
          recentWork = await _scanRecentChanges(
            projectPath,
          ); // Fallback for now until GitService is upgraded
        } else {
          recentWork = await _scanRecentChanges(projectPath);
        }
      } catch (e) {
        recentWork = '\n\n--- RECENT WORK (SCAN FAILED) ---\nError: $e';
      }
    }

    return '''
--- BEGIN PROJECT CONTEXT ---
Project: $projectPath
Branch: ${branch ?? 'Not a repo'}
Strategy: $strategy
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
    final topFiles = recentFiles.take(5).toList();

    if (topFiles.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('\n--- RECENT WORK (AUTO-SCANNED) ---');
    buffer.writeln('Files modified in the last 24 hours (Top 5):');

    // ── Step 1: Read all file contents and build a combined batch string ──────
    final batchBuffer = StringBuffer();
    final Map<String, String> fileContents = {}; // relativePath → content

    for (final file in topFiles) {
      if (file is File) {
        final relativePath = file.path.replaceFirst(projectPath, '');
        try {
          final content = await file.readAsString();
          fileContents[relativePath] = content;
          // Format for the batch prompt
          batchBuffer.writeln('--- File: $relativePath ---');
          // Cap each file at 3 000 chars to keep the prompt manageable
          if (content.length > 3000) {
            batchBuffer.writeln(
              '${content.substring(0, 3000)}\n... (truncated)',
            );
          } else {
            batchBuffer.writeln(content);
          }
          batchBuffer.writeln();
        } catch (_) {
          fileContents[relativePath] = '(Error reading file)';
        }
      }
    }

    // ── Step 2: ONE single AI call for the entire batch ───────────────────────
    String? batchSummary;
    if (_aiSummarizer.isConfigured && batchBuffer.isNotEmpty) {
      final result = await _aiSummarizer.summarizeCode(batchBuffer.toString());
      if (!result.startsWith('Error')) {
        batchSummary = result;
      }
    }

    // ── Step 3: Write output — AI summary or individual raw fallbacks ─────────
    if (batchSummary != null) {
      buffer.writeln('\nAI BATCH SUMMARY (${fileContents.length} files):');
      buffer.writeln(batchSummary);
    } else {
      // Fallback: include raw contents per-file
      for (final entry in fileContents.entries) {
        buffer.writeln('\n[File: ${entry.key}]');
        final content = entry.value;
        if (content.length > 5000) {
          buffer.writeln('${content.substring(0, 5000)}\n... (truncated)');
        } else {
          buffer.writeln(content);
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
