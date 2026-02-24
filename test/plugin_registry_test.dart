import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omnicontext/core/plugins/omni_plugin.dart';
import 'package:omnicontext/core/plugins/plugin_registry.dart';

class MockPlugin implements OmniPlugin {
  @override
  final String id;
  @override
  final String name;
  @override
  final IconData icon = Icons.extension;
  final String mockContext;

  MockPlugin(this.id, this.name, this.mockContext);

  @override
  Widget buildPanel(BuildContext context, WidgetRef ref) => const SizedBox();

  @override
  Future<String> generateContext(String projectPath) async => mockContext;
}

void main() {
  test(
    'PluginRegistry adds, removes plugins and gathers context correctly',
    () async {
      final container = ProviderContainer();
      final registry = container.read(pluginRegistryProvider.notifier);

      // Register plugin 1
      registry.registerPlugin(
        MockPlugin('test.plugin1', 'Plugin 1', 'Context from P1'),
      );
      // Should not allow duplicate ID
      registry.registerPlugin(
        MockPlugin('test.plugin1', 'Plugin 1.2', 'Dupe context'),
      );
      // Register plugin 2
      registry.registerPlugin(MockPlugin('test.plugin2', 'Plugin 2', ''));

      final plugins = container.read(pluginRegistryProvider);
      expect(plugins.length, 2);
      expect(plugins.first.name, 'Plugin 1');
      expect(plugins.last.name, 'Plugin 2');

      final gathered = await registry.gatherPluginContexts('/dummy/path');
      expect(gathered, contains('Plugin Source Plugin 1:'));
      expect(gathered, contains('Context from P1'));
      // Blank context should be ignored
      expect(gathered.contains('Plugin 2'), false);

      // Unregister plugin 1
      registry.unregisterPlugin('test.plugin1');
      final afterRemove = container.read(pluginRegistryProvider);
      expect(afterRemove.length, 1);
      expect(afterRemove.first.id, 'test.plugin2');

      container.dispose();
    },
  );
}
