import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicontext/core/services/git_service.dart';

void main() {
  late Directory tempDir;
  late GitService gitService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('git_service_test');
    gitService = GitService();

    // Initialize a real git repo for testing
    await Process.run('git', ['init'], workingDirectory: tempDir.path);

    // Create an initial commit to establish HEAD and master/main branch
    final testFile = File('${tempDir.path}/test.txt');
    await testFile.writeAsString('initial content');

    await Process.run('git', ['add', '.'], workingDirectory: tempDir.path);
    await Process.run('git', [
      'commit',
      '-m',
      'Initial commit',
    ], workingDirectory: tempDir.path);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('getBranches returns list of branches', () async {
    final branches = await gitService.getBranches(tempDir.path);
    // Should have at least master or main
    expect(branches.isNotEmpty, isTrue);
    expect(branches.any((b) => b == 'master' || b == 'main'), isTrue);

    // Create a new branch
    await Process.run('git', [
      'branch',
      'feature-branch',
    ], workingDirectory: tempDir.path);

    final newBranches = await gitService.getBranches(tempDir.path);
    expect(newBranches.contains('feature-branch'), isTrue);
  });

  test('getCurrentBranch returns the current active branch', () async {
    final currentBranch = await gitService.getCurrentBranch(tempDir.path);
    expect(currentBranch == 'master' || currentBranch == 'main', isTrue);
  });

  test('getTrackedFiles returns list of tracked files', () async {
    final files = await gitService.getTrackedFiles(tempDir.path);
    expect(files, contains('test.txt'));
  });

  test('getStagedDiff returns diff of staged changes', () async {
    // Stage a new change
    final testFile = File('${tempDir.path}/test.txt');
    await testFile.writeAsString('updated content');
    await Process.run('git', ['add', '.'], workingDirectory: tempDir.path);

    final diff = await gitService.getStagedDiff(tempDir.path);
    expect(diff, contains('-initial content'));
    expect(diff, contains('+updated content'));
  });
}
