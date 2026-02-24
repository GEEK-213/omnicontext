import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omnicontext/core/providers/active_project_provider.dart';
import 'package:omnicontext/core/services/drift_service.dart';
import 'package:omnicontext/features/dashboard/dashboard_screen.dart';
import 'package:omnicontext/features/dashboard/data/context_repository.dart';
import 'package:omnicontext/core/services/websocket_service.dart';
import 'package:omnicontext/core/plugins/plugin_registry.dart';
import 'package:omnicontext/core/plugins/omni_plugin.dart';
import 'package:omnicontext/core/services/ai_summarizer_service.dart';
import 'package:omnicontext/core/services/embedding_service.dart';
import 'package:omnicontext/main.dart'; // For hotkeyTriggerProvider

class FakeWebsocketService extends WebsocketService {
  @override
  void build() {}
  @override
  Future<void> startServer({int port = 7171}) async {}
}

class FakeDriftMonitor extends DriftMonitor {
  @override
  Future<DriftInfo> build() async => DriftInfo(DriftStatus.synced);
}

class FakePluginRegistry extends PluginRegistry {
  @override
  List<OmniPlugin> build() => [];
  @override
  void registerPlugin(dynamic plugin) {}
}

class FakeAISummarizer extends AiSummarizer {
  @override
  void build() {}
  @override
  void initialize(String geminiKey, {String? openAiKey}) {}
}

class FakeEmbeddingService extends EmbeddingService {
  @override
  void build() {}
  @override
  void initialize(String apiKey) {}
}

class FakeActiveProject extends ActiveProject {
  final AsyncValue<String?> value;
  FakeActiveProject(this.value);

  @override
  FutureOr<String?> build() {
    return value.when(
      data: (d) => d,
      error: (e, s) => throw e,
      loading: () => null,
    );
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('DashboardScreen renders its main sections', (tester) async {
    // Set screen size larger to avoid RenderFlex overflows
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeActiveProject = FakeActiveProject(
      const AsyncValue.data('/mock/path'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeProjectProvider.overrideWith(() => fakeActiveProject),
          recentSnapshotsProvider.overrideWith((ref) => Future.value([])),
          driftMonitorProvider.overrideWith(FakeDriftMonitor.new),
          hotkeyTriggerProvider.overrideWith((ref) => 0),
          websocketServiceProvider.overrideWith(() => FakeWebsocketService()),
          pluginRegistryProvider.overrideWith(() => FakePluginRegistry()),
          aiSummarizerProvider.overrideWith(() => FakeAISummarizer()),
          embeddingServiceProvider.overrideWith(() => FakeEmbeddingService()),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );

    // Initial settle for UI components and avoid infinite animations
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify main components are present in default state
    expect(find.text('EXPLORER'), findsOneWidget); // Left panel header
    expect(
      find.text('INTELLIGENCE UNIT'),
      findsOneWidget,
    ); // Center panel header
    expect(find.text('INTEGRATIONS'), findsOneWidget); // Right panel header
  });
}
