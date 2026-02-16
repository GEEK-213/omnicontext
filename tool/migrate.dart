import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;

// Note: Usage: dart tool/migrate.dart
// This script assumes it is run from the project root (omnicontext/omnicontext)
// and that .antigravity/schema.sql is in ../.antigravity/schema.sql

Future<void> main() async {
  print('🚀 Starting Database Migration...');

  // 1. Locate schema.sql
  // We are in omnicontext/omnicontext. schema is in ../.antigravity/schema.sql
  // Let's try to find it relative to script or CWD.
  final schemaPath = p.normalize(
    p.join(Directory.current.path, '../.antigravity/schema.sql'),
  );
  final schemaFile = File(schemaPath);

  if (!schemaFile.existsSync()) {
    print('❌ Error: Schema file not found at $schemaPath');
    // Try alternate location if likely
    return;
  }

  print('📄 Found schema at: $schemaPath');
  final schemaSql = schemaFile.readAsStringSync();

  // 2. Open Database
  // We need to match the path used in db_helper.dart
  // We can't rely on path_provider in a CLI script easily on Windows without some setup if we are just running `dart`.
  // However, path_provider supports Windows.
  // Wait, path_provider FFI might need layout.
  // Actually, for a simple script, we should probably just ask where the DB is or rely on standard Windows path.
  // C:\Users\[User]\Documents\omnicontext.db

  // Let's try to get Documents directory via env or standard path construction for reliability in this script.
  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile == null) {
    print('❌ Error: USERPROFILE environment variable not found.');
    return;
  }
  final dbPath = p.join(userProfile, 'Documents', 'omnicontext.db');

  print('💾 Database Path: $dbPath');

  // 3. Migrate
  try {
    final db = sqlite3.open(dbPath);
    print('✅ Database opened successfully.');

    // Execute schema
    // sqlite3 execute allows multiple statements? Yes.
    db.execute(schemaSql);
    print('✅ Schema executed successfully.');

    // Check if new tables exist
    final result = db.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND (name='remote_state' OR name='sync_events')",
    );
    if (result.length == 2) {
      print(
        '✨ Verification: New tables `remote_state` and `sync_events` found.',
      );
    } else {
      print(
        '⚠️ Warning: Verification found ${result.length} of 2 new tables. They might have already existed or failed.',
      );
    }

    db.dispose();
  } catch (e) {
    print('❌ Migration Failed: $e');
  }

  print('🏁 Migration Complete.');
}
