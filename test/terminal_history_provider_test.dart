import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:omnicontext/features/dashboard/data/terminal_history_provider.dart';

void main() {
  test(
    'TerminalHistory loads and parses logs correctly natively and via fallback',
    () {
      final tempDir = Directory.systemTemp.createTempSync(
        'terminal_history_test',
      );
      final logDir = Directory(p.join(tempDir.path, '.omnicontext'));
      logDir.createSync();

      final logFile = File(p.join(logDir.path, 'history.log'));
      logFile.writeAsStringSync('1708611800000|echo "hello"|0\n');
      logFile.writeAsStringSync(
        '1708611850000|git status|1\n',
        mode: FileMode.append,
      );
      logFile.writeAsStringSync('invalid_line\n', mode: FileMode.append);
      logFile.writeAsStringSync(
        '1708611900000|npm install\n',
        mode: FileMode.append,
      ); // no exit code

      final container = ProviderContainer();

      final logs = container.read(terminalHistoryProvider(tempDir.path));

      // Reversed since it returns newest first
      expect(logs.length, 3);

      // First log should be newest (npm install)
      expect(logs[0].command, 'npm install');
      expect(logs[0].exitCode, null);

      expect(logs[1].command, 'git status');
      expect(logs[1].exitCode, '1');

      expect(logs[2].command, 'echo "hello"');
      expect(logs[2].exitCode, '0');
      expect(logs[2].timestamp, 1708611800000);

      container.dispose();
      tempDir.deleteSync(recursive: true);
    },
  );
}
