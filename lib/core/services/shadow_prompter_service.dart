import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:omnicontext/core/providers/active_project_provider.dart';
import 'package:omnicontext/core/services/context_generator_service.dart';

part 'shadow_prompter_service.g.dart';

@Riverpod(keepAlive: true)
class ShadowPrompter extends _$ShadowPrompter {
  Timer? _timer;

  @override
  String build() {
    _startTimer();
    ref.onDispose(() {
      _timer?.cancel();
    });
    return ''; // Initial empty state
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(minutes: 2), (_) {
      _generateShadowContext();
    });
    // Run immediately once
    Future.microtask(_generateShadowContext);
  }

  Future<void> _generateShadowContext() async {
    // Use the active project selected by the user, not the app's install dir
    final activeProject = ref.read(activeProjectProvider);
    final projectPath = activeProject.value;

    if (projectPath == null) {
      debugPrint('ShadowPrompter: no active project selected, skipping.');
      return;
    }

    final service = ref.read(contextGeneratorServiceProvider);

    try {
      final context = await service.generateContextPrompt(
        projectPath,
        deepScan: true,
        figmaUrl: '',
      );
      state = context;
    } catch (e) {
      debugPrint('ShadowPrompter error: $e');
    }
  }

  /// Allow manual trigger via "Flash" button
  Future<void> forceUpdate() async {
    await _generateShadowContext();
  }
}
