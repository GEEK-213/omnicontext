import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:http/http.dart' as http;
import 'package:omnicontext/core/providers/active_project_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

class OnboardingScreen extends HookConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = useState(0); // 0 = Project, 1 = Ollama, 2 = Done
    final selectedPath = useState<String?>(null);
    final ollamaStatus = useState<String>(
      'idle',
    ); // idle | checking | ok | error
    final ollamaModel = useState<String>('–');

    Future<void> checkOllama() async {
      ollamaStatus.value = 'checking';
      try {
        final res = await http
            .get(Uri.parse('http://localhost:11434/api/tags'))
            .timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final models = (body['models'] as List<dynamic>?) ?? [];
          if (models.isNotEmpty) {
            ollamaModel.value = (models.first as Map)['name'] as String? ?? '–';
          }
          ollamaStatus.value = 'ok';
        } else {
          ollamaStatus.value = 'error';
        }
      } catch (_) {
        ollamaStatus.value = 'error';
      }
    }

    Future<void> finish() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);
      if (selectedPath.value != null) {
        ref.read(activeProjectProvider.notifier).setPath(selectedPath.value!);
      }
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    }

    // ── Step widgets ──────────────────────────────────────────────────────────

    Widget buildStep0() {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.folder_open,
            color: Color(0xFF00E5FF),
            size: 48,
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            'SELECT YOUR PROJECT',
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'OmniContext will monitor this folder for changes.',
            style: GoogleFonts.roboto(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (selectedPath.value != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withOpacity(0.08),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withOpacity(0.5),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                selectedPath.value!,
                style: GoogleFonts.firaCode(
                  color: const Color(0xFF00E5FF),
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final dir = await FilePicker.platform.getDirectoryPath();
              if (dir != null) selectedPath.value = dir;
            },
            icon: const Icon(Icons.folder_open, size: 18),
            label: Text(
              'Browse Folder',
              style: GoogleFonts.orbitron(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF).withOpacity(0.15),
              foregroundColor: const Color(0xFF00E5FF),
              side: const BorderSide(color: Color(0xFF00E5FF)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: selectedPath.value == null ? null : () => step.value = 1,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              'Continue →',
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    Widget buildStep1() {
      final statusColor = switch (ollamaStatus.value) {
        'ok' => Colors.greenAccent,
        'error' => Colors.redAccent,
        'checking' => Colors.amber,
        _ => Colors.white30,
      };
      final statusText = switch (ollamaStatus.value) {
        'ok' => '✅  Ollama is running — model: ${ollamaModel.value}',
        'error' => '❌  Cannot reach Ollama. Start it with: ollama serve',
        'checking' => '⏳  Checking...',
        _ => 'Press Check to verify Ollama is running.',
      };

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.smart_toy,
            color: Colors.cyanAccent,
            size: 48,
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            'CONNECT AI ENGINE',
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'OmniContext uses a local Ollama server.\nNo data ever leaves your machine.',
            style: GoogleFonts.roboto(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black26,
              border: Border.all(color: statusColor.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: GoogleFonts.firaCode(color: statusColor, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: checkOllama,
            icon: ollamaStatus.value == 'checking'
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.cyanAccent,
                    ),
                  )
                : const Icon(Icons.wifi_tethering, size: 16),
            label: Text(
              'Check Connection',
              style: GoogleFonts.orbitron(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.cyanAccent,
              side: const BorderSide(color: Colors.cyanAccent),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => step.value = 0,
                child: Text(
                  '← Back',
                  style: GoogleFonts.roboto(color: Colors.white38),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => step.value = 2,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  'Continue →',
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    Widget buildStep2() {
      final features = [
        (
          Icons.bolt,
          '⚡ Generate Context',
          'One-tap AI context snapshot copied to clipboard.',
        ),
        (
          Icons.search,
          '🔍 Semantic Search',
          'Search your codebase by meaning, not just keywords.',
        ),
        (
          Icons.merge_type,
          '🤖 AI Mediator',
          'Instant AI analysis when Git drift is detected.',
        ),
        (
          Icons.history,
          '📜 Context History',
          'All your snapshots saved and searchable.',
        ),
      ];

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.rocket_launch,
            color: Color(0xFF00E5FF),
            size: 48,
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 20),
          Text(
            'YOU\'RE ALL SET',
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(f.$1, size: 16, color: Colors.white54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.$2,
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          f.$3,
                          style: GoogleFonts.roboto(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: finish,
            icon: const Icon(Icons.rocket_launch, size: 18),
            label: Text(
              'Launch OmniContext',
              style: GoogleFonts.orbitron(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      );
    }

    // Step indicator
    Widget buildStepDots() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final active = i == step.value;
          return AnimatedContainer(
            duration: 200.ms,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? const Color(0xFF00E5FF) : Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      );
    }

    // ── Main scaffold ─────────────────────────────────────────────────────────
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E1E1E).withOpacity(0.98),
                const Color(0xFF000000).withOpacity(0.95),
              ],
            ),
            border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              // Drag area / mini title bar
              Container(
                height: 40,
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.terminal,
                      color: Color(0xFF00E5FF),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'OMNICONTEXT — SETUP',
                      style: GoogleFonts.orbitron(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => windowManager.close(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white38,
                        size: 16,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Step content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  child: AnimatedSwitcher(
                    duration: 300.ms,
                    child: KeyedSubtree(
                      key: ValueKey(step.value),
                      child: switch (step.value) {
                        0 => buildStep0(),
                        1 => buildStep1(),
                        _ => buildStep2(),
                      },
                    ),
                  ),
                ),
              ),

              // Step dots
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: buildStepDots(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
