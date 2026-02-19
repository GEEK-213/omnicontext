import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omnicontext/core/services/context_generator_service.dart';
import 'package:omnicontext/core/services/shadow_prompter_service.dart';
import 'package:omnicontext/core/providers/active_project_provider.dart';
import 'package:omnicontext/features/dashboard/data/context_repository.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:omnicontext/core/services/drift_service.dart';
import 'package:omnicontext/core/services/sync_service.dart';
import 'package:window_manager/window_manager.dart';

class DashboardScreen extends HookConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentSnapshots = ref.watch(recentSnapshotsProvider);
    final figmaController = useTextEditingController();
    final driftStatusAsync = ref.watch(driftMonitorProvider);
    final activeProjectAsync = ref.watch(activeProjectProvider);
    // Keep shadow prompter alive
    ref.watch(shadowPrompterProvider);

    // Listen to Sync Events
    ref.listen(syncEventsProvider, (previous, next) {
      next.whenData((event) {
        if (event.isNotEmpty && event['event'] == 'context_updated') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🔄 Received Sync Event: ${event['event'] ?? 'Unknown'}',
              ),
              backgroundColor: const Color(0xFF00E5FF),
              behavior: SnackBarBehavior.floating,
            ),
          );
          ref.invalidate(recentSnapshotsProvider);
        }
      });
    });

    final isMiniMode = useState(false);
    final useDeepScan = useState(false);
    final isHovered = useState(false);

    Future<void> setWindowSize(bool mini) async {
      isMiniMode.value = mini;
      if (mini) {
        await windowManager.setSize(const Size(120, 120));
        await windowManager.setOpacity(0.9);
      } else {
        await windowManager.setSize(const Size(380, 850));
        await windowManager.setOpacity(0.95);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final showMiniDetails = constraints.maxWidth < 250;

        return MouseRegion(
          onEnter: (_) async {
            isHovered.value = true;
            await windowManager.setOpacity(1.0);
          },
          onExit: (_) async {
            isHovered.value = false;
            // "Type-Through" - fade out when mouse leaves
            await windowManager.setOpacity(showMiniDetails ? 0.8 : 0.85);
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF00E5FF).withOpacity(0.3),
                  width: 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1E1E1E).withOpacity(0.98), // Almost opaque
                    const Color(0xFF000000).withOpacity(0.95),
                  ],
                ),
              ),
              child: AnimatedSwitcher(
                duration: 300.ms,
                child: showMiniDetails
                    ? _buildMiniMode(context, () => setWindowSize(false))
                    : _buildCommandCenter(
                        context,
                        () => setWindowSize(true),
                        ref,
                        figmaController,
                        driftStatusAsync,
                        recentSnapshots,
                        useDeepScan,
                        activeProjectAsync,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniMode(BuildContext context, VoidCallback onExpand) {
    return GestureDetector(
      onDoubleTap: onExpand,
      onPanStart: (_) => windowManager.startDragging(),
      child: Center(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF00E5FF), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child:
              const Icon(
                    Icons.power_settings_new_rounded,
                    color: Color(0xFF00E5FF),
                    size: 40,
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.1, 1.1),
                    duration: 2.seconds,
                  ),
        ),
      ),
    );
  }

  Widget _buildCommandCenter(
    BuildContext context,
    VoidCallback onShrink,
    WidgetRef ref,
    TextEditingController figmaController,
    AsyncValue<DriftStatus> driftStatusAsync,
    AsyncValue<List<Map<String, dynamic>>> recentSnapshots,
    ValueNotifier<bool> useDeepScan,
    AsyncValue<String?> activeProjectAsync,
  ) {
    return Column(
      children: [
        // 1. Custom Title Bar
        _buildTitleBar(onShrink),

        // 2. Main Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // SYSTEM STATUS PANEL
                _buildCommandPanel(
                  title: 'SYSTEM STATUS',
                  child: Column(
                    children: [
                      _buildStatusRow(
                        'CORE SYSTEM',
                        'ONLINE',
                        Colors.greenAccent,
                      ),
                      const SizedBox(height: 4),
                      _buildStatusRow('AI UPLINK', 'READY', Colors.greenAccent),
                      const SizedBox(height: 4),
                      driftStatusAsync.when(
                        data: (status) {
                          final isDrift =
                              status == DriftStatus.behind ||
                              status == DriftStatus.diverged;
                          return _buildStatusRow(
                            'DRIFT MONITOR',
                            isDrift ? 'WARNING' : 'NOMINAL',
                            isDrift ? Colors.orangeAccent : Colors.greenAccent,
                          );
                        },
                        loading: () => _buildStatusRow(
                          'DRIFT MONITOR',
                          'SCANNING...',
                          Colors.yellow,
                        ),
                        error: (_, __) => _buildStatusRow(
                          'DRIFT MONITOR',
                          'ERROR',
                          Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // TARGET SELECTOR (Context)
                _buildCommandPanel(
                  title: 'TARGET PARAMETERS',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          border: Border(
                            left: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        child: InkWell(
                          onTap: () async {
                            final selectedDirectory = await FilePicker.platform
                                .getDirectoryPath();
                            if (selectedDirectory != null) {
                              ref
                                  .read(activeProjectProvider.notifier)
                                  .setPath(selectedDirectory);
                            }
                          },
                          child: Row(
                            children: [
                              Icon(
                                Icons.folder_open,
                                size: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.7),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: activeProjectAsync.when(
                                  data: (path) => Text(
                                    path != null
                                        ? path
                                              .split(Platform.pathSeparator)
                                              .last
                                              .toUpperCase()
                                        : 'NO PROJECT SELECTED',
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: path != null
                                          ? Colors.white
                                          : Colors.orange,
                                    ),
                                  ),
                                  loading: () => const Text(
                                    'LOADING...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  error: (e, _) => const Text(
                                    'ERROR',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.edit,
                                size: 12,
                                color: Colors.white30,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Figma Input
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: TextField(
                          controller: figmaController,
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter Figma URL...',
                            hintStyle: GoogleFonts.roboto(
                              fontSize: 12,
                              color: Colors.white38,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 9,
                            ),
                            suffixIcon: const Icon(
                              Icons.link,
                              size: 14,
                              color: Colors.white30,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Configure Toggles
                      Row(
                        children: [
                          Text(
                            'DEEP SCAN PROTOCOL',
                            style: GoogleFonts.orbitron(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                          const Spacer(),
                          Transform.scale(
                            scale: 0.7,
                            child: Switch(
                              value: useDeepScan.value,
                              onChanged: (v) => useDeepScan.value = v,
                              activeColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              activeTrackColor: Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.3),
                              inactiveThumbColor: Colors.grey,
                              inactiveTrackColor: Colors.white12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ACTION MODULE
                ElevatedButton(
                      onPressed: activeProjectAsync.value == null
                          ? null
                          : () async {
                              final service = ref.read(
                                contextGeneratorServiceProvider,
                              );
                              final repo = ref.read(contextRepositoryProvider);
                              final projectPath = activeProjectAsync.value!;
                              try {
                                final prompt = await service
                                    .generateContextPrompt(
                                      projectPath,
                                      figmaUrl: figmaController.text,
                                      deepScan: useDeepScan.value,
                                    );
                                final branch = 'HEAD'; // Simplified for now
                                await repo.saveSnapshot(
                                  projectPath: projectPath,
                                  branch: branch,
                                  summary: prompt,
                                );
                                ref.invalidate(recentSnapshotsProvider);
                                await Clipboard.setData(
                                  ClipboardData(text: prompt),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'DATA PACKET COPIED TO CLIPBOARD',
                                      ),
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.8),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('ERROR: $e')),
                                  );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.2),
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: BeveledRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1,
                          ),
                        ),
                        shadowColor: Theme.of(context).colorScheme.primary,
                        elevation: 5,
                      ),
                      child: Text(
                        'INITIATE SEQUENCE',
                        style: GoogleFonts.orbitron(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .shimmer(
                      duration: 2.seconds,
                      color: Theme.of(context).colorScheme.primary,
                    ),

                const SizedBox(height: 8),
                // Shadow Flash
                OutlinedButton(
                  onPressed: () async {
                    final shadowContext = ref.read(shadowPrompterProvider);
                    if (shadowContext.isEmpty) {
                      await ref
                          .read(shadowPrompterProvider.notifier)
                          .forceUpdate();
                    }
                    final currentShadow = ref.read(shadowPrompterProvider);
                    if (currentShadow.isNotEmpty) {
                      await Clipboard.setData(
                        ClipboardData(text: currentShadow),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('SHADOW CACHE RETRIEVED'),
                            backgroundColor: Colors.amber,
                          ),
                        );
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber,
                    side: const BorderSide(color: Colors.amberAccent, width: 1),
                    shape: BeveledRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flash_on, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'FLASH SHADOW CACHE',
                        style: GoogleFonts.orbitron(fontSize: 11),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // INTELLIGENCE MODULE
                _buildCommandPanel(
                  title: 'INTELLIGENCE',
                  child: Column(
                    children: [
                      TextField(
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.search,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          hintText: 'Search database...',
                          hintStyle: GoogleFonts.roboto(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: Colors.black54, // Darker fill
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 10,
                          ),
                        ),
                        onSubmitted: (query) async {
                          final repo = ref.read(contextRepositoryProvider);
                          final results = await repo.searchCodebase(query);
                          if (context.mounted) {
                            // Show simple dialog for results (styling omitted for brevity in rewrite, focus on main UI)
                            showDialog(
                              context: context,
                              builder: (c) =>
                                  _buildSearchResults(c, query, results),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: activeProjectAsync.value == null
                              ? null
                              : () async {
                                  final repo = ref.read(
                                    contextRepositoryProvider,
                                  );
                                  final count = await repo.indexLocalFiles(
                                    activeProjectAsync.value!,
                                  );
                                  if (context.mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('INDEXED $count FILES'),
                                      ),
                                    );
                                },
                          icon: const Icon(
                            Icons.refresh,
                            size: 14,
                            color: Colors.white54,
                          ),
                          label: Text(
                            'RE-INDEX LOCAL',
                            style: GoogleFonts.orbitron(
                              fontSize: 10,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                Text(
                  'LOGS',
                  style: GoogleFonts.orbitron(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
                const Divider(color: Colors.white10),

                // RECENT HISTORY (Simplified)
                recentSnapshots.when(
                  data: (snapshots) {
                    return Column(
                      children: snapshots
                          .take(3)
                          .map(
                            (s) => Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  s['git_branch'] ?? 'UNKNOWN',
                                  style: GoogleFonts.roboto(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  s['created_at']?.toString().substring(
                                        11,
                                        16,
                                      ) ??
                                      '',
                                  style: const TextStyle(
                                    color: Colors.white30,
                                    fontSize: 10,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.check_circle_outline,
                                  size: 14,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.5),
                                ),
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(text: s['summary_text']),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('LOG ENTITY COPIED'),
                                    ),
                                  );
                                },
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('ERR_LOGS'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildTitleBar(VoidCallback onShrink) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          border: const Border(bottom: BorderSide(color: Colors.white10)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.terminal, color: Color(0xFF00E5FF), size: 18),
            const SizedBox(width: 10),
            Text(
              'OMNICONTEXT',
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            _buildWindowBtn(Icons.remove, onShrink),
            const SizedBox(width: 8),
            _buildWindowBtn(Icons.close, () => windowManager.close()),
          ],
        ),
      ),
    );
  }

  Widget _buildWindowBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Icon(icon, color: Colors.white70, size: 14),
      ),
    );
  }

  Widget _buildCommandPanel({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.9), // Increased Opacity
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            color: const Color(0xFF00E5FF).withOpacity(0.15),
            child: Text(
              '// $title',
              style: GoogleFonts.orbitron(
                color: const Color(0xFF00E5FF),
                fontSize: 11,
                fontWeight: FontWeight.w900, // Thicker font
                letterSpacing: 1.2,
              ),
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.roboto(
            // Switch to standard font
            color: Colors.white70, // Brighter
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.orbitron(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: valueColor.withOpacity(0.5), blurRadius: 4),
            ],
          ),
        ),
      ],
    );
  }

  // Reuse the search results dialog structure but styled
  Widget _buildSearchResults(
    BuildContext c,
    String query,
    List<Map<String, Object?>> results,
  ) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: BeveledRectangleBorder(
        side: const BorderSide(color: Color(0xFF00E5FF)),
        borderRadius: BorderRadius.zero,
      ),
      title: Text(
        'QUERY RESULTS: "$query"',
        style: GoogleFonts.orbitron(color: Colors.white, fontSize: 14),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: results.isEmpty
            ? Text(
                'NO RECORDS FOUND',
                style: GoogleFonts.robotoMono(color: Colors.white54),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: results.length,
                itemBuilder: (context, i) {
                  final row = results[i];
                  final snippet = (row['match_snippet'] as String)
                      .replaceAll('<b>', '')
                      .replaceAll('</b>', '');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white12)),
                    ),
                    child: ListTile(
                      title: Text(
                        (row['file_path'] as String)
                            .split(Platform.pathSeparator)
                            .last,
                        style: GoogleFonts.roboto(
                          color: const Color(0xFF00E5FF),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.robotoMono(
                          // Code snippet stays Mono
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      onTap: () {
                        final path = row['file_path'] as String;
                        final f = File(path);
                        f.readAsString().then((c) {
                          Clipboard.setData(ClipboardData(text: c));
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('FILE DATA EXTRACTED'),
                            ),
                          );
                        });
                      },
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: Text(
            'TERMINATE',
            style: GoogleFonts.orbitron(color: Colors.white30),
          ),
        ),
      ],
    );
  }
}
