import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:omnicontext/core/services/git_watcher_service.dart';

part 'context_generator_service.g.dart';

@Riverpod(keepAlive: true)
ContextGeneratorService contextGeneratorService(
  ContextGeneratorServiceRef ref,
) {
  final gitWatcher = ref.watch(gitWatcherServiceProvider);
  return ContextGeneratorService(gitWatcher);
}

class ContextGeneratorService {
  final GitWatcherService _gitWatcher;

  ContextGeneratorService(this._gitWatcher);

  Future<String> generateContextPrompt(
    String projectPath, {
    String? figmaUrl,
  }) async {
    final branch = await _gitWatcher.getCurrentBranch(projectPath);

    final figmaLine = figmaUrl != null && figmaUrl.isNotEmpty
        ? '\n- Figma Design: $figmaUrl'
        : '';

    return '''
--- BEGIN PROJECT CONTEXT ---
Project: $projectPath
Branch: ${branch ?? 'Not a repo'}
System: Windows 11$figmaLine
--- END CONTEXT ---''';
  }
}
