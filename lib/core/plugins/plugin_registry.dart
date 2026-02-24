import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:omnicontext/core/plugins/omni_plugin.dart';

part 'plugin_registry.g.dart';

@Riverpod(keepAlive: true)
class PluginRegistry extends _$PluginRegistry {
  @override
  List<OmniPlugin> build() {
    // Initial plugins will be loaded here
    return [];
  }

  void registerPlugin(OmniPlugin plugin) {
    if (!state.any((p) => p.id == plugin.id)) {
      state = [...state, plugin];
    }
  }

  void unregisterPlugin(String pluginId) {
    state = state.where((p) => p.id != pluginId).toList();
  }

  /// Collects all generated context from active plugins
  Future<String> gatherPluginContexts(String projectPath) async {
    final futures = state.map((plugin) => plugin.generateContext(projectPath));
    final results = await Future.wait(futures);

    final validResults = results.where((ctx) => ctx.trim().isNotEmpty).toList();
    if (validResults.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('\n--- [EXTERNAL PLUGIN CONTEXT] ---');
    for (var i = 0; i < validResults.length; i++) {
      buffer.writeln('Plugin Source ${state[i].name}:');
      buffer.writeln(validResults[i]);
      buffer.writeln('--------------------------------');
    }
    return buffer.toString();
  }
}
