import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'git_watcher_service.g.dart';

@Riverpod(keepAlive: true)
GitWatcherService gitWatcherService(GitWatcherServiceRef ref) {
  return GitWatcherService();
}

class GitWatcherService {
  Future<String?> getCurrentBranch(String projectPath) async {
    try {
      final gitDir = Directory(p.join(projectPath, '.git'));
      if (!await gitDir.exists()) {
        return null;
      }

      final headFile = File(p.join(gitDir.path, 'HEAD'));
      if (!await headFile.exists()) {
        return null;
      }

      final content = await headFile.readAsString();
      final trimmed = content.trim();

      if (trimmed.startsWith('ref: refs/heads/')) {
        return trimmed.replaceFirst('ref: refs/heads/', '');
      }

      // If needed, we could return the hash for detached HEAD,
      // but for now we follow the specific instruction to parse the ref.
      return null;
    } catch (e) {
      // Gracefully handle permission errors or other FS exceptions
      return null;
    }
  }
}
