import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omnicontext/core/providers/active_project_provider.dart';
import 'package:omnicontext/core/services/websocket_service.dart';
import 'package:omnicontext/features/dashboard/data/terminal_history_provider.dart';
import 'package:intl/intl.dart';

class TerminalHistoryPanel extends ConsumerWidget {
  const TerminalHistoryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProject = ref.watch(activeProjectProvider);

    return activeProject.when(
      data: (path) {
        if (path == null || path.isEmpty) return const SizedBox.shrink();
        final history = ref.watch(terminalHistoryProvider(path));

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.history_edu,
                        color: Colors.cyanAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'PROJECT HISTORY',
                        style: GoogleFonts.orbitron(
                          color: Colors.cyanAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      size: 16,
                      color: Colors.white54,
                    ),
                    onPressed: () {
                      ref
                          .read(terminalHistoryProvider(path).notifier)
                          .refresh();
                    },
                    tooltip: 'Refresh Log',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No commands recorded for this project yet.\nInstall the VS Code extension to begin tracking.',
                      style: GoogleFonts.roboto(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final log = history[index];
                      final timeStr = DateFormat(
                        'HH:mm:ss',
                      ).format(log.dateTime);
                      final bool isError =
                          log.exitCode != null &&
                          log.exitCode != '0' &&
                          log.exitCode != '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(6),
                          border: Border(
                            left: BorderSide(
                              color: isError
                                  ? Colors.redAccent
                                  : Colors.white24,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '[$timeStr]',
                              style: GoogleFonts.firaCode(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                log.command,
                                style: GoogleFonts.firaCode(
                                  color: isError
                                      ? Colors.redAccent.withOpacity(0.9)
                                      : Colors.white70,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.copy,
                                size: 14,
                                color: Colors.white38,
                              ),
                              tooltip: 'Copy Command',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: log.command),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Command copied to clipboard',
                                    ),
                                    backgroundColor: Colors.cyan,
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(
                                Icons.send_to_mobile,
                                size: 14,
                                color: Colors.cyanAccent,
                              ),
                              tooltip: 'Apply to Editor',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                ref
                                    .read(websocketServiceProvider.notifier)
                                    .sendInsertCodeCommand(log.command);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Command sent to VS Code'),
                                    backgroundColor: Colors.cyan,
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
