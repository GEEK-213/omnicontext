import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  print('🕵️‍♀️ Starting System Verification...\n');

  // --- 1. Database & Persistence (Phases 1 & 4) ---
  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile == null) {
    print('❌ Critical: USERPROFILE not found.');
    return;
  }
  final dbPath = p.join(userProfile, 'Documents', 'omnicontext.db');
  final dbFile = File(dbPath);

  if (dbFile.existsSync()) {
    print('✅ Phase 1 (Foundation): Database file found at $dbPath');
    print('   Size: ${dbFile.lengthSync()} bytes');

    try {
      final db = sqlite3.open(dbPath);

      // Check Tables
      final tables = db.select(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final tableNames = tables.map((r) => r['name']).toList();

      print('\n📊 Database Tables Found:');
      for (var t in tableNames) print('   - $t');

      bool hasContext = tableNames.contains('context_snapshots');
      bool hasRemote = tableNames.contains('remote_state');

      if (hasContext) {
        final count = db.select(
          'SELECT COUNT(*) as c FROM context_snapshots',
        )[0]['c'];
        print(
          '✅ Phase 4 (Persistence): `context_snapshots` table exists with $count records.',
        );
      } else {
        print('❌ Phase 4 Failed: `context_snapshots` table missing.');
      }

      if (hasRemote) {
        print(
          '✅ Phase 7 (Remote Radar): `remote_state` table exists (Schema migrated).',
        );
      } else {
        print('❌ Phase 7 Failed: `remote_state` table missing.');
      }

      db.dispose();
    } catch (e) {
      print('❌ Database Error: $e');
    }
  } else {
    print('❌ Phase 1 Failed: Database file NOT found at $dbPath');
  }

  // --- 2. Git Watcher (Phase 2 & 7) ---
  print('\n👀 Verifying Git Watcher...');
  try {
    final result = await Process.run('git', [
      'rev-parse',
      '--abbrev-ref',
      'HEAD',
    ], runInShell: true);
    if (result.exitCode == 0) {
      print(
        '✅ Phase 2 (Watcher): Detected active branch: ${result.stdout.toString().trim()}',
      );
    } else {
      print('⚠️ Git Warning: Could not detect branch (is this a git repo?).');
    }
  } catch (e) {
    print('❌ Git Error: $e');
  }

  print('\n🏁 Verification Complete.');
}
