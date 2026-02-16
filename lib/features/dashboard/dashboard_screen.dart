import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omnicontext/core/services/context_generator_service.dart';
import 'package:omnicontext/features/dashboard/data/context_repository.dart';

import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:omnicontext/core/services/drift_service.dart';

class DashboardScreen extends HookConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentSnapshots = ref.watch(recentSnapshotsProvider);
    final figmaController = useTextEditingController();
    final driftStatusAsync = ref.watch(driftMonitorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('OmniContext Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drift Alert Banner
            driftStatusAsync.when(
              data: (status) {
                if (status == DriftStatus.behind ||
                    status == DriftStatus.diverged) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '⚠️ Remote changes detected (Ahead of local). Please pull changes.',
                            style: TextStyle(color: Colors.deepOrange),
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
              decoration: const InputDecoration(
                labelText: 'Figma Frame URL (Optional)',
                hintText: 'https://www.figma.com/...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final service = ref.read(contextGeneratorServiceProvider);
                final repo = ref.read(contextRepositoryProvider);
                final projectPath = Directory.current.path;

                try {
                  final prompt = await service.generateContextPrompt(
                    projectPath,
                  );
                  debugPrint(prompt);

                  // Extract branch from new Markdown format
                  // Format: Branch: [BranchName]
                  final branchLine = prompt
                      .split('\n')
                      .firstWhere(
                        (l) => l.startsWith('Branch:'),
                        orElse: () => '',
                      );
                  final branch = branchLine.replaceAll('Branch: ', '').trim();

                  await repo.saveSnapshot(
                    projectPath: projectPath,
                    branch: branch.isEmpty ? 'Unknown' : branch,
                    summary: prompt,
                  );

                  // Refresh list
                  ref.invalidate(recentSnapshotsProvider);

                  // Copy to Clipboard
                  await Clipboard.setData(ClipboardData(text: prompt));

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Context copied! Paste into your AI.'),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error generating/saving context: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Generate & Save Context'),
            ),
            const SizedBox(height: 20),
            const Text(
              'History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: recentSnapshots.when(
                data: (snapshots) {
                  if (snapshots.isEmpty) {
                    return const Center(child: Text('No snapshots yet.'));
                  }
                  return ListView.builder(
                    itemCount: snapshots.length,
                    itemBuilder: (context, index) {
                      final snapshot = snapshots[index];
                      final summary = snapshot['summary_text'] as String? ?? '';

                      return Card(
                        child: ListTile(
                          title: Text(
                            snapshot['git_branch'] ?? 'Unknown Branch',
                          ),
                          subtitle: Text(
                            snapshot['created_at']?.toString() ?? '',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: summary),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Snapshot copied to clipboard!',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
