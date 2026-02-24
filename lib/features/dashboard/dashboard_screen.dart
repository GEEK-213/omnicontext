import 'dart:io';
import 'package:flutter/material.dart';
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
import 'package:omnicontext/features/templates/template_picker_sheet.dart';
import 'package:omnicontext/main.dart'; // Import main to access hotkeyTriggerProvider
import 'package:omnicontext/core/services/drift_service.dart';
import 'package:omnicontext/core/services/sync_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:omnicontext/core/services/ai_summarizer_service.dart';
import 'package:omnicontext/core/services/git_service.dart';
import 'package:omnicontext/core/services/commit_message_service.dart';
import 'package:omnicontext/core/services/embedding_service.dart';
import 'package:omnicontext/core/services/websocket_service.dart';
import 'package:omnicontext/features/dashboard/widgets/terminal_history_panel.dart';
import 'package:omnicontext/core/plugins/plugin_registry.dart';
import 'package:omnicontext/core/plugins/figma_plugin.dart';
import 'package:omnicontext/core/plugins/jira_plugin.dart';

// --- PROVIDERS FOR REAL DATA ---
final gitBranchesProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, path) async {
      return ref.read(gitServiceProvider).getBranches(path);
    });

final currentBranchProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, path) async {
    return ref.read(gitServiceProvider).getCurrentBranch(path);
  },
);

