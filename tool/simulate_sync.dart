import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

Future<void> main() async {
  print('🔄 Simulating External Sync Event...');

  // Create .antigravity directory if not exists
  final dir = Directory('.antigravity');
  if (!dir.existsSync()) {
    dir.createSync();
  }

  final file = File(p.join('.antigravity', 'sync_events.json'));

  final event = {
    'event': 'context_updated',
    'timestamp': DateTime.now().toIso8601String(),
    'source': 'External Script',
  };

  await file.writeAsString(jsonEncode(event));
  print('✅ Wrote event to ${file.path}');
  print('👉 Watch the Dashboard for a "Received Sync Event" snackbar.');
}
