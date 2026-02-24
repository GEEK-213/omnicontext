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

  // Rate Limiting: Track timestamps of messages per connection
  final Map<WebSocket, List<DateTime>> _messageTimestamps = {};

  // Configuration
  static const int _maxConnections = 5;
  static const int _maxMessagesPerSecond = 10;
  static const int _maxPayloadLength = 5000;

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
    if (_clients.length >= _maxConnections) {
      debugPrint(
        'Connection rejected: Max connections reached ($_maxConnections).',
      );
      socket.close(WebSocketStatus.policyViolation, 'Max connections reached.');
      return;
    }

    _clients.add(socket);
    _messageTimestamps[socket] = [];
    debugPrint(
      'VS Code Extension Connected! Total clients: ${_clients.length}',
    );

    socket.listen(
      (dynamic data) {
        _handleMessage(socket, data.toString());
      },
      onDone: () {
        _clients.remove(socket);
        _messageTimestamps.remove(socket);
        debugPrint('Client disconnected. Total clients: ${_clients.length}');
      },
      onError: (error) {
        _clients.remove(socket);
        _messageTimestamps.remove(socket);
        debugPrint('WebSocket error: $error');
      },
    );
  }

  void _handleMessage(WebSocket socket, String message) {
    // 1. Rate Limiting Check
    final now = DateTime.now();
    final timestamps = _messageTimestamps[socket] ?? [];

    // Remove timestamps older than 1 second
    timestamps.removeWhere((t) => now.difference(t).inSeconds > 1);

    if (timestamps.length >= _maxMessagesPerSecond) {
      debugPrint('Rate limit exceeded for client.');
      socket.add(
        jsonEncode({'error': 'Rate limit exceeded. Too many requests.'}),
      );
      return;
    }

    timestamps.add(now);
    _messageTimestamps[socket] = timestamps;

    // 2. Payload Size Check
    if (message.length > _maxPayloadLength) {
      debugPrint('Payload size exceeds $_maxPayloadLength characters.');
      socket.add(jsonEncode({'error': 'Payload limits exceeded.'}));
      return;
    }

    try {
      final payloadStr = message.toString();
      final payload = jsonDecode(payloadStr);

      // 3. Strict Type Checking
      if (payload is! Map<String, dynamic>) {
        debugPrint('Invalid JSON format: expected Map.');
        return;
      }

      final type = payload['type'];
      if (type is! String) {
        debugPrint('Invalid or missing "type" in payload.');
        return;
      }

      switch (type) {
        case 'active_file_changed':
          final filePath = payload['filePath'];
          if (filePath is! String || filePath.length > 2000) return;
          debugPrint('VS Code Active File Changed: $filePath');
          // TODO: Trigger Context Generation or UI updates
          break;
        case 'terminal_command':
          final command = payload['command'];
          final projectPath = payload['projectPath'];
          final timestamp = payload['timestamp'];
          final exitCode = payload['exitCode'];

          // Length and Type checks
          if (command is! String || command.length > 2000) return;
          if (projectPath is! String || projectPath.length > 2000) return;
          if (timestamp != null && timestamp is! int) return;
          if (exitCode != null && exitCode is! int) return;

          debugPrint('Command intercepted: $command in $projectPath');

          // 4. Path Traversal & Integrity Validation
          // Only allow writes if the paths belong to the active, user-selected project
          final activePath = ref.read(activeProjectProvider).valueOrNull;
          if (activePath == null || activePath.isEmpty) {
            debugPrint('No active project set. Rejecting sync request.');
            socket.add(
              jsonEncode({
                'error': 'No active project selected in OmniContext.',
              }),
            );
            return;
          }

          // Canonicalize safely mitigates "../" directory traversal
          final canonicalProject = p.canonicalize(projectPath);
          final canonicalActive = p.canonicalize(activePath);

          if (canonicalProject != canonicalActive) {
            debugPrint(
              'Path traversal/mismatch attempt rejected: $canonicalProject != $canonicalActive',
            );
            socket.add(
              jsonEncode({
                'error': 'Project path does not match active project.',
              }),
            );
            return;
          }

          final finalTimestamp =
              timestamp ?? DateTime.now().millisecondsSinceEpoch;

          final logDir = Directory(p.join(canonicalActive, '.omnicontext'));
          if (!logDir.existsSync()) {
            logDir.createSync(recursive: true);
          }
          final logFile = File(p.join(logDir.path, 'history.log'));

          final exitStr = exitCode != null ? '|$exitCode' : '';
          logFile.writeAsStringSync(
            '$finalTimestamp|$command$exitStr\n',
            mode: FileMode.append,
          );

          // Auto refresh UI
          ref.read(terminalHistoryProvider(canonicalActive).notifier).refresh();
          break;
        default:
          debugPrint('Unknown WebSocket message type: $type');
          socket.add(jsonEncode({'error': 'Unknown message type.'}));
      }
    } catch (e) {
      debugPrint('Error parsing WebSocket message: $e');
    }
  }

  void broadcastMessage(Map<String, dynamic> data) {
    if (_clients.isEmpty) {
      debugPrint('No clients connected to broadcast message.');
      return;
    }

    final message = jsonEncode(data);
    for (final client in _clients) {
      client.add(message);
    }
    debugPrint('Broadcasted message to ${_clients.length} clients: $message');
  }

  /// Helper to send an instruction to VS Code to insert code at the active cursor
  void sendInsertCodeCommand(String code) {
    broadcastMessage({'type': 'insert_code', 'code': code});
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
