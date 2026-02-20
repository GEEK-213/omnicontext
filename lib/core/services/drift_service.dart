import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:omnicontext/core/providers/active_project_provider.dart';

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

  /// Returns raw `git diff --name-status HEAD..@{u}` output.
  /// This shows which files the remote has changed that haven't been pulled yet.
  Future<String> getRemoteDiffSummary(String projectPath) async {
    try {
      // Ensure we have the latest remote state
      await Process.run(
        'git',
        ['fetch'],
        workingDirectory: projectPath,
        runInShell: true,
      );

      final result = await Process.run(
        'git',
        ['diff', '--name-status', 'HEAD..@{u}'],
        workingDirectory: projectPath,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        return 'No upstream branch configured or not a git repository.';
      }

      final output = result.stdout.toString().trim();
      if (output.isEmpty) {
        return 'No differences found between local HEAD and remote.';
      }

      return output;
    } catch (e) {
      return 'Error fetching diff: $e';
    }
  }
}

@riverpod
class DriftMonitor extends _$DriftMonitor with WidgetsBindingObserver {
  Timer? _timer;

  @override
  Future<DriftStatus> build() async {
    final service = ref.watch(driftServiceProvider);
    final activeProject = ref.watch(activeProjectProvider);

    // Add lifecycle observer to check when app comes to foreground
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _timer?.cancel();
    });

    // Start periodic check - Reduced to 30 seconds for "Real Time" feel
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidateSelf();
    });

    final projectPath = activeProject.value;
    if (projectPath == null) return DriftStatus.unknown;

    return service.checkDrift(projectPath);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Immediately check when user comes back to the app
      ref.invalidateSelf();
    }
  }
}
