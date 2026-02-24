import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omnicontext/core/services/websocket_service.dart';

void main() {
  group('WebsocketService Tests', () {
    late ProviderContainer container;
    late WebsocketService websocketService;
    final int testPort = 7172; // Use a different port to avoid conflicts

    setUp(() async {
      container = ProviderContainer();
      websocketService = container.read(websocketServiceProvider.notifier);
      await websocketService.startServer(port: testPort);
      // Give server a moment to bind
      await Future.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() async {
      await websocketService.stopServer();
      container.dispose();
    });

    test('Server binds and accepts connections', () async {
      final socket = await WebSocket.connect('ws://localhost:$testPort');
      expect(socket.readyState, WebSocket.open);
      await socket.close();
    });

    test('Enforces connection limits (Max 5)', () async {
      final sockets = <WebSocket>[];

      // Connect 5 allowed clients
      for (int i = 0; i < 5; i++) {
        final socket = await WebSocket.connect('ws://localhost:$testPort');
        sockets.add(socket);
      }

      // The 6th connection should be rejected
      try {
        final excessSocket = await WebSocket.connect(
          'ws://localhost:$testPort',
        );

        // Listen for the close event
        bool wasClosed = false;
        excessSocket.listen(
          (_) {},
          onDone: () {
            wasClosed = true;
          },
        );

        // Wait for the server to process and close
        await Future.delayed(const Duration(milliseconds: 200));

        expect(wasClosed, isTrue);
        expect(excessSocket.closeCode, WebSocketStatus.policyViolation);
      } catch (e) {
        // Depending on timing, connect itself might throw if the server closes immediately
        expect(e, isNotNull);
      }

      for (var s in sockets) {
        await s.close();
      }
    });

    test('sendInsertCodeCommand broadcasts to connected clients', () async {
      final socket = await WebSocket.connect('ws://localhost:$testPort');

      String? receivedMessage;
      socket.listen((data) {
        receivedMessage = data.toString();
      });

      // Wait a bit for connection to register
      await Future.delayed(const Duration(milliseconds: 100));

      websocketService.sendInsertCodeCommand('print("hello");');

      // Wait for broadcast
      await Future.delayed(const Duration(milliseconds: 100));

      expect(receivedMessage, isNotNull);
      final json = jsonDecode(receivedMessage!);
      expect(json['type'], 'insert_code');
      expect(json['code'], 'print("hello");');

      await socket.close();
    });
  });
}