final projectFilesProvider = FutureProvider.autoDispose
    .family<List<FileSystemEntity>, String>((ref, path) async {
      final dir = Directory(path);
      if (!await dir.exists()) return [];
      try {
        final entities = await dir.list().toList();
        entities.sort((a, b) {
          if (a is Directory && b is File) return -1;
          if (a is File && b is Directory) return 1;
          return a.path.compareTo(b.path);
        });
        return entities;
      } catch (e) {
        return [];
      }
    });

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

    // Initialize AI Service (warm up key cache)
    useEffect(() {
      // Start the local WebSocket Server for VS Code companion
      ref.read(websocketServiceProvider.notifier).startServer();
      // Register built-in plugins
      ref.read(pluginRegistryProvider.notifier)
        ..registerPlugin(FigmaPlugin())
        ..registerPlugin(JiraPlugin());

      SharedPreferences.getInstance().then((prefs) {
        final geminiKey = prefs.getString('GEMINI_API_KEY') ?? '';
        final openAiKey = prefs.getString('OPENAI_API_KEY') ?? '';
        if (geminiKey.isNotEmpty || openAiKey.isNotEmpty) {
          ref
              .read(aiSummarizerProvider.notifier)
              .initialize(geminiKey, openAiKey: openAiKey);
        }
        if (geminiKey.isNotEmpty) {
          ref.read(embeddingServiceProvider.notifier).initialize(geminiKey);
        }
      });
      return null;
    }, []);

    final searchFocusNode = useFocusNode();

    final isMiniMode = useState(false);
    final useDeepScan = useState(false);
    final isHovered = useState(false);
    final sourceStrategy = useState('local'); // 'local' or 'git'

    // Intelligence Console State
    final searchController = useTextEditingController();
    final searchResults = useState<List<Map<String, dynamic>>>([]);
    final isIndexing = useState(false);

    // AI Mediator State
    final driftAnalysis = useState<String?>(null);
    final isAnalyzingDrift = useState(false);

    // Git Pull State
    final isPullingGit = useState(false);
    final gitPullResult = useState<String?>(null);

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

    // Listen to the global hotkey trigger to focus the search bar
    ref.listen(hotkeyTriggerProvider, (previous, next) {
      if (next > 0) {
        // Ensure not mini mode
        if (isMiniMode.value) {
          setWindowSize(false);
        }
        // Focus search input and select all text
        searchFocusNode.requestFocus();
        searchController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: searchController.text.length,
        );
      }
    });

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
                        sourceStrategy,
                        searchController,
                        searchResults,
                        isIndexing,
                        driftAnalysis,
                        isAnalyzingDrift,
                        isPullingGit,
                        gitPullResult,
                        searchFocusNode,
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
    AsyncValue<DriftInfo> driftStatusAsync,
    AsyncValue<List<Map<String, dynamic>>> recentSnapshots,
    ValueNotifier<bool> useDeepScan,
    AsyncValue<String?> activeProjectAsync,
    ValueNotifier<String> sourceStrategy,
    TextEditingController searchController,
    ValueNotifier<List<Map<String, dynamic>>> searchResults,
    ValueNotifier<bool> isIndexing,
    ValueNotifier<String?> driftAnalysis,
    ValueNotifier<bool> isAnalyzingDrift,
    ValueNotifier<bool> isPullingGit,
    ValueNotifier<String?> gitPullResult,
    FocusNode searchFocusNode,
  ) {
    return Column(
      children: [
        // 1. Custom Title Bar
        _buildTitleBar(context, ref, onShrink),

        // 2. Main Content (3 Columns)
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LEFT: EXPLORER (Flex 2)
              Expanded(
                flex: 2,
                child: _buildExplorerPanel(context, ref, activeProjectAsync),
              ),

              // CENTER: LIVE CORE (Flex 5)
              Expanded(
                flex: 5,
                child: _buildCenterConsole(
                  context,
                  ref,
                  activeProjectAsync,
                  driftStatusAsync,
                  recentSnapshots,
                  searchController,
                  searchResults,
                  isIndexing,
                  driftAnalysis,
                  isAnalyzingDrift,
                  isPullingGit,
                  gitPullResult,
                  searchFocusNode,
                ),
              ),

              // RIGHT: INTEGRATIONS (Flex 3)
              Expanded(
                flex: 3,
                child: _buildIntegrationsPanel(
                  context,
                  ref,
                  figmaController,
                  useDeepScan,
                  activeProjectAsync,
                  sourceStrategy,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- COLUMN 1: EXPLORER ---
  Widget _buildExplorerPanel(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<String?> activeProjectAsync,
  ) {
    final projectPath = activeProjectAsync.value;
    final branchesAsync = projectPath != null
        ? ref.watch(gitBranchesProvider(projectPath))
        : const AsyncValue.data(<String>[]);
    final currentBranchAsync = projectPath != null
        ? ref.watch(currentBranchProvider(projectPath))
        : const AsyncValue.data('');
    final filesAsync = projectPath != null
        ? ref.watch(projectFilesProvider(projectPath))
        : const AsyncValue.data(<FileSystemEntity>[]);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2746).withOpacity(0.5),
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPanelHeader('EXPLORER', Icons.folder_open),
          Expanded(
            child: projectPath == null
                ? Center(
                    child: Text(
                      'NO PROJECT SELECTED',
                      style: GoogleFonts.orbitron(
                        color: Colors.white30,
                        fontSize: 10,
                      ),
                    ),
                  )
                : filesAsync.when(
                    data: (files) => ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final entity = files[index];
                        final name = entity.path
                            .split(Platform.pathSeparator)
                            .last;
                        final isDir = entity is Directory;
                        return _buildExplorerItem(
                          name,
                          isFolder: isDir,
                          level: 0,
                        );
                      },
                    ),
                    loading: () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (err, stack) => Center(
                      child: Text(
                        'ERROR: $err',
                        style: const TextStyle(color: Colors.red, fontSize: 10),
                      ),
                    ),
                  ),
          ),
          // BRANCHES SECTION
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BRANCHES',
                  style: GoogleFonts.orbitron(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                branchesAsync.when(
                  data: (branches) {
                    if (branches.isEmpty) {
                      return const Text(
                        'No git repository',
                        style: TextStyle(color: Colors.white30, fontSize: 10),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: branches.take(5).map((branch) {
                        final isCurrent = branch == currentBranchAsync.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                color: isCurrent
                                    ? const Color(0xFF00E5FF)
                                    : Colors.grey,
                                size: 8,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  branch,
                                  style: GoogleFonts.firaCode(
                                    color: isCurrent
                                        ? const Color(0xFF00E5FF)
                                        : Colors.grey,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const LinearProgressIndicator(minHeight: 1),
                  error: (_, __) => const Text(
                    'Git Error',
                    style: TextStyle(color: Colors.red, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplorerItem(
    String name, {
    required bool isFolder,
    required int level,
    bool isActive = false,
    bool isModified = false,
    String? modificationType,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: EdgeInsets.only(
        left: 8.0 + (level * 16),
        top: 6,
        bottom: 6,
        right: 8,
      ),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF00E5FF).withOpacity(0.1) : null,
        border: isActive
            ? const Border(left: BorderSide(color: Color(0xFF00E5FF), width: 2))
            : null,
      ),
      child: Row(
        children: [
          Icon(
            isFolder ? Icons.keyboard_arrow_down : Icons.code,
            size: 14,
            color: isFolder
                ? Colors.white70
                : (isActive ? const Color(0xFF00E5FF) : Colors.blueGrey),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.firaCode(
                color: isActive ? const Color(0xFF00E5FF) : Colors.white70,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (modificationType != null)
            Text(
              modificationType,
              style: GoogleFonts.firaCode(
                color: Colors.amber,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (isModified && modificationType == null)
            Text(
              'M',
              style: GoogleFonts.firaCode(
                color: Colors.greenAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  // --- COLUMN 2: CENTER CONSOLE ---
  Widget _buildCenterConsole(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<String?> activeProjectAsync,
    AsyncValue<DriftInfo> driftStatusAsync,
    AsyncValue<List<Map<String, dynamic>>> recentSnapshots,
    TextEditingController searchController,
    ValueNotifier<List<Map<String, dynamic>>> searchResults,
    ValueNotifier<bool> isIndexing,
    ValueNotifier<String?> driftAnalysis,
    ValueNotifier<bool> isAnalyzingDrift,
    ValueNotifier<bool> isPullingGit,
    ValueNotifier<String?> gitPullResult,
    FocusNode searchFocusNode,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      color: Colors.black.withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // 1. DRIFT WARNING BANNER + AI MEDIATOR
          driftStatusAsync.when(
            data: (info) {
              if (info.status == DriftStatus.unknown ||
                  info.status == DriftStatus.error) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Git Branch Visualizer ─────────────────────────────────
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      border: Border.all(color: Colors.white12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${info.ahead}',
                              style: GoogleFonts.orbitron(
                                fontSize: 24,
                                color: info.ahead > 0
                                    ? Colors.greenAccent
                                    : Colors.white24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'COMMITS AHEAD',
                              style: GoogleFonts.orbitron(
                                fontSize: 9,
                                color: info.ahead > 0
                                    ? Colors.green.shade200
                                    : Colors.white54,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 30, color: Colors.white12),
                        Column(
                          children: [
                            Text(
                              '${info.behind}',
                              style: GoogleFonts.orbitron(
                                fontSize: 24,
                                color: info.behind > 0
                                    ? Colors.orangeAccent
                                    : Colors.white24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'COMMITS BEHIND',
                              style: GoogleFonts.orbitron(
                                fontSize: 9,
                                color: info.behind > 0
                                    ? Colors.orange.shade200
                                    : Colors.white54,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Show existing pull warning ONLY if we are behind or diverged
                  if (info.status == DriftStatus.behind ||
                      info.status == DriftStatus.diverged) ...[
                    // ── Orange drift warning ─────────────────────────────────
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3E2723).withOpacity(0.85),
                        border: Border.all(color: Colors.orangeAccent),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orangeAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DRIFT DETECTED',
                                  style: GoogleFonts.orbitron(
                                    color: Colors.orangeAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  'Remote is ahead — pull required.',
                                  style: GoogleFonts.roboto(
                                    color: Colors.orange.shade100,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── AI Analyze button / loading state ──────────────────
                    if (isAnalyzingDrift.value)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          border: Border.all(
                            color: Colors.cyanAccent.withOpacity(0.4),
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.cyanAccent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Qwen is reading remote changes...',
                              style: GoogleFonts.firaCode(
                                color: Colors.cyanAccent,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                                final projectPath = activeProjectAsync.value;
                                if (projectPath == null) return;
                                isAnalyzingDrift.value = true;
                                driftAnalysis.value = null;
                                try {
                                  final rawDiff = await ref
                                      .read(driftServiceProvider)
                                      .getRemoteDiffSummary(projectPath);
                                  final explanation = await ref
                                      .read(aiSummarizerProvider.notifier)
                                      .summarizeDrift(rawDiff);
                                  driftAnalysis.value = explanation;
                                } catch (e) {
                                  driftAnalysis.value = '❌ Error: $e';
                                } finally {
                                  isAnalyzingDrift.value = false;
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.cyanAccent,
                                side: const BorderSide(
                                  color: Colors.cyanAccent,
                                  width: 1,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              icon: const Icon(Icons.smart_toy, size: 16),
                              label: Text(
                                'AI Analyze Drift',
                                style: GoogleFonts.orbitron(fontSize: 11),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: isPullingGit.value
                                  ? null
                                  : () async {
                                      final projectPath =
                                          activeProjectAsync.value;
                                      if (projectPath == null) return;
                                      isPullingGit.value = true;
                                      gitPullResult.value = null;
                                      try {
                                        final result = await ref
                                            .read(driftServiceProvider)
                                            .pullAndMerge(projectPath);
                                        gitPullResult.value = result;
                                        ref.invalidate(driftMonitorProvider);
                                        ref.invalidate(gitBranchesProvider);
                                      } catch (e) {
                                        gitPullResult.value = '❌ Error: $e';
                                      } finally {
                                        isPullingGit.value = false;
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.greenAccent,
                                side: const BorderSide(
                                  color: Colors.greenAccent,
                                  width: 1,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              icon: isPullingGit.value
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.greenAccent,
                                      ),
                                    )
                                  : const Icon(Icons.download, size: 16),
                              label: Text(
                                isPullingGit.value
                                    ? 'Pulling...'
                                    : '⚡ Pull Now',
                                style: GoogleFonts.orbitron(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Git Pull result panel ────────────────────────────────
                    if (gitPullResult.value != null &&
                        gitPullResult.value!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          border: Border.all(
                            color:
                                gitPullResult.value!.toLowerCase().contains(
                                      'conflict',
                                    ) ||
                                    gitPullResult.value!.toLowerCase().contains(
                                      'error',
                                    ) ||
                                    gitPullResult.value!.toLowerCase().contains(
                                      'failed',
                                    )
                                ? Colors.redAccent.withOpacity(0.5)
                                : Colors.greenAccent.withOpacity(0.5),
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  gitPullResult.value!.toLowerCase().contains(
                                            'conflict',
                                          ) ||
                                          gitPullResult.value!
                                              .toLowerCase()
                                              .contains('error') ||
                                          gitPullResult.value!
                                              .toLowerCase()
                                              .contains('failed')
                                      ? Icons.error_outline
                                      : Icons.check_circle_outline,
                                  size: 14,
                                  color:
                                      gitPullResult.value!
                                              .toLowerCase()
                                              .contains('conflict') ||
                                          gitPullResult.value!
                                              .toLowerCase()
                                              .contains('error') ||
                                          gitPullResult.value!
                                              .toLowerCase()
                                              .contains('failed')
                                      ? Colors.redAccent
                                      : Colors.greenAccent,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'GIT PULL RESULT',
                                  style: GoogleFonts.orbitron(
                                    color:
                                        gitPullResult.value!
                                                .toLowerCase()
                                                .contains('conflict') ||
                                            gitPullResult.value!
                                                .toLowerCase()
                                                .contains('error') ||
                                            gitPullResult.value!
                                                .toLowerCase()
                                                .contains('failed')
                                        ? Colors.redAccent
                                        : Colors.greenAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white54,
                                  ),
                                  onPressed: () => gitPullResult.value = null,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              gitPullResult.value!,
                              style: GoogleFonts.firaCode(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── AI Mediator result panel ─────────────────────────────
                    if (driftAnalysis.value != null &&
                        driftAnalysis.value!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A1628),
                          border: Border.all(
                            color: Colors.cyanAccent.withOpacity(0.5),
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.withOpacity(0.08),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.smart_toy,
                                    size: 14,
                                    color: Colors.cyanAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'AI MEDIATOR — QWEN ANALYSIS',
                                    style: GoogleFonts.orbitron(
                                      color: Colors.cyanAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () => driftAnalysis.value = null,
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Colors.white38,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Dismiss',
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: SelectableText(
                                driftAnalysis.value!,
                                style: GoogleFonts.roboto(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12,
                                  height: 1.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ], // End of behind/diverged specific children
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // 2. INTELLIGENCE CONSOLE (Replaces Terminal)
          _buildIntelligenceConsole(
            context,
            ref,
            activeProjectAsync.value,
            searchController,
            searchResults,
            isIndexing,
            searchFocusNode,
          ),

          const SizedBox(height: 16),
          // 3. TERMINAL HISTORY PANEL
          const Expanded(flex: 2, child: TerminalHistoryPanel()),

          const SizedBox(height: 16),
          // 4. CONTEXT HISTORY (Title)
          Row(
            children: [
              Flexible(
                child: Text(
                  'CONTEXT HISTORY',
                  style: GoogleFonts.orbitron(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              Text(
                'View All',
                style: GoogleFonts.roboto(
                  color: const Color(0xFF00E5FF),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 5. HISTORY LIST
          Expanded(
            flex: 3,
            child: recentSnapshots.when(
              data: (snapshots) {
                return ListView.separated(
                  itemCount: snapshots.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (c, i) {
                    final s = snapshots[i];
                    return _buildHistoryCard(context, s);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Center(child: Text('Error loading history')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    Map<String, dynamic> snapshot,
  ) {
    final createdAt = DateTime.parse(
      snapshot['created_at'] ?? DateTime.now().toIso8601String(),
    ).toLocal();
    final timeAgo = DateTime.now().difference(createdAt);
    final timeLabel = timeAgo.inMinutes < 60
        ? '${timeAgo.inMinutes}m ago'
        : '${timeAgo.inHours}h ago';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2746).withOpacity(0.5),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withOpacity(0.2), // Purple tint
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '#${(snapshot['id'] as String).substring(0, 4)}',
            style: GoogleFonts.firaCode(
              color: const Color(0xFF8A84FF),
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
        title: Text(
          snapshot['git_branch'] ?? 'HEAD',
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            (snapshot['summary_text'] as String?)?.split('\n').first ??
                'Context Snapshot',
            style: GoogleFonts.roboto(color: Colors.white54, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Text(
          timeLabel,
          style: GoogleFonts.roboto(color: Colors.white30, fontSize: 11),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.black26,
            child: SelectableText(
              snapshot['summary_text'] ?? 'No summary available.',
              style: GoogleFonts.firaCode(color: Colors.white70, fontSize: 11),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: snapshot['summary_text'] ?? ''),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Context copied to clipboard'),
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('COPY CONTEXT'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF00E5FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- COLUMN 3: INTEGRATIONS ---
  Widget _buildIntegrationsPanel(
    BuildContext context,
    WidgetRef ref,
    TextEditingController figmaController,
    ValueNotifier<bool> useDeepScan,
    AsyncValue<String?> activeProjectAsync,
    ValueNotifier<String> sourceStrategy,
  ) {
    // Local state for strategy selector - HOISTED to build() because of LayoutBuilder context issues
    // final sourceStrategy = useState('local'); // 'local' or 'git'

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2746).withOpacity(0.3),
        border: Border(left: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPanelHeader('AI ROUTING', Icons.settings_input_component),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // MODEL SELECTOR
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      border: Border.all(color: Colors.white10),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFF8A84FF),
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Gemini 1.5 Flash',
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.unfold_more,
                          color: Colors.white30,
                          size: 16,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  // SETTINGS GRID
                  Row(
                    children: [
                      Expanded(
                        child: _buildParamCard(
                          'TEMPERATURE',
                          '0.7',
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildParamCard(
                          'CONTEXT WIN',
                          '1M',
                          Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _buildPanelHeader('CONTEXT SOURCE', Icons.source),

                  // SOURCE STRATEGY TOGGLE
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => sourceStrategy.value = 'local',
                            child: Container(
                              decoration: BoxDecoration(
                                color: sourceStrategy.value == 'local'
                                    ? const Color(0xFF00E5FF).withOpacity(0.2)
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(3),
                                  bottomLeft: Radius.circular(3),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'LOCAL SCAN',
                                style: GoogleFonts.orbitron(
                                  color: sourceStrategy.value == 'local'
                                      ? const Color(0xFF00E5FF)
                                      : Colors.white30,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(width: 1, color: Colors.white10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => sourceStrategy.value = 'git',
                            child: Container(
                              decoration: BoxDecoration(
                                color: sourceStrategy.value == 'git'
                                    ? const Color(0xFF00E5FF).withOpacity(0.2)
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(3),
                                  bottomRight: Radius.circular(3),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'GIT DIFF',
                                style: GoogleFonts.orbitron(
                                  color: sourceStrategy.value == 'git'
                                      ? const Color(0xFF00E5FF)
                                      : Colors.white30,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),
                  // DEEP SCAN TOGGLE
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'DEEP SCAN MODE',
                          style: GoogleFonts.orbitron(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Switch(
                        value: useDeepScan.value,
                        onChanged: (val) => useDeepScan.value = val,
                        activeThumbColor: const Color(0xFF00E5FF),
                        activeTrackColor: const Color(
                          0xFF00E5FF,
                        ).withOpacity(0.3),
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: Colors.white10,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  if (useDeepScan.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Will analyze file contents and relationships. Slower but more comprehensive.',
                        style: GoogleFonts.roboto(
                          color: Colors.white38,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),
                  _buildPanelHeader('INTEGRATIONS', Icons.link),

                  // DYNAMIC PLUGINS
                  ...ref
                      .watch(pluginRegistryProvider)
                      .map(
                        (plugin) => Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: plugin.buildPanel(context, ref),
                        ),
                      ),

                  const SizedBox(height: 12),
                  _buildPanelHeader('ACTIVE MCP SERVERS', Icons.dns),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white10),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.dns_outlined,
                          size: 24,
                          color: Colors.white12,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'NO ACTIVE SERVERS',
                          style: GoogleFonts.orbitron(
                            color: Colors.white30,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: null,
                          child: Text(
                            'SCAN FOR SERVERS',
                            style: GoogleFonts.orbitron(
                              color: const Color(0xFF00E5FF).withOpacity(0.5),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  // SHADOW PROMPT
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6C63FF).withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF6C63FF).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.psychology,
                          color: Color(0xFF6C63FF),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SHADOW PROMPT',
                                style: GoogleFonts.orbitron(
                                  color: const Color(0xFF6C63FF),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'AI suggests improvements to your query as you type.',
                                style: GoogleFonts.roboto(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: true, // Always on for now
                          onChanged: (val) {},
                          activeThumbColor: const Color(0xFF6C63FF),
                          activeTrackColor: const Color(
                            0xFF6C63FF,
                          ).withOpacity(0.3),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100), // Bottom padding for button area
                ],
              ),
            ),
          ),

          // AUTO-COMMIT GENERATOR BUTTON
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              onPressed: activeProjectAsync.value == null
                  ? null
                  : () async {
                      final projectPath = activeProjectAsync.value!;
                      final commitService = ref.read(
                        commitMessageServiceProvider.notifier,
                      );

                      // Scaffold messenger for loading state inside an async gap
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Analyzing staged changes...'),
                          duration: Duration(seconds: 1),
                        ),
                      );

                      final message = await commitService.generateCommitMessage(
                        projectPath,
                      );

                      if (message.startsWith('Error:') ||
                          message.startsWith('No staged changes')) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(message),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                        return;
                      }

                      await Clipboard.setData(ClipboardData(text: message));

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('COMMIT MESSAGE GENERATED & COPIED'),
                            backgroundColor: Color(0xFF00E5FF),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E2746),
                foregroundColor: const Color(0xFF00E5FF),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: const BorderSide(color: Color(0xFF00E5FF), width: 1),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.edit_note, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'GENERATE COMMIT MSG',
                      style: GoogleFonts.orbitron(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // BIG GENERATE BUTTON (Fixed at bottom)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: activeProjectAsync.value == null
                  ? null
                  : () async {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (context) => TemplatePickerSheet(
                          onTemplateSelected: (template) async {
                            final service = ref.read(
                              contextGeneratorServiceProvider,
                            );
                            final repo = ref.read(contextRepositoryProvider);
                            final projectPath = activeProjectAsync.value!;

                            try {
                              // Add plugin contexts
                              final pluginContext = await ref
                                  .read(pluginRegistryProvider.notifier)
                                  .gatherPluginContexts(projectPath);

                              // 1. Generate Raw Prompt
                              final rawPrompt = await service
                                  .generateContextPrompt(
                                    projectPath,
                                    pluginContext: pluginContext,
                                    deepScan: useDeepScan.value,
                                    strategy: sourceStrategy.value,
                                  );

                              // 2. Apply Template Scaffold
                              final finalPrompt = template.apply(rawPrompt);

                              // 3. Save Snapshot
                              await repo.saveSnapshot(
                                projectPath: projectPath,
                                branch: 'HEAD',
                                summary: finalPrompt,
                              );

                              // 4. Copy & Notify
                              ref.invalidate(recentSnapshotsProvider);
                              await Clipboard.setData(
                                ClipboardData(text: finalPrompt),
                              );

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'COPIED [${template.name}] CONTEXT PACKET',
                                    ),
                                    backgroundColor: const Color(0xFF00E5FF),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'GENERATE CONTEXT',
                      style: GoogleFonts.orbitron(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPERS ---
  Widget _buildPanelHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
      child: Row(
        children: [
          // Icon(icon, size: 12, color: Colors.white30), // Optional
          // SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              style: GoogleFonts.orbitron(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamCard(String title, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border(bottom: BorderSide(color: accent, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.orbitron(color: Colors.white30, fontSize: 8),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: GoogleFonts.firaCode(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.check_circle, size: 10, color: accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntelligenceConsole(
    BuildContext context,
    WidgetRef ref,
    String? projectPath,
    TextEditingController searchController,
    ValueNotifier<List<Map<String, dynamic>>> searchResults,
    ValueNotifier<bool> isIndexing,
    FocusNode searchFocusNode,
  ) {
    if (projectPath == null) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white10),
        ),
        child: Text(
          'SELECT A PROJECT TO ENABLE INTELLIGENCE',
          style: GoogleFonts.orbitron(color: Colors.white30, fontSize: 10),
        ),
      );
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, size: 16, color: Color(0xFF00E5FF)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'INTELLIGENCE UNIT',
                  style: GoogleFonts.orbitron(
                    color: const Color(0xFF00E5FF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
              if (isIndexing.value)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00E5FF),
                  ),
                )
              else
                // FittedBox auto-scales buttons down to fit available width
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () async {
                          isIndexing.value = true;
                          try {
                            final repo = ref.read(contextRepositoryProvider);
                            final count = await repo.indexLocalFiles(
                              projectPath,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Indexed $count files'),
                                  backgroundColor: const Color(0xFF00E5FF),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceAll('Exception: ', ''),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            isIndexing.value = false;
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'LOCAL',
                          style: GoogleFonts.firaCode(
                            fontSize: 10,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          isIndexing.value = true;
                          try {
                            final repo = ref.read(contextRepositoryProvider);
                            final count = await repo.indexGitFiles(projectPath);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Indexed $count git files'),
                                  backgroundColor: const Color(0xFF00E5FF),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceAll('Exception: ', ''),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            isIndexing.value = false;
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'GIT',
                          style: GoogleFonts.firaCode(
                            fontSize: 10,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white12),
            ),
            child: TextField(
              controller: searchController,
              focusNode: searchFocusNode,
              style: GoogleFonts.firaCode(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search codebase (e.g. "auth provider")...',
                hintStyle: const TextStyle(color: Colors.white24),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 14,
                  color: Colors.white30,
                ),
              ),
              onSubmitted: (query) async {
                if (query.trim().isEmpty) return;
                isIndexing.value = true;
                try {
                  final repo = ref.read(contextRepositoryProvider);
                  final results = await repo.searchCodebase(query);
                  searchResults.value = results;

                  if (results.isEmpty && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No semantic matches found.'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          e.toString().replaceAll('Exception: ', ''),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  isIndexing.value = false;
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: searchResults.value.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.search_off,
                          color: Colors.white12,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'NO ACTIVE SEARCH RESULTS',
                          style: GoogleFonts.orbitron(
                            color: Colors.white12,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: searchResults.value.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final item = searchResults.value[index];
                      String snippet = (item['match_snippet'] as String?) ?? '';
                      snippet = snippet
                          .replaceAll('<b>', '')
                          .replaceAll('</b>', '')
                          .replaceAll('\n', ' ');

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          (item['file_path'] as String)
                              .split(Platform.pathSeparator)
                              .last,
                          style: GoogleFonts.firaCode(
                            color: const Color(0xFF00E5FF),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['file_path'] as String,
                              style: GoogleFonts.firaCode(
                                color: Colors.white30,
                                fontSize: 9,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '...$snippet...',
                              style: GoogleFonts.robotoMono(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        onTap: () {
                          try {
                            // Desktop VS Code format: code -g <file>
                            Process.run('code', [
                              '-g',
                              item['file_path'] as String,
                            ], runInShell: true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Opened file in VS Code'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to open VS Code: $e'),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar(
    BuildContext context,
    WidgetRef ref,
    VoidCallback onShrink,
  ) {
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
            // PROJECT PICKER
            _buildWindowBtn(Icons.create_new_folder_outlined, () async {
              final selectedDirectory = await FilePicker.platform
                  .getDirectoryPath();
              if (selectedDirectory != null) {
                ref
                    .read(activeProjectProvider.notifier)
                    .setPath(selectedDirectory);
              }
            }),
            const SizedBox(width: 8),
            _buildWindowBtn(
              Icons.settings,
              () => _showSettingsDialog(context, ref),
            ),
            const SizedBox(width: 8),
            _buildWindowBtn(Icons.remove, onShrink),
            const SizedBox(width: 8),
            _buildWindowBtn(Icons.close, () => windowManager.close()),
          ],
        ),
      ),
    );
  }

  Future<void> _showSettingsDialog(BuildContext context, WidgetRef ref) async {
    final prefs = await SharedPreferences.getInstance();
    final currentKey = prefs.getString('GEMINI_API_KEY') ?? '';
    final controller = TextEditingController(text: currentKey);

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: BeveledRectangleBorder(
          side: const BorderSide(color: Color(0xFF00E5FF)),
        ),
        title: Text(
          'SYSTEM CONFIGURATION',
          style: GoogleFonts.orbitron(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GEMINI API KEY',
              style: GoogleFonts.orbitron(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter API Key...',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.black45,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(
              'CANCEL',
              style: GoogleFonts.orbitron(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await prefs.setString('GEMINI_API_KEY', controller.text.trim());
              // Re-initialize services
              final key = controller.text.trim();
              ref.read(aiSummarizerProvider.notifier).initialize(key);
              ref.read(embeddingServiceProvider.notifier).initialize(key);

              if (context.mounted) Navigator.pop(c);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF).withOpacity(0.2),
              foregroundColor: const Color(0xFF00E5FF),
              shape: BeveledRectangleBorder(),
            ),
            child: Text('SAVE CONFIG', style: GoogleFonts.orbitron()),
          ),
        ],
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
}
