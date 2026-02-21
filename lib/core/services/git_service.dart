import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'git_service.g.dart';

@Riverpod(keepAlive: true)
GitService gitService(GitServiceRef ref) {
  return GitService();
}

class GitService {
  Future<List<String>> getBranches(String projectPath) async {
    try {
      final result = await Process.run('git', [
        'branch',
        '--list',
      ], workingDirectory: projectPath);
      if (result.exitCode != 0) return [];

      final lines = (result.stdout as String).split('\n');
      return lines
          .where((l) => l.trim().isNotEmpty)
          .map(
            (l) => l.trim().replaceAll('* ', ''),
          ) // Remove current branch marker
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<String> getCurrentBranch(String projectPath) async {
    try {
      final result = await Process.run('git', [
        'rev-parse',
        '--abbrev-ref',
        'HEAD',
      ], workingDirectory: projectPath);
      if (result.exitCode != 0) return 'HEAD';
      return (result.stdout as String).trim();
    } catch (e) {
      return 'HEAD';
    }
  }

  Future<List<String>> getTrackedFiles(String projectPath) async {
    try {
      final result = await Process.run('git', [
        'ls-files',
      ], workingDirectory: projectPath);
      if (result.exitCode != 0) return [];
      final lines = (result.stdout as String).split('\n');
      return lines.where((l) => l.trim().isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  Future<String> getStagedDiff(String projectPath) async {
    try {
      final result = await Process.run('git', [
        'diff',
        '--cached',
      ], workingDirectory: projectPath);

      if (result.exitCode != 0) return '';
      return (result.stdout as String).trim();
    } catch (e) {
      return '';
    }
  }
}
