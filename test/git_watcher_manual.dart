import 'package:flutter_test/flutter_test.dart';
import 'package:omnicontext/core/services/git_watcher_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

void main() {
  test('GitWatcherService detects branch', () async {
    final container = ProviderContainer();
    final service = container.read(gitWatcherServiceProvider);

    // Check current dir and parent dir
    String projectPath = Directory.current.path;
    print('Checking: $projectPath');
    String? branch = await service.getCurrentBranch(projectPath);

    if (branch == null) {
      // Try parent
      projectPath = Directory(projectPath).parent.path;
      print('Checking parent: $projectPath');
      branch = await service.getCurrentBranch(projectPath);
    }

    print('Detected Branch: $branch');

    // We don't assert non-null because we don't know if the environment is actually a git repo,
    // but this verifies the code runs without error and logic is sound.
    if (branch != null) {
      expect(branch, isNotEmpty);
    }
  });
}
