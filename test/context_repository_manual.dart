import 'package:flutter_test/flutter_test.dart';
import 'package:omnicontext/features/dashboard/data/context_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Actually, db_helper uses sqlite3 package, not sqflite.
// But flutter_test environment might not have sqlite3 dynamic library readily available without setup.
// However, since we are on Windows and using `sqlite3` package which bundles/downloads it, it should work if we run `flutter test`.

void main() {
  test('ContextRepository saves and retrieves snapshots', () async {
    final container = ProviderContainer();
    final repo = container.read(contextRepositoryProvider);

    final projectPath = r'C:\Test\Project';
    final branch = 'feature/test';
    final summary = 'Test Summary';

    print('Saving snapshot...');
    await repo.saveSnapshot(
      projectPath: projectPath,
      branch: branch,
      summary: summary,
    );

    print('Retrieving snapshots...');
    final snapshots = await repo.getRecentSnapshots();

    expect(snapshots, isNotEmpty);
    expect(snapshots.first['git_branch'], branch);
    expect(snapshots.first['summary_text'], summary);

    print('Snapshot retrieved: ${snapshots.first}');
  });
}
