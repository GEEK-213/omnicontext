import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:omnicontext/core/providers/active_project_provider.dart';
import 'package:omnicontext/features/dashboard/data/terminal_history_provider.dart';
import 'package:path/path.dart' as p;

part 'websocket_service.g.dart';

@Riverpod(keepAlive: true)
class WebsocketService extends _$WebsocketService {
  HttpServer? _server;
  final List<WebSocket> _clients = [];

  @override
  void build() {
    // Initial state
    ref.onDispose(() {
      stopServer();
    });
  }

  Future<void> startServer({int port = 7171}) async {
    if (_server != null) return;

    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      debugPrint('WebSocket Server listening on ws://localhost:$port');

      _server!.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          _handleConnection(socket);
        } else {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..writeln('WebSocket connections only')
            ..close();
        }
      });
    } catch (e) {
      debugPrint('Failed to start WebSocket server: $e');
    }
  }

  void _handleConnection(WebSocket socket) {
    _clients.add(socket);
    debugPrint(
      'VS Code Extension Connected! Total clients: ${_clients.length}',
    );

    socket.listen(
      (dynamic data) {
        _handleMessage(data.toString());
      },
      onDone: () {
        _clients.remove(socket);
        debugPrint('Client disconnected. Total clients: ${_clients.length}');
      },
      onError: (error) {
        _clients.remove(socket);
        debugPrint('WebSocket error: $error');
      },
    );
  }

  void _handleMessage(String message) {
    try {
      final payload = jsonDecode(message);
      final String type = payload['type'] ?? 'unknown';

      switch (type) {
        case 'active_file_changed':
          final filePath = payload['filePath'];
          debugPrint('VS Code Active File Changed: $filePath');
          // TODO: Trigger Context Generation or UI updates
          break;
        case 'terminal_command':
          final command = payload['command'];
          final String projectPath = payload['projectPath'] ?? '';
          final timestamp =
              payload['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
          debugPrint('Command intercepted: $command in $projectPath');

          if (projectPath.isNotEmpty && command != null) {
            final logDir = Directory(p.join(projectPath, '.omnicontext'));
            if (!logDir.existsSync()) {
              logDir.createSync(recursive: true);
            }
            final logFile = File(p.join(logDir.path, 'history.log'));
            // Format: Timestamp|Command|ExitCode(Optional)
            final exitCode = payload['exitCode'] != null
                ? '|${payload['exitCode']}'
                : '';
            logFile.writeAsStringSync(
              '$timestamp|$command$exitCode\n',
              mode: FileMode.append,
            );

            // Auto refresh UI if active project matches (or just refresh the active one)
            final activePath = ref.read(activeProjectProvider).valueOrNull;
            if (activePath != null) {
              ref.read(terminalHistoryProvider(activePath).notifier).refresh();
            }
          }
          break;
        default:
          debugPrint('Unknown WebSocket message type: $type');
      }
    } catch (e) {
      debugPrint('Error parsing WebSocket message: $e');
    }
  }

  void broadcastMessage(Map<String, dynamic> data) {
    final message = jsonEncode(data);
    for (final client in _clients) {
      client.add(message);
    }
  }

  Future<void> stopServer() async {
    for (final client in _clients) {
      await client.close();
    }
    _clients.clear();
    await _server?.close();
    _server = null;
    debugPrint('WebSocket Server stopped.');
  }
}
