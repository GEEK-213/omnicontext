import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omnicontext/core/services/context_generator_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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
    final service = ref.read(contextGeneratorServiceProvider);
    final projectPath = Directory.current.path;

    try {
      // Background generation with deep scan enabled
      final context = await service.generateContextPrompt(
        projectPath,
        deepScan: true,
        figmaUrl:
            '', // Optional: could inject if we had access, but for shadow it's fine empty or we need a provider for Figma URL
      );
      state = context;
    } catch (e) {
      // Silently fail or log
      print('Shadow Prompter Error: $e');
    }
  }

  // Allow manual trigger (e.g., "Flash" button if user wants to force update)
  Future<void> forceUpdate() async {
    await _generateShadowContext();
  }
}
