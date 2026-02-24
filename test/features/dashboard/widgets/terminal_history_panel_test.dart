import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omnicontext/core/providers/active_project_provider.dart';
import 'package:omnicontext/core/services/websocket_service.dart';
import 'package:omnicontext/features/dashboard/data/terminal_history_provider.dart';
import 'package:omnicontext/features/dashboard/widgets/terminal_history_panel.dart';

class FakeWebsocketService extends WebsocketService {
  bool sendCodeCalled = false;
  String? lastCodeSent;

  @override
  void build() {}

  @override
  void sendInsertCodeCommand(String code) {
    sendCodeCalled = true;
    lastCodeSent = code;
  }
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

class FakeTerminalHistory extends TerminalHistory {
  final List<TerminalCommandLog> logs;
  FakeTerminalHistory(this.logs);

  @override
  List<TerminalCommandLog> build(String projectPath) => logs;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('TerminalHistoryPanel renders empty state', (tester) async {
    final activeProjectProviderMock = AsyncValue.data('/mock/path');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeProjectProvider.overrideWith(
            () => FakeActiveProject(activeProjectProviderMock),
          ),
          terminalHistoryProvider(
            '/mock/path',
          ).overrideWith(() => FakeTerminalHistory([])),
        ],
        child: const MaterialApp(home: Scaffold(body: TerminalHistoryPanel())),
      ),
    );

    // Wait for async rendering
    await tester.pumpAndSettle();

    expect(find.text('PROJECT HISTORY'), findsOneWidget);
    expect(find.textContaining('No commands recorded'), findsOneWidget);
  });

  testWidgets('TerminalHistoryPanel renders commands and buttons', (
    tester,
  ) async {
    final activeProjectProviderMock = AsyncValue.data('/mock/path');
    final fakeWsService = FakeWebsocketService();

    final logs = [
      TerminalCommandLog(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        command: 'npm run build',
        exitCode: '0',
      ),
      TerminalCommandLog(
        timestamp: DateTime.now().millisecondsSinceEpoch - 10000,
        command: 'flutter test',
        exitCode: '1',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeProjectProvider.overrideWith(
            () => FakeActiveProject(activeProjectProviderMock),
          ),
          terminalHistoryProvider(
            '/mock/path',
          ).overrideWith(() => FakeTerminalHistory(logs)),
          websocketServiceProvider.overrideWith(() => fakeWsService),
        ],
        child: const MaterialApp(home: Scaffold(body: TerminalHistoryPanel())),
      ),
    );

    await tester.pumpAndSettle();

    // Verify commands rendered
    expect(find.text('npm run build'), findsOneWidget);
    expect(find.text('flutter test'), findsOneWidget);

    // Verify buttons rendered (2 commands * 2 buttons = 4 icons total + 1 refresh icon)
    expect(find.byIcon(Icons.copy), findsNWidgets(2));
    expect(find.byIcon(Icons.send_to_mobile), findsNWidgets(2));

    // Tap the Apply to Editor button
    await tester.tap(find.byIcon(Icons.send_to_mobile).first);
    await tester.pumpAndSettle();

    // Check if fake service was called
    expect(fakeWsService.sendCodeCalled, isTrue);
    expect(fakeWsService.lastCodeSent, 'npm run build');

    // Verify toast opens
    expect(find.text('Command sent to VS Code'), findsOneWidget);
  });
}
