import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omnicontext/core/services/context_generator_service.dart';
import 'package:omnicontext/core/services/shadow_prompter_service.dart';
import 'package:omnicontext/features/dashboard/data/context_repository.dart';

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
            ),
          );
          ref.invalidate(recentSnapshotsProvider);
        }
      });
    });

    final isMiniMode = useState(false);
    final useDeepScan = useState(false);

    Future<void> setWindowSize(bool mini) async {
      isMiniMode.value = mini;
      if (mini) {
        await windowManager.setSize(const Size(100, 100));
        await windowManager.setOpacity(0.8);
      } else {
        await windowManager.setSize(const Size(350, 800));
        await windowManager.setOpacity(0.9);
      }
    }

    final isHovered = useState(false);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Automatically switch to Mini Mode UI if width is small
        // This handles cases where window size doesn't match logical state
        final showMiniDetails = constraints.maxWidth < 200;

        return MouseRegion(
          onEnter: (_) async {
            isHovered.value = true;
            await windowManager.setOpacity(1.0);
          },
          onExit: (_) async {
            isHovered.value = false;
            // "Type-Through" - fade out when mouse leaves
            await windowManager.setOpacity(showMiniDetails ? 0.7 : 0.6);
          },
          child: Scaffold(
            backgroundColor:
                Colors.transparent, // Let Acrylic show through from main.dart
            body: AnimatedOpacity(
              duration: 200.ms,
              opacity: isHovered.value ? 1.0 : 0.8, // subtle content fade
              child: showMiniDetails
                  ? _buildMiniMode(context, () => setWindowSize(false))
                  : _buildExpandedMode(
                      context,
                      () => setWindowSize(true),
                      isHovered.value,
                      ref,
                      figmaController,
                      driftStatusAsync,
                      recentSnapshots,
                      useDeepScan,
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
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.5), // Semi-transparent pill
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          padding: const EdgeInsets.all(12),
          child:
              const Icon(
                    Icons.aspect_ratio_rounded,
                    color: Colors.white,
                    size: 32,
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(
                    duration: 2.seconds,
                    color: Colors.white54,
                  ), // Subtle heartbeat
        ),
      ),
    );
  }

  Widget _buildExpandedMode(
    BuildContext context,
    VoidCallback onShrink,
    bool isHovered,
    WidgetRef ref,
    TextEditingController figmaController,
    AsyncValue<DriftStatus> driftStatusAsync,
    AsyncValue<List<Map<String, dynamic>>> recentSnapshots,
    ValueNotifier<bool> useDeepScan,
  ) {
    return Column(
      children: [
        // Custom Draggable Title Bar
        GestureDetector(
          onPanStart: (_) => windowManager.startDragging(),
          child: Container(
            height: 40,
            color: Colors.black.withOpacity(0.2), // Darker overlay for title
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.drag_indicator,
                  color: Colors.white54,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'OmniContext',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white54,
                    size: 16,
                  ),
                  onPressed: () => windowManager.close(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.minimize,
                    color: Colors.white54,
                    size: 16,
                  ),
                  onPressed: onShrink,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drift Alert
                driftStatusAsync.when(
                  data: (status) {
                    if (status == DriftStatus.behind ||
                        status == DriftStatus.diverged) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '⚠️ Remote changes detected.',
                                style: TextStyle(
                                  color: Colors.deepOrange,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                TextField(
                  controller: figmaController,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'Figma URL',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),

                // Deep Scan Toggle
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.radar,
                        color: Colors.cyanAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Deep Scan (Non-Git)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Switch(
                        value: useDeepScan.value,
                        onChanged: (val) => useDeepScan.value = val,
                        activeColor: Colors.cyanAccent,
                      ),
                    ],
                  ),
                ),

                ElevatedButton(
                  onPressed: () async {
                    // Keeping existing logic but referencing via ref.read
                    final service = ref.read(contextGeneratorServiceProvider);
                    final repo = ref.read(contextRepositoryProvider);
                    final projectPath = Directory.current.path;
                    try {
                      final prompt = await service.generateContextPrompt(
                        projectPath,
                        figmaUrl: figmaController.text,
                        deepScan: useDeepScan.value,
                      );
                      // Extract branch logic...
                      final branchLine = prompt
                          .split('\n')
                          .firstWhere(
                            (l) => l.startsWith('Branch:'),
                            orElse: () => '',
                          );
                      final branch = branchLine
                          .replaceAll('Branch: ', '')
                          .trim();

                      await repo.saveSnapshot(
                        projectPath: projectPath,
                        branch: branch.isEmpty ? 'Unknown' : branch,
                        summary: prompt,
                      );
                      ref.invalidate(recentSnapshotsProvider);
                      await Clipboard.setData(ClipboardData(text: prompt));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Context copied!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  },
                  child: const Text('Generate Context'),
                ),

                // Shadow Prompter Flash Button
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final shadowContext = ref.read(shadowPrompterProvider);
                    if (shadowContext.isEmpty) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⏳ Shadow context initializing...'),
                          ),
                        );
                      }
                      await ref
                          .read(shadowPrompterProvider.notifier)
                          .forceUpdate();
                    }

                    // Get fresh val after update
                    // Get fresh val after update
                    final currentShadow = ref.read(shadowPrompterProvider);

                    if (currentShadow.isNotEmpty) {
                      await Clipboard.setData(
                        ClipboardData(text: currentShadow),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⚡ Shadow Context Flashed!'),
                            backgroundColor: Colors.amber,
                            duration: Duration(milliseconds: 800),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.flash_on,
                    color: Colors.amber,
                    size: 18,
                  ),
                  label: const Text(
                    'Flash Context (Instant)',
                    style: TextStyle(color: Colors.amber),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.amber),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: recentSnapshots.when(
                    data: (snapshots) {
                      if (snapshots.isEmpty)
                        return const Center(child: Text('No snapshots yet.'));
                      return ListView.builder(
                        itemCount: snapshots.length,
                        itemBuilder: (context, index) {
                          final snapshot = snapshots[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              title: Text(
                                snapshot['git_branch'] ?? 'Unknown',
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                snapshot['created_at']?.toString().substring(
                                      0,
                                      16,
                                    ) ??
                                    '',
                                style: const TextStyle(fontSize: 10),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.copy, size: 18),
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(
                                      text: snapshot['summary_text'] ?? '',
                                    ),
                                  );
                                  if (context.mounted)
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Copied!')),
                                    );
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
