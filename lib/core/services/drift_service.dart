import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'drift_service.g.dart';

enum DriftStatus { synced, ahead, behind, diverged, unknown, error }

@Riverpod(keepAlive: true)
DriftService driftService(DriftServiceRef ref) {
  return DriftService();
}

class DriftService {
  Timer? _timer;

  // This stream controller could broadcast changes if we wanted a stream-based API
  // But for Riverpod, we might just use a separate provider for the state.
  // For now, let's just expose a method to check.

  Future<DriftStatus> checkDrift(String projectPath) async {
    try {
      // 1. Fetch from remote
      // We use Process.run to avoid blocking the main isolate significantly
      await Process.run(
        'git',
        ['fetch'],
        workingDirectory: projectPath,
        runInShell: true,
      );

      // 2. Compare HEAD with upstream
      // git rev-list --left-right --count HEAD...@{u}
      // Output: "0  0" (synced), "1  0" (ahead), "0  1" (behind), "1  1" (diverged)
      final result = await Process.run(
        'git',
        ['rev-list', '--left-right', '--count', 'HEAD...@{u}'],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        // Likely no upstream configured
        return DriftStatus.unknown;
      }

      final output = result.stdout.toString().trim();
      final parts = output.split(RegExp(r'\s+'));

      if (parts.length != 2) return DriftStatus.unknown;

      final ahead = int.tryParse(parts[0]) ?? 0;
      final behind = int.tryParse(parts[1]) ?? 0;

      if (ahead == 0 && behind == 0) return DriftStatus.synced;
      if (ahead > 0 && behind == 0) return DriftStatus.ahead;
      if (behind > 0 && ahead == 0) return DriftStatus.behind;
      if (ahead > 0 && behind > 0) return DriftStatus.diverged;

      return DriftStatus.unknown;
    } catch (e) {
      debugPrint('Error checking drift: $e');
      return DriftStatus.error;
    }
  }
}

@riverpod
class DriftMonitor extends _$DriftMonitor {
  Timer? _timer;

  @override
  Future<DriftStatus> build() async {
    final service = ref.watch(driftServiceProvider);

    // Start periodic check
    // In a real app, strict background isolation might be needed if this is heavy.
    // For `git fetch` on a small repo, standard async IO is usually fine.
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      // Invalidate self to re-trigger build/fetch
      ref.invalidateSelf();
    });

    final projectPath = Directory.current.path; // Or pass via provider family
    return service.checkDrift(projectPath);
  }
}
