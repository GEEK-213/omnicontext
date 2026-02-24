import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:path/path.dart' as p;

part 'terminal_history_provider.g.dart';

class TerminalCommandLog {
  final int timestamp;
  final String command;
  final String? exitCode;

  TerminalCommandLog({
    required this.timestamp,
    required this.command,
    this.exitCode,
  });

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);
}

@riverpod
class TerminalHistory extends _$TerminalHistory {
  @override
  List<TerminalCommandLog> build(String projectPath) {
    if (projectPath.isEmpty) return [];
    final logs = _loadHistory();
    return logs;
  }

  List<TerminalCommandLog> _loadHistory() {
    var logFile = File(p.join(projectPath, '.omnicontext', 'history.log'));
    if (!logFile.existsSync()) {
      // Fallback: check parent directory in case Flutter app is in a subfolder and VS code is opened at root
      final parentFile = File(
        p.join(
          Directory(projectPath).parent.path,
          '.omnicontext',
          'history.log',
        ),
      );
      if (parentFile.existsSync()) {
        logFile = parentFile;
      } else {
        return [];
      }
    }

    try {
      final lines = logFile.readAsLinesSync();
      final logs = <TerminalCommandLog>[];
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        final parts = line.split('|');
        if (parts.length >= 2) {
          logs.add(
            TerminalCommandLog(
              timestamp: int.tryParse(parts[0]) ?? 0,
              command: parts[1],
              exitCode: parts.length > 2 ? parts[2] : null,
            ),
          );
        }
      }
      // Newest first
      return logs.reversed.toList();
    } catch (e) {
      return [];
    }
  }

  void refresh() {
    state = _loadHistory();
  }
}
